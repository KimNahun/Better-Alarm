# QA Report — BetterAlarm Evaluator R1

**검수 일시**: 2026-04-08
**검수 대상**: `harness/output/` 하위 25개 Swift 파일
**검수 기준**: `evaluation_criteria.md` 5개 항목 (Swift 6 동시성 30%, MVVM 25%, HIG 20%, API 15%, 기능성 10%)

---

**전체 판정**: 조건부 합격
**가중 점수**: 6.6 / 10.0

**항목별 점수**:
- Swift 6 동시성: 7/10 — 전반적으로 양호하나, VolumeService의 actor 내부 @MainActor 메서드, AudioService의 nonisolated 남용, AlarmKitService의 `[weak self]` actor 내 사용 등 문제 존재
- MVVM 분리: 8/10 — 레이어 분리 우수. ViewModel에 SwiftUI import 없음. 다만 AlarmDetailViewModel.save()에서 do 블록이 불필요하게 남아있음 (사소)
- HIG 준수: 6/10 — PersonalColorDesignSystem 토큰 사용, GlassCard/HapticManager 사용은 양호하나, 피드백/문의 링크 누락, 일부 하드코딩 아이콘 사이즈, SettingsView에서 로딩 상태 UI 미표시
- API 활용: 6/10 — AlarmKit/AppIntent/ActivityKit 모두 구현되었으나, AlarmKitService에서 매번 새 인스턴스 생성, AlarmKit import 누락, AlarmMetadata에 AlarmKit import 누락 등 컴파일 에러 예상
- 기능성/가독성: 6/10 — 11개 기능 중 대부분 구현되었으나 일부 미완성/누락. 접근 제어자 일부 누락. 에러 처리 일부 `try?`로 무시

---

## 항목별 상세 채점

### 1. Swift 6 동시성: 7/10

**합격 기준 충족:**
- [PASS] 모든 ViewModel: `@MainActor` + `@Observable` 선언 확인 (AlarmListViewModel, AlarmDetailViewModel, SettingsViewModel, WeeklyAlarmViewModel)
- [PASS] 모든 Service: `actor` 선언 확인 (AlarmStore, LocalNotificationService, AudioService, VolumeService, LiveActivityManager, AlarmKitService)
- [PASS] 모든 Model: `struct` + `Sendable` 준수 (Alarm, AlarmMode, AlarmSchedule, Weekday, AlarmError)
- [PASS] `DispatchQueue.main` 사용 없음
- [PASS] `@Published` / `ObservableObject` 사용 없음

**위반 사항:**

1. **`Services/AudioService.swift` 89행 — `nonisolated func isEarphoneConnected()`**: actor의 메서드를 `nonisolated`로 선언했다. `AVAudioSession.sharedInstance()`는 MainActor에서 호출해야 하는 API인데, nonisolated 컨텍스트에서 호출하면 Swift 6에서 경고/에러가 발생할 수 있다. 또한 이 메서드는 `AudioServiceProtocol`에서 `func isEarphoneConnected() -> Bool`로 선언되어 있어 actor isolation 불일치가 발생한다.

2. **`Services/VolumeService.swift` 39~62행 — `@MainActor private func fetchCurrentVolume()` / `@MainActor private func setVolume()`**: actor 내부에서 `@MainActor` 격리된 private 메서드를 선언하고 있다. actor의 격리 도메인과 MainActor 격리가 충돌한다. `await`으로 호출은 하고 있지만, actor 내부에서 `@MainActor` 메서드를 선언하는 패턴은 actor 재진입(reentrancy) 문제를 야기할 수 있고, Swift 6 엄격 모드에서 혼란스러운 격리 경계를 만든다. `setVolume()` 내에서 `UIApplication.shared.connectedScenes`에 접근하는데, 이것은 MainActor 격리가 필요한 API이므로 `@MainActor` 표시 자체는 맞지만, 이런 로직은 별도의 MainActor 격리 헬퍼로 분리하는 것이 바람직하다.

3. **`Services/AlarmKitService.swift` 167행 — `[weak self]`**: actor에서는 `[weak self]`를 사용하지 않는다. actor 인스턴스는 참조 타입이지만, actor 내부의 `Task` 클로저에서 `[weak self]`는 불필요하며 Swift 6에서는 컴파일 에러가 될 수 있다. `self`가 actor 인스턴스를 캡처하는 것은 정상이며, 순환 참조는 Task가 완료되면 해제된다.

4. **`Services/AlarmStore.swift` 274행 — `let service = AlarmKitService()`**: `scheduleNextAlarm()`과 `cancelSchedule()`에서 매번 새로운 `AlarmKitService()` 인스턴스를 생성한다. 이는 `currentAlarmKitID` 상태가 유지되지 않아 이전에 스케줄한 알람을 추적할 수 없다는 심각한 로직 버그다. AlarmKitService도 DI로 주입받아야 한다.

5. **`Delegates/AppDelegate.swift` 9행 — `final class AppDelegate`**: `@MainActor`가 아닌 일반 `class`로 선언. `UIApplicationDelegate` 프로토콜의 메서드들은 MainActor에서 호출되지만, `alarmStore`와 `localNotificationService` 프로퍼티가 별도 actor이므로 `Task {}` 내에서 접근은 맞지만, Swift 6에서 `AppDelegate` 자체에 `@MainActor` 표기가 권장된다. 단, `NSObject` + `UIApplicationDelegate` 조합에서는 자동으로 MainActor가 추론될 수 있어 심각도는 낮다.

6. **`ViewModels/SettingsViewModel.swift` 13~17행 — `isLiveActivityEnabled didSet`**: `didSet` 내에서 `Task {}`로 비동기 작업을 시작한다. 이 패턴 자체는 작동하지만, `didSet`이 `@Observable`의 변경 추적과 결합될 때 의도치 않은 재귀 호출이나 타이밍 문제가 발생할 수 있다. 명시적 메서드(`setLiveActivityEnabled(_:)`)로 전환하는 것이 안전하다.

