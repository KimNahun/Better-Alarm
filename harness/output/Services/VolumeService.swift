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
/// Swift 6: actor로 구현하여 스레드 안전성 보장.
actor VolumeService: VolumeServiceProtocol {
    private var originalVolume: Float?

    /// 현재 시스템 볼륨이 0.8 미만이면 0.8로 올리고 원래 값을 저장한다.
    func ensureMinimumVolume() async {
        let current = await fetchCurrentVolume()
        if current < 0.8 {
            originalVolume = current
            await setVolume(0.8)
        } else {
            originalVolume = nil // 이미 충분히 크므로 복원 불필요
        }
    }

    /// 저장해둔 원래 볼륨으로 복원한다. 저장값이 없으면 아무것도 하지 않는다.
    func restoreVolume() async {
        guard let original = originalVolume else { return }
        await setVolume(original)
        originalVolume = nil
    }

    // MARK: - Private Helpers

    @MainActor
    private func fetchCurrentVolume() -> Float {
        AVAudioSession.sharedInstance().outputVolume
    }

    /// MPVolumeView의 숨겨진 슬라이더를 통해 시스템 볼륨을 설정한다.
    /// UI 조작이므로 MainActor에서 실행해야 한다.
    @MainActor
    private func setVolume(_ volume: Float) {
        let volumeView = MPVolumeView()
        // MPVolumeView를 화면에 추가하지 않으면 슬라이더에 접근할 수 없으므로
        // 화면 밖 위치에 추가하고 즉시 제거하는 패턴 사용
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        volumeView.frame = CGRect(x: -1000, y: -1000, width: 1, height: 1)
        window?.addSubview(volumeView)

        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            slider.value = volume
        }
        volumeView.removeFromSuperview()
    }
}
