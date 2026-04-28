# 프로젝트 컨텍스트

> Planner, Generator, Evaluator가 **반드시 먼저 읽어야 하는** 프로젝트 고정 요구사항.
> 이 파일에 적힌 내용은 사용자 프롬프트보다 우선한다.

---

## 대상 프로젝트

- **앱 이름**: BetterAlarm
- **번들 ID**: com.nahun.BetterAlarm
- **최소 타겟 iOS**: 17.0 (AlarmKit 기능은 iOS 26+)
- **Swift 버전**: Swift 6 (엄격 동시성 필수)
- **UI 프레임워크**: SwiftUI (신규 화면), 일부 UIKit 잔존 코드 가능

---

## 프로젝트 경로 (하네스가 사용하는 변수)

```bash
# 프로젝트 루트 (xcodeproj가 있는 폴더)
PROJECT_ROOT="/Users/haesuyoun/Desktop/NahunPersonalFolder/Better-Alarm"

# 소스 코드 폴더 (App/, Views/, Models/ 등이 있는 폴더)
TARGET_DIR="BetterAlarm"

# 하네스 루트
HARNESS_ROOT="/Users/haesuyoun/Desktop/NahunPersonalFolder/Better-Alarm/harness"
```

---

## 빌드 / 테스트 명령어

```bash
# 빌드 (시뮬레이터 ID 고정 — 신규 시뮬레이터 생성 금지)
BUILD_COMMAND="xcodebuild -project $PROJECT_ROOT/BetterAlarm.xcodeproj \
  -scheme BetterAlarm \
  -destination 'id=1CE14D49-DEB7-4BED-AFEE-AF349E430DB3' \
  build 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'"

# 테스트
TEST_COMMAND="xcodebuild test -project $PROJECT_ROOT/BetterAlarm.xcodeproj \
  -scheme BetterAlarm \
  -destination 'id=1CE14D49-DEB7-4BED-AFEE-AF349E430DB3' \
  2>&1 | tail -5"
```

---

## Xcode 통합 방식

```
# output/ -> 프로젝트 폴더 동기화 방식
# "auto" = PBXFileSystemSynchronizedRootGroup (파일 복사만으로 Xcode 자동 인식)
SYNC_METHOD="auto"
```

`BetterAlarm.xcodeproj`는 `PBXFileSystemSynchronizedRootGroup`을 사용한다.
**`BetterAlarm/` 폴더에 파일을 복사하면 Xcode가 자동으로 빌드 대상에 포함**한다.
xcodeproj 직접 수정이나 Ruby 스크립트는 필요 없다.

---

## 디자인 시스템 (필수)

**`PersonalColorDesignSystem` SPM 패키지가 이미 프로젝트에 추가되어 있다.**
색상, 타이포그래피, 컴포넌트를 절대 자체 구현하지 마라.

```swift
import PersonalColorDesignSystem
```

### 색상 토큰 (하드코딩 금지)
```swift
// SwiftUI
Color.pTextPrimary / Color.pTextSecondary / Color.pTextTertiary
Color.pAccentPrimary / Color.pBackgroundTop / Color.pBackgroundBottom
// UIKit
UIColor.pTextPrimary / UIColor.pAccentPrimary
// 테마 연동
theme.colors.accentPrimary / theme.colors.backgroundTop
```

### 컴포넌트 (자체 구현 금지)
```swift
GlassCard { content }                    // SwiftUI 카드 컨테이너
HapticManager.impact()                   // 기본 medium
HapticManager.impact(.light / .heavy)
HapticManager.notification(.success / .error / .warning)
HapticManager.selection()
GradientBackground()
.pTheme(themeManager.currentTheme)       // 테마 적용
```

### 타이포그래피 (UIKit)
```swift
UIFont.pDisplay(40)    // 큰 숫자
UIFont.pTitle(17)      // 섹션 타이틀
UIFont.pBody(14)       // 본문
```

### 토스트
- 자체 구현 금지 — `PersonalColorDesignSystem` 내 토스트/스낵바 컴포넌트 사용

