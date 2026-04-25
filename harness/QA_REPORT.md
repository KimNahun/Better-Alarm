# QA 리포트 — i18n 라운드 (Evaluator R1)

```
RESULT: pass
SCORE_OVERALL: 8.5
SCORE_CONCURRENCY: 9
SCORE_MVVM: 9
SCORE_HIG: 8
SCORE_API: 8
SCORE_FUNCTIONALITY: 8
BLOCKERS: 0
```

가중치: 동시성 0.30 / MVVM 0.25 / HIG 0.20 / API 0.15 / 기능 0.10
가중 평균 = 9·0.30 + 9·0.25 + 8·0.20 + 8·0.15 + 8·0.10 = 8.55

빌드 게이트: BUILD SUCCEEDED (iPhone 17 Pro Max, iOS 26.1) ✅
한국어 하드코딩 잔류: 0건 (사용자 노출 문자열 기준, 주석/로그 제외) ✅
String Catalog 165/165 키 (ko·en 양쪽 translated) ✅

---

## 1. 검수 절차 결과

### 1.1 SPEC 작업 범위 구현 확인

| SPEC 항목 | 상태 | 근거 |
|-----------|------|------|
| §1 String Catalog 채택 | PASS | `harness/output/Resources/Localizable.xcstrings` (sourceLanguage=en, ko 추가) |
| §2 CFBundleDevelopmentRegion=en, CFBundleLocalizations=[en,ko] | PASS | `BetterAlarm/Info.plist`에 적용 완료 (직접 확인) |
| §4 24개 .swift 파일 i18n 적용 | PASS | output/ 직접 확인, 20개 파일 수정 (10개는 사용자 표시 문자열 없어 변경 불필요) |
| §5.1~5.18 키 카탈로그 165개 | PASS | python3 분석으로 165/165 확인, 누락·중복 0 |
| §6.2 시간 표시 — Date.formatted 로케일 자동 | PASS | `Models/Alarm.swift:14` `LocalizedDateFormatters.timeDisplayString` |
| §6.3 상대 날짜 — 오늘/내일/dateTime | PASS | `Models/Alarm.swift:18-27` |
| §6.4 Weekday.shortName 키화 | PASS | `Models/AlarmSchedule.swift:15-25` |
| §6.5 nextAlarmDisplayString 리팩토링 | PASS | `Services/AlarmStore.swift:274-288` `next_alarm_format_*` 사용 |
| §7.2B alarmMode 토글 PToggle fallback | PASS | `Views/AlarmDetail/AlarmDetailView.swift:317-334` HStack+lineLimit(2)+minimumScaleFactor(0.9)+fixedSize 적용 |
| §7.2D 잠금화면 위젯 권한 VStack 분리 | PASS | `Views/Settings/SettingsView.swift:142-163` |
| §7.2F 스누즈 버튼 minWidth 200 | PASS | `Views/AlarmRinging/AlarmRingingView.swift:113` |
| §10 결정 사항 — Weekday/AlarmMode/AlarmSchedule rawValue 보존 | PASS | enum 직접 확인 |

### 1.2 Localizable.xcstrings 카탈로그 검증

```
Total keys:               165
Duplicates:               0
ko 번역 상태:             165개 모두 "translated"
en 번역 상태:             165개 모두 "translated"
포맷 지정자 불일치:       0건 (정밀 정규식 검증)
sourceLanguage:           "en" ✅
extractionState:          모든 키 "manual" (수동 입력)
```

### 1.3 한국어 하드코딩 잔류 검사

```bash
grep -rnE '"[가-힣]' harness/output/ --include="*.swift"
```

12건 발견 — **전부 코드 주석(`//` / `///`) 또는 AppLogger 메시지**. 사용자 노출 문자열 0건.

