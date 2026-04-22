import Foundation
import MediaPlayer
import AVFoundation

// MARK: - VolumeServiceProtocol

protocol VolumeServiceProtocol: Sendable {
    func ensureMinimumVolume() async
    func restoreVolume() async
    func startVolumeGuard() async
    func stopVolumeGuard() async
}

// MARK: - VolumeService

/// 알람 재생 시 볼륨을 자동으로 80% 이상으로 올리고, 종료 후 원래 볼륨으로 복원하는 서비스.
/// 알람이 울리는 동안 사용자가 볼륨을 낮추면 다시 80%로 강제 복원.
@MainActor
final class VolumeService: VolumeServiceProtocol, @unchecked Sendable {
    private var originalVolume: Float?
    private var volumeView: MPVolumeView?
    private var volumeGuardTask: Task<Void, Never>?
    private var isGuarding: Bool = false

    nonisolated init() {}

    /// 현재 시스템 볼륨이 0.8 미만이면 0.8로 올리고 원래 값을 저장한다.
    func ensureMinimumVolume() async {
        let session = AVAudioSession.sharedInstance()
        let current = session.outputVolume

        AppLogger.info("Current volume: \(current), threshold: 0.8", category: .alarm)

        if current < 0.8 {
            originalVolume = current
            setVolumeWithDelay(0.8)
        } else {
            originalVolume = nil
            AppLogger.info("Volume already >= 0.8, no adjustment needed", category: .alarm)
        }
    }

    /// 알람이 울리는 동안 볼륨을 80% 이상으로 유지하는 가드를 시작한다.
    /// 사용자가 볼륨을 낮추면 다시 80%로 강제 복원.
    func startVolumeGuard() async {
        isGuarding = true
        volumeGuardTask?.cancel()
        volumeGuardTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.isGuarding else { break }
                let current = AVAudioSession.sharedInstance().outputVolume
                if current < 0.8 {
                    AppLogger.info("Volume dropped to \(current), restoring to 0.8", category: .alarm)
                    self.setVolumeWithDelay(0.8)
                }
            }
        }
    }

    /// 볼륨 가드를 중지한다.
    func stopVolumeGuard() async {
        isGuarding = false
        volumeGuardTask?.cancel()
        volumeGuardTask = nil
    }

    /// 저장해둔 원래 볼륨으로 복원한다.
    func restoreVolume() async {
        await stopVolumeGuard()
        guard let original = originalVolume else { return }
        setVolumeWithDelay(original)
        originalVolume = nil
        AppLogger.info("Volume restored to \(original)", category: .alarm)
    }

    // MARK: - Private

    private func setVolumeWithDelay(_ volume: Float, retryCount: Int = 0) {
        volumeView?.removeFromSuperview()

        let newVolumeView = MPVolumeView()
        newVolumeView.frame = CGRect(x: -1000, y: -1000, width: 100, height: 100)
        newVolumeView.alpha = 0.01

        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first

        guard let window else {
            // Cold launch 시 window가 아직 없으면 최대 3회 재시도 (0.3초 간격)
            if retryCount < 3 {
                AppLogger.warning("No window found for volume adjustment — retry \(retryCount + 1)/3", category: .alarm)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.setVolumeWithDelay(volume, retryCount: retryCount + 1)
                }
            } else {
                AppLogger.error("No window found for volume adjustment after 3 retries", category: .alarm)
            }
            return
        }

        window.addSubview(newVolumeView)
        self.volumeView = newVolumeView

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            if let slider = newVolumeView.subviews.compactMap({ $0 as? UISlider }).first {
                slider.value = volume
                AppLogger.info("Volume slider set to \(volume)", category: .alarm)
            } else {
                self?.findAndSetSlider(in: newVolumeView, value: volume)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                newVolumeView.removeFromSuperview()
                if self?.volumeView === newVolumeView {
                    self?.volumeView = nil
                }
            }
        }
    }

    private func findAndSetSlider(in view: UIView, value: Float) {
        for subview in view.subviews {
            if let slider = subview as? UISlider {
                slider.value = value
                AppLogger.info("Volume slider found (recursive) and set to \(value)", category: .alarm)
                return
            }
            findAndSetSlider(in: subview, value: value)
        }
        AppLogger.warning("No UISlider found in MPVolumeView", category: .alarm)
    }
}
