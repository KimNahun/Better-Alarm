import Foundation
import AVFoundation
import UIKit

// MARK: - Alarm Player for Sound Playback

class AlarmPlayer: NSObject {
    static let shared = AlarmPlayer()

    private var audioPlayer: AVAudioPlayer?
    private var alarmTimer: Timer?
    private var isPlaying = false
    private var currentSoundID: SystemSoundID?

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
        stopAlarm()

        // Get the sound from AlarmSound list
        let sound = AlarmSound.sound(forId: soundName)
        playSystemSoundLoop(sound.systemSoundID)
       
    }

    private func playSystemSoundLoop(_ soundID: SystemSoundID) {
        isPlaying = true
        currentSoundID = soundID

        // Play immediately
        AudioServicesPlaySystemSound(soundID)

        // Loop every 2 seconds (system sounds are short)
        alarmTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying, let soundID = self.currentSoundID else {
                self?.alarmTimer?.invalidate()
                return
            }
            AudioServicesPlaySystemSound(soundID)
        }
    }

    // MARK: - Stop Alarm

    func stopAlarm() {
        audioPlayer?.stop()
        audioPlayer = nil
        alarmTimer?.invalidate()
        alarmTimer = nil
        isPlaying = false
        currentSoundID = nil
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
