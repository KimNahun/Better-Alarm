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
    @State private var themeManager = AppThemeManager()
    @Environment(\.scenePhase) private var scenePhase

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

        // 전체 앱 배경색을 설정하여 탭/화면 전환 시 흰색 깜빡임 방지
        configureAppearance()

        let mode = alarmKitSvc != nil ? "AlarmKit+Local" : "Local only"
        AppLogger.info("BetterAlarmApp initialized (mode: \(mode))", category: .lifecycle)
    }

    /// UIKit 전역 외관 설정: 네비게이션바, 테이블뷰 배경색 설정. 탭바는 AppThemeManager가 담당.
    private static func configureAppearance() {
        // 네비게이션바 배경
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance

        // 테이블뷰/리스트 배경
        UITableView.appearance().backgroundColor = .clear
    }

    private func configureAppearance() {
        Self.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 루트 배경색: 화면 전환 시 흰색 깜빡임 방지
                Color(themeManager.currentTheme.colors.backgroundTop)
                    .ignoresSafeArea()

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
                    alarmKitService: alarmKitService,
                    themeManager: themeManager
                )
                .tabItem {
                    Label("설정", systemImage: "gearshape")
                }
                .accessibilityLabel("설정 탭")
            }
            .tint(themeManager.currentTheme.colors.accentPrimary)
            .pTheme(themeManager.currentTheme)
            .fullScreenCover(item: $ringingAlarm) { alarm in
                AlarmRingingView(
                    alarm: alarm,
                    audioService: audioService,
                    volumeService: volumeService,
                    alarmStore: alarmStore
                )
                .pTheme(themeManager.currentTheme)
            }
            .onChange(of: ringingAlarm) { _, newValue in
                if newValue == nil {
                    // 알람이 dismiss됨 → 즉시 목록 갱신
                    Task { await alarmStore.loadAlarms() }
                    NotificationCenter.default.post(name: .alarmCompleted, object: nil)
                }
            }
            .onChange(of: themeManager.currentTheme) { _, _ in
                // 테마 변경 시 Live Activity 색상도 즉시 동기화
                if #available(iOS 17.0, *) {
                    Task {
                        let nextAlarm = await alarmStore.nextAlarm
                        await liveActivityManager?.updateActivity(nextAlarm: nextAlarm)
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                Task {
                    switch newPhase {
                    case .background:
                        AppLogger.info("ScenePhase → background", category: .lifecycle)
                        // 백그라운드 무음 루프 시작 (앱 유지)
                        await audioService.startSilentLoop()
                        // 가장 임박한 local 알람에 대해 백그라운드 리마인더 등록
                        let alarms = await alarmStore.alarms
                        let nextLocal = alarms
                            .filter { $0.isEnabled && $0.alarmMode == .local }
                            .compactMap { alarm -> (Alarm, Date)? in
                                guard let date = alarm.nextTriggerDate() else { return nil }
                                return (alarm, date)
                            }
                            .min { $0.1 < $1.1 }?
                            .0
                        if let alarm = nextLocal {
                            await localNotificationService.scheduleBackgroundReminder(for: alarm)
                        }
                    case .active:
                        AppLogger.info("ScenePhase → active", category: .lifecycle)
                        // 백그라운드 리마인더 취소 + 무음 루프 정지
                        await localNotificationService.cancelBackgroundReminder()
                        // 알람 재생 중이 아닐 때만 무음 루프 정지
                        let isPlaying = await audioService.isAlarmPlaying
                        if !isPlaying {
                            await audioService.stopSilentLoop()
                        }
                        // AlarmKit Intent에서 저장한 스누즈 상태 동기화
                        await alarmStore.syncSnoozeFromIntent()
                        // 포그라운드 복귀 시 알람 재스케줄링 (local + alarmKit)
                        await alarmStore.scheduleNextAlarm()
                        // pending 알람 처리 (race condition 방지)
                        if let pendingID = appDelegate.consumePendingAlarmID() {
                            let alarms = await alarmStore.alarms
                            if let alarm = alarms.first(where: { $0.id == pendingID }) {
                                AppLogger.info("Processing pending alarm from notification tap: \(alarm.displayTitle)", category: .alarm)
                                ringingAlarm = alarm
                            }
                        }
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
            }
            .task {
                // 포그라운드 알림 수신 → 울림 화면 표시
                for await notification in NotificationCenter.default.notifications(named: .alarmShouldRing) {
                    if let alarmIDString = notification.userInfo?["alarmID"] as? String,
                       let alarmID = UUID(uuidString: alarmIDString) {
                        let alarms = await alarmStore.alarms
                        if let alarm = alarms.first(where: { $0.id == alarmID }) {
                            AppLogger.info("Notification received → showing ringing screen: \(alarm.displayTitle)", category: .alarm)
                            ringingAlarm = alarm
                        } else {
                            AppLogger.warning("Notification received but alarm not found: \(alarmIDString)", category: .alarm)
                        }
                    }
                }
            }
            .task {
                // 다음 알람 시각까지 정확히 sleep 후 발화 (폴링 대신 정밀 타이머)
                while !Task.isCancelled {
                    await waitAndFireNextAlarm()
                }
            }
            .task {
                // AppDelegate에 의존성 주입
                appDelegate.configure(alarmStore: alarmStore, localNotificationService: localNotificationService, audioService: audioService)

                // 알람 로드 + OS 알림 동기화 (local + alarmKit)
                await alarmStore.loadAlarms()
                await alarmStore.scheduleNextAlarm()

                // Live Activity 초기화
                if #available(iOS 17.0, *) {
                    let nextAlarm = await alarmStore.nextAlarm
                    await liveActivityManager?.updateActivity(nextAlarm: nextAlarm)
                }

                // 알림 카테고리 등록 (정지/스누즈 액션)
                await localNotificationService.registerAlarmCategory()

                // 알림 권한 요청
                _ = await localNotificationService.requestPermission()

                AppLogger.info("App launch tasks completed", category: .lifecycle)
            }
            } // ZStack
        }
    }

    // MARK: - Precise Alarm Timer

    /// 다음 알람 시각까지 정확히 대기한 후 알람을 발화한다.
    /// 폴링(10초 간격) 대신 정밀 sleep을 사용하여 100% 정확도 보장.
    @MainActor
    private func waitAndFireNextAlarm() async {
        // 이미 울리는 중이면 1초 대기 후 재시도
        guard ringingAlarm == nil else {
            try? await Task.sleep(for: .seconds(1))
            return
        }

        let alarms = await alarmStore.alarms
        let now = Date()

        // 가장 임박한 local 알람 찾기
        let nextAlarm = alarms
            .filter { $0.isEnabled && $0.alarmMode == .local && !$0.isSkippingNext }
            .compactMap { alarm -> (Alarm, Date)? in
                guard let triggerDate = alarm.nextTriggerDate() else { return nil }
                guard triggerDate > now else { return nil }
                return (alarm, triggerDate)
            }
            .min { $0.1 < $1.1 }

        guard let (alarm, triggerDate) = nextAlarm else {
            // 활성화된 알람이 없으면 30초마다 재확인
            try? await Task.sleep(for: .seconds(30))
            return
        }

        let sleepDuration = triggerDate.timeIntervalSince(now)

        // 최대 60초 단위로 잘라서 sleep (알람 추가/삭제 시 빠르게 재계산)
        let sleepChunk = min(sleepDuration, 60.0)
        AppLogger.debug("Next alarm '\(alarm.displayTitle)' in \(Int(sleepDuration))s — sleeping \(Int(sleepChunk))s chunk", category: .alarm)

        do {
            try await Task.sleep(for: .seconds(sleepChunk))
        } catch {
            return
        }

        // 아직 시간이 남았으면 루프 상단으로 돌아가 재계산
        let remaining = triggerDate.timeIntervalSince(Date())
        if remaining > 1 {
            return
        }

        // 깨어남 — 알람 발화
        guard ringingAlarm == nil else { return }

        // 알람이 아직 활성 상태인지 재확인 (대기 중에 삭제/비활성 가능)
        let currentAlarms = await alarmStore.alarms
        guard let currentAlarm = currentAlarms.first(where: { $0.id == alarm.id }),
              currentAlarm.isEnabled,
              !currentAlarm.isSkippingNext else {
            return
        }

        AppLogger.info("Alarm timer fired: '\(currentAlarm.displayTitle)'", category: .alarm)
        ringingAlarm = currentAlarm

        // 백그라운드에서는 AlarmRingingView가 표시되지 않으므로 직접 소리 재생
        // 포그라운드에서도 즉시 소리 시작 (View 렌더링 대기 없이)
        await audioService.stopSilentLoop()
        try? await audioService.playAlarmSound(
            soundName: currentAlarm.soundName,
            isSilent: currentAlarm.isSilentAlarm,
            loop: true
        )
    }
}