### 금지
```swift
// 하드코딩 색상 금지
Color(red: 0.2, green: 0.3, blue: 0.8)
UIColor(red: 0.7, green: 0.5, blue: 1.0, alpha: 1.0)
```

---

## 아키텍처 요구사항

### 고정 요구사항

- **MVVM**: View → ViewModel → Service 단방향 의존
- **모든 ViewModel**: `@MainActor @Observable final class` (SwiftUI import 금지, UIKit import 허용)
- **모든 Service**: `actor` + 프로토콜 기반 (DI + 테스트 목킹)
- **모든 Model**: `struct Sendable` + Codable

### 사용자 추가 요구사항

#### 1. 알람 모드 분기 (AlarmMode)

`Alarm` 모델에 `alarmMode: AlarmMode` 필드를 추가하라.

```swift
enum AlarmMode: String, Codable, Sendable {
    case alarmKit   // iOS 26+ 전용: AlarmKit 사용, 앱 꺼진 상태에서도 울림
    case local      // iOS 17+: UNUserNotificationCenter 기반, 백그라운드/포그라운드에서 울림
}
```

- **alarmKit 모드**: 기존 `AlarmKitService`를 그대로 사용한다. `@available(iOS 26.0, *)` 가드 필수.
- **local 모드**: `LocalNotificationService` (새로 구현)를 사용한다. `UNUserNotificationCenter`로 로컬 알림을 스케줄하고, 앱이 포그라운드 상태일 때는 `AVAudioPlayer`로 직접 소리를 재생한다.
- **AlarmStore.scheduleNextAlarm()**: `alarm.alarmMode`에 따라 `AlarmKitService` 또는 `LocalNotificationService`로 분기한다.

#### 2. 알람 설정 화면 — "앱이 꺼진 상태에서도 알람 받기" 옵션

- 알람 편집/생성 화면에 토글을 추가한다.
- 토글 레이블: **"앱이 꺼진 상태에서도 알람 받기"**
- 토글 ON → `alarmMode = .alarmKit`
- 토글 OFF → `alarmMode = .local`
- **iOS 버전 체크**: 토글을 ON으로 바꾸려 할 때 `if #available(iOS 26, *)` 체크.
  - iOS 26 미만이면 토글을 ON으로 바꾸지 말고, 디자인 시스템의 토스트로 안내:
    > "이 기능은 iOS 26 이상에서만 사용할 수 있습니다."
  - 토스트는 `PersonalColorDesignSystem`의 토스트/스낵바 컴포넌트 사용. 자체 구현 금지.

#### 3. "조용한 알람" 옵션

- `Alarm` 모델에 `isSilentAlarm: Bool` 필드를 추가한다 (기본값 `false`).
- 알람 편집/생성 화면에 **"조용한 알람"** 토글을 추가한다.
- `isSilentAlarm = true`이면:
  - 핸드폰 스피커가 아닌 **이어폰(AirPlay/블루투스 포함)으로만 소리 출력**.
  - `AVAudioSession` 카테고리를 `.playback`으로 설정하되, `AVAudioSessionPortDescription`으로 이어폰 연결 여부 확인.
  - 이어폰이 연결되어 있지 않으면 알람이 울리지 않거나 사용자에게 안내한다.
- `isSilentAlarm = false`이면 기본 알람 동작 (스피커 출력).
- **AlarmKit 모드(`alarmKit`)**에서는 조용한 알람을 지원하지 않는다. UI에서 `alarmMode == .alarmKit`일 때 조용한 알람 옵션을 비활성화(grayed out)하라.

#### 4. 알람 울릴 때 볼륨 자동 조절

- 알람이 시작될 때 (`local` 모드, 앱 포그라운드/백그라운드 모두):
  - `MPVolumeView` 또는 `AVAudioSession`을 통해 현재 기기 볼륨을 확인한다.
  - 볼륨이 **0.8 (80%) 미만**이면 자동으로 0.8로 올린다.
  - 볼륨이 이미 0.8 이상이면 현재 볼륨을 유지한다.
  - 알람 종료 후 원래 볼륨으로 복원한다.
