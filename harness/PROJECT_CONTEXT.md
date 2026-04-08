# 프로젝트 컨텍스트

Planner, Generator, Evaluator가 **반드시 먼저 읽어야 하는** 프로젝트 고정 요구사항.
이 파일에 적힌 내용은 사용자 프롬프트보다 우선한다.

---

## 대상 프로젝트

- **앱 이름**: BetterAlarm
- **번들 ID**: com.nahun.BetterAlarm
- **최소 타겟 iOS**: 17.0
- **Swift 버전**: Swift 6 (엄격 동시성 필수)
- **UI 프레임워크**: SwiftUI (신규 화면), UIKit (기존 화면 유지)

---

## 디자인 시스템 (필수)

**`PersonalColorDesignSystem` SPM 패키지가 이미 프로젝트에 추가되어 있다.**
색상, 타이포그래피, 컴포넌트를 절대 자체 구현하지 마라.

```swift
import PersonalColorDesignSystem
```

사용 가능한 것들:
- 색상: `UIColor.pAccentPrimary`, `Color.pTextPrimary` 등 `p` 접두사 토큰
- 폰트: `UIFont.pDisplay()`, `UIFont.pTitle()`, `UIFont.pBodyMedium()` 등
- 컴포넌트: `GlassCardView`, `HapticManager`, `GradientBackground`
- 그래디언트: `UIColor.pBackgroundGradient(frame:)`, `view.applyBackgroundGradient()`
- 토스트: `ToastView` 또는 디자인 시스템 내 토스트/스낵바 컴포넌트 사용

---

## 아키텍처 요구사항

아래 요구사항은 사용자가 직접 수정하는 영역이다.
기능 추가, 구조 변경, 특정 패턴 강제 등을 여기에 적으면 하네스가 반영한다.

### 현재 고정 요구사항

- MVVM: View → ViewModel → Service 단방향 의존
- 모든 ViewModel: `@MainActor` + `@Observable`
- 모든 Service: `actor`
- 모든 Model: `struct` + `Sendable`

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

- 알람 편집/생성 화면(`AlarmDetailViewController` 또는 신규 SwiftUI 뷰)에 토글을 추가한다.
- 토글 레이블: **"앱이 꺼진 상태에서도 알람 받기"**
- 토글 ON → `alarmMode = .alarmKit`
- 토글 OFF → `alarmMode = .local`
- **iOS 버전 체크**: 토글을 ON으로 바꾸려 할 때 `if #available(iOS 26, *)` 체크를 한다.
  - iOS 26 미만이면 토글을 ON으로 바꾸지 말고, 디자인 시스템의 토스트 컴포넌트로 아래 메시지를 표시한다:
    > "이 기능은 iOS 26 이상에서만 사용할 수 있습니다."
  - 토스트는 `PersonalColorDesignSystem`의 토스트/스낵바 컴포넌트를 사용한다. 자체 구현 금지.

#### 3. "조용한 알람" 옵션

- `Alarm` 모델에 `isSilentAlarm: Bool` 필드를 추가한다 (기본값 `false`).
- 알람 편집/생성 화면에 **"조용한 알람"** 탭(또는 토글)을 추가한다.
- `isSilentAlarm = true`이면:
  - 핸드폰 스피커가 아닌 **이어폰(AirPlay/블루투스 포함)으로만 소리를 출력**한다.
  - `AVAudioSession` 카테고리를 `.playback`으로 설정하되, `AVAudioSessionPortDescription`을 확인해 이어폰 연결 여부를 체크한다.
  - 이어폰이 연결되어 있지 않으면 알람이 울리지 않거나 사용자에게 안내한다.
- `isSilentAlarm = false`이면 기본 알람 동작 (스피커 출력).
- **AlarmKit 모드(alarmKit)**에서는 조용한 알람을 지원하지 않는다. UI에서 `alarmMode == .alarmKit`일 때 조용한 알람 옵션을 비활성화(grayed out)하라.

#### 4. 알람 울릴 때 볼륨 자동 조절

- 알람이 시작될 때 (`local` 모드, 앱 포그라운드/백그라운드 모두):
  - `MPVolumeView` 또는 `AVAudioSession`을 통해 현재 기기 볼륨을 확인한다.
  - 볼륨이 **0.8 (80%) 미만**이면 자동으로 0.8로 올린다.
  - 볼륨이 이미 0.8 이상이면 현재 볼륨을 유지한다.
  - 알람 종료 후 원래 볼륨으로 복원한다.
- `VolumeService` (actor)로 분리 구현한다.

#### 5. 앱 종료 시 푸시 알림 (1회)

- `local` 모드 알람이 활성화된 상태에서 앱이 백그라운드로 전환되거나 종료될 때:
  - `UNUserNotificationCenter`로 **즉시 로컬 알림 1건**을 등록한다.
  - 알림 내용: `"[알람 제목] 알람이 설정되어 있습니다. 알람 시각: [시간]"`
  - 앱이 다시 포그라운드로 올라오면 해당 알림을 취소한다 (`removeDeliveredNotifications`, `removePendingNotificationRequests`).
  - 이 로직은 `AppDelegate`의 `applicationDidEnterBackground` / `applicationWillEnterForeground`에서 처리한다.

---

## 기존 코드 참고 (Generator용)

기존 BetterAlarm 프로젝트의 로직을 참고할 수 있다.
단, 참고만 하고 UIKit 코드를 그대로 복사하지 마라.

**참고할 핵심 로직:**
- `Alarm.swift` — 알람 모델, `nextTriggerDate()`, 스킵 로직
- `AlarmKitService.swift` — AlarmKit Fixed/Relative 스케줄 구분 (`@available(iOS 26.0, *)` 추가 필요)
- `AlarmStore.swift` — 알람 CRUD, UserDefaults 저장
- `LiveActivityManager.swift` — ActivityKit 연동

---

## 이 파일 수정 방법

기능을 추가하거나 구조를 바꾸고 싶으면:
1. `## 사용자 추가 요구사항` 섹션에 항목을 추가한다
2. 하네스를 실행한다 (`claude` 명령어)
3. 한 줄 프롬프트를 입력한다

**한 줄 프롬프트**: 만들고 싶은 앱/기능을 간단히 설명
**PROJECT_CONTEXT.md**: 항상 적용되어야 하는 구조적 요구사항, 기술 스택, 제약
