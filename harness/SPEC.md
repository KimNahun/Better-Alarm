# BetterAlarm

## 개요

BetterAlarm은 iOS 사용자를 위한 알람 앱으로, AlarmKit(iOS 26+)과 로컬 알림(iOS 17+)을 이중 지원하여 앱 종료 상태에서도 안정적으로 알람을 울릴 수 있다. Swift 6 엄격 동시성 + SwiftUI + MVVM 아키텍처 기반으로 구현하며, PersonalColorDesignSystem 디자인 시스템을 전면 사용한다.

## 타겟 플랫폼

- iOS 17.0 이상 (최소), iOS 26.0 이상 (AlarmKit 기능)
- Swift 버전: Swift 6 (엄격 동시성 필수)
- 번들 ID: com.nahun.BetterAlarm
- 필요 권한: 알림(UNUserNotificationCenter), AlarmKit(iOS 26+), 오디오 세션(AVAudioSession)

---

## 아키텍처

### 레이어 구조

```
output/
├── App/
│   └── BetterAlarmApp.swift              # @main, 의존성 주입 루트, AppDelegate 연결
├── Views/
│   ├── AlarmList/
│   │   └── AlarmListView.swift           # 알람 목록 화면
│   ├── AlarmDetail/
│   │   └── AlarmDetailView.swift         # 알람 생성/편집 화면
│   └── Components/
│       └── AlarmRowView.swift            # 알람 목록 행 컴포넌트
├── ViewModels/
│   ├── AlarmList/
│   │   └── AlarmListViewModel.swift      # 알람 목록 상태 관리
│   └── AlarmDetail/
│       └── AlarmDetailViewModel.swift    # 알람 생성/편집 상태 관리
├── Models/
│   ├── Alarm.swift                       # 알람 데이터 모델
│   ├── AlarmMode.swift                   # AlarmMode enum
│   ├── AlarmSchedule.swift               # AlarmSchedule enum + Weekday enum
│   └── AlarmError.swift                  # 에러 타입 정의
├── Services/
│   ├── AlarmStore.swift                  # 알람 CRUD + UserDefaults 저장
│   ├── AlarmKitService.swift             # AlarmKit 기반 스케줄링 (iOS 26+)
│   ├── LocalNotificationService.swift    # UNUserNotificationCenter 기반 스케줄링
│   ├── AudioService.swift                # AVAudioPlayer 기반 소리 재생 + 조용한 알람
│   └── VolumeService.swift              # 볼륨 자동 조절 (80%)
├── Intents/
│   ├── StopAlarmIntent.swift             # LiveActivityIntent: 알람 정지
│   └── SnoozeAlarmIntent.swift           # LiveActivityIntent: 스누즈
├── Delegates/
│   └── AppDelegate.swift                 # 앱 종료 시 푸시 알림 등록/해제
└── Shared/
    └── AlarmMetadata.swift               # AlarmKit AlarmMetadata 구현
```

### 동시성 경계

- **View**: `@MainActor` struct -- UI 선언만 담당, 상태 소유 없음
- **ViewModel**: `@MainActor final class` + `@Observable` -- UI 상태 소유, Service 호출
- **Service**: `actor` -- 비동기 데이터 처리, 외부 API 호출
- **Model**: `struct` + `Sendable` -- 순수 데이터, 부수효과 없음

### 의존성 흐름

```
View → ViewModel → Service → (AlarmKit / UNUserNotificationCenter / AVAudioSession / 기타)
```

역방향 의존 금지. Service는 ViewModel을 모른다.

---

## 기능 목록

### 기능 1: 알람 목록 (CRUD)

- **설명**: 저장된 알람을 목록으로 표시하고, 생성/수정/삭제/토글을 지원한다.
- **사용자 스토리**: 사용자가 알람 목록을 보고, 스와이프로 삭제하고, 토글로 활성화/비활성화할 수 있다. 다음 알람 시간이 상단에 표시된다.
- **관련 파일**: `AlarmListView.swift`, `AlarmListViewModel.swift`, `AlarmStore.swift`, `AlarmRowView.swift`
- **사용 API**: 없음 (내부 CRUD)
- **HIG 패턴**: `NavigationStack`, `List`, `swipeActions`, `Toggle`