- `VolumeService` (actor)로 분리 구현한다.

#### 5. 앱 종료 시 푸시 알림 (1회)

- `local` 모드 알람이 활성화된 상태에서 앱이 백그라운드로 전환되거나 종료될 때:
  - `UNUserNotificationCenter`로 **즉시 로컬 알림 1건** 등록.
  - 알림 내용: `"[알람 제목] 알람이 설정되어 있습니다. 알람 시각: [시간]"`
  - 앱이 다시 포그라운드로 올라오면 해당 알림 취소 (`removeDeliveredNotifications`, `removePendingNotificationRequests`).
  - 이 로직은 `AppDelegate`의 `applicationDidEnterBackground` / `applicationWillEnterForeground`에서 처리한다.

#### 6. Live Activity (잠금화면 실시간 위젯) — 기존 기능 유지 필수

**이미 구현된 기능이다. 반드시 유지하고 새 아키텍처와 통합하라.**

- `ActivityKit`을 사용한 Live Activity로 잠금화면/Dynamic Island에 다음 알람 정보를 실시간 표시한다.
- `AlarmActivityAttributes` 구조체 (이미 존재, 변경 금지):
  ```swift
  struct AlarmActivityAttributes: ActivityAttributes {
      struct ContentState: Codable, Hashable {
          var nextAlarmTime: String   // "오전 7:00"
          var nextAlarmDate: String   // "M월 d일" 형식 고정
          var alarmTitle: String
          var isSkipped: Bool
          var isEmpty: Bool
      }
      var alarmId: String
  }
  ```
- `LiveActivityManager` (actor):
  - `startActivity(for alarm: Alarm) async`
  - `updateActivity(nextAlarm: Alarm?) async`
  - `endActivity() async`
  - `isLiveActivityEnabled: Bool` (UserDefaults 저장, 기본값 true)
  - `areActivitiesAvailable: Bool`
- `AlarmStore`가 알람 상태 변경 시 `LiveActivityManager` 호출:
  - 알람 생성/수정/삭제/토글 시 → `LiveActivityManager.updateActivity(nextAlarm:)`
  - 알람 완료 시 → `LiveActivityManager.endActivity()`
- **BetterAlarmWidget 타겟** (기존 그대로 유지):
  - `BetterAlarmWidget/` 폴더의 파일은 수정하지 않는다.
  - `AlarmActivityAttributes`는 위젯 타겟에도 동일하게 정의되어 있다 (별도 타겟이므로 중복 정의 필수).

#### 7. Settings View (기존 기능 유지 필수)

- `SettingsView.swift` (SwiftUI):
  - Live Activity 활성화/비활성화 토글 (`LiveActivityManager.isLiveActivityEnabled`)
  - AlarmKit 권한 상태 표시 (`@available(iOS 26, *)`)
  - 앱 버전 표시
  - 피드백/문의 링크

#### 8. Weekly Alarm View (기존 기능 유지 필수)

- `WeeklyAlarmView.swift` (SwiftUI):
  - 주간 반복 알람만 필터링하여 표시 (`AlarmSchedule.weekly`)
  - 알람 생성/편집/삭제 지원
  - 요일 그룹별 표시

#### 9. 탭바 네비게이션 (기존 기능 유지 필수)

- `BetterAlarmApp.swift`에서 `TabView`로 3탭 구성:
  - 탭 1: 알람 목록 (`AlarmListView`)
  - 탭 2: 주간 알람 (`WeeklyAlarmView`)
  - 탭 3: 설정 (`SettingsView`)
- `@UIApplicationDelegateAdaptor(AppDelegate.self)` 사용

#### 10. 알람 울림 화면 (AlarmRingingView)