세부 분류:
- `Models/Alarm.swift:8,17,99,104` — DocC 주석 ("오전 7:00", "오늘", "Alarm/알람" 표기)
- `Delegates/AppDelegate.swift:201,208` — 코드 주석 ("정지" / "스누즈" 액션 분기 설명)
- `Views/AlarmList/AlarmListView.swift:7` — DocC 주석
- `Services/AudioService.swift:93,159` — AppLogger.warning 메시지 + 코드 주석
- `Services/LocalNotificationService.swift:166` — 메서드 DocC
- `Services/LiveActivityManager.swift:12,13` — ContentState 필드 DocC

→ 모두 i18n 대상 아님 (개발자 전용). PASS.

### 1.4 MVVM 분리

`grep -rn "import SwiftUI" harness/output/ViewModels/` → **0건**.
모든 ViewModel은 `import Foundation`만 사용. UI 타입(Color/Font/Image) 전무.
i18n 작업 후에도 MVVM 분리 보존됨.

### 1.5 동시성 보존

| 어노테이션 | 대상 | 보존 |
|------------|------|------|
| `@MainActor @Observable` | AlarmListViewModel, AlarmDetailViewModel, SettingsViewModel, WeeklyAlarmViewModel, AlarmRingingViewModel, AppThemeManager | ✅ |
| `actor` | AlarmStore, AudioService, VolumeService, LocalNotificationService, LiveActivityManager, AlarmKitService | ✅ |
| `@available(iOS 26.0, *)` | AlarmKitService, StopAlarmIntent, SnoozeAlarmIntent, AlarmMetadata | ✅ |
| `@available(iOS 17.0, *)` | LiveActivityManager, ActivityKit 분기 | ✅ |
| `Sendable` | Alarm, AlarmMode, AlarmSchedule, Weekday, AlarmError, ContentState | ✅ |

### 1.6 rawValue 영구 식별자 보존

| Enum | rawValue 형 | 보존 여부 |
|------|------------|----------|
| `AlarmMode` | String ("alarmKit"/"local") | ✅ 보존 |
| `Weekday` | Int (1~7, Calendar weekday 매핑) | ✅ 보존 |
| `AlarmSchedule` (Codable TypeKey) | String ("once"/"weekly"/"specificDate") | ✅ 보존 |
| `AlarmDetailViewModel.ScheduleType` | String ("once"/"weekly"/"specificDate") | ⚠️ 변경됨 — 한국어 → 영문. **ViewModel 내부 in-memory enum**, UserDefaults 저장 안 됨 (Alarm 모델은 별도 `AlarmSchedule` 사용). SELF_CHECK 주장 검증 완료, 데이터 호환 영향 없음 |

UserDefaults `savedAlarms_v2` 호환성 깨질 가능성 0%.

### 1.7 AlarmKit API 정합성

`AlarmButton(text: LocalizedStringResource)`, `AlarmPresentation.Alert(title: LocalizedStringResource)` 패턴이 일관되게 적용됨:

- `Services/AlarmKitService.swift:80-92, 184-189` — alert title은 `LocalizedStringResource(stringLiteral: alarm.displayTitle)` (사용자 동적 입력값), 버튼 text는 `LocalizedStringResource("alarmkit_button_*")` (카탈로그 키)
- `Intents/SnoozeAlarmIntent.swift:42-54` — 동일한 패턴

빌드 #2에서 `AlarmButton(text: LocalizedStringResource)` 타입 정합성 확인됨. 빌드 #1의 `String(localized:)` → `LocalizedStringResource()` 핫픽스도 정상 작동.

### 1.8 Info.plist 적용 확인

```bash
cat /Users/kimnahun/Desktop/Side-Project/BetterAlarm/BetterAlarm/Info.plist
```

```xml
<key>CFBundleDevelopmentRegion</key>
<string>en</string>
<key>CFBundleLocalizations</key>
<array>
    <string>en</string>
    <string>ko</string>
</array>
<key>NSAlarmKitUsageDescription</key>
<string>This app needs permission to schedule alarms.</string>
```