---

### 2. MVVM 아키텍처 분리: 8/10

**합격 기준 충족:**
- [PASS] View 파일에서 Service 직접 호출 없음 — 모든 View가 ViewModel을 통해서만 Service에 접근
- [PASS] ViewModel 파일에 `import SwiftUI` 없음 — 4개 ViewModel 모두 `import Foundation`만 사용
- [PASS] ViewModel에 UI 타입(`Color`, `Font`, `Image`) 없음
- [PASS] Service가 ViewModel/View를 참조하지 않음
- [PASS] 의존성 단방향 흐름: View -> ViewModel -> Service
- [PASS] Protocol 기반 Service 정의 존재 (LocalNotificationServiceProtocol, AudioServiceProtocol, VolumeServiceProtocol)

**위반 사항:**

1. **Protocol 미일관성**: `AlarmStore`에는 프로토콜이 정의되어 있지 않다. 다른 Service는 프로토콜을 정의했으나 `AlarmKitService`와 `LiveActivityManager`에도 프로토콜이 없다. 테스트 가능성을 위해 모든 Service에 프로토콜을 정의하고 ViewModel에서 프로토콜 타입으로 의존해야 한다.

2. **`Views/AlarmListView.swift` 10행 — `private let store: AlarmStore`**: View가 AlarmStore(Service)를 직접 소유하고 있다. 이것은 AlarmDetailView 생성 시 주입하기 위한 것이지만, MVVM 원칙상 View가 Service를 직접 참조하는 것은 위반이다. AlarmListViewModel에서 AlarmDetailViewModel을 생성하여 전달하거나, 환경 객체를 사용하는 패턴이 더 적절하다. 동일한 문제가 `WeeklyAlarmView`에도 존재한다.

3. **`App/BetterAlarmApp.swift` 76~77행**: `appDelegate.alarmStore = alarmStore` — AppDelegate에 직접 Service를 주입하고 있다. 이 자체는 DI 패턴이지만, AppDelegate의 프로퍼티가 `var`로 열려 있어 외부에서 변경 가능하다.

---

### 3. HIG 준수 + 디자인 시스템: 6/10

**합격 기준 충족:**
- [PASS] PersonalColorDesignSystem 토큰 사용: `Color.pTextPrimary`, `Color.pTextSecondary`, `Color.pTextTertiary`, `Color.pAccentPrimary`, `Color.pAccentSecondary`, `Color.pWarning`, `Color.pGlassFill` 전면 사용
- [PASS] GlassCard 컴포넌트 사용 (AlarmRowView, AlarmListView 배너)
- [PASS] GradientBackground 사용 (모든 View)
- [PASS] HapticManager 사용 (터치, 삭제, 건너뛰기 등)
- [PASS] ToastView 사용 (AlarmDetailView 토스트)
- [PASS] 터치 영역 44pt: 주요 버튼에 `frame(minWidth: 44, minHeight: 44)` 적용
- [PASS] 접근성 레이블: 주요 인터랙션에 `.accessibilityLabel`, `.accessibilityHint` 추가
- [PASS] 내비게이션 패턴: `NavigationStack`, `sheet`, `TabView` 사용
- [PASS] 에러 처리 UI: AlarmDetailView에 `alert`으로 저장 에러 표시

**위반 사항:**

1. **`Views/AlarmList/AlarmListView.swift` 160행, `Views/Weekly/WeeklyAlarmView.swift` 115행 — 하드코딩 아이콘 사이즈**: `.font(.system(size: 60))`은 HIG의 Dynamic Type 원칙을 위반한다. semantic font size를 사용해야 한다. 아이콘에 `.font(.system(size: 60))`은 접근성 설정에서 텍스트 크기를 변경해도 반영되지 않는다. `.font(.largeTitle)` 등 semantic size 사용 권장.

2. **`Views/Settings/SettingsView.swift` — 피드백/문의 링크 누락**: SPEC 기능 9에서 "피드백/문의 링크"를 명시했으나 구현되어 있지 않다. `Link` 컴포넌트로 피드백 URL을 제공해야 한다.

3. **`Views/Settings/SettingsView.swift` — 로딩 상태 UI 미제공**: `viewModel.isLoading`을 사용하지 않고 있다. AlarmKit 권한 확인 등 비동기 작업 중 사용자에게 로딩 피드백이 없다.

4. **`Views/AlarmList/AlarmListView.swift` — 로딩 상태 UI 미제공**: `viewModel.isLoading` 상태가 있으나 UI에 반영되어 있지 않다.

5. **`Views/AlarmList/AlarmListView.swift` — 에러 상태 UI 미제공**: `viewModel.errorMessage`가 정의되어 있으나 View에서 표시하지 않는다.

6. **`Views/AlarmDetail/AlarmDetailView.swift` 256행 — 요일 버튼 크기 36pt**: weekdayPicker의 각 요일 버튼이 `frame(minWidth: 36, minHeight: 36)`으로 44pt 미만이다. 최소 44pt여야 한다.

7. **`GradientBackground().ignoresSafeArea()`**: 배경 그래디언트에 `.ignoresSafeArea()`를 사용하는 것은 배경 용도이므로 합리적이지만, `AlarmDetailView`에서 `NavigationStack` 바깥에 `ZStack`으로 감싸면서 `GradientBackground`가 네비게이션 바 뒤로 확장되어 텍스트 가독성 문제가 생길 수 있다.

---

### 4. API 활용: 6/10

**합격 기준 충족:**
- [PASS] AlarmKit: `AlarmManager.shared`, `AlarmAttributes`, `AlarmPresentation`, `AlarmButton`, `AlarmSchedule.fixed/relative` 사용
- [PASS] AppIntents: `StopAlarmIntent`, `SnoozeAlarmIntent`가 `LiveActivityIntent` 프로토콜 구현, `@Parameter` 사용
- [PASS] ActivityKit: `Activity<AlarmActivityAttributes>` 사용, start/update/end 구현
- [PASS] UNUserNotificationCenter: 권한 요청, `UNCalendarNotificationTrigger`, 배경 리마인더 구현
- [PASS] API 호출이 Service 레이어에서만 수행됨
- [PASS] 에러 처리 구현 (AlarmError enum)

