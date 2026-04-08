import SwiftUI

// MARK: - App Entry Point
// NOTE: 이 파일은 최소 진입점입니다.
// Generator가 BetterAlarmApp.swift를 생성하면 이 파일을 덮어씁니다.
// 필요한 추가 구현: TabView 3탭, Settings/Weekly 뷰 연결, DI 완성

@main
struct BetterAlarmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let alarmStore: AlarmStore
    private let localNotificationService: LocalNotificationService

    init() {
        let notificationService = LocalNotificationService()
        let audioService = AudioService()
        let store = AlarmStore(
            localNotificationService: notificationService,
            audioService: audioService
        )
        self.alarmStore = store
        self.localNotificationService = notificationService
    }

    var body: some Scene {
        WindowGroup {
            AlarmListView(store: alarmStore)
                .task {
                    appDelegate.alarmStore = alarmStore
                    appDelegate.localNotificationService = localNotificationService
                    await alarmStore.loadAlarms()
                }
        }
    }
}
