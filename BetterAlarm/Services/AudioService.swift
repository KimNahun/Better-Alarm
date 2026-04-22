import Foundation
import AVFoundation

// MARK: - AudioServiceProtocol

protocol AudioServiceProtocol: Sendable {
    func playAlarmSound(soundName: String, isSilent: Bool, loop: Bool) async throws
    func stopAlarmSound() async
    func isEarphoneConnected() async -> Bool
    func startSilentLoop() async
    func stopSilentLoop() async
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
    var isAlarmPlaying: Bool { audioPlayer?.isPlaying ?? false }

    // MARK: - Silent Loop Properties
    private var silentEngine: AVAudioEngine?
    private var silentPlayerNode: AVAudioPlayerNode?
    private var isSilentLoopRunning: Bool = false

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

        // AVAudioSession 설정 — .playback 카테고리 (무음 모드에서도 스피커로 재생)
        // 주의: .defaultToSpeaker는 .playAndRecord 전용이므로 .playback에서 사용 금지
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.duckOthers])
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

    // MARK: - Silent Loop

    /// 무음 PCM 버퍼를 AVAudioEngine으로 무한 루프 재생하여 백그라운드 앱 유지.
    /// 실패해도 throw하지 않고 로그만 남긴다 (크래시 방지).
    func startSilentLoop() async {
        guard !isSilentLoopRunning else { return }

        do {
            // AVAudioSession 설정 (.playback, .mixWithOthers — 다른 오디오 방해 안 함)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let engine = AVAudioEngine()
            let playerNode = AVAudioPlayerNode()

            engine.attach(playerNode)

            guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
                AppLogger.error("Failed to create AVAudioFormat for silent loop", category: .alarm)
                return
            }

            engine.connect(playerNode, to: engine.mainMixerNode, format: format)

            // 무음 PCM 버퍼 생성 (1초 분량, float 채널 기본값 0 = 무음)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100) else {
                AppLogger.error("Failed to create AVAudioPCMBuffer for silent loop", category: .alarm)
                return
            }
            buffer.frameLength = buffer.frameCapacity

            // .loops 옵션으로 무한 반복 스케줄
            await playerNode.scheduleBuffer(buffer, at: nil, options: .loops)

            engine.prepare()
            try engine.start()
            playerNode.play()

            // 거의 무음이지만 0이 아닌 볼륨 — iOS가 "진짜 오디오 재생 중"으로 인식하도록.
            // 0.0이면 iOS가 실제 오디오가 아니라고 판단하여 앱을 suspend할 수 있음.
            engine.mainMixerNode.outputVolume = 0.01

            silentEngine = engine
            silentPlayerNode = playerNode
            isSilentLoopRunning = true

            AppLogger.info("Silent audio loop started", category: .alarm)
        } catch {
            AppLogger.error("Failed to start silent audio loop: \(error)", category: .alarm)
        }
    }

    /// 무음 루프를 정지하고 관련 리소스를 해제한다.
    func stopSilentLoop() async {
        guard isSilentLoopRunning else { return }

        silentPlayerNode?.stop()
        silentEngine?.stop()
        silentPlayerNode = nil
        silentEngine = nil
        isSilentLoopRunning = false

        AppLogger.info("Silent audio loop stopped", category: .alarm)
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