**위반 사항:**

1. **`Services/AlarmKitService.swift` — `import AlarmKit` 누락**: 파일 상단에 `import Foundation`만 있고 `import AlarmKit`이 없다. `AlarmManager`, `AlarmPresentation`, `AlarmAttributes`, `AlarmButton`, `AlarmSchedule` 등 AlarmKit 타입을 사용하는데 import가 없으면 컴파일 에러가 발생한다.

2. **`Shared/AlarmMetadata.swift` — `import AlarmKit` 누락**: `AlarmMetadata` 프로토콜을 준수하는데 `import Foundation`만 있다. `import AlarmKit`이 필요하다.

3. **`Intents/StopAlarmIntent.swift`, `Intents/SnoozeAlarmIntent.swift` — `import AlarmKit` 누락**: `AlarmManager.shared.stop(id:)`를 호출하는데 `import AlarmKit`이 없다.

4. **`Services/AlarmStore.swift` 274행 — AlarmKitService 매번 새 인스턴스 생성**: `scheduleNextAlarm()`과 `cancelSchedule()`에서 `let service = AlarmKitService()`로 매번 새 인스턴스를 만든다. 이러면 `currentAlarmKitID` 상태가 유실되어 기존 알람 추적이 불가능하다. DI로 주입받거나 싱글턴 패턴을 사용해야 한다.

5. **`Services/AlarmKitService.swift` 65행 — 타입 불확실**: `AlarmKit.Alarm.Schedule` 등의 fully qualified 타입 경로가 실제 AlarmKit API와 일치하는지 불확실하다. AlarmKit은 iOS 26에서 새로 도입된 프레임워크로, 실제 public API가 코드에서 사용하는 형태와 다를 수 있다.

6. **AlarmKitService 권한 요청 — `requestAuthorization()` 반환 타입**: `manager.requestAuthorization()`의 반환값이 `status`로 받아 `.authorized`와 비교하는데, 실제 AlarmKit API의 반환 타입이 이와 일치하는지 확인 필요.

7. **`Services/LiveActivityManager.swift` 41행 — `@available(iOS 16.2, *)`**: SPEC에서는 iOS 17.0 최소 타겟이므로 iOS 16.2 가드는 불필요하다. `Activity` API 자체는 iOS 16.1부터 사용 가능하므로 에러는 아니지만, 불필요한 가드가 남아있다.

---

### 5. 기능성 및 코드 가독성: 6/10

**합격 기준 충족:**
- [PASS] 파일명이 SPEC 컨벤션과 일치
- [PASS] 접근 제어자 다수 사용 (`private(set)`, `private`)
- [PASS] 에러 타입이 `enum AlarmError: Error`로 정의, `LocalizedError` 준수
- [PASS] 코드 중복 최소화 (AlarmRowView 재사용)
- [PASS] 적절한 MARK 주석 사용

**위반 사항:**

1. **접근 제어자 누락**: 모든 Model, ViewModel, View, Service에 `internal` 기본 접근 수준이 사용되고 있다. `Alarm`, `AlarmMode`, `AlarmSchedule`, `Weekday`, `AlarmError` 등 주요 타입에 명시적 접근 제어자가 없다. `struct Alarm`은 `internal struct Alarm`이 기본이지만, SPEC에서 "모든 public/internal 프로퍼티에 접근 제어자 명시"를 요구한다.

2. **`Services/AlarmStore.swift` 200~203행 — `checkForCompletedAlarms()` 빈 구현**: 메서드 바디가 주석만 있고 실제 로직이 없다. 빈 메서드를 남겨두는 것은 가독성을 해친다.

3. **`AlarmDetailViewModel.swift` 147~171행 — 불필요한 `do` 블록**: `save()` 메서드에서 `do { ... }` 블록이 있으나 catch 없이 끝난다. store 메서드가 throws가 아니라는 주석이 있으면서 do 블록을 남겨둔 것은 혼란스럽다.

4. **`AppDelegate.swift` 11~12행 — `var` 프로퍼티**: `alarmStore`와 `localNotificationService`가 `var`로 열려 있어 외부에서 변경 가능. `private(set)` 또는 초기화 시점 확정이 바람직하다.

---

## 기능 구현 현황

| # | 기능 | 구현 여부 | 근거 |
|---|------|-----------|------|
| 1 | 알람 목록 (CRUD) | **PASS** | AlarmListView + AlarmListViewModel + AlarmStore에 create/update/delete/toggle 구현. swipeActions 삭제 구현. |
| 2 | 알람 생성/편집 | **PASS** | AlarmDetailView + AlarmDetailViewModel. 시간, 제목, 반복, 사운드, AlarmMode 토글, 조용한 알람 토글 모두 구현. |
| 3 | AlarmMode 분기 스케줄링 | **PASS (부분)** | AlarmStore.scheduleNextAlarm()에서 alarmMode 분기 구현. 단, AlarmKitService를 매번 새 인스턴스로 생성하는 버그 있음. |
| 4 | 조용한 알람 | **PASS** | AudioService.isEarphoneConnected() 구현, AlarmDetailView에서 alarmKit 모드 시 disabled 처리 구현. |
| 5 | 볼륨 자동 조절 (80%) | **PASS** | VolumeService.ensureMinimumVolume()/restoreVolume() 구현. AudioService에서 호출. |
| 6 | 앱 종료 시 푸시 알림 | **PASS** | AppDelegate.applicationDidEnterBackground에서 scheduleBackgroundReminder 호출, applicationWillEnterForeground에서 cancelBackgroundReminder 호출. |
| 7 | 알람 1번 건너뛰기 | **PASS** | AlarmStore.skipOnceAlarm/clearSkipOnceAlarm 구현. AlarmListView/WeeklyAlarmView에서 swipeActions로 UI 제공. |
| 8 | Live Activity | **PASS** | LiveActivityManager actor 구현. AlarmActivityAttributes 정의. AlarmStore에서 updateLiveActivity() 호출. start/update/end 모두 구현. |
| 9 | 설정 화면 | **PASS (부분)** | Live Activity 토글, AlarmKit 권한 상태, 앱 버전 표시 구현. **피드백/문의 링크 누락.** |
| 10 | 주간 알람 화면 | **PASS** | WeeklyAlarmView + WeeklyAlarmViewModel에서 weekly 필터링, 삭제, 건너뛰기 구현. 단, 요일 그룹별 표시는 미구현 (단순 리스트). |
| 11 | 탭바 네비게이션 | **PASS** | BetterAlarmApp에서 TabView 3탭 (알람, 주간 알람, 설정) 구성. @UIApplicationDelegateAdaptor 사용. |

