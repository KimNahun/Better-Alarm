RESULT: pass
SCORE: 9.0
BLOCKERS: 0

---

# QA Report -- R3 Re-evaluation (5 Minor Fixes)

## Previous R2 Issues -- Fix Verification

### [FIXED] M3: AlarmRingingViewModel `import PersonalColorDesignSystem` 제거
- `ViewModels/AlarmRinging/AlarmRingingViewModel.swift` line 1: `import Foundation` only. PersonalColorDesignSystem import 완전 제거.
- Lines 27-28: `private let onStopHaptic: @MainActor () -> Void` / `private let onSnoozeHaptic: @MainActor () -> Void` -- 클로저 주입 패턴으로 변경.
- Line 90: `onStopHaptic()`, line 101: `onSnoozeHaptic()` -- HapticManager 직접 호출 없음.
- `Views/AlarmRinging/AlarmRingingView.swift` init (lines 19-27): View에서 `HapticManager.notification(.success)`, `HapticManager.impact()` 클로저 주입 -- 올바른 MVVM 패턴.

### [FIXED] M6/M7: `.padding(.top, 60)` 하드코딩 제거
- `AlarmListView.swift` line 132: `.padding(.top, 16)` -- safe area 기반으로 변경.
- `WeeklyAlarmView.swift` line 34: `.padding(.top, 16)` -- 동일하게 변경.
- `SettingsView.swift` line 39: `.padding(.top, 16)` -- 동일하게 변경.
- 16pt는 safe area inset 위에 추가되는 합리적 패딩 값.

### [FIXED] M10: AlarmListViewModel / WeeklyAlarmViewModel 코드 중복 제거
- `AlarmListViewModel.swift` lines 7-94: `AlarmToggleHandling` 프로토콜 정의 + extension으로 공통 로직 추출.
  - `requestToggle`, `toggleAlarm`, `skipOnceAndDisable`, `confirmDisable`, `cancelDisable`, `deleteAlarm`, `skipOnceAlarm`, `clearSkip`, `dismissToast`, `showToastMessage` -- 10개 메서드 공통화.
- `AlarmListViewModel` (line 103): `AlarmToggleHandling` 준수, `alarmToggleStore` computed property 제공.
- `WeeklyAlarmViewModel` (line 11): 동일하게 `AlarmToggleHandling` 준수.
- 프로토콜이 `@MainActor`로 선언되어 동시성 일관성 유지.

### [FIXED] M8: AlarmKitService 불필요한 requestPermission() 중복
- `AlarmKitService.swift` lines 63-68: `checkPermission()` 우선 호출 후, 미허용 시에만 `requestPermission()` 호출.
  ```
  var authorized = await checkPermission()
  if !authorized {
      authorized = await requestPermission()
  }
  ```
- 불필요한 시스템 권한 다이얼로그 반복 방지.

### [FIXED] M12: BetterAlarmApp configureAppearance() 중복 정리
- `BetterAlarmApp.swift` line 67: `private static func configureAppearance()` -- 단일 정적 메서드만 존재.
- Line 60: `Self.configureAppearance()` -- 정적 호출. 인스턴스 메서드 중복 완전 제거.

---

## 1단계: 파일 구조 분석

27개 Swift 파일. 이전 R2와 동일 구조. SPEC.md와 일치.

| 레이어 | 파일 수 | 파일 목록 |
|--------|---------|-----------|
| App | 1 | BetterAlarmApp.swift |
| Models | 4 | Alarm, AlarmError, AlarmMode, AlarmSchedule |
| Services | 7 | AlarmKitService, AlarmStore, AppThemeManager, AudioService, LiveActivityManager, LocalNotificationService, VolumeService |
| ViewModels | 5 | AlarmDetailVM, AlarmListVM(+AlarmToggleHandling), AlarmRingingVM, SettingsVM, WeeklyAlarmVM |
| Views | 6 | AlarmDetailView, AlarmListView, AlarmRingingView, AlarmRowView, SettingsView, WeeklyAlarmView |
| Intents | 2 | StopAlarmIntent, SnoozeAlarmIntent |
| Delegates | 1 | AppDelegate |
| Shared | 1 | AlarmMetadata |

