# 자체 점검

## SPEC 기능 체크

- [x] 기능 1: 알람 목록 (CRUD) — `AlarmListView.swift`, `AlarmListViewModel.swift`, `AlarmStore.swift`, `AlarmRowView.swift`. NavigationStack + List + swipeActions + Toggle.
- [x] 기능 2: 알람 생성/편집 — `AlarmDetailView.swift`, `AlarmDetailViewModel.swift`. sheet 모달, DatePicker(시/분), AlarmMode 토글, 조용한 알람 토글.
- [x] 기능 3: AlarmMode 분기 스케줄링 — `AlarmStore.scheduleNextAlarm()`. alarmMode에 따라 AlarmKitService(iOS 26+) 또는 LocalNotificationService로 분기.
- [x] 기능 4: 조용한 알람 — `AudioService.playAlarmSound()`. isSilent=true면 이어폰 연결 확인 후 이어폰으로만 출력. alarmKit 모드에서 disabled.
- [x] 기능 5: 볼륨 자동 조절 (80%) — `VolumeService.ensureMinimumVolume()`. 볼륨 < 0.8이면 0.8으로 올림. 종료 시 `restoreVolume()`.
- [x] 기능 6: 앱 종료 시 푸시 알림 (1회) — `AppDelegate.applicationDidEnterBackground()`. local 모드 알람 활성화 시 즉시 리마인더 등록. 포그라운드 복귀 시 취소.
- [x] 기능 7: 알람 1번만 건너뛰기 — `AlarmListView` swipeActions + `AlarmStore.skipOnceAlarm()`. 주간 반복 알람에서 다음 1회 건너뛰기 지원.
- [x] 기능 8: Live Activity 잠금화면 위젯 — `LiveActivityManager.swift` (actor). AlarmActivityAttributes 정의. startActivity, updateActivity, endActivity. AlarmStore에서 CRUD 후 자동 호출.
- [x] 기능 9: 설정 화면 — `SettingsView.swift`, `SettingsViewModel.swift`. Live Activity 토글, AlarmKit 권한 상태, 앱 버전 표시.
- [x] 기능 10: 주간 알람 화면 — `WeeklyAlarmView.swift`, `WeeklyAlarmViewModel.swift`. AlarmSchedule.weekly 필터링, AlarmRowView 재사용, swipeActions (삭제/건너뛰기).
- [x] 기능 11: 탭바 네비게이션 — `BetterAlarmApp.swift`. TabView 3탭 (알람 목록, 주간 알람, 설정). SF Symbols: alarm, calendar, gearshape.

## Swift 6 동시성 체크

- [x] 모든 ViewModel이 @MainActor + @Observable인가? — AlarmListViewModel, AlarmDetailViewModel, SettingsViewModel, WeeklyAlarmViewModel 모두 적용.
- [x] 모든 Service가 actor인가? — AlarmStore, AlarmKitService, AudioService, LocalNotificationService, VolumeService, LiveActivityManager 모두 actor.
- [x] 모든 Model이 struct + Sendable인가? — Alarm, AlarmMode, AlarmSchedule, Weekday, AlarmError, AlarmActivityAttributes.ContentState 모두 struct + Sendable.
- [x] DispatchQueue 사용 없음? — 전체 코드에서 DispatchQueue 미사용.
- [x] Sendable 경계 위반 없음? — actor 경계 넘는 데이터는 모두 Sendable struct.

## MVVM 분리 체크

- [x] View에 비즈니스 로직 없음? — View는 UI 선언만 포함. Task 내에서 ViewModel 호출만 수행.
- [x] ViewModel에 SwiftUI import 없음? — 모든 ViewModel은 `import Foundation`만 사용.
- [x] Service가 ViewModel을 참조하지 않음? — Service는 독립적. ViewModel/View 참조 없음.
- [x] 의존성이 단방향 (View -> VM -> Service)인가? — View -> ViewModel -> AlarmStore/Service 단방향 흐름.

## HIG 체크

- [x] Dynamic Type 지원? — semantic font size 사용 (.body, .caption, .title2 등).
- [x] Semantic color 사용? — PersonalColorDesignSystem 토큰 사용 (Color.pTextPrimary, Color.pAccentPrimary 등). 하드코딩 색상 없음.
- [x] 터치 영역 44pt 이상? — minWidth/minHeight 44 적용 (버튼, 토글 등).
- [x] 접근성 레이블 추가? — accessibilityLabel, accessibilityHint 주요 인터랙션에 추가.

## API 활용 체크

- [x] AlarmKit: AlarmKitService actor. AlarmManager.shared, AlarmSchedule.fixed/relative, AlarmPresentation, AlarmButton. @available(iOS 26.0, *) 가드 적용.
- [x] AppIntent: StopAlarmIntent, SnoozeAlarmIntent (LiveActivityIntent). @Parameter alarmID. AlarmManager.shared.stop() 호출.
- [x] ActivityKit: LiveActivityManager actor. Activity.request(), activity.update(), activity.end(). AlarmActivityAttributes 정의.

## PersonalColorDesignSystem 사용 체크

- [x] GradientBackground() — AlarmListView, AlarmDetailView, SettingsView, WeeklyAlarmView 배경.
- [x] GlassCard { } — AlarmRowView, AlarmListView 다음 알람 배너.
- [x] Color.p* 토큰 — 모든 View에서 Color.pTextPrimary, pTextSecondary, pTextTertiary, pAccentPrimary, pAccentSecondary, pWarning, pGlassFill 사용.
- [x] HapticManager — 버튼 탭, 토글, 삭제 시 impact/selection/notification 사용.
- [x] ToastView — AlarmDetailView에서 AlarmKit 미지원 토스트 표시.

## AppLogger 사용 체크

- [x] AlarmStore — CRUD 시 alarmCreated, alarmUpdated, alarmDeleted, alarmToggled 호출. load/save에 info/error 로깅.
- [x] LiveActivityManager — start/update/end 시 info/debug/warning/error 로깅.
- [x] SettingsViewModel — 설정 동기화 시 info 로깅.
- [x] WeeklyAlarmViewModel — 로드 시 info 로깅.
- [x] BetterAlarmApp — 초기화 및 launch tasks 완료 시 info 로깅.