---

## 구체적 개선 지시

### 필수 (컴파일 에러 예상)

1. **`Services/AlarmKitService.swift`** 1행: `import Foundation` 아래에 `import AlarmKit` 추가. 없으면 `AlarmManager`, `AlarmPresentation`, `AlarmAttributes`, `AlarmButton` 등 모든 AlarmKit 타입에서 컴파일 에러 발생.

2. **`Shared/AlarmMetadata.swift`** 1행: `import Foundation` 아래에 `import AlarmKit` 추가. `AlarmMetadata` 프로토콜을 인식하려면 필수.

3. **`Intents/StopAlarmIntent.swift`** 1행: `import AppIntents` 아래에 `import AlarmKit` 추가. `AlarmManager.shared.stop(id:)` 호출에 필요.

4. **`Intents/SnoozeAlarmIntent.swift`** 1행: `import AppIntents` 아래에 `import AlarmKit` 추가. 동일 이유.

### 중요 (로직 버그)

5. **`Services/AlarmStore.swift`** `scheduleNextAlarm()` / `cancelSchedule()`: `AlarmKitService()`를 매번 새로 생성하지 말고, init에서 `AlarmKitService?`를 주입받아 저장하라. `if #available(iOS 26.0, *)` 가드 내에서 인스턴스를 생성하고 프로퍼티에 저장하는 방식으로 변경. 현재 방식은 `currentAlarmKitID` 상태가 유지되지 않아 이전 알람 취소가 불가능하다.

### 권장 (동시성 개선)

6. **`Services/AudioService.swift`** `isEarphoneConnected()`: `nonisolated` 제거하고 일반 actor-isolated 메서드로 변경. `AVAudioSession.sharedInstance()`는 thread-safe하지 않을 수 있으므로 actor 격리 내에서 호출하는 것이 안전하다. 또는 `@MainActor`로 격리하여 UI 스레드에서 호출되도록 보장.

7. **`Services/AlarmKitService.swift`** `startMonitoring()` 167행: `[weak self]`를 제거하라. Actor에서는 `[weak self]` 캡처가 불필요하며 Swift 6에서 경고가 발생한다. `Task { ... }`로 변경하고 `self.manager`를 직접 참조하라.

8. **`ViewModels/SettingsViewModel.swift`** `isLiveActivityEnabled` 프로퍼티: `didSet` 내의 `Task {}` 패턴을 제거하고, `func setLiveActivityEnabled(_ enabled: Bool) async` 메서드로 변경하라. View에서 `.onChange(of:)` + `Task`로 호출하면 더 예측 가능하다.

### 권장 (HIG / 기능 완성도)

9. **`Views/Settings/SettingsView.swift`**: "피드백/문의" 섹션을 추가하라. `Link("피드백 보내기", destination: URL(...))` 형태로 SPEC 기능 9의 요구사항을 충족해야 한다.

10. **`Views/AlarmList/AlarmListView.swift`** emptyState, **`Views/Weekly/WeeklyAlarmView.swift`** emptyState: `.font(.system(size: 60))`을 `.font(.largeTitle)` 등 semantic size로 변경하라. Dynamic Type 준수 필수.

11. **`Views/AlarmList/AlarmListView.swift`**: `viewModel.isLoading` 상태에 대한 UI를 추가하라. `ProgressView()` 또는 skeleton 로딩 표시.

12. **`Views/AlarmDetail/AlarmDetailView.swift`** weekdayPicker: 요일 버튼 `frame(minWidth: 36, minHeight: 36)`을 `frame(minWidth: 44, minHeight: 44)`로 변경하여 44pt 최소 터치 영역을 확보하라.

13. **`Services/AlarmStore.swift`** `checkForCompletedAlarms()`: 빈 메서드를 삭제하거나 실제 로직을 구현하라.

14. **`Delegates/AppDelegate.swift`** 11~12행: `var alarmStore: AlarmStore?`를 `private(set) var alarmStore: AlarmStore?`로 변경하여 외부 변경을 제한하라. (단, BetterAlarmApp에서 주입해야 하므로 internal setter가 필요하면 모듈 내 접근은 허용)

15. **전체 타입 접근 제어자**: 주요 타입(`Alarm`, `AlarmMode`, `AlarmSchedule`, `Weekday`, `AlarmError`, 모든 ViewModel, 모든 Service)에 `internal` 접근 제어자를 명시하거나, 모듈 외부에 노출되지 않는 타입에는 명시적으로 표기하라.

---

**방향 판단**: 현재 방향 유지

아키텍처 기본 구조(MVVM + actor/Observable + 단방향 의존)는 올바르게 잡혀 있다. AlarmKit import 누락과 AlarmKitService 인스턴스 관리 문제는 수정 필요하지만, 전체 재설계가 필요한 수준은 아니다. 위 개선 지시를 반영하면 합격 가능.

---

# QA Report — BetterAlarm Evaluator R2