---

## 2단계: SPEC 기능 검증

### [PASS] 기능 1: AudioService -- 무음 오디오 루프
- `AudioService.swift` lines 118-178: `startSilentLoop()` / `stopSilentLoop()` -- AVAudioEngine + AVAudioPlayerNode, 무음 PCM 버퍼, `.loops` 무한 반복, `.mixWithOthers`, `outputVolume = 0.01`.
- `AudioServiceProtocol`에 메서드 포함 확인.

### [PASS] 기능 2: AppDelegate -- 생명주기 연동
- `AppDelegate.swift`: `applicationDidEnterBackground` (line 56) -- `hasEnabledLocalAlarms` 체크 후 `audioService?.startSilentLoop()`.
- `applicationWillEnterForeground` (line 90) -- `audioService?.stopSilentLoop()`.
- `applicationWillTerminate` (line 100) -- DispatchGroup Task 내 `audioService?.stopSilentLoop()` 첫 줄.
- `configure()` 시그니처에 `audioService` 파라미터 포함.

### [PASS] 기능 3: BetterAlarmApp -- DI 연결
- `BetterAlarmApp.swift` line 211: `appDelegate.configure(alarmStore: alarmStore, localNotificationService: localNotificationService, audioService: audioService)`.

---

## 3단계: evaluation_criteria 채점

### 1. Swift 6 동시성: 9.5/10

**양호한 점:**
- 모든 ViewModel: `@MainActor @Observable final class` (5개 전부)
- Core Services: AlarmStore, AudioService, LocalNotificationService, LiveActivityManager, AlarmKitService, VolumeService -- 모두 `actor`
- Models: Alarm, AlarmMode, AlarmSchedule, AlarmError, Weekday -- 모두 struct/enum + Sendable
- `@Published` / `ObservableObject` / `DispatchQueue.main.async` 미사용
- `nonisolated(unsafe)` 미사용
- VolumeService: `@MainActor VolumeUIHelper`로 UIKit 조작 올바르게 격리
- AlarmToggleHandling 프로토콜: `@MainActor` 선언으로 동시성 보장

**경미한 이슈:**
- (M1 유지) `AppThemeManager`: `@MainActor @Observable final class` -- Services/ 폴더에 위치하지만 actor가 아님. UIKit 외관 관리(탭바, 아이콘 변경)를 위해 MainActor 필수인 특수 케이스. 기능적 문제 없으나 레이어 분류상 어색함 (-0.5).

### 2. MVVM 아키텍처 분리: 9/10

**양호한 점:**
- View: 순수 UI 선언, Service 직접 호출 없음
- **모든 ViewModel: `import SwiftUI` 없음, `import PersonalColorDesignSystem` 없음** (이전 M3 수정 확인)
  - AlarmRingingViewModel: HapticManager 클로저 주입 패턴 -- MVVM 순수성 우수
- Service: ViewModel/View 참조 없음
- 의존성 단방향 (View -> ViewModel -> Service)
- Protocol 기반 Service 주입
- AlarmToggleHandling 프로토콜로 코드 중복 제거 -- 재사용성 향상

**경미한 이슈:**
- (M4 유지) BetterAlarmApp.swift `waitAndFireNextAlarm()` (lines 240-307): 알람 필터링, 스케줄 계산, 오디오 재생 등 비즈니스 로직이 App 진입점에 존재. AlarmTimerService actor로 분리가 이상적 (-0.5).
- (M5 유지) BetterAlarmApp.swift `onChange(of: scenePhase)` (lines 141-188): AppDelegate와 일부 중복되는 생명주기 로직 (-0.5).

### 3. HIG 준수 + 디자인 시스템: 9.5/10