### 기능 2: 알람 생성/편집

- **설명**: 시간, 제목, 반복 요일, 사운드, AlarmMode 토글, 조용한 알람 토글을 설정하는 화면.
- **사용자 스토리**: 사용자가 새 알람을 만들거나 기존 알람을 편집한다. "앱이 꺼진 상태에서도 알람 받기" 토글과 "조용한 알람" 토글을 설정할 수 있다.
- **관련 파일**: `AlarmDetailView.swift`, `AlarmDetailViewModel.swift`, `AlarmStore.swift`
- **사용 API**: 없음 (UI + 모델 수정)
- **HIG 패턴**: `sheet`, `DatePicker`, `Toggle`, `NavigationStack`

### 기능 3: AlarmMode 분기 스케줄링

- **설명**: `alarm.alarmMode`에 따라 AlarmKit 또는 로컬 알림으로 분기하여 알람을 스케줄링한다.
- **사용자 스토리**: 사용자가 alarmKit 모드를 켜면 앱이 꺼진 상태에서도 알람이 울린다. local 모드는 UNUserNotificationCenter로 스케줄링된다.
- **관련 파일**: `AlarmStore.swift`, `AlarmKitService.swift`, `LocalNotificationService.swift`
- **사용 API**: AlarmKit (iOS 26+), UNUserNotificationCenter (iOS 17+)
- **HIG 패턴**: 없음 (백그라운드 로직)

### 기능 4: 조용한 알람

- **설명**: `isSilentAlarm = true`이면 이어폰으로만 소리를 출력한다. 이어폰 미연결 시 사용자에게 안내한다.
- **사용자 스토리**: 사용자가 조용한 알람을 켜면, 이어폰이 연결된 경우에만 소리가 출력된다.
- **관련 파일**: `AudioService.swift`, `AlarmDetailView.swift`, `AlarmDetailViewModel.swift`
- **사용 API**: AVAudioSession, AVAudioPlayer
- **HIG 패턴**: `Toggle` (alarmKit 모드일 때 disabled 상태)

### 기능 5: 볼륨 자동 조절 (80%)

- **설명**: local 모드 알람이 시작될 때 볼륨이 0.8 미만이면 자동으로 0.8로 올리고, 알람 종료 후 원래 볼륨으로 복원한다.
- **사용자 스토리**: 사용자가 볼륨을 낮춰 놓았더라도 알람이 울릴 때 충분한 볼륨으로 들린다.
- **관련 파일**: `VolumeService.swift`, `AudioService.swift`
- **사용 API**: MPVolumeView, AVAudioSession
- **HIG 패턴**: 없음 (자동 동작)

### 기능 6: 앱 종료 시 푸시 알림 (1회)

- **설명**: local 모드 알람이 활성화된 상태에서 앱이 백그라운드/종료되면 즉시 로컬 알림 1건을 등록한다. 포그라운드 복귀 시 취소한다.
- **사용자 스토리**: 사용자가 앱을 닫아도 알람이 설정되어 있다는 알림을 받아 안심할 수 있다.
- **관련 파일**: `AppDelegate.swift`, `LocalNotificationService.swift`, `AlarmStore.swift`
- **사용 API**: UNUserNotificationCenter
- **HIG 패턴**: 없음 (시스템 알림)

### 기능 7: 알람 1번만 건너뛰기

- **설명**: 주간 반복 알람에서 다음 1회만 건너뛸 수 있다. 건너뛴 상태는 UI에 표시된다.
- **사용자 스토리**: 사용자가 주간 알람을 끄지 않고 다음 1번만 건너뛸 수 있다.
- **관련 파일**: `AlarmListView.swift`, `AlarmListViewModel.swift`, `AlarmStore.swift`
- **사용 API**: 없음
- **HIG 패턴**: `swipeActions` 또는 컨텍스트 메뉴

---

## AlarmMode 분기 설계

### enum 정의

```
enum AlarmMode: String, Codable, Sendable {
    case alarmKit   // iOS 26+ 전용: AlarmKit 사용
    case local      // iOS 17+: UNUserNotificationCenter 기반
}
```