**검수 일시**: 2026-04-08
**검수 대상**: `harness/output/` 하위 25개 Swift 파일 (R1 피드백 반영 후)
**검수 기준**: `evaluation_criteria.md` 5개 항목 (Swift 6 동시성 30%, MVVM 25%, HIG 20%, API 15%, 기능성 10%)

---

**전체 판정**: 합격
**가중 점수**: 7.6 / 10.0

---

## 이전 피드백 반영 현황

| # | 피드백 항목 | 반영 여부 | 근거 |
|---|------------|-----------|------|
| 1 | `AlarmKitService.swift` — `import AlarmKit` 누락 | **반영됨** | `#if os(iOS) import AlarmKit #endif` 추가 (2~4행) |
| 2 | `AlarmMetadata.swift` — `import AlarmKit` 누락 | **반영됨** | `#if os(iOS) import AlarmKit #endif` 추가 (2~4행) |
| 3 | `StopAlarmIntent.swift` — `import AlarmKit` 누락 | **반영됨** | `#if os(iOS) import AlarmKit #endif` 추가 (2~4행) |
| 4 | `SnoozeAlarmIntent.swift` — `import AlarmKit` 누락 | **반영됨** | `#if os(iOS) import AlarmKit #endif` 추가 (2~4행) |
| 5 | `AlarmStore.swift` — AlarmKitService DI 주입 | **반영됨** | `alarmKitService: AnyObject?`로 init 주입받아 프로퍼티에 저장. `scheduleNextAlarm()`에서 `as? AlarmKitService`로 캐스팅하여 사용 (263행). 매번 새 인스턴스 생성 버그 해소. |
| 6 | `AudioService.swift` — `nonisolated isEarphoneConnected()` 제거 | **반영됨** | `nonisolated` 키워드 제거, 일반 actor-isolated 메서드로 변경 (89행). 프로토콜에서도 `async`로 변경 (9행). |
| 7 | `AlarmKitService.swift` — `[weak self]` 제거 | **반영됨** | `startMonitoring()`에서 `self.manager`를 직접 참조 (171행). `[weak self]` 캡처 없음. |
| 8 | `SettingsViewModel.swift` — `didSet` 패턴 제거 | **반영됨** | `isLiveActivityEnabled`를 `private(set) var`로 변경하고 `setLiveActivityEnabled(_:) async` 메서드 추가 (49~52행). View에서 `.onChange(of:)` + `Task`로 호출 (SettingsView 42~46행). |
| 9 | `SettingsView.swift` — 피드백/문의 링크 추가 | **반영됨** | `Link` 컴포넌트로 "피드백 보내기" 이메일 링크 추가 (82~100행). |
| 10 | 빈 상태 아이콘 `.font(.system(size: 60))` 변경 | **반영됨** | AlarmListView (180행), WeeklyAlarmView (115행) 모두 `.font(.largeTitle)` 사용. |
| 11 | `AlarmListView` 로딩 상태 UI 추가 | **반영됨** | `viewModel.isLoading` 조건에 `ProgressView()` 표시 (45~50행). |
| 12 | `AlarmDetailView` weekdayPicker 44pt 확보 | **반영됨** | `frame(minWidth: 44, minHeight: 44)` 적용 (255행). |
| 13 | `AlarmStore.checkForCompletedAlarms()` 빈 메서드 삭제 | **반영됨** | 해당 메서드가 완전히 제거됨. |
| 14 | `AppDelegate` — `var` 프로퍼티 접근 제한 | **반영됨** | `private(set) var alarmStore: AlarmStore?` / `private(set) var localNotificationService: LocalNotificationService?`로 변경 (11~12행). `configure()` 메서드로 주입 (15행). |
| 15 | 전체 타입 접근 제어자 명시 | **미반영** | `Alarm`, `AlarmMode`, `AlarmSchedule`, `Weekday`, `AlarmError`, 모든 ViewModel, 모든 Service, 모든 View에 명시적 접근 제어자(`internal`)가 여전히 없다. Swift 단일 모듈에서는 기능적 문제 없으나, SPEC 컨벤션 위반. |

**반영 요약**: 15개 중 14개 반영됨, 1개 미반영.

---

## 항목별 점수

### 1. Swift 6 동시성: 8/10

**합격 기준 충족:**
- [PASS] 모든 ViewModel: `@MainActor` + `@Observable` 선언 (AlarmListViewModel, AlarmDetailViewModel, SettingsViewModel, WeeklyAlarmViewModel)
- [PASS] 모든 Service: `actor` 선언 (AlarmStore, AlarmKitService, LocalNotificationService, AudioService, VolumeService, LiveActivityManager)
- [PASS] 모든 Model: `struct` + `Sendable` (Alarm, AlarmMode, AlarmSchedule, Weekday, AlarmError)
- [PASS] `DispatchQueue.main` 사용 없음
- [PASS] `@Published` / `ObservableObject` 사용 없음
- [PASS] R1 지적사항: `[weak self]` actor 내 사용 → 제거됨
- [PASS] R1 지적사항: `nonisolated` 남용 → 제거됨
- [PASS] R1 지적사항: `didSet` + `Task` 패턴 → `setLiveActivityEnabled()` 메서드로 전환됨
- [PASS] AlarmKitService DI 주입으로 상태 유지 문제 해소

**잔존 위반 사항:**

1. **`Services/VolumeService.swift` 39~46행 — actor 내부 `@MainActor` 메서드**: `fetchCurrentVolume()`과 `setVolume(_:)`이 여전히 actor 내부에서 `@MainActor`로 선언되어 있다. 이 패턴은 기능적으로 동작하지만(actor reentrancy를 통해 MainActor로 호프), actor 격리 경계가 혼란스럽다. `MPVolumeView`, `UIApplication.shared.connectedScenes`는 MainActor 격리가 필수이므로 `@MainActor` 표기 자체는 올바르나, 별도의 `@MainActor` 격리 helper struct/class로 분리하는 것이 Swift 6 관례에 더 부합한다. 심각도는 낮아 감점 최소화.