Info.plist.patch.md 지시문이 실제 BetterAlarm/Info.plist에 반영 완료. PASS.

### 1.9 UI 잘림 점검 (SPEC §7.2 / SELF_CHECK §D)

**적용 완료 (3건)**:
1. AlarmDetailView alarmMode 토글 — PToggle 제거 → HStack + lineLimit(2) + minimumScaleFactor(0.9) + fixedSize. ✅
2. AlarmRingingView 스누즈 버튼 — minWidth: 160 → 200. ✅
3. SettingsView 잠금화면 위젯 권한 행 — HStack → VStack(spacing:4) 분리. ✅

**미적용 (3건, 대부분 SELF_CHECK §D.2의 정당한 결정)**:
- §7.2A 탭바 — "Weekly"/"Alarms"/"Settings" 단어 채택으로 SwiftUI 자동 처리에 위임. (보통 OK)
- §7.2C iOS26 토스트 — `pToast` 컴포넌트 자동 wrap에 위임. (PersonalColorDesignSystem 동작 의존)
- §7.2E 알림권한·AlarmKit 권한 행 — 한 줄 HStack. `lineLimit(1)+minimumScaleFactor(0.85)`만 적용. **영어 환경에서 "Notifications" + "Allowed" + "Open Settings"이 한 줄에 들어가지 않을 가능성 있음**. SPEC §7.2D는 VStack 분리를 권고했지만 잠금화면 위젯 행만 적용. — 권장 보강 사항으로 분류 (BLOCKER는 아님).

### 1.10 자연스러움 평가 (30개 샘플)

| Key | ko | en | 평가 |
|-----|----|----|------|
| `tab_alarm_title` | 알람 | Alarms | 자연 |
| `tab_weekly_title` | 주간 | Weekly | 짧고 자연 |
| `tab_settings_title` | 설정 | Settings | 자연 |
| `alarm_list_empty_title` | 설정된 알람이 없습니다 | No alarms set | 자연 |
| `alarm_list_empty_subtitle` | + 버튼을 눌러 첫 알람을 추가하세요 | Tap + to add your first alarm | 자연, 영어가 직관적 |
| `alarm_detail_alarmkit_toggle_label` | 앱이 꺼진 상태에서도 알람 받기 | Ring even when app is closed | 자연, 영어 28자라 잘림 보강 적용됨 |
| `alarm_detail_alarmkit_footer_on` | 앱이 꺼진 상태에서도 알람이 울립니다. (iOS 26 이상 필요) | Rings even when the app is closed. (Requires iOS 26 or later) | 자연 |
| `alarm_detail_silent_toggle_label` | 조용한 알람 | Silent Alarm | 자연 |
| `alarm_detail_earphone_warning` | 이어폰이 연결되어 있지 않습니다. 알람 시각에 이어폰을 연결해주세요. | No headphones connected. Please connect headphones before the alarm rings. | 자연, en이 약간 길지만 alert wrap |
| `alarm_detail_specific_date_unavailable` | 특정 날짜 알람은 iOS 26 이상에서만 지원됩니다. | Specific-date alarms require iOS 26 or later. | 자연 |
| `alarm_detail_schedule_specific_date` | 특정 날짜 | Specific Date | 자연 |
| `alarm_row_skipping_next` | 다음 1회 건너뜀 | Skipping next | 자연 |
| `alarm_row_snoozed` | 스누즈 중 | Snoozed | 자연 |
| `alarm_row_swipe_skip_once` | 1회 건너뛰기 | Skip Once | 자연 |
| `alarm_ringing_stop_button` | 정지 | Stop | 자연 |
| `alarm_ringing_snooze_button` | 스누즈 (5분) | Snooze (5 min) | 자연 |
| `alarm_ringing_stop_a11y_hint` | 알람을 끕니다 | Turns off the alarm | 자연 |
| `weekly_disable_action_title` | 이 주간 알람을 어떻게 처리할까요? | What would you like to do with this alarm? | en이 길지만 자연. action sheet wrap 의존 |
| `weekly_disable_action_skip_once` | 이번만 스킵 | Skip Once | 자연 (ko에 영어 차용어 — 한국 사용자 익숙) |
| `weekly_disable_action_disable_full` | 완전히 끄기 | Turn Off | 자연 |
| `settings_section_feedback` | 피드백/문의 | Feedback | en이 짧지만 의미 동등 |
| `settings_open_app_settings` | 설정 열기 | Open Settings | 자연 |
| `settings_permission_authorized` | 허용됨 | Allowed | 자연 |
| `settings_permission_denied` | 허용 안 됨 | Not allowed | 자연 |
| `settings_theme_changed_format` | %@ 테마로 변경되었습니다 | Switched to %@ theme | 자연, en이 능동형 |
| `toast_alarm_saved` | 알람이 저장되었습니다 | Alarm saved | 자연 |
| `toast_alarm_disabled` | 알람이 꺼졌습니다 | Alarm turned off | 자연 |
| `toast_skip_next_once` | 다음 1회 건너뜁니다 | Skipping next occurrence | 자연 |
| `notif_alarm_body_default` | 알람이 울립니다. | Your alarm is ringing. | 자연 |
| `error_not_authorized` | 알람을 사용하려면 알림 권한이 필요합니다. 설정에서 권한을 허용해주세요. | Notification permission is required. Please enable it in Settings. | 자연 (ko가 약간 길지만 alert wrap) |

