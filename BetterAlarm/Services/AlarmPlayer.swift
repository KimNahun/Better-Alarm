import Foundation
import AVFoundation
import UIKit

// MARK: - Alarm Player for Sound Playback

class AlarmPlayer: NSObject {
    static let shared = AlarmPlayer()

    private var audioPlayer: AVAudioPlayer?
    private var alarmTimer: Timer?
    private var isPlaying = false

    private override init() {
        super.init()
        setupAudioSession()
        setupNotificationObservers()
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            break
        case .ended:
            if isPlaying {
                audioPlayer?.play()
            }
        @unknown default:
            break
        }
    }

    // MARK: - Play Alarm Sound

    func playAlarmSound(named soundName: String = "default") {
        let soundURL: URL?

        if let customURL = Bundle.main.url(forResource: soundName, withExtension: "mp3") {
            soundURL = customURL
        } else if let customURL = Bundle.main.url(forResource: soundName, withExtension: "wav") {
            soundURL = customURL
        } else if let customURL = Bundle.main.url(forResource: soundName, withExtension: "m4a") {
            soundURL = customURL
        } else if let defaultURL = Bundle.main.url(forResource: "alarm_default", withExtension: "mp3") {
            soundURL = defaultURL
        } else {
            playSystemAlarmSound()
            return
        }

        guard let url = soundURL else {
            playSystemAlarmSound()
            return
        }

        do {
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Failed to play alarm sound: \(error)")
            playSystemAlarmSound()
        }
    }

    private func playSystemAlarmSound() {
        isPlaying = true

        alarmTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard self?.isPlaying == true else {
                self?.alarmTimer?.invalidate()
                return
            }
            AudioServicesPlaySystemSound(SystemSoundID(1005))
        }

        AudioServicesPlaySystemSound(SystemSoundID(1005))
    }

    // MARK: - Stop Alarm

    func stopAlarm() {
        audioPlayer?.stop()
        audioPlayer = nil
        alarmTimer?.invalidate()
        alarmTimer = nil
        isPlaying = false
    }

    // MARK: - Snooze

    func snoozeAlarm(_ alarm: Alarm, minutes: Int = 5) {
        stopAlarm()

        let snoozeDate = Date().addingTimeInterval(TimeInterval(minutes * 60))

        // Post notification for snooze
        NotificationCenter.default.post(
            name: .alarmSnoozed,
            object: nil,
            userInfo: ["alarm": alarm, "snoozeDate": snoozeDate]
        )
    }

    // MARK: - Check if Playing

    var isAlarmPlaying: Bool {
        return isPlaying
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let alarmTriggered = Notification.Name("alarmTriggered")
    static let alarmSnoozed = Notification.Name("alarmSnoozed")
    static let alarmDismissed = Notification.Name("alarmDismissed")
}