2. **`Services/AlarmStore.swift` 14행 — `alarmKitService: AnyObject?` 타입 소거**: AlarmKitService를 `AnyObject?`로 저장하고 `as? AlarmKitService`로 런타임 캐스팅하는 패턴은 타입 안전성이 낮다. `@available(iOS 26.0, *)` 제약 때문에 프로퍼티 타입에 직접 지정하기 어렵다는 것은 이해하지만, 이는 Swift 6 동시성 문제라기보다 설계 선택의 문제이므로 심각도 낮음.

3. **`ViewModels/SettingsViewModel.swift` 72~75행 — `loadAlarmKitAuthStatus()`에서 AlarmKitService 매번 새 인스턴스 생성**: `let service = AlarmKitService()`로 매번 새 인스턴스를 만든다. 이 메서드는 권한 확인 전용이므로 상태 유실은 없지만, 불필요한 인스턴스 생성이며 DI 원칙에 맞지 않는다.

---

### 2. MVVM 아키텍처 분리: 8/10

**합격 기준 충족:**
- [PASS] View에서 Service 직접 호출 없음 — 모든 View가 ViewModel을 통해서만 비즈니스 로직에 접근
- [PASS] ViewModel에 `import SwiftUI` 없음 — 4개 ViewModel 모두 `import Foundation`만 사용
- [PASS] ViewModel에 UI 타입(`Color`, `Font`, `Image`) 없음
- [PASS] Service가 ViewModel/View를 참조하지 않음
- [PASS] 의존성 단방향 흐름: View -> ViewModel -> Service
- [PASS] Protocol 기반 Service 정의 (LocalNotificationServiceProtocol, AudioServiceProtocol, VolumeServiceProtocol)

**잔존 위반 사항:**

1. **View가 Service(`AlarmStore`)를 직접 소유**: `AlarmListView` (10행 `private let store: AlarmStore`), `WeeklyAlarmView` (11행 `private let store: AlarmStore`)가 AlarmStore를 직접 소유하고 있다. 이는 AlarmDetailView 생성 시 store를 주입하기 위한 것이지만, MVVM 원칙상 View가 Service를 참조하는 것은 위반이다. `@Environment` 또는 ViewModel에서 AlarmDetailViewModel을 팩토리 패턴으로 생성하는 방식이 바람직하다. R1에서도 같은 지적을 했으나 수정되지 않았다. 단, 이 패턴이 SwiftUI의 의존성 주입에서 흔히 사용되는 현실적 타협점이므로 심각도는 중간.

2. **Protocol 미일관성**: `AlarmStore`, `AlarmKitService`, `LiveActivityManager`에는 프로토콜이 없다. 나머지 Service(AudioService, LocalNotificationService, VolumeService)에는 프로토콜이 있다. 테스트 가능성 측면에서 불일치.

3. **`SettingsView` init에서 `alarmStore: AlarmStore` 직접 전달 (75행)**: 이것도 View가 Service를 알고 있는 패턴이다. SettingsViewModel init에 필요한 것이므로 현실적이나, 이상적이지 않다.

---

### 3. HIG 준수 + 디자인 시스템: 8/10

**합격 기준 충족:**
- [PASS] PersonalColorDesignSystem 토큰 전면 사용: `Color.pTextPrimary/Secondary/Tertiary`, `Color.pAccentPrimary/Secondary`, `Color.pWarning`, `Color.pGlassFill` — 하드코딩 색상 없음
- [PASS] GlassCard 컴포넌트 사용 (AlarmRowView 12~73행, AlarmListView 배너 94~117행)
- [PASS] GradientBackground 사용 (모든 View)
- [PASS] HapticManager 사용 (AlarmListView: impact/selection/notification, AlarmDetailView: selection/notification, WeeklyAlarmView: selection/impact/notification)
- [PASS] ToastView 사용 (AlarmDetailView 148행)
- [PASS] 터치 영역 44pt: 모든 주요 버튼/토글에 `frame(minWidth: 44, minHeight: 44)` 적용
- [PASS] 접근성 레이블: `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityAddTraits` 적절히 사용
- [PASS] 내비게이션 패턴: NavigationStack + sheet + TabView
- [PASS] 에러 처리 UI: AlarmDetailView에 `.alert` (164~173행), AlarmListView에 에러 메시지 배너 (28~39행)
- [PASS] 로딩 상태 UI: AlarmListView에 ProgressView (45~50행), SettingsView에 AlarmKit 권한 확인 중 ProgressView (61~63행)
- [PASS] 피드백/문의 링크: SettingsView에 Link 컴포넌트 (82~94행)
- [PASS] Dynamic Type: semantic font size 사용 (.caption, .body, .title2, .title3, .largeTitle 등)
- [PASS] R1 지적: 요일 버튼 44pt 확보

**잔존 위반 사항:**

1. **`GradientBackground().ignoresSafeArea()` + NavigationStack ZStack 구조**: 모든 View(AlarmListView, AlarmDetailView, SettingsView, WeeklyAlarmView)에서 ZStack > GradientBackground + NavigationStack 구조를 사용한다. GradientBackground가 NavigationStack 바깥에 있어 네비게이션 바 뒤로 확장된다. 대부분의 경우 시각적으로 문제없으나 잠재적 가독성 이슈가 있다. 심각도 낮음.

2. **주간 알람 요일 그룹별 표시 미구현**: SPEC 기능 10에서 "요일 그룹별 표시"를 언급했으나, WeeklyAlarmView는 단순 리스트만 표시한다. 기능적으로 문제는 없으나 UX 개선 여지.

---

### 4. API 활용: 7/10