전체 평균: **자연스러움 우수**. 직역 톤 거의 없음. en은 명사형/명령형 짧게, ko는 격식체이지만 어색하지 않음.

**미세 이슈 (BLOCKER 아님, 권장 개선)**:
1. `alarm_row_toggle_disable` ko "비활성화" / en "disable" — 보간 시 `Wake up alarm enable`/"Wake up alarm disable" 처럼 동사 소문자가 어색. 영어 단어를 명사형 "on"/"off" 또는 "enabled"/"disabled"로 변경 권장.
2. `intent_*_description` 마침표 일관성 부족 — ko ("알람을 정지합니다"/"알람을 스누즈합니다") 마침표 없음, en ("Stops the alarm."/"Snoozes the alarm.") 마침표 있음. 한쪽 통일 권장.
3. `live_activity_no_alarm_title` ko "알람을 추가해주세요" — 위젯 짧은 공간에 다소 길다. "알람 없음" 같은 짧은 표현 고려 가능.
4. `intent_alarmid_param` "Alarm ID" — Apple HIG는 user-facing parameter title을 "Alarm" 또는 "Which alarm"으로 자연스럽게 권장. 현재로도 OK.

---

## 2. 채점표

| 항목 | 점수 | 사유 |
|------|------|------|
| 동시성 | 9/10 | @MainActor·@Observable·actor·@available(iOS 26)·Sendable 모두 보존. ScheduleType String rawValue로 변경되었으나 internal enum이라 영향 없음. 감점 1점은 `LocalizedStringResource(stringLiteral: alarm.displayTitle)`이 dynamic 동작이라 SPEC §10.2 주의 권고 대상이지만 사용자 입력 텍스트 표시 의도라 정당. |
| MVVM | 9/10 | ViewModel에 SwiftUI/UI 타입 0건. 의존성 단방향 보존. 감점 1점은 SettingsViewModel.swift:25-27에서 init 시점에 `String(localized:)` 평가하는 패턴이 약간의 인지 부하 (구조적 위반은 아님). |
| HIG | 8/10 | UI 잘림 점검 §7.2 핵심 3건 적용. dynamicTypeSize 적용. 감점 2점은 §7.2D 권장이지만 알림권한·AlarmKit 권한 행은 한 줄 HStack 유지로, 영어 환경 시뮬레이터 검증이 필요한 잠재 잘림 위험 존재. minimumScaleFactor 0.85로 폰트 축소는 적용했지만 button 폭에 의한 압박 잔존. |
| API | 8/10 | LocalizedStringResource·String Catalog·NSLocalizedString·String(localized:) 적절 혼용. AlarmButton/AlarmPresentation에 LocalizedStringResource 정확 적용. AlarmKit 권한 흐름·iOS 26 가드 모두 보존. 감점 2점: (a) `LocalizedStringResource(stringLiteral: alarm.displayTitle)`은 verbatim 의도 명시 부족, (b) `String.LocalizationValue` 보간 가능한 곳에서 `String(format: NSLocalizedString(...))` 옛 스타일 혼재. |
| 기능 충실도 | 8/10 | i18n 커버리지 전수 적용 (사용자 노출 0건 한국어 하드코딩). 번역 자연스러움 우수. 감점 2점: (a) `common_loading` 미사용 dead key, (b) `disable`/`enable` 영어 소문자가 토글 a11y 보간 시 어색, (c) `intent_*_description` 마침표 일관성 부족 — 셋 다 폴리싱. |