### 분기 흐름 (AlarmStore.scheduleNextAlarm)

```
AlarmStore.scheduleNextAlarm()
  ├─ alarm.alarmMode == .alarmKit
  │   └─ if #available(iOS 26, *)
  │       ├─ YES → AlarmKitService.scheduleAlarm(for:)
  │       └─ NO  → fallback to LocalNotificationService (이론상 발생하지 않음; UI에서 차단)
  │
  └─ alarm.alarmMode == .local
      └─ LocalNotificationService.scheduleAlarm(for:)
```

### AlarmKitService (actor)

- `@available(iOS 26.0, *)` 가드 필수
- `AlarmManager.shared` 사용
- `schedule(id:configuration:)`: Fixed(1회성, 특정 날짜) / Relative(주간 반복) 분기
- `alarmUpdates` AsyncSequence 모니터링
- `StopAlarmIntent`, `SnoozeAlarmIntent` 연동
- 조용한 알람 미지원 (alarmKit 모드에서 `isSilentAlarm` 옵션 비활성화)

### LocalNotificationService (actor)

- `UNUserNotificationCenter` 사용
- `requestAuthorization(options:)`: 알림 권한 요청
- `scheduleAlarm(for:)`: `UNCalendarNotificationTrigger`로 알람 시간에 알림 등록
- `cancelAlarm(for:)`: 등록된 알림 제거
- 앱 포그라운드 시: `AudioService`를 통해 `AVAudioPlayer`로 직접 소리 재생
- 앱 백그라운드 시: 시스템 알림 사운드 사용

### AudioService (actor)

- `AVAudioPlayer` 인스턴스 관리
- `playAlarmSound(soundName:isSilent:)`:
  - `isSilent = true`: `AVAudioSession` 포트 확인 → 이어폰 연결 시만 재생
  - `isSilent = false`: 기본 스피커 출력
- `stopAlarmSound()`: 재생 중지
- `AVAudioSession.Category`: `.playback`

### VolumeService (actor)

- `MPVolumeView`의 슬라이더를 통해 시스템 볼륨 제어
- `ensureMinimumVolume()`: 현재 볼륨 < 0.8이면 0.8으로 설정, 원래 값 저장
- `restoreVolume()`: 저장된 원래 볼륨으로 복원
- local 모드 알람 시작 시 `ensureMinimumVolume()`, 종료 시 `restoreVolume()` 호출

---

## iOS 버전 분기 처리 방식

### 컴파일 타임 가드

- AlarmKit 관련 코드 전체에 `@available(iOS 26.0, *)` 적용
- `AlarmKitService` actor 선언부에 `@available(iOS 26.0, *)` 적용
- `StopAlarmIntent`, `SnoozeAlarmIntent`에 `@available(iOS 26.0, *)` 적용
- `AlarmMetadata`에 `@available(iOS 26.0, *)` 적용

### 런타임 가드

- 알람 편집 화면에서 "앱이 꺼진 상태에서도 알람 받기" 토글 ON 시도 시:
  ```
  if #available(iOS 26, *) {
      alarm.alarmMode = .alarmKit
  } else {
      // 토글을 ON으로 바꾸지 않음
      // PersonalColorDesignSystem의 토스트 컴포넌트로 메시지 표시:
      // "이 기능은 iOS 26 이상에서만 사용할 수 있습니다."
  }
  ```

- `AlarmStore.scheduleNextAlarm()`에서:
  ```
  if alarm.alarmMode == .alarmKit {
      if #available(iOS 26, *) {
          await alarmKitService.scheduleAlarm(for: alarm)
      }
      // iOS 26 미만에서는 UI에서 이미 차단되므로 도달하지 않음
  } else {
      await localNotificationService.scheduleAlarm(for: alarm)
  }
  ```

### 기본값

- `Alarm` 모델의 `alarmMode` 기본값: `.local` (iOS 17+ 모든 기기에서 동작 보장)

---

## 데이터 모델 필드 전체 목록

### Alarm (struct, Sendable, Codable, Identifiable, Equatable)