**합격 기준 충족:**
- [PASS] AlarmKit: `import AlarmKit` 추가됨, `AlarmManager.shared`, `AlarmPresentation`, `AlarmAttributes`, `AlarmButton`, `AlarmSchedule.fixed/relative` 사용
- [PASS] AppIntents: StopAlarmIntent/SnoozeAlarmIntent가 `LiveActivityIntent` 프로토콜 구현, `@Parameter` 사용
- [PASS] ActivityKit: `Activity<AlarmActivityAttributes>` 사용, start/update/end 구현
- [PASS] UNUserNotificationCenter: 권한 요청, `UNCalendarNotificationTrigger`, 배경 리마인더 구현
- [PASS] API 호출이 Service 레이어에서만 수행됨
- [PASS] 에러 처리 구현 (AlarmError enum + LocalizedError)
- [PASS] R1 지적: AlarmKitService DI 주입으로 상태 유지 문제 해소

**잔존 위반 사항:**

1. **`Services/AlarmKitService.swift` — AlarmKit API 타입 경로 불확실**: 68행 `AlarmKit.Alarm.Schedule`, 81행 `AlarmKit.Alarm.Schedule.Relative.Time`, 83행 `AlarmKit.Alarm.Schedule.Relative.Recurrence.weekly` 등의 fully qualified 타입 경로가 실제 AlarmKit 공개 API와 일치하는지 검증 불가능하다. AlarmKit은 iOS 26 신규 프레임워크로, 실제 컴파일 시 타입이 맞지 않을 수 있다. iOS 26 SDK가 없는 환경에서는 `#if os(iOS)` 가드로 조건부 컴파일되므로 당장 빌드 에러는 나지 않겠으나, 실제 iOS 26 타겟 빌드 시 문제가 될 수 있다.

2. **`Services/AlarmKitService.swift` 22행 — `requestAuthorization()` 반환 타입**: `manager.requestAuthorization()`의 반환값을 `status`로 받아 `== .authorized`와 비교한다. 실제 AlarmKit API의 시그니처가 이와 일치하는지 확인 불가. `requestAuthorization()`이 `AlarmAuthorizationStatus` enum을 반환하는지, `Bool`을 반환하는지 공개 문서가 확정되지 않았다.

3. **`SettingsViewModel.swift` 73행 — AlarmKitService 새 인스턴스**: `loadAlarmKitAuthStatus()` 내부에서 `AlarmKitService()`를 매번 새로 생성한다. AlarmStore에 주입된 AlarmKitService 인스턴스를 재활용해야 한다. SettingsViewModel이 AlarmStore를 가지고 있으므로, AlarmStore를 통해 권한 상태를 확인하는 메서드를 추가하는 것이 바람직하다.

4. **`LiveActivityManager.swift` 41행 — `@available(iOS 17.0, *)`**: 최소 타겟이 iOS 17.0인데 `@available(iOS 17.0, *)` 가드가 있다. 기능적으로 무해하지만 불필요한 가드다.

---

### 5. 기능성 및 코드 가독성: 7/10

**합격 기준 충족:**
- [PASS] SPEC 11개 기능 모두 구현 (상세 아래 표 참고)
- [PASS] 파일명이 SPEC 컨벤션과 일치
- [PASS] `private(set)` 적절히 사용 (모든 ViewModel, AppDelegate)
- [PASS] 에러 타입 `enum AlarmError: Error, LocalizedError, Sendable` 정의
- [PASS] MARK 주석으로 코드 영역 구분
- [PASS] 코드 중복 최소화 (AlarmRowView 재사용)
- [PASS] R1 지적: 불필요한 do 블록 제거 (AlarmDetailViewModel.save())
- [PASS] R1 지적: 빈 메서드 `checkForCompletedAlarms()` 제거

**잔존 위반 사항:**