---

## 3. BLOCKERS

**없음.**

빌드 SUCCEEDED, 사용자 노출 한국어 0건, 165 키 ko/en 양쪽 완비, 동시성·MVVM·rawValue 호환성 보존. 사용자 핵심 요구 3가지 모두 충족:
- ✅ 한국어/영어 동시 지원 (String Catalog 165 키)
- ✅ UI 잘림 방지 (영어 길이 위험 3건 보강)
- ✅ 자연스러운 번역 (직역 톤 없음)

---

## 4. 권장 개선 사항 (Generator R2 — 선택, BLOCKER 아님)

다음은 통합·머지 후 폴리싱 차원 항목. R2 강제 트리거 사유는 아님.

### 4.1 a11y 토글 라벨 영어 자연화

`harness/output/Resources/Localizable.xcstrings`:
```
"alarm_row_toggle_disable" : { "en": "off",     "ko": "비활성화" → "끄기" 권장 }
"alarm_row_toggle_enable"  : { "en": "on",      "ko": "활성화"  → "켜기" 권장 }
"alarm_row_toggle_a11y_format" : { "en": "Turn %2$@ alarm: %1$@", "ko": "%1$@ 알람 %2$@" }
```
보간 시 영어가 "Wake up alarm on" / "Wake up alarm off" 형태로 자연스러워짐. 현재 "Wake up alarm enable" 어색.

### 4.2 Intent description 마침표 일관성

```
"intent_stop_description"   : ko "알람을 정지합니다" → "알람을 정지합니다."
"intent_snooze_description" : ko "알람을 스누즈합니다" → "알람을 스누즈합니다."
```

### 4.3 미사용 키 정리 또는 사용

`common_loading` ("로딩 중..." / "Loading…") — 카탈로그에는 있으나 코드 어디서도 사용 안 됨. 제거하거나, AlarmListView/SettingsView의 `pLoadingOverlay(message:)` 기본 메시지로 활용 권장.

### 4.4 SettingsView 권한 행 영어 환경 검증

`harness/output/Views/Settings/SettingsView.swift:79-122` — 알림권한·AlarmKit 권한 행 1줄 HStack은 영어 환경 좁은 화면(SE/mini)에서 잘림 가능. 잠금화면 위젯 행과 동일한 VStack 분리 패턴 적용 권장:

```swift
VStack(alignment: .leading, spacing: 4) {
    Text("settings_notification_permission")
        .font(.body)
        .foregroundStyle(Color.pTextPrimary)
    HStack {
        Text(viewModel.notificationAuthStatus)
            .font(.caption)
            .foregroundStyle(...)
        Spacer()
        Button("settings_open_app_settings") { openAppSettings() }
            .font(.caption)
            .foregroundStyle(theme.accentPrimary)
    }
}
```