| 필드 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `id` | `UUID` | `UUID()` | 고유 식별자 |
| `title` | `String` | `""` | 알람 제목 |
| `hour` | `Int` | `8` | 시 (0-23) |
| `minute` | `Int` | `0` | 분 (0-59) |
| `schedule` | `AlarmSchedule` | `.once` | 반복 스케줄 |
| `isEnabled` | `Bool` | `true` | 활성화 여부 |
| `soundName` | `String` | `"default"` | 알람 사운드 파일명 |
| `createdAt` | `Date` | `Date()` | 생성 시각 |
| `skippedDate` | `Date?` | `nil` | 건너뛸 날짜 |
| `alarmMode` | `AlarmMode` | `.local` | 알람 모드 (alarmKit / local) |
| `isSilentAlarm` | `Bool` | `false` | 조용한 알람 여부 |

### AlarmMode (enum, String, Codable, Sendable)

| 케이스 | 설명 |
|--------|------|
| `.alarmKit` | iOS 26+ AlarmKit 사용, 앱 꺼진 상태에서도 울림 |
| `.local` | iOS 17+ UNUserNotificationCenter 기반 |

### AlarmSchedule (enum, Codable, Equatable, Sendable)

| 케이스 | 연관값 | 설명 |
|--------|--------|------|
| `.once` | 없음 | 1회성 알람 |
| `.weekly(Set<Weekday>)` | 요일 집합 | 주간 반복 |
| `.specificDate(Date)` | 날짜 | 특정 날짜 1회 |

### Weekday (enum, Int, Codable, CaseIterable, Hashable, Sendable)

| 케이스 | rawValue | shortName |
|--------|----------|-----------|
| `.sunday` | 1 | "일" |
| `.monday` | 2 | "월" |
| `.tuesday` | 3 | "화" |
| `.wednesday` | 4 | "수" |
| `.thursday` | 5 | "목" |
| `.friday` | 6 | "금" |
| `.saturday` | 7 | "토" |

### AlarmError (enum, Error)

| 케이스 | 설명 |
|--------|------|
| `.notAuthorized` | 알림/AlarmKit 권한 없음 |
| `.scheduleFailed(String)` | 스케줄링 실패 |
| `.soundNotFound(String)` | 사운드 파일 없음 |
| `.earphoneNotConnected` | 조용한 알람: 이어폰 미연결 |
| `.alarmKitUnavailable` | iOS 26 미만에서 AlarmKit 시도 |

---

## API 활용 계획

### AlarmKit (iOS 26+)

- **사용 타입**: `AlarmManager`, `AlarmAttributes`, `AlarmPresentation`, `AlarmButton`, `AlarmSchedule.fixed`, `AlarmSchedule.relative`, `AlarmManager.AlarmConfiguration`, `AlarmMetadata`
- **권한 요청 시점**: 알람 생성 시 `alarmMode = .alarmKit`이 처음 설정될 때 `requestAuthorization()` 호출
- **연동 기능**: 기능 3 (AlarmMode 분기 스케줄링)
- **스트림**: `alarmUpdates` AsyncSequence로 알람 상태(alerting, completed) 실시간 모니터링

### AppIntents

- **Intent 목록**:
  - `StopAlarmIntent`: 잠금화면 Live Activity에서 알람 정지
  - `SnoozeAlarmIntent`: 잠금화면 Live Activity에서 스누즈 (5분 후 재알람)
- **Siri / Shortcuts 연동**: Live Activity 버튼을 통한 실행 (Siri 직접 연동은 범위 외)
- **`@Parameter` 목록**: `alarmID: String` (UUID 문자열)

### UNUserNotificationCenter (iOS 17+)

- **사용 타입**: `UNUserNotificationCenter`, `UNMutableNotificationContent`, `UNCalendarNotificationTrigger`, `UNNotificationRequest`
- **권한 요청 시점**: 앱 최초 실행 시 또는 알람 최초 생성 시
- **연동 기능**: 기능 3 (local 모드), 기능 6 (앱 종료 시 푸시 알림)

---

## 뷰 계층 (Navigation Flow)