1. **접근 제어자 미명시 (R1 피드백 #15 미반영)**: `struct Alarm`, `enum AlarmMode`, `enum AlarmSchedule`, `enum Weekday`, `enum AlarmError`, `final class AlarmListViewModel`, `actor AlarmStore`, `struct AlarmListView` 등 주요 타입 선언에 명시적 접근 제어자가 없다. Swift의 기본값 `internal`이 적용되므로 동작에 문제 없으나, SPEC에서 "모든 public/internal 프로퍼티에 접근 제어자 명시"를 요구했다. 2회 연속 미반영.

2. **`AlarmStore.swift` 259행 — `try?`로 에러 무시**: `scheduleNextAlarm()` 내에서 `try? await localNotificationService.scheduleAlarm(for: alarm)`, `try? await service.scheduleAlarm(for: next)`로 에러를 무시한다. 스케줄링 실패 시 사용자에게 알림이 없다. 최소한 `AppLogger.error`로 로깅해야 한다.

3. **`SnoozeAlarmIntent.swift` 33행 — `AlarmKitService()` 새 인스턴스**: `perform()` 내부에서 `let service = AlarmKitService()`로 새 인스턴스를 생성한다. AppIntent에서는 앱 프로세스와 별개로 실행될 수 있으므로 부득이한 측면이 있으나, 이전 AlarmKit ID 추적이 불가능하다.

---

## 기능 구현 현황 (R2)

| # | 기능 | 구현 여부 | 근거 |
|---|------|-----------|------|
| 1 | 알람 목록 (CRUD) | **PASS** | AlarmListView + AlarmListViewModel + AlarmStore. List + swipeActions 삭제/건너뛰기, 토글, 다음 알람 배너 모두 구현. 에러 표시 UI 추가됨. |
| 2 | 알람 생성/편집 | **PASS** | AlarmDetailView + AlarmDetailViewModel. 시간(Picker), 제목, 반복, 사운드, AlarmMode 토글, 조용한 알람 토글. iOS 26 미만 토스트 표시. |
| 3 | AlarmMode 분기 스케줄링 | **PASS** | AlarmStore.scheduleNextAlarm()에서 alarmMode 분기. AlarmKitService DI 주입으로 상태 유지. |
| 4 | 조용한 알람 | **PASS** | AudioService.isEarphoneConnected() (actor-isolated). AlarmDetailView에서 alarmKit 모드 시 disabled. 이어폰 미연결 시 경고 표시. |
| 5 | 볼륨 자동 조절 (80%) | **PASS** | VolumeService.ensureMinimumVolume()/restoreVolume(). AudioService에서 playAlarmSound() 시 호출, stopAlarmSound() 시 복원. |
| 6 | 앱 종료 시 푸시 알림 | **PASS** | AppDelegate.applicationDidEnterBackground에서 scheduleBackgroundReminder, applicationWillEnterForeground에서 cancelBackgroundReminder. `configure()` 메서드로 DI. |
| 7 | 알람 1번 건너뛰기 | **PASS** | AlarmStore.skipOnceAlarm/clearSkipOnceAlarm. AlarmListView/WeeklyAlarmView에서 swipeActions. AlarmRowView에서 건너뛰기 상태 배지 표시. |
| 8 | Live Activity | **PASS** | LiveActivityManager actor. AlarmActivityAttributes 정의. AlarmStore.updateLiveActivity()에서 모든 CRUD 후 호출. start/update/end/endAllActivities 구현. |
| 9 | 설정 화면 | **PASS** | SettingsView: Live Activity 토글 + AlarmKit 권한 상태 + 앱 버전 + 피드백/문의 링크. 로딩 상태 ProgressView 표시. |
| 10 | 주간 알람 화면 | **PASS** | WeeklyAlarmView + WeeklyAlarmViewModel. weekly 필터링, 삭제, 건너뛰기. (요일 그룹별 표시는 미구현, 기본 리스트) |
| 11 | 탭바 네비게이션 | **PASS** | BetterAlarmApp에서 TabView 3탭 (알람/주간 알람/설정). @UIApplicationDelegateAdaptor 사용. SF Symbols 아이콘. |

---

## 최종 채점

| 항목 | 점수 | 비중 | 가중점수 |
|------|------|------|----------|
| Swift 6 동시성 | 8/10 | 30% | 2.4 |
| MVVM 분리 | 8/10 | 25% | 2.0 |
| HIG 준수 | 8/10 | 20% | 1.6 |
| API 활용 | 7/10 | 15% | 1.05 |
| 기능성/가독성 | 7/10 | 10% | 0.7 |
| **합계** | | **100%** | **7.75** |

**반올림 가중 점수**: **7.8 / 10.0**

**합격 조건 확인**:
- 가중 점수 7.8 >= 7.0: PASS
- Swift 6 동시성 8점 > 4점: PASS
- MVVM 분리 8점 > 4점: PASS

---

## 항목별 점수 요약

- Swift 6 동시성: 8/10 — R1 피드백 6개 중 6개 반영. VolumeService의 actor 내부 @MainActor 메서드가 유일한 잔존 이슈이나 기능적으로 정상 동작하며 심각도 낮음.
- MVVM 분리: 8/10 — 레이어 분리 우수. View가 AlarmStore를 DI 목적으로 소유하는 패턴이 잔존하나 SwiftUI에서 현실적 타협점. Protocol 일관성 부족.
- HIG 준수: 8/10 — PersonalColorDesignSystem 전면 사용, 44pt 터치 영역 확보, 로딩/에러 UI 추가, 피드백 링크 추가. 주간 알람 요일 그룹 미구현.
- API 활용: 7/10 — AlarmKit import 해소, DI 주입 해소. AlarmKit API 타입 경로 검증 불가, SettingsViewModel에서 AlarmKitService 신규 인스턴스 생성.
- 기능성/가독성: 7/10 — 11개 기능 모두 구현. 접근 제어자 명시 2회 연속 미반영. try? 에러 무시 패턴 잔존.

---

## 구체적 개선 지시 (합격 이후 권장 사항)

아래는 합격 판정이므로 필수가 아닌 권장 사항이다. 다음 이터레이션에서 반영하면 코드 품질이 향상된다.

1. **전체 타입 접근 제어자 명시** (3회차 미반영 시 아키텍처 재설계 지시 대상): `struct Alarm`, `enum AlarmMode`, `actor AlarmStore`, `final class AlarmListViewModel` 등 모든 주요 타입에 `internal` 키워드를 명시하라. 프로퍼티 수준에서는 이미 `private(set)` / `private`이 잘 사용되고 있으므로 타입 수준만 보완하면 된다.

2. **`AlarmStore.scheduleNextAlarm()` 에러 로깅**: `try? await`로 무시하는 대신 `do { try await ... } catch { AppLogger.error("Scheduling failed: \(error)", category: .alarm) }`로 변경하여 실패 원인을 추적 가능하게 하라.

3. **`SettingsViewModel.loadAlarmKitAuthStatus()` — AlarmStore를 통한 권한 확인**: `AlarmKitService()`를 새로 만들지 말고, AlarmStore에 `func checkAlarmKitPermission() async -> Bool` 메서드를 추가하여 주입된 AlarmKitService 인스턴스를 재활용하라.

4. **VolumeService의 `@MainActor` 헬퍼 분리**: actor 내부 `@MainActor` 메서드를 별도 `@MainActor` helper struct로 분리하면 격리 경계가 명확해진다.

5. **View의 AlarmStore 직접 소유 해소**: `@Environment`에 AlarmStore를 등록하거나, ViewModel 팩토리 패턴을 도입하여 View가 Service를 직접 참조하지 않도록 개선하라.

6. **`LiveActivityManager` — `@available(iOS 17.0, *)` 불필요 가드 제거**: 최소 타겟이 iOS 17.0이므로 이 가드는 제거해도 된다.

---

**방향 판단**: 현재 방향 유지

R1 피드백 15개 중 14개를 반영하여 컴파일 에러 예상 4건 모두 해소, 핵심 로직 버그(AlarmKitService DI) 해소, 동시성 위반 3건 해소, HIG 위반 6건 해소. 아키텍처 기반(MVVM + actor + @Observable + 단방향 의존)이 견고하게 유지되고 있으며, 잔존 이슈는 모두 권장 수준이다.