**양호한 점:**
- PersonalColorDesignSystem 토큰 전반 사용: Color.pTextPrimary, .pTextSecondary, .pTextTertiary, .pGlassFill, .pWarning, .pSuccess, .pAccentSecondary 등
- GlassCard 컴포넌트 사용 (AlarmRowView, AlarmListView nextAlarmBanner)
- PGradientBackground 사용 (모든 View)
- PToggle 컴포넌트 사용 (AlarmDetailView, AlarmRowView, SettingsView)
- HapticManager 사용: View 레이어에서만 직접 호출 (AlarmListView, AlarmDetailView, WeeklyAlarmView) + AlarmRingingView에서 클로저 주입
- 하드코딩 Color(red:) / UIColor(red:) 없음
- 터치 영역 44pt 준수 (minWidth/minHeight: 44 명시)
- 접근성 레이블: accessibilityLabel/accessibilityHint 전반 추가
- Dynamic Type: semantic font size (.largeTitle, .title, .body, .caption)
- 로딩/에러 상태 UI: pLoadingOverlay, alert
- 토스트: PersonalColorDesignSystem .toast 컴포넌트
- pActionSheet: 주간 알람 disable 시 커스텀 액션 시트
- **이전 M6/M7 수정 확인**: `.padding(.top, 16)` -- safe area 기반 합리적 패딩

**경미한 이슈:**
- (N1) AlarmRingingView `timeDisplay` line 67: `.font(.system(.largeTitle, design: .rounded, weight: .ultraLight))` -- semantic size이지만 `.system()` 호출로 design 파라미터 사용. PersonalColorDesignSystem 폰트 토큰(`UIFont.pDisplay()` 등) 대신 시스템 폰트 직접 사용. 특수한 디자인 요구(rounded, ultraLight)를 위한 것이므로 경미 처리 (-0.5).

### 4. API 활용: 9/10

**양호한 점:**
- AlarmKit: AlarmManager.shared, AlarmAttributes, AlarmPresentation, AlarmButton, AlarmSchedule(.fixed/.relative) 올바른 사용
- `@available(iOS 26.0, *)` 가드 적용
- AppIntents: StopAlarmIntent, SnoozeAlarmIntent -- LiveActivityIntent 올바른 준수
- SnoozeAlarmIntent: AlarmManager.shared 직접 사용 (App Extension 별도 프로세스 고려)
- ActivityKit: Activity.request, activity.update, activity.end
- UNUserNotificationCenter: 카테고리 등록, 권한 요청, 스케줄링, cancelAlarm/cancelBackgroundReminder
- AVAudioEngine/AVAudioPlayerNode: 무음 루프 (scheduleBuffer non-async 올바름)
- AVAudioPlayer: numberOfLoops = -1
- MPVolumeView: actor + @MainActor helper 분리
- 모든 API 호출이 Service 레이어에만 존재
- **이전 M8 수정 확인**: checkPermission() 우선 호출 패턴 올바름

**경미한 이슈:**
- (M9 유지) LocalNotificationService `scheduleRepeatingAlerts()` count 기본값 30개, 30초 간격. AlarmStore에서 가장 임박한 1개에만 적용하므로 실질 문제 경미 (-0.5).
- (N2) AlarmKitService `stopAllAlarms()` line 163: `let existing = try manager.alarms` -- `try` 사용하지만 catch 블록이 빈 `catch {}`. 에러 로깅이 없어 디버깅 어려움 (-0.5).

### 5. 기능성 및 코드 가독성: 9/10

**양호한 점:**
- SPEC의 3개 기능 모두 구현 (무음 루프, AppDelegate 연동, DI 연결)
- 접근 제어자 명시 (`private`, `private(set)`)
- AlarmError: Error, LocalizedError, Sendable, 5개 케이스 모두 errorDescription
- 파일 구조 컨벤션 일치
- **AlarmToggleHandling 프로토콜로 코드 중복 대폭 감소** -- 이전 M10 완전 해결
- AlarmSwipeActionsModifier: ViewModifier로 swipe actions 재사용
- KoreanDateFormatters: 날짜 포맷터 캐시
- MARK 주석으로 섹션 분리
- `#if DEBUG` 가드 적용 (testSilentMode)
- **configureAppearance() 중복 제거** -- 이전 M12 해결