- **알람이 울릴 시각이 되면** 전용 **알람 울림 화면**이 전체 화면으로 표시된다.
- 이 화면에서 **알람 사운드가 반복 재생**된다 (푸시 알림이 아닌 `AVAudioPlayer`로 실제 소리 무한 반복).
- **볼륨 자동 조절**: `VolumeService.ensureMinimumVolume()` (80%)을 알람 울림 시작 시 호출.
- **화면 구성**:
  - 현재 시각 (큰 글자)
  - 알람 제목
  - **"정지" 버튼**: 알람 정지 + 원래 볼륨 복원 + 화면 닫기 + 알람 완료 처리
  - **"스누즈" 버튼**: 알람 정지 + 5분 후 재스케줄 + 화면 닫기
- **소리 재생**:
  - `AudioService.playAlarmSound(soundName:isSilent:)` 호출, `numberOfLoops = -1`로 무한 반복.
  - `isSilentAlarm = true`이면 이어폰으로만 재생.
- **진입 경로**:
  - `local` 모드: 앱 포그라운드에서 알람 시각이 되면 자동으로 `fullScreenCover`로 표시.
  - `alarmKit` 모드: AlarmKit이 시스템 수준에서 처리하므로 이 화면 미사용.
- **PersonalColorDesignSystem** 사용 필수: `PGradientBackground`, `Color.p*`, `HapticManager`.

#### 11. 로거 유틸리티 (기존 기능 유지 필수)

- `Utils/Logger.swift` (기존 파일 유지):
  - `AppLogger.info(_, category:)` / `.debug` / `.warning` / `.error` 사용.
  - 카테고리: `.lifecycle`, `.ui`, `.action`, `.alarm`, `.store`, `.alarmKit`, `.liveActivity`, `.settings`, `.permission`, `.navigation`.
  - 새로 만들지 말고 기존 파일을 그대로 사용한다.

---

## API 문서 수집 (선택)

`docs/` 폴더에 이미 다음 파일이 존재하므로 **이 단계는 스킵**:

- `docs/alarmkit_notes.md`
- `docs/appintent_notes.md`
- `docs/widgetkit_notes.md`

새 API가 필요하면 NotebookLM MCP로 추가 수집한다.

---

## 기존 코드 참고 (Generator용)

기존 BetterAlarm 프로젝트의 로직을 참고할 수 있다.
단, 참고만 하고 UIKit 코드를 그대로 복사하지 마라.

**참고할 핵심 로직:**
- `BetterAlarm/Models/Alarm.swift` — 알람 모델, `nextTriggerDate()`, 스킵 로직
- `BetterAlarm/Services/AlarmKitService.swift` — AlarmKit Fixed/Relative 스케줄 구분
- `BetterAlarm/Services/AlarmStore.swift` — 알람 CRUD, UserDefaults 저장 (`"savedAlarms_v2"`)
- `BetterAlarm/Services/LiveActivityManager.swift` — ActivityKit 연동 (actor)
- `BetterAlarm/Utils/Logger.swift` — 로거 (그대로 사용)
- `BetterAlarmWidget/BetterAlarmWidgetLiveActivity.swift` — 위젯 Live Activity UI

---

## 보존 파일 (덮어쓰기 금지)

Xcode 통합 시 **절대 덮어쓰지 않아야 할 파일**:

- `BetterAlarm/Utils/Logger.swift` — 기존 로거 유지
- `BetterAlarmWidget/` — 위젯 타겟 전체 (별도 타겟, 직접 수정 시 위젯 빌드 확인 필요)
- `BetterAlarmTests/` — 테스트 코드 (하네스가 신규 생성하지 않음)
- `BetterAlarm/Localizable.xcstrings` — 번역 리소스

`UserDefaults` 키 `"savedAlarms_v2"`는 기존 데이터와 호환되어야 한다. 테스트 후 반드시 `removeObject`로 정리.

---

## 이 파일 수정 방법

기능을 추가하거나 구조를 바꾸고 싶으면:
1. `## 사용자 추가 요구사항` 섹션에 항목을 추가한다
2. `/harness [한 줄 프롬프트]` 로 파이프라인 실행

**한 줄 프롬프트**: 만들고 싶은 기능을 간단히 설명
**PROJECT_CONTEXT.md**: 항상 적용되어야 하는 구조적 요구사항, 기술 스택, 제약