```
BetterAlarmApp (@main)
  └─ NavigationStack
       └─ AlarmListView (루트)
            ├─ [+] 버튼 → sheet → AlarmDetailView (생성 모드)
            ├─ 알람 행 탭 → sheet → AlarmDetailView (편집 모드)
            ├─ 알람 행 swipeActions → 삭제 / 건너뛰기
            └─ 알람 행 Toggle → 활성화/비활성화
```

- `AlarmListView`: `NavigationStack` 루트, `List` + `AlarmRowView` 반복
- `AlarmDetailView`: `.sheet`으로 표시, `DatePicker`(시/분), 제목 입력, 요일 선택, AlarmMode 토글, 조용한 알람 토글, 사운드 선택

---

## 각 파일의 책임과 주요 타입/메서드

### App/BetterAlarmApp.swift

- `@main struct BetterAlarmApp: App`
- `@UIApplicationDelegateAdaptor` -- `AppDelegate` 연결
- 의존성 생성 및 주입 (AlarmStore, Services)

### Views/AlarmList/AlarmListView.swift

- `@MainActor struct AlarmListView: View`
- `@State private var viewModel: AlarmListViewModel`
- 다음 알람 표시, 알람 목록 List, 생성 버튼, swipeActions(삭제, 건너뛰기)
- `PersonalColorDesignSystem` 색상/폰트/컴포넌트 사용

### Views/AlarmDetail/AlarmDetailView.swift

- `@MainActor struct AlarmDetailView: View`
- `@State private var viewModel: AlarmDetailViewModel`
- 시간 선택(DatePicker), 제목 입력, 요일 선택, AlarmMode 토글, 조용한 알람 토글
- AlarmMode 토글 ON 시 iOS 버전 체크 + 토스트 표시
- `alarmMode == .alarmKit`일 때 조용한 알람 토글 비활성화(disabled)

### Views/Components/AlarmRowView.swift

- `@MainActor struct AlarmRowView: View`
- 시간 표시, 제목, 반복 설명, 활성화 토글
- `GlassCardView` 컴포넌트 사용

### ViewModels/AlarmList/AlarmListViewModel.swift

- `@MainActor @Observable final class AlarmListViewModel`
- `private(set) var alarms: [Alarm]`
- `private(set) var nextAlarmDisplayString: String?`
- `func loadAlarms()`, `func toggleAlarm(_:enabled:)`, `func deleteAlarm(_:)`, `func skipOnceAlarm(_:)`, `func clearSkip(_:)`
- `AlarmStore` 의존

### ViewModels/AlarmDetail/AlarmDetailViewModel.swift

- `@MainActor @Observable final class AlarmDetailViewModel`
- `var hour: Int`, `var minute: Int`, `var title: String`, `var selectedWeekdays: Set<Weekday>`, `var alarmMode: AlarmMode`, `var isSilentAlarm: Bool`, `var soundName: String`
- `private(set) var showAlarmKitUnavailableToast: Bool`
- `func save()`, `func toggleAlarmMode(_:)` (iOS 버전 체크 포함), `func validateSilentAlarm()`
- `AlarmStore` 의존

### Models/Alarm.swift

- `struct Alarm: Codable, Identifiable, Equatable, Sendable`
- 전체 필드 (위 데이터 모델 참조)
- `var timeString: String`, `var displayTitle: String`, `var repeatDescriptionWithoutSkip: String`
- `var isSkippingNext: Bool`, `var isWeeklyAlarm: Bool`
- `func nextTriggerDate(from:) -> Date?`

### Models/AlarmMode.swift

- `enum AlarmMode: String, Codable, Sendable`

### Models/AlarmSchedule.swift

- `enum AlarmSchedule: Codable, Equatable, Sendable`
- `enum Weekday: Int, Codable, CaseIterable, Hashable, Sendable`

### Models/AlarmError.swift

- `enum AlarmError: Error`

### Services/AlarmStore.swift

- `actor AlarmStore`
- `private(set) var alarms: [Alarm]`
- `func loadAlarms()`, `func saveAlarms()`
- `func createAlarm(...)`, `func updateAlarm(...)`, `func deleteAlarm(...)`, `func toggleAlarm(_:enabled:)`
- `func skipOnceAlarm(...)`, `func clearSkipOnceAlarm(...)`
- `func scheduleNextAlarm()` -- AlarmMode 분기 포함
- `func handleAlarmCompleted(...)`, `func checkForCompletedAlarms()`
- `var nextAlarm: Alarm?`, `var nextAlarmDisplayString: String?`
- UserDefaults 저장/로드

