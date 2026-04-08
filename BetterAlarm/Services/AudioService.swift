import Foundation
import AVFoundation

// MARK: - AudioServiceProtocol

protocol AudioServiceProtocol: Sendable {
    func playAlarmSound(soundName: String, isSilent: Bool, loop: Bool) async throws
    func stopAlarmSound() async
    func isEarphoneConnected() async -> Bool
}

extension AudioServiceProtocol {
    /// 기본값: loop = true
    func playAlarmSound(soundName: String, isSilent: Bool) async throws {
        try await playAlarmSound(soundName: soundName, isSilent: isSilent, loop: true)
    }
}

// MARK: - AudioService

/// AVAudioPlayer를 통한 알람 소리 재생을 담당하는 서비스.
/// isSilentAlarm=true이면 이어폰 연결 여부를 확인하고 이어폰으로만 출력한다.
/// Swift 6: actor로 구현.
actor AudioService: AudioServiceProtocol {
    private var audioPlayer: AVAudioPlayer?
    private let volumeService: VolumeService

    init(volumeService: VolumeService) {
        self.volumeService = volumeService
    }

    // MARK: - Play

    /// 알람 사운드를 재생한다.
    /// - Parameters:
    ///   - soundName: 재생할 사운드 파일명 (번들 내 파일)
    ///   - isSilent: true이면 이어폰 전용 출력
    ///   - loop: true이면 무한 반복 재생
    func playAlarmSound(soundName: String, isSilent: Bool, loop: Bool = true) async throws {
        // 조용한 알람: 이어폰 연결 확인
        if isSilent {
            guard isEarphoneConnected() else {
                throw AlarmError.earphoneNotConnected
            }
        }

        // AVAudioSession 설정 — 무음 모드에서도 스피커로 울리도록
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playback,
            mode: .default,
            options: [.duckOthers, .defaultToSpeaker]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // 볼륨 자동 조절
        await volumeService.ensureMinimumVolume()

        // 사운드 파일 로드 (번들 내 파일만 사용)
        let url: URL
        if soundName == "default" {
            if let bundleURL = Bundle.main.url(forResource: "default_alarm", withExtension: "wav")
                ?? Bundle.main.url(forResource: "default_alarm", withExtension: "mp3") {
                url = bundleURL
            } else {
                AppLogger.error("default_alarm 사운드 파일이 번들에 없습니다", category: .alarm)
                throw AlarmError.soundNotFound(soundName)
            }
        } else {
            if let bundleURL = Bundle.main.url(forResource: soundName, withExtension: "mp3")
                ?? Bundle.main.url(forResource: soundName, withExtension: "wav") {
                url = bundleURL
            } else if let fallback = Bundle.main.url(forResource: "default_alarm", withExtension: "wav")
                        ?? Bundle.main.url(forResource: "default_alarm", withExtension: "mp3") {
                AppLogger.warning("사운드 '\(soundName)' 없음, default_alarm으로 폴백", category: .alarm)
                url = fallback
            } else {
                throw AlarmError.soundNotFound(soundName)
            }
        }

        let player = try AVAudioPlayer(contentsOf: url)
        player.numberOfLoops = loop ? -1 : 0
        player.volume = 1.0
        player.prepareToPlay()
        player.play()
        audioPlayer = player
    }

    // MARK: - Stop

    /// 재생 중인 알람 사운드를 중지하고 볼륨을 복원한다.
    func stopAlarmSound() async {
        audioPlayer?.stop()
        audioPlayer = nil

        await volumeService.restoreVolume()

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Earphone Check

    /// 현재 이어폰(유선/블루투스/AirPlay 포함)이 연결되어 있는지 확인한다.
    func isEarphoneConnected() -> Bool {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        for output in outputs {
            switch output.portType {
            case .headphones,
                 .bluetoothA2DP,
                 .bluetoothHFP,
                 .bluetoothLE,
                 .airPlay,
                 .headsetMic,
                 .usbAudio:
                return true
            default:
                continue
            }
        }
        return false
    }
}