### 4.5 LocalizedStringResource(stringLiteral:) 의도 명시

`harness/output/Services/AlarmKitService.swift:80`:
```swift
title: LocalizedStringResource(stringLiteral: alarm.displayTitle),
```
사용자 동적 입력 → verbatim 표시 의도임을 주석으로 명시 (또는 iOS 17+의 `LocalizedStringResource(verbatim:)` 사용 가능 확인).

---

## 5. UI 잘림 점검 누락 항목

SPEC §7.3 화면별 점검 체크리스트 27개 정적 분석 결과:

### AlarmListView (3개)
- [x] 헤더 + 버튼 — `Spacer()` + `minWidth/minHeight 44` ✅
- [x] Next alarm 배너 — GlassCard wrap ✅
- [x] empty state — `multilineTextAlignment(.center)` ✅

### AlarmDetailView (7개)
- [x] navigationBarTitleDisplayMode(.inline) + .principal Text ✅
- [x] alarmMode 토글 — HStack+lineLimit(2)+minimumScaleFactor(0.9)+fixedSize ✅
- [x] silent 토글 — "Silent Alarm" 12자 ✅
- [x] footer 텍스트 — Text 자연 wrap ✅
- [x] 시간 picker — 70/80/80pt 고정폭 ✅
- [x] 저장/취소 버튼 — minWidth 44 ✅
- [x] alert "Save Failed"/"OK" — SwiftUI alert 자동 wrap ✅

### SettingsView (6개)
- [x] 헤더 "Settings" ✅
- [⚠️] 권한 섹션 알림 행 — HStack 한 줄 (잠재 위험 §4.4)
- [⚠️] AlarmKit 권한 행 — 동일 (잠재 위험)
- [x] 잠금화면 위젯 권한 — VStack 분리 ✅
- [x] 피드백 행 — Link + envelope, minHeight 44 ✅
- [x] 버전 표시 — Spacer + 우측 Text ✅

### AlarmRingingView (4개)
- [x] 시간 — largeTitle + dynamicTypeSize 제한 ✅
- [x] 알람 제목 — lineLimit(2) + multilineTextAlignment ✅
- [x] 정지 버튼 (120×120 원형) ✅
- [x] 스누즈 버튼 — minWidth 200 ✅

### WeeklyAlarmView (3개)
- [x] 헤더 "Weekly Alarms" ✅
- [x] 요일 탭 — `frame(maxWidth: .infinity)` 균등 분할 ✅
- [x] empty state — multilineTextAlignment(.center) ✅

### AlarmRowView (2개)
- [x] 시간 + 제목 — VStack ✅
- [x] chip — minimumScaleFactor(0.85) ✅

### AppIntents (1개)
- [x] AlarmKit 시스템 잠금화면 버튼 — LocalizedStringResource(키) ✅

**누락**: 정적 분석 불가능한 시각 잘림은 시뮬레이터 영어 로케일 부팅 후 R5/R6 라운드에서 확인. SPEC §7.2E 권한 행 한 줄 HStack은 잠재 위험으로 §4.4에 권장.

---

## 6. 결론

**판정: pass (8.5/10)**

i18n 라운드 R1는 한 번에 통과 수준의 품질. 165개 키가 ko/en 양쪽 자연스럽게 채워졌고, Swift 6 동시성·MVVM·rawValue 호환성 모두 보존. UI 잘림 위험 핵심 3건 보강. 빌드 SUCCEEDED.

권장 개선 4건은 모두 폴리싱 차원으로 R2를 강제할 BLOCKER가 아니다. 통합 후 사용자 시뮬레이터 검증(Phase 2)에서 영어 권한 행 잘림 여부와 토글 a11y 발화를 확인하면서 자연스럽게 해결할 수 있다.

방향 판단: **현재 방향 유지**. 단계 5(Xcode 통합)로 진행 가능.