**경미한 이슈:**
- (M11 유지) AppDelegate `applicationWillTerminate` line 108-129: DispatchGroup + Task 패턴. 2초 타임아웃 적절하나 async 작업을 동기 대기하는 패턴은 본질적으로 불안정 (-0.5).
- (N3) AlarmToggleHandling 프로토콜이 `AlarmListViewModel.swift` 파일 내에 정의됨 (lines 7-94). 별도 파일(`Protocols/AlarmToggleHandling.swift`)로 분리가 파일 구조상 더 명확 (-0.5).

---

## 4단계: 최종 판정

**전체 판정**: 합격
**가중 점수**: 9.0 / 10.0

계산: (9.5 x 0.30) + (9 x 0.25) + (9.5 x 0.20) + (9 x 0.15) + (9 x 0.10)
= 2.85 + 2.25 + 1.90 + 1.35 + 0.90 = **9.25 -> 9.0** (경미한 이슈 누적 감안 소폭 보정)

**항목별 점수**:
- Swift 6 동시성: 9.5/10 -- AppThemeManager의 레이어 분류만 경미한 이슈. 모든 actor/MainActor 패턴 올바름.
- MVVM 분리: 9/10 -- AlarmRingingVM의 PersonalColorDesignSystem import 제거 완료. BetterAlarmApp의 비즈니스 로직 과다만 잔존.
- HIG 준수: 9.5/10 -- padding 하드코딩 수정 완료. 디자인 시스템 전반 사용 우수. AlarmRingingView 시간 폰트만 시스템 직접 사용.
- API 활용: 9/10 -- checkPermission() 우선 패턴 수정 완료. stopAllAlarms 빈 catch, repeatingAlerts 30개 한도만 경미.
- 기능성/가독성: 9/10 -- AlarmToggleHandling으로 중복 제거 우수. configureAppearance 정리 완료. 프로토콜 파일 위치만 경미.

---

## 잔존 경미한 이슈 (비차단)

| # | 위치 | 설명 | 심각도 |
|---|------|------|--------|
| M1 | Services/AppThemeManager.swift | @MainActor class이지만 Services/ 폴더에 위치 -- 레이어 분류 어색 | 매우 경미 |
| M4 | App/BetterAlarmApp.swift `waitAndFireNextAlarm()` | 비즈니스 로직이 App 진입점에 존재 | 경미 |
| M5 | App/BetterAlarmApp.swift `onChange(of: scenePhase)` | AppDelegate와 일부 중복 생명주기 로직 | 경미 |
| M9 | Services/LocalNotificationService.swift `scheduleRepeatingAlerts()` | 30개 반복 알림 -- 64개 제한 근접 가능성 | 매우 경미 |
| M11 | Delegates/AppDelegate.swift `applicationWillTerminate` | DispatchGroup+Task 동기 대기 패턴 | 경미 |
| N1 | Views/AlarmRinging/AlarmRingingView.swift `timeDisplay` | 시스템 폰트 직접 사용 (디자인 토큰 대신) | 매우 경미 |
| N2 | Services/AlarmKitService.swift `stopAllAlarms()` | 빈 catch {} -- 에러 로깅 누락 | 매우 경미 |
| N3 | ViewModels/AlarmList/AlarmListViewModel.swift | AlarmToggleHandling 프로토콜이 별도 파일 아닌 동일 파일 내 정의 | 매우 경미 |

**방향 판단**: 현재 방향 유지. 이전 R2에서 제기된 5개 경미한 이슈 모두 올바르게 수정됨. 새로 발견된 이슈(N1-N3)는 모두 매우 경미하며 아키텍처나 기능에 영향 없음. 9.0/10 달성.
