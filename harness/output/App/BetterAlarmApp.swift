import SwiftUI
import PersonalColorDesignSystem

// MARK: - BetterAlarmApp

/// BetterAlarm 앱의 진입점.
/// DI 루트: AlarmStore, LocalNotificationService, AudioService, VolumeService, LiveActivityManager 생성 및 주입.
/// TabView 3탭: 알람 목록, 주간 알람, 설정.
@main
struct BetterAlarmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // MARK: - Dependencies

    private let localNotificationService: LocalNotificationService
    private let audioService: AudioService
    private let volumeService: VolumeService
    private let liveActivityManager: LiveActivityManager?
    private let alarmKitService: (any AlarmKitServiceProtocol)?
    private let alarmStore: AlarmStore

    // MARK: - Ringing State

    @State private var ringingAlarm: Alarm? = nil

    init() {
        let notificationService = LocalNotificationService()
        let volumeSvc = VolumeService()
        let audioSvc = AudioService(volumeService: volumeSvc)

        let liveActivityMgr: LiveActivityManager?
        if #available(iOS 17.0, *) {
            liveActivityMgr = LiveActivityManager()
        } else {
            liveActivityMgr = nil
        }

        let alarmKitSvc: (any AlarmKitServiceProtocol)?
        if #available(iOS 26.0, *) {
            alarmKitSvc = AlarmKitService()
        } else {
            alarmKitSvc = nil
        }

        self.localNotificationService = notificationService
        self.audioService = audioSvc
        self.volumeService = volumeSvc
        self.liveActivityManager = liveActivityMgr
        self.alarmKitService = alarmKitSvc
        self.alarmStore = AlarmStore(
            localNotificationService: notificationService,
            audioService: audioSvc,
            liveActivityManager: liveActivityMgr,
            alarmKitService: alarmKitSvc
        )

        AppLogger.info("BetterAlarmApp initialized", category: .lifecycle)
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                // 탭 1: 알람 목록
                AlarmListView(store: alarmStore)
                    .tabItem {
                        Label("알람", systemImage: "alarm")
                    }
                    .accessibilityLabel("알람 목록 탭")

                // 탭 2: 주간 알람
                WeeklyAlarmView(store: alarmStore)
                    .tabItem {
                        Label("주간 알람", systemImage: "calendar")
                    }
                    .accessibilityLabel("주간 알람 탭")

                // 탭 3: 설정
                SettingsView(
                    liveActivityManager: liveActivityManager,
                    alarmStore: alarmStore,
                    alarmKitService: alarmKitService
                )
                .tabItem {
                    Label("설정", systemImage: "gearshape")
                }
                .accessibilityLabel("설정 탭")
            }
            .tint(Color.pAccentPrimary)
            .fullScreenCover(item: $ringingAlarm) { alarm in
                AlarmRingingView(
                    alarm: alarm,
                    audioService: audioService,
                    volumeService: volumeService,
                    alarmStore: alarmStore
                )
            }
            .task {
                // 포그라운드 알림 수신 → 울림 화면 표시
                for await notification in NotificationCenter.default.notifications(named: .alarmShouldRing) {
                    if let alarmIDString = notification.userInfo?["alarmID"] as? String,
                       let alarmID = UUID(uuidString: alarmIDString) {
                        let alarms = await alarmStore.alarms
                        if let alarm = alarms.first(where: { $0.id == alarmID }) {
                            ringingAlarm = alarm
                        }
                    }
                }
            }
            .task {
                // 30초마다 임박한 알람 확인
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    await checkForImminentAlarm()
                }
            }
            .task {
                // AppDelegate에 의존성 주입
                appDelegate.configure(alarmStore: alarmStore, localNotificationService: localNotificationService)

                // 알람 로드
                await alarmStore.loadAlarms()

                // Live Activity 초기화
                if #available(iOS 17.0, *) {
                    let nextAlarm = await alarmStore.nextAlarm
                    await liveActivityManager?.updateActivity(nextAlarm: nextAlarm)
                }

                // 알림 권한 요청
                _ = await localNotificationService.requestPermission()

                AppLogger.info("App launch tasks completed", category: .lifecycle)
            }
        }
    }

    // MARK: - Alarm Check

    /// 활성화된 알람 중 30초 이내에 울릴 알람이 있는지 확인하여 울림 화면을 표시한다.
    @MainActor
    private func checkForImminentAlarm() async {
        guard ringingAlarm == nil else { return }

        let alarms = await alarmStore.alarms
        let now = Date()
        let threshold: TimeInterval = 30

        let imminent = alarms
            .filter { $0.isEnabled && $0.alarmMode == .local && !$0.isSkippingNext }
            .first { alarm in
                guard let triggerDate = alarm.nextTriggerDate() else { return false }
                let interval = triggerDate.timeIntervalSince(now)
                return interval >= 0 && interval <= threshold
            }

        if let alarm = imminent {
            ringingAlarm = alarm
        }
    }
}
