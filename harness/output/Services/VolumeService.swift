import Foundation
import MediaPlayer
import AVFoundation

// MARK: - VolumeServiceProtocol

protocol VolumeServiceProtocol: Sendable {
    func ensureMinimumVolume() async
    func restoreVolume() async
}

// MARK: - VolumeService

/// 알람 재생 시 볼륨을 자동으로 80% 이상으로 올리고, 종료 후 원래 볼륨으로 복원하는 서비스.
/// MPVolumeView 슬라이더 방식 사용 — @MainActor에서 UI 조작 필요.
/// actor → @MainActor로 변경: MPVolumeView는 UI 요소이므로 hop 없이 직접 실행.
@MainActor
final class VolumeService: VolumeServiceProtocol, @unchecked Sendable {
    private var originalVolume: Float?
    private var volumeView: MPVolumeView?

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
            originalVolume = nil // 이미 충분히 크므로 복원 불필요
            AppLogger.info("Volume already >= 0.8, no adjustment needed", category: .alarm)
        }
    }

    /// 저장해둔 원래 볼륨으로 복원한다. 저장값이 없으면 아무것도 하지 않는다.
    func restoreVolume() async {
        guard let original = originalVolume else { return }
        setVolumeWithDelay(original)
        originalVolume = nil
        AppLogger.info("Volume restored to \(original)", category: .alarm)
    }

    // MARK: - Private

    /// MPVolumeView 슬라이더를 통해 시스템 볼륨을 설정한다.
    /// 레이아웃 처리를 위해 약간의 딜레이 후 슬라이더 접근.
    private func setVolumeWithDelay(_ volume: Float) {
        // 기존 volumeView 정리
        volumeView?.removeFromSuperview()

        let newVolumeView = MPVolumeView()
        newVolumeView.frame = CGRect(x: -1000, y: -1000, width: 100, height: 100)
        newVolumeView.alpha = 0.01 // 완전 투명하되 레이아웃 유지

        // keyWindow 또는 첫 번째 window 사용 (fallback)
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first

        guard let window else {
            AppLogger.error("No window found for volume adjustment", category: .alarm)
            return
        }

        window.addSubview(newVolumeView)
        self.volumeView = newVolumeView

        // 레이아웃 처리 후 슬라이더 접근 — 0.15초 딜레이
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            if let slider = newVolumeView.subviews.compactMap({ $0 as? UISlider }).first {
                slider.value = volume
                AppLogger.info("Volume slider set to \(volume)", category: .alarm)
            } else {
                // Fallback: 재귀적 서브뷰 탐색
                self?.findAndSetSlider(in: newVolumeView, value: volume)
            }

            // 정리 (약간의 추가 딜레이)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                newVolumeView.removeFromSuperview()
                if self?.volumeView === newVolumeView {
                    self?.volumeView = nil
                }
            }
        }
    }

    /// 서브뷰를 재귀적으로 탐색하여 UISlider를 찾고 값을 설정한다.
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