### Services/AlarmKitService.swift

- `@available(iOS 26.0, *) actor AlarmKitService`
- `func requestPermission() async -> Bool`
- `func scheduleAlarm(for:) async throws`
- `func cancelAlarm(for:)`, `func stopAllAlarms() async`
- `func snoozeAlarm(id:) async`
- `func startMonitoring()` -- `alarmUpdates` AsyncSequence 감시
- AlarmKit 타입 사용: `AlarmManager`, `AlarmAttributes`, `AlarmSchedule`, `AlarmConfiguration`

### Services/LocalNotificationService.swift

- `actor LocalNotificationService`
- `func requestPermission() async -> Bool`
- `func scheduleAlarm(for:) async throws` -- `UNCalendarNotificationTrigger` 사용
- `func cancelAlarm(for:) async`
- `func cancelAllAlarms() async`
- `func scheduleBackgroundReminder(for:) async` -- 기능 6: 앱 종료 시 즉시 알림 1건
- `func cancelBackgroundReminder() async` -- 포그라운드 복귀 시 알림 취소

### Services/AudioService.swift

- `actor AudioService`
- `func playAlarmSound(soundName:isSilent:) async throws`
- `func stopAlarmSound() async`
- `func isEarphoneConnected() -> Bool` -- `AVAudioSession.currentRoute.outputs` 포트 확인
- AVAudioSession 카테고리: `.playback`

### Services/VolumeService.swift

- `actor VolumeService`
- `private var originalVolume: Float?`
- `func ensureMinimumVolume() async` -- 볼륨 < 0.8이면 0.8으로 설정
- `func restoreVolume() async` -- 원래 볼륨 복원
- MPVolumeView 슬라이더를 통한 시스템 볼륨 제어

### Intents/StopAlarmIntent.swift

- `@available(iOS 26.0, *) struct StopAlarmIntent: LiveActivityIntent`
- `@Parameter(title: "알람 ID") var alarmID: String`
- `func perform() async throws -> some IntentResult`

### Intents/SnoozeAlarmIntent.swift

- `@available(iOS 26.0, *) struct SnoozeAlarmIntent: LiveActivityIntent`
- `@Parameter(title: "알람 ID") var alarmID: String`
- `func perform() async throws -> some IntentResult`

### Delegates/AppDelegate.swift

- `class AppDelegate: NSObject, UIApplicationDelegate`
- `func applicationDidEnterBackground(_:)` -- local 모드 알람 활성화 시 즉시 알림 등록
- `func applicationWillEnterForeground(_:)` -- 알림 취소 (`removeDeliveredNotifications`, `removePendingNotificationRequests`)
- 알림 내용: `"[알람 제목] 알람이 설정되어 있습니다. 알람 시각: [시간]"`

### Shared/AlarmMetadata.swift

- `@available(iOS 26.0, *) nonisolated struct BetterAlarmMetadata: AlarmMetadata`

---

## 코드 컨벤션 (Generator가 따를 것)

- 뷰 파일: `[Feature]View.swift` -- body만 갖는 순수 뷰
- 뷰모델 파일: `[Feature]ViewModel.swift` -- `@Observable`, `@MainActor`
- 서비스 파일: `[Feature]Service.swift` -- `actor`, `protocol` 우선
- 모든 `public`/`internal` 프로퍼티에 접근 제어자 명시
- `private(set)`으로 외부 변이 차단
- 에러 타입은 `enum [Domain]Error: Error`로 정의
- `DispatchQueue`, `@Published`, `ObservableObject` 사용 금지
- PersonalColorDesignSystem 토큰 사용 필수: `Color.p*`, `UIFont.p*`, `GlassCardView`, `HapticManager`
- 하드코딩 색상/폰트 크기 금지
- `import SwiftUI`는 View 파일에서만 허용, ViewModel에서 금지
