# BetterAlarm — 다국어(i18n) 적용 SPEC

## 개요

이번 라운드는 **신규 기능 추가가 아닌 i18n(국제화) 작업**이다. 기존 SPEC(SPEC.previous.md)에 정의된 기능과 아키텍처는 그대로 유지하면서, 프로젝트 전체의 하드코딩된 한국어 문자열을 추출하여 한국어(ko)·영어(en) 두 언어를 동시에 자연스럽게 지원하도록 한다.

설계 원칙:
1. **String Catalog (`.xcstrings`) 채택** — 아래 "1. 작업 개요"에 채택 이유 명시.
2. **자연스러운 번역 우선** — 직역 금지. 영어권 사용자가 어색하지 않도록.
3. **UI 잘림 방지** — 영어가 한국어보다 길어지는 케이스를 사전 식별, 레이아웃 보강.
4. **PROJECT_CONTEXT.md 의 디자인 시스템·아키텍처 요구사항 100% 준수** — Color/Font 토큰, GlassCard, HapticManager, 토스트 컴포넌트(PersonalColorDesignSystem), `@MainActor @Observable` ViewModel, `actor` Service, Sendable struct Model 그대로.
5. **위젯 타깃은 건드리지 않는다** — 위젯이 표시할 텍스트는 메인 앱이 미리 포맷하여 `AlarmActivityAttributes.ContentState`에 주입.

---

## 1. 작업 개요

### i18n 전략: String Catalog (`.xcstrings`) 채택

**채택 사유:**
- 최소 배포 타깃이 iOS 17.0이므로 String Catalog의 모든 기능을 활용 가능 (Xcode 15+).
- Xcode가 `Text("foo")`, `LocalizedStringKey`, `String(localized:)` 등 SwiftUI/Foundation API에서 키를 **자동 추출**해 카탈로그에 채워 넣는다 — 누락 위험 감소.
- 단일 `.xcstrings` 파일 하나로 ko/en 매핑을 모두 관리하므로 PR 리뷰가 쉬움.
- 플루럴(`%lld 분`/`minutes`) 처리, 디바이스 변형(iPhone vs iPad) 처리가 편리.
- 빌드 시점에 Xcode가 `.lproj/Localizable.strings`로 컴파일하므로 런타임 비용은 동일.

**대안 고려:**
- 전통적 `Localizable.strings (ko.lproj / en.lproj)`도 가능하지만, Xcode가 자동 추출하지 않아 누락이 발생하기 쉬움. 본 SPEC에서는 String Catalog를 채택한다.

### 산출물

| 분류 | 작업 |
|------|------|
| 신규 파일 | `BetterAlarm/Resources/Localizable.xcstrings` (1개) |
| 신규 파일 (선택) | `BetterAlarm/Resources/InfoPlist.xcstrings` — `NSAlarmKitUsageDescription` 등 |
| 설정 변경 | `BetterAlarm/Info.plist` — `CFBundleLocalizations`, `CFBundleDevelopmentRegion` 추가 |
| 코드 수정 (Edit) | output/ 아래 .swift 파일 24개 (Logger.swift, Extensions/* 등 제외) — 하드코딩 한글을 키로 교체 |
| 헬퍼 리팩토링 | `Models/Alarm.swift` 내 `KoreanDateFormatters` → 로케일 인지형으로 본문 교체 (이름 유지 또는 `LocalizedDateFormatters`로 rename) |

---

## 2. 지원 로케일

| 항목 | 값 |
|------|---|
| 기본(개발) 로케일 | `en` (영어) — 베이스 |
| 추가 로케일 | `ko` (한국어) |
| `CFBundleDevelopmentRegion` | `en` |
| `CFBundleLocalizations` | `[en, ko]` |

### 위젯 타깃과의 관계

- `BetterAlarmWidget/` 폴더는 본 SPEC 범위 밖 — **수정 금지**.
- 위젯이 표시하는 동적 텍스트 (`nextAlarmTime`, `nextAlarmDate`, `alarmTitle`)는 **메인 앱이 사용자 로케일에 맞게 미리 포맷한 문자열**을 `AlarmActivityAttributes.ContentState`에 주입하는 방식으로 처리.
- 즉 위젯 코드는 그대로 두되, `LiveActivityManager.createContentState(for:)`에서 `Locale.current` 기반 포맷터로 문자열을 만들어 넣는다.
- 위젯이 자체 갖는 정적 라벨(있다면)은 이번 라운드에서 다루지 않음.

---

## 3. 키 네이밍 규칙

```
<도메인>_<위치/역할>_<세부>
```

- snake_case 소문자.
- 도메인 prefix: `alarm_list`, `alarm_detail`, `alarm_ringing`, `weekly`, `settings`, `tab`, `error`, `notif`, `live_activity`, `intent`, `alarmkit`, `common`, `weekday`, `repeat`, `next_alarm`, `toast`, `alarmmode`.
- 동적 인자는 `%@` (문자열) / `%lld` (Int) / `%d` (Int 작은 값) 사용. 위치 파라미터(`%1$@`, `%2$@`)는 어순이 다른 두 언어에서 필수.
- 시간 문자열은 키로 만들지 않고 `Date.formatted(date: .omitted, time: .shortened)` 결과를 사용 (Locale 자동 적용).
- 요일 약어는 `Calendar.current.shortWeekdaySymbols` 또는 `weekday_short_*` 키 사용.

---

## 4. 작업 대상 파일 목록 (전수 점검 결과)

`harness/output/` 아래 **30개 .swift 파일**을 모두 훑은 결과. (Logger/Extensions의 일부는 사용자 표시 문자열 없음.)

| # | 파일 경로 | 발견된 하드코딩 한국어 문자열 (대표) | 처리 방식 |
|---|----------|-----------------------------------|----------|
| 1 | `App/BetterAlarmApp.swift` | "알람", "주간 알람", "설정", "알람 목록 탭", "주간 알람 탭", "설정 탭" | `Label("tab_alarm_title", ...)` + `accessibilityLabel("tab_alarm_a11y")` |
| 2 | `Views/AlarmList/AlarmListView.swift` | "알람", "다음 알람", "다음 알람: %@", "설정된 알람이 없습니다", "+ 버튼을 눌러 첫 알람을 추가하세요", "새 알람 추가", "이 주간 알람을 어떻게 처리할까요?", "이번만 스킵", "완전히 끄기" | `LocalizedStringKey` 적용 |
| 3 | `Views/AlarmDetail/AlarmDetailView.swift` | "시간", "알람 제목", "기본 설정", "알람 모드", "앱이 꺼진 상태에서도 알람이 울립니다. (iOS 26 이상 필요)", "조용한 알람", "AlarmKit 모드에서는 조용한 알람을 지원하지 않습니다.", "이어폰 연결 시 이어폰으로만 소리가 출력됩니다.", "사운드", "기본", "알람 삭제", "알람 편집", "새 알람", "취소", "저장", "오전", "오후", "오전/오후", "시", "분", "%d시", "%02d분", "오전 오후 선택", "시 선택", "분 선택", "반복", "날짜", "특정 날짜 선택", "선택됨", "선택 안됨", "앱이 꺼진 상태에서도 알람 받기", "iOS 26 이상에서만 사용할 수 있습니다", "AlarmKit 모드에서는 사용할 수 없습니다", "1회", "주간 반복", "특정 날짜", "저장 중...", "삭제 중...", "저장 실패", "확인" | `LocalizedStringKey` + `String(localized:)` |
| 4 | `Views/Settings/SettingsView.swift` | "설정", "테마", "알림 권한", "허용됨", "허용 안 됨", "설정 열기", "AlarmKit 권한", "iOS 26 이상 필요", "잠금화면 위젯", "잠금화면 위젯 권한", "iOS 17 이상 필요", "Live Activity를 통해 잠금화면에 다음 알람 정보를 표시합니다", "피드백 보내기", "이메일로 피드백을 보냅니다", "피드백/문의", "버전", "앱 정보", "앱 버전 %@, 빌드 %@", "권한 확인 중...", "BetterAlarm%20피드백" | `LocalizedStringKey` + URL의 subject만 영문/한글 분기 |
| 5 | `Views/Weekly/WeeklyAlarmView.swift` | "주간 알람", "주간 반복 알람이 없습니다", "알람 탭에서 주간 반복 알람을 추가하세요", "이 주간 알람을 어떻게 처리할까요?", "이번만 스킵", "완전히 끄기" | `LocalizedStringKey` |
| 6 | `Views/AlarmRinging/AlarmRingingView.swift` | "정지", "스누즈 (5분)", "현재 시각: %@", "알람 이름: %@", "알람 정지", "알람을 끕니다", "스누즈", "5분 후 다시 알람이 울립니다" | `LocalizedStringKey` |
| 7 | `Views/Components/AlarmRowView.swift` | "다음 1회 건너뜀", "스누즈 중", "알람 시각: %@", "%@ 알람 %@" (활성/비활성), "AlarmKit 모드", "조용한 알람", "건너뛰기 취소", "1회 건너뛰기" | `LocalizedStringKey` |
| 8 | `Models/Alarm.swift` | "알람" (displayTitle 폴백), "1회", "매일", "주말", "주중", "오전"/"오후", "오늘"/"내일" — `KoreanDateFormatters` 메서드 내부 | `String(localized:)` 로 변경 + 포맷터 로케일 인지형으로 |
| 9 | `Models/AlarmSchedule.swift` (Weekday) | "일", "월", "화", "수", "목", "금", "토" | `String(localized:)` — `weekday_short_*` 키 |
| 10 | `Models/AlarmMode.swift` | "AlarmKit (앱 꺼진 상태에서도 울림)", "로컬 알림" | `String(localized:)` |
| 11 | `Models/AlarmError.swift` | "알람을 사용하려면 알림 권한이 필요합니다…", "알람 등록에 실패했습니다: %@", "사운드 파일을 찾을 수 없습니다: %@", "조용한 알람을 사용하려면 이어폰을 연결해주세요.", "이 기능은 iOS 26 이상에서만 사용할 수 있습니다." | `errorDescription`을 `String(localized:)` 로 |
| 12 | `Services/LocalNotificationService.swift` | "정지", "스누즈 (5분)", "알람이 울립니다.", "알람이 울리고 있습니다. 앱을 열어 알람을 끄세요.", "알람이 설정되어 있습니다. 알람 시각: %@", "스누즈 알람이 울립니다.", `AlarmError.scheduleFailed("다음 발생 시각을 계산할 수 없습니다.")` | `String(localized:)` (notification body는 시스템이 표시하므로 디바이스 로케일 그대로 적용됨) |
| 13 | `Services/LiveActivityManager.swift` | "--:--" (그대로 유지), "설정된 알람 없음", "알람을 추가해주세요" — ContentState empty 표시 | 메인 앱 측에서 `String(localized:)` 후 ContentState 주입 |
| 14 | `Services/AlarmKitService.swift` | "정지", "스누즈", "스누즈 알람", "다음 발생 시각 계산 실패", "과거 시각으로는 알람을 설정할 수 없습니다.", "날짜 변환 실패", "과거 날짜로는 알람을 설정할 수 없습니다." | `String(localized:)` — AlarmKit Button text는 시스템 잠금화면 표시이므로 디바이스 로케일 적용 |
| 15 | `Services/AudioService.swift` | "default_alarm 사운드 파일이 번들에 없습니다", "사운드 '%@' 없음, default_alarm으로 폴백" | **로그 전용** → 그대로 유지 (개발자용, i18n 대상 아님) |
| 16 | `Services/AlarmStore.swift` | "오전", "오후", "오늘", "내일", "%@ %@ %d시 %02d분" (nextAlarmDisplayString) | 로케일 인지형 포맷터로 교체 (`Date.formatted` 사용) |
| 17 | `Services/VolumeService.swift` | (사용자 표시 문자열 없음 — 로그만) | 변경 없음 |
| 18 | `Services/AppThemeManager.swift` | (사용자 표시 문자열 없음 — 로그만) | 변경 없음 |
| 19 | `Delegates/AppDelegate.swift` | (UNNotification body는 LocalNotificationService 경유 — 직접 한글 없음. 로그만) | 변경 없음 |
| 20 | `Intents/StopAlarmIntent.swift` | `title: LocalizedStringResource = "알람 정지"`, `IntentDescription("알람을 정지합니다")`, `@Parameter(title: "알람 ID")` | `LocalizedStringResource("intent_stop_title")` 의 키화 |
| 21 | `Intents/SnoozeAlarmIntent.swift` | `title: LocalizedStringResource = "스누즈"`, `IntentDescription("알람을 스누즈합니다")`, `@Parameter(title: "알람 ID")`, `"스누즈 알람"`, `"정지"`, `"스누즈"` | `LocalizedStringResource(...)` 키화 |
| 22 | `ViewModels/AlarmList/AlarmListViewModel.swift` | "알람이 켜졌습니다", "알람이 꺼졌습니다", "알람이 수정되었습니다", "알람이 저장되었습니다", "알람이 삭제되었습니다", "다음 1회 건너뜁니다", "건너뛰기가 취소되었습니다" (AlarmToggleHandling 프로토콜 default 구현 포함) | `String(localized:)` |
| 23 | `ViewModels/AlarmDetail/AlarmDetailViewModel.swift` | "1회"/"주간 반복"/"특정 날짜" (ScheduleType.rawValue), "이 기능은 iOS 26 이상에서만 사용할 수 있습니다.", "특정 날짜 알람은 iOS 26 이상에서만 지원됩니다.", "이어폰이 연결되어 있지 않습니다. 알람 시각에 이어폰을 연결해주세요.", "알람이 수정되었습니다", "알람이 저장되었습니다" | ScheduleType의 displayName computed property 추가 후 view에서 displayName 사용. rawValue는 영구 식별자로 영문화하거나 그대로 유지 (호환성 영향 없음 — 메모리 enum) |
| 24 | `ViewModels/Settings/SettingsViewModel.swift` | "확인 중...", "허용됨", "허용 안 됨", "미설정", "알 수 없음", "iOS 17 이상 필요", "iOS 26 이상 필요", "%@ 테마로 변경되었습니다" | `String(localized:)` |
| 25 | `ViewModels/Weekly/WeeklyAlarmViewModel.swift` | (대부분 AlarmToggleHandling 프로토콜 default impl에서 처리) | 변경 없음 (#22의 메시지 키가 적용되면 자동 반영) |
| 26 | `ViewModels/AlarmRinging/AlarmRingingViewModel.swift` | (시간 문자열은 KoreanDateFormatters 경유 → 포맷터 교체로 자동 반영) | 변경 없음 |
| 27 | `Shared/AlarmMetadata.swift` | (사용자 표시 문자열 없음) | 변경 없음 |
| 28 | `Utils/Logger.swift` | (개발자용 로그) | **i18n 대상 아님** — 변경 없음 |
| 29 | `Extensions/UIColor+Theme.swift` | (사용자 표시 문자열 없음) | 변경 없음 |
| 30 | `Extensions/UIView+Glass.swift` | (사용자 표시 문자열 없음) | 변경 없음 |

---

## 5. 키 카탈로그 (전체 키-한국어-영어 매핑)

자연스러운 번역 우선. 직역 금지. 약 **130개 키** 예상.

### 5.1 탭바 (6개)
| Key | ko | en |
|-----|----|----|
| `tab_alarm_title` | 알람 | Alarms |
| `tab_weekly_title` | 주간 | Weekly |
| `tab_settings_title` | 설정 | Settings |
| `tab_alarm_a11y` | 알람 목록 탭 | Alarms tab |
| `tab_weekly_a11y` | 주간 알람 탭 | Weekly alarms tab |
| `tab_settings_a11y` | 설정 탭 | Settings tab |

(영어 탭바 텍스트가 한국어보다 길어지므로 짧은 단어 채택. "Weekly Alarms" 대신 "Weekly".)

### 5.2 알람 목록 화면 (AlarmListView)
| Key | ko | en |
|-----|----|----|
| `alarm_list_title` | 알람 | Alarms |
| `alarm_list_next_alarm_label` | 다음 알람 | Next alarm |
| `alarm_list_next_alarm_a11y` | 다음 알람: %@ | Next alarm: %@ |
| `alarm_list_empty_title` | 설정된 알람이 없습니다 | No alarms set |
| `alarm_list_empty_subtitle` | + 버튼을 눌러 첫 알람을 추가하세요 | Tap + to add your first alarm |
| `alarm_list_empty_a11y` | 설정된 알람이 없습니다. + 버튼을 눌러 첫 알람을 추가하세요. | No alarms set. Tap + to add your first alarm. |
| `alarm_list_add_button_a11y` | 새 알람 추가 | Add new alarm |

### 5.3 알람 상세 화면 (AlarmDetailView)
| Key | ko | en |
|-----|----|----|
| `alarm_detail_title_new` | 새 알람 | New Alarm |
| `alarm_detail_title_edit` | 알람 편집 | Edit Alarm |
| `alarm_detail_section_time` | 시간 | Time |
| `alarm_detail_section_basic` | 기본 설정 | General |
| `alarm_detail_section_mode` | 알람 모드 | Alarm Mode |
| `alarm_detail_section_sound_output` | 소리 출력 | Sound Output |
| `alarm_detail_section_sound` | 사운드 | Sound |
| `alarm_detail_title_placeholder` | 알람 제목 | Alarm name |
| `alarm_detail_repeat_label` | 반복 | Repeat |
| `alarm_detail_date_label` | 날짜 | Date |
| `alarm_detail_date_a11y` | 특정 날짜 선택 | Select specific date |
| `alarm_detail_save_button` | 저장 | Save |
| `alarm_detail_cancel_button` | 취소 | Cancel |
| `alarm_detail_delete_button` | 알람 삭제 | Delete Alarm |
| `alarm_detail_saving` | 저장 중... | Saving… |
| `alarm_detail_deleting` | 삭제 중... | Deleting… |
| `alarm_detail_save_error_title` | 저장 실패 | Save Failed |
| `alarm_detail_ok_button` | 확인 | OK |
| `alarm_detail_sound_default` | 기본 | Default |
| `alarm_detail_period_am` | 오전 | AM |
| `alarm_detail_period_pm` | 오후 | PM |
| `alarm_detail_picker_period_a11y` | 오전 오후 선택 | Select AM or PM |
| `alarm_detail_picker_hour_a11y` | 시 선택 | Select hour |
| `alarm_detail_picker_minute_a11y` | 분 선택 | Select minute |
| `alarm_detail_hour_unit_format` | %d시 | %d |
| `alarm_detail_minute_unit_format` | %02d분 | %02d |
| `alarm_detail_alarmkit_toggle_label` | 앱이 꺼진 상태에서도 알람 받기 | Ring even when app is closed |
| `alarm_detail_alarmkit_toggle_a11y_hint` | iOS 26 이상에서만 사용할 수 있습니다 | Requires iOS 26 or later |
| `alarm_detail_alarmkit_footer_on` | 앱이 꺼진 상태에서도 알람이 울립니다. (iOS 26 이상 필요) | Rings even when the app is closed. (Requires iOS 26 or later) |
| `alarm_detail_alarmkit_footer_off` | 앱이 백그라운드 또는 포그라운드 상태에서 알람이 울립니다. | Rings while the app is in the background or foreground. |
| `alarm_detail_silent_toggle_label` | 조용한 알람 | Silent Alarm |
| `alarm_detail_silent_footer_alarmkit` | AlarmKit 모드에서는 조용한 알람을 지원하지 않습니다. | Silent alarms are not available in AlarmKit mode. |
| `alarm_detail_silent_footer_default` | 이어폰 연결 시 이어폰으로만 소리가 출력됩니다. | Plays only through connected headphones. |
| `alarm_detail_silent_a11y_hint_alarmkit` | AlarmKit 모드에서는 사용할 수 없습니다 | Not available in AlarmKit mode |
| `alarm_detail_silent_a11y_hint_default` | 이어폰 연결 시 이어폰으로만 소리가 출력됩니다 | Plays only through connected headphones |
| `alarm_detail_earphone_warning` | 이어폰이 연결되어 있지 않습니다. 알람 시각에 이어폰을 연결해주세요. | No headphones connected. Please connect headphones before the alarm rings. |
| `alarm_detail_weekday_a11y_selected_format` | %@ 선택됨 | %@ selected |
| `alarm_detail_weekday_a11y_unselected_format` | %@ 선택 안됨 | %@ not selected |
| `alarm_detail_repeat_a11y` | 알람 반복 유형 선택 | Choose repeat option |
| `alarm_detail_schedule_once` | 1회 | Once |
| `alarm_detail_schedule_weekly` | 주간 반복 | Weekly |
| `alarm_detail_schedule_specific_date` | 특정 날짜 | Specific Date |
| `alarm_detail_specific_date_unavailable` | 특정 날짜 알람은 iOS 26 이상에서만 지원됩니다. | Specific-date alarms require iOS 26 or later. |

### 5.4 알람 행 (AlarmRowView)
| Key | ko | en |
|-----|----|----|
| `alarm_row_skipping_next` | 다음 1회 건너뜀 | Skipping next |
| `alarm_row_snoozed` | 스누즈 중 | Snoozed |
| `alarm_row_alarmkit_a11y` | AlarmKit 모드 | AlarmKit mode |
| `alarm_row_silent_a11y` | 조용한 알람 | Silent alarm |
| `alarm_row_time_a11y` | 알람 시각: %@ | Alarm time: %@ |
| `alarm_row_toggle_a11y_format` | %1$@ 알람 %2$@ | %1$@ alarm %2$@ |
| `alarm_row_toggle_disable` | 비활성화 | disable |
| `alarm_row_toggle_enable` | 활성화 | enable |
| `alarm_row_swipe_clear_skip` | 건너뛰기 취소 | Cancel Skip |
| `alarm_row_swipe_skip_once` | 1회 건너뛰기 | Skip Once |

### 5.5 알람 울림 화면 (AlarmRinging)
| Key | ko | en |
|-----|----|----|
| `alarm_ringing_stop_button` | 정지 | Stop |
| `alarm_ringing_snooze_button` | 스누즈 (5분) | Snooze (5 min) |
| `alarm_ringing_current_time_a11y` | 현재 시각: %@ | Current time: %@ |
| `alarm_ringing_alarm_title_a11y` | 알람 이름: %@ | Alarm name: %@ |
| `alarm_ringing_stop_a11y` | 알람 정지 | Stop alarm |
| `alarm_ringing_stop_a11y_hint` | 알람을 끕니다 | Turns off the alarm |
| `alarm_ringing_snooze_a11y` | 스누즈 | Snooze |
| `alarm_ringing_snooze_a11y_hint` | 5분 후 다시 알람이 울립니다 | Rings again in 5 minutes |

### 5.6 주간 알람 화면 (Weekly)
| Key | ko | en |
|-----|----|----|
| `weekly_title` | 주간 알람 | Weekly Alarms |
| `weekly_empty_title` | 주간 반복 알람이 없습니다 | No weekly alarms |
| `weekly_empty_subtitle` | 알람 탭에서 주간 반복 알람을 추가하세요 | Add a weekly alarm from the Alarms tab |
| `weekly_empty_a11y` | 주간 반복 알람이 없습니다. 알람 탭에서 주간 반복 알람을 추가하세요. | No weekly alarms. Add one from the Alarms tab. |
| `weekly_disable_action_title` | 이 주간 알람을 어떻게 처리할까요? | What would you like to do with this alarm? |
| `weekly_disable_action_skip_once` | 이번만 스킵 | Skip Once |
| `weekly_disable_action_disable_full` | 완전히 끄기 | Turn Off |

### 5.7 설정 화면 (Settings)
| Key | ko | en |
|-----|----|----|
| `settings_title` | 설정 | Settings |
| `settings_section_theme` | 테마 | Theme |
| `settings_section_permission` | 권한 | Permissions |
| `settings_section_lock_widget` | 잠금화면 위젯 | Lock Screen Widget |
| `settings_section_feedback` | 피드백/문의 | Feedback |
| `settings_section_app_info` | 앱 정보 | About |
| `settings_notification_permission` | 알림 권한 | Notifications |
| `settings_alarmkit_permission` | AlarmKit 권한 | AlarmKit |
| `settings_lock_widget_label` | 잠금화면 위젯 | Lock Screen Widget |
| `settings_lock_widget_permission` | 잠금화면 위젯 권한 | Widget permission |
| `settings_lock_widget_a11y_hint` | Live Activity를 통해 잠금화면에 다음 알람 정보를 표시합니다 | Shows next alarm info on the Lock Screen via Live Activity |
| `settings_open_app_settings` | 설정 열기 | Open Settings |
| `settings_feedback_button` | 피드백 보내기 | Send Feedback |
| `settings_feedback_a11y_hint` | 이메일로 피드백을 보냅니다 | Sends feedback by email |
| `settings_feedback_email_subject` | BetterAlarm 피드백 | BetterAlarm Feedback |
| `settings_version_label` | 버전 | Version |
| `settings_version_a11y_format` | 앱 버전 %1$@, 빌드 %2$@ | App version %1$@, build %2$@ |
| `settings_loading_message` | 권한 확인 중... | Checking permissions… |
| `settings_permission_authorized` | 허용됨 | Allowed |
| `settings_permission_denied` | 허용 안 됨 | Not allowed |
| `settings_permission_not_determined` | 미설정 | Not set |
| `settings_permission_unknown` | 알 수 없음 | Unknown |
| `settings_permission_loading` | 확인 중... | Checking… |
| `settings_requires_ios17` | iOS 17 이상 필요 | Requires iOS 17+ |
| `settings_requires_ios26` | iOS 26 이상 필요 | Requires iOS 26+ |
| `settings_theme_changed_format` | %@ 테마로 변경되었습니다 | Switched to %@ theme |
| `settings_notification_permission_a11y_format` | 알림 권한: %@ | Notification permission: %@ |
| `settings_alarmkit_permission_a11y_format` | AlarmKit 권한: %@ | AlarmKit permission: %@ |
| `settings_lock_widget_permission_a11y_format` | 잠금화면 위젯 권한: %@ | Lock Screen Widget permission: %@ |

### 5.8 토스트 메시지
| Key | ko | en |
|-----|----|----|
| `toast_alarm_enabled` | 알람이 켜졌습니다 | Alarm turned on |
| `toast_alarm_disabled` | 알람이 꺼졌습니다 | Alarm turned off |
| `toast_alarm_saved` | 알람이 저장되었습니다 | Alarm saved |
| `toast_alarm_updated` | 알람이 수정되었습니다 | Alarm updated |
| `toast_alarm_deleted` | 알람이 삭제되었습니다 | Alarm deleted |
| `toast_skip_next_once` | 다음 1회 건너뜁니다 | Skipping next occurrence |
| `toast_skip_cleared` | 건너뛰기가 취소되었습니다 | Skip cancelled |
| `toast_alarmkit_unavailable` | 이 기능은 iOS 26 이상에서만 사용할 수 있습니다. | This feature requires iOS 26 or later. |

### 5.9 에러 메시지 (AlarmError)
| Key | ko | en |
|-----|----|----|
| `error_not_authorized` | 알람을 사용하려면 알림 권한이 필요합니다. 설정에서 권한을 허용해주세요. | Notification permission is required. Please enable it in Settings. |
| `error_schedule_failed_format` | 알람 등록에 실패했습니다: %@ | Failed to schedule alarm: %@ |
| `error_sound_not_found_format` | 사운드 파일을 찾을 수 없습니다: %@ | Sound file not found: %@ |
| `error_earphone_not_connected` | 조용한 알람을 사용하려면 이어폰을 연결해주세요. | Please connect headphones to use Silent Alarm. |
| `error_alarmkit_unavailable` | 이 기능은 iOS 26 이상에서만 사용할 수 있습니다. | This feature requires iOS 26 or later. |
| `error_next_trigger_unavailable` | 다음 발생 시각을 계산할 수 없습니다. | Unable to compute next trigger time. |
| `error_past_time` | 과거 시각으로는 알람을 설정할 수 없습니다. | Cannot schedule an alarm in the past. |
| `error_past_date` | 과거 날짜로는 알람을 설정할 수 없습니다. | Cannot schedule an alarm on a past date. |
| `error_date_conversion_failed` | 날짜 변환 실패 | Date conversion failed |
| `error_compute_trigger_failed` | 다음 발생 시각 계산 실패 | Failed to compute next trigger time |

### 5.10 알림 본문 (UNNotification)
| Key | ko | en |
|-----|----|----|
| `notif_alarm_body_default` | 알람이 울립니다. | Your alarm is ringing. |
| `notif_alarm_body_repeating` | 알람이 울리고 있습니다. 앱을 열어 알람을 끄세요. | Your alarm is still ringing. Open the app to turn it off. |
| `notif_alarm_body_snooze` | 스누즈 알람이 울립니다. | Snooze alarm is ringing. |
| `notif_background_reminder_format` | 알람이 설정되어 있습니다. 알람 시각: %@ | Alarm scheduled for %@. |
| `notif_action_stop` | 정지 | Stop |
| `notif_action_snooze_5min` | 스누즈 (5분) | Snooze (5 min) |

### 5.11 Live Activity (메인 앱이 ContentState로 주입)
| Key | ko | en |
|-----|----|----|
| `live_activity_no_alarm_date` | 설정된 알람 없음 | No alarm set |
| `live_activity_no_alarm_title` | 알람을 추가해주세요 | Add an alarm |
| `live_activity_relative_today` | 오늘 | Today |
| `live_activity_relative_tomorrow` | 내일 | Tomorrow |

### 5.12 AppIntent (LocalizedStringResource)
| Key | ko | en |
|-----|----|----|
| `intent_stop_title` | 알람 정지 | Stop Alarm |
| `intent_stop_description` | 알람을 정지합니다 | Stops the alarm. |
| `intent_snooze_title` | 스누즈 | Snooze |
| `intent_snooze_description` | 알람을 스누즈합니다 | Snoozes the alarm. |
| `intent_alarmid_param` | 알람 ID | Alarm ID |
| `alarmkit_alert_snooze_title` | 스누즈 알람 | Snooze Alarm |
| `alarmkit_button_stop` | 정지 | Stop |
| `alarmkit_button_snooze` | 스누즈 | Snooze |

### 5.13 요일 (Weekday.shortName)
| Key | ko | en |
|-----|----|----|
| `weekday_short_sun` | 일 | Sun |
| `weekday_short_mon` | 월 | Mon |
| `weekday_short_tue` | 화 | Tue |
| `weekday_short_wed` | 수 | Wed |
| `weekday_short_thu` | 목 | Thu |
| `weekday_short_fri` | 금 | Fri |
| `weekday_short_sat` | 토 | Sat |

### 5.14 반복 설명 (Alarm.repeatDescriptionWithoutSkip)
| Key | ko | en |
|-----|----|----|
| `repeat_once` | 1회 | Once |
| `repeat_every_day` | 매일 | Every day |
| `repeat_weekend` | 주말 | Weekends |
| `repeat_weekdays` | 주중 | Weekdays |

### 5.15 다음 알람 표시 문자열 (AlarmStore.nextAlarmDisplayString)
| Key | ko | en |
|-----|----|----|
| `next_alarm_format_today` | 오늘 %@ | Today %@ |
| `next_alarm_format_tomorrow` | 내일 %@ | Tomorrow %@ |
| `next_alarm_format_date` | %1$@ %2$@ | %1$@ %2$@ |

(`%@`에는 `Date.formatted(date: .omitted, time: .shortened)` 결과가 들어가며 시스템 로케일이 자동 반영된다.)

### 5.16 AlarmMode displayName
| Key | ko | en |
|-----|----|----|
| `alarmmode_alarmkit_display` | AlarmKit (앱 꺼진 상태에서도 울림) | AlarmKit (rings even when closed) |
| `alarmmode_local_display` | 로컬 알림 | Local Notification |

### 5.17 공통/폴백
| Key | ko | en |
|-----|----|----|
| `common_loading` | 로딩 중... | Loading… |
| `common_alarm_default_title` | 알람 | Alarm |

### 5.18 InfoPlist
| Key | ko | en |
|-----|----|----|
| `NSAlarmKitUsageDescription` | 알람을 설정하기 위해 권한이 필요합니다. | This app needs permission to schedule alarms. |

---

## 6. 동적/플루럴/포맷 처리

### 6.1 권장 패턴

**SwiftUI Text:**
```swift
Text("alarm_list_title")           // 자동으로 LocalizedStringKey 추론
Text("alarm_list_next_alarm_a11y \(displayString)")  // String interpolation OK
```

**ViewModel/Service에서 String 필요:**
```swift
String(localized: "toast_alarm_saved")
String(localized: "settings_theme_changed_format \(themeName)")  // String.LocalizationValue 보간
```

**Format specifier가 들어가는 옛 스타일이 필요할 때:**
```swift
String(format: NSLocalizedString("notif_background_reminder_format", comment: ""), alarm.timeString)
```
(가능하면 `String(localized: "...")` + 보간으로 통일.)

**accessibilityLabel 동적:**
```swift
.accessibilityLabel(Text("alarm_row_time_a11y \(alarm.timeString)"))
```

**LocalizedStringResource (AppIntents):**
```swift
static var title: LocalizedStringResource = "intent_stop_title"
static var description = IntentDescription("intent_stop_description")
@Parameter(title: "intent_alarmid_param") var alarmID: String
```

### 6.2 시간 표시

`KoreanDateFormatters.timeDisplayString(hour:minute:)`을 **로케일 자동 인지형**으로 교체.

```swift
static func timeDisplayString(hour: Int, minute: Int) -> String {
    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    let date = Calendar.current.date(from: components) ?? Date()
    return date.formatted(date: .omitted, time: .shortened)  // 로케일 자동
    // ko_KR → "오전 7:00"
    // en_US → "7:00 AM"
}
```

기존 enum 이름은 유지(호출처 변경 최소화)하되, 본문만 로케일 인지형으로 교체. 또는 신규 `LocalizedDateFormatters`로 rename + typealias.

### 6.3 상대 날짜 (오늘/내일/M월 d일)

```swift
static func relativeDateString(for date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        return String(localized: "live_activity_relative_today")
    }
    if calendar.isDateInTomorrow(date) {
        return String(localized: "live_activity_relative_tomorrow")
    }
    return date.formatted(.dateTime.month().day().weekday(.abbreviated))  // 로케일 자동
}
```

### 6.4 요일 약어

`Weekday.shortName`을 다음과 같이 변경:
```swift
var shortName: String {
    switch self {
    case .sunday:    return String(localized: "weekday_short_sun")
    case .monday:    return String(localized: "weekday_short_mon")
    case .tuesday:   return String(localized: "weekday_short_tue")
    case .wednesday: return String(localized: "weekday_short_wed")
    case .thursday:  return String(localized: "weekday_short_thu")
    case .friday:    return String(localized: "weekday_short_fri")
    case .saturday:  return String(localized: "weekday_short_sat")
    }
}
```

### 6.5 다음 알람 표시 문자열

`AlarmStore.nextAlarmDisplayString` 리팩토링:
```swift
var nextAlarmDisplayString: String? {
    guard let alarm = nextAlarm, let date = alarm.nextTriggerDate() else { return nil }
    let timeStr = date.formatted(date: .omitted, time: .shortened)
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        return String(localized: "next_alarm_format_today \(timeStr)")
    }
    if calendar.isDateInTomorrow(date) {
        return String(localized: "next_alarm_format_tomorrow \(timeStr)")
    }
    let dateStr = date.formatted(.dateTime.month().day().weekday(.abbreviated))
    return String(localized: "next_alarm_format_date \(dateStr) \(timeStr)")
}
```

### 6.6 플루럴

이번 라운드에서 사용자에게 노출되는 플루럴 표현은 거의 없음 ("5분"/"5 min" 같은 고정값). 별도 plural variation은 만들지 않는다. 추후 "%lld 분 후"(한국어)/"%lld minutes"(영어)가 필요해지면 카탈로그에 plural variation을 추가.

---

## 7. UI 잘림 위험 식별 + 수정 방침

### 7.1 위험 케이스 매트릭스

| 위치 | ko 문자열 | en 문자열 | 길이비 | 위험 |
|------|----------|----------|-------|------|
| 탭바 라벨 | "알람" (2자) | "Alarms" (6자) | 1:3 | **높음** — TabView가 잘림/줄임 처리 |
| 탭바 라벨 | "주간" / "주간 알람" | "Weekly" | 1:1.5 | 중 |
| 탭바 라벨 | "설정" | "Settings" | 1:2 | 중 |
| 알람 모드 토글 | "앱이 꺼진 상태에서도 알람 받기" (16자) | "Ring even when app is closed" (28자) | 1:1.7 | **높음** — 한 줄 안 들어감 |
| 알람 모드 footer | "앱이 꺼진 상태에서도 알람이 울립니다. (iOS 26 이상 필요)" | "Rings even when the app is closed. (Requires iOS 26 or later)" | 비슷 | 중 (footer는 wrap 자동) |
| iOS26 안내 토스트 | "이 기능은 iOS 26 이상에서만 사용할 수 있습니다." (24자) | "This feature requires iOS 26 or later." (38자) | 1:1.6 | **높음** — 토스트 한 줄 안 됨 |
| 권한 행 우측 상태 | "허용됨" (3자) | "Allowed" (7자) | 1:2.3 | 중 — 옆 버튼과 겹칠 위험 |
| 권한 상태 | "iOS 26 이상 필요" (10자) | "Requires iOS 26+" (16자) | 1:1.6 | 중 |
| 알람 행 라벨 | "다음 1회 건너뜀" (8자) | "Skipping next" (13자) | 1:1.6 | 중 — 캡슐 chip 폭 |
| 알람 행 라벨 | "스누즈 중" (4자) | "Snoozed" (7자) | 1:1.7 | 중 |
| 정지 버튼 (원형) | "정지" (2자) | "Stop" (4자) | 1:2 | 낮 — 120pt 원형이라 충분 |
| 스누즈 버튼 | "스누즈 (5분)" (7자) | "Snooze (5 min)" (14자) | 1:2 | 중 |
| Action Sheet 타이틀 | "이 주간 알람을 어떻게 처리할까요?" (17자) | "What would you like to do with this alarm?" (42자) | 1:2.5 | **높음** — sheet 타이틀 잘림 |
| 빈 상태 안내 | "+ 버튼을 눌러 첫 알람을 추가하세요" (16자) | "Tap + to add your first alarm" (29자) | 1:1.8 | 낮 — multiline OK |
| 알림 권한 권유 (에러) | "알람을 사용하려면 알림 권한이 필요합니다…" (35자) | "Notification permission is required. Please enable it in Settings." (66자) | 1:1.9 | 중 — alert에 출력되므로 wrap |
| settings 행 — "잠금화면 위젯 권한" | (10자) | "Lock Screen Widget" (18자) — 같은 키 사용 시 행이 좁음 | 1:1.8 | 중 |
| 권한 행 — "Open Settings" 버튼 | "설정 열기" (4자) | "Open Settings" (13자) | 1:3 | 중 — 버튼 폭 부족 |
| 토글 라벨 | "조용한 알람" (5자) | "Silent Alarm" (12자) | 1:2.4 | 낮 |

### 7.2 수정 방침 (각 위치별)

#### A. 탭바
- 영어 라벨도 짧게 유지: "Alarms" / "Weekly" / "Settings". (한국어는 "알람" / "주간" / "설정".)
- 라벨 폰트 자동 줄임 의존 — `.tabItem` 자체가 SF에서 처리. 추가 설정 불필요.
- 한국어 "주간 알람"을 그대로 두면 영어 "Weekly Alarms"가 되어 더 길어지므로 **한국어도 "주간"으로 단축** 권장.

#### B. AlarmDetailView — alarmMode 토글 행
- `PToggle`은 라벨이 좌측, 토글이 우측이라 영어 28자가 한 줄에 안 들어갈 수 있음.
- **수정**: PToggle 라벨에 `.lineLimit(2)` + `.minimumScaleFactor(0.85)` 또는 `.fixedSize(horizontal: false, vertical: true)` 적용.
- 만약 `PToggle`이 디자인시스템 컴포넌트라 라벨 modifier 적용이 어려우면, 호출 측에서:
  ```swift
  HStack {
      Text("alarm_detail_alarmkit_toggle_label")
          .font(.body)
          .foregroundStyle(Color.pTextPrimary)
          .lineLimit(2)
          .minimumScaleFactor(0.9)
          .frame(maxWidth: .infinity, alignment: .leading)
      Toggle("", isOn: ...).labelsHidden()
  }
  ```
  형태의 fallback 사용. **단 디자인시스템 토큰(`Color.p*`/`Font.*` 토큰) 사용 원칙은 유지**.
- 우선 `PToggle("alarm_detail_alarmkit_toggle_label", ...)` 그대로 두고 시뮬레이터에서 영어 로케일로 확인 후 잘리면 위 fallback 적용.

#### C. iOS26 안내 토스트
- `PersonalColorDesignSystem`의 토스트는 일반적으로 1~2줄 wrap이 자동. 영어 38자도 2줄로 잘 들어감.
- 토스트 타입 `.warning`이 좌측 아이콘을 차지하므로 우측 텍스트 영역이 좁다 — `lineLimit` 제거 확인.

#### D. 권한 행 (Settings)
- 행 구조: `Text(label) | Spacer() | Text(status) | Button("Open Settings")`.
- 영어 "Not allowed" + "Open Settings" + "Lock Screen Widget" → 한 줄 over. `.layoutPriority(1)` 와 `.lineLimit(1)` + `.truncationMode(.tail)` 조합.
- **수정**: 행을 `VStack` 두 줄로 변경 (긴 라벨 → 별도 줄로):
  ```swift
  VStack(alignment: .leading, spacing: 4) {
      Text("settings_lock_widget_permission")
          .font(.body)
          .foregroundStyle(Color.pTextPrimary)
      HStack {
          Text(viewModel.lockScreenWidgetStatus)
              .font(.caption)
              .foregroundStyle(Color.pTextSecondary)
          Spacer()
          Button("settings_open_app_settings") { ... }
      }
  }
  ```
  단 디자인 일관성 유지를 위해 한국어에서도 같은 레이아웃 사용 OK.

#### E. 알람 행 (AlarmRowView) chip
- "Skipping next", "Snoozed" 같은 캡슐 chip은 자동으로 텍스트만큼 넓어지므로 잘림 없음.
- 단 chip이 옆에 여러 개 붙어 있을 때 가로 over flow 가능. → `HStack`을 `WrapHStack` 또는 `LazyHStack` 로 변경하거나 `.lineLimit(1)` + `.minimumScaleFactor(0.85)` 적용.
- 이번 라운드는 chip 자체 잘림은 위험 낮으니 폰트 축소만 적용, 레이아웃 변경은 보류.

#### F. AlarmRingingView 버튼
- 정지 버튼 — 120×120 원형이므로 "Stop" 4자도 충분.
- 스누즈 버튼 — 기존 `.frame(minWidth: 160)` → "Snooze (5 min)" 14자도 OK. 안정상 `minWidth: 200` 으로 상향. 시각적 패딩만 미세 조정.

#### G. Action Sheet 타이틀
- "What would you like to do with this alarm?" 42자 — `pActionSheet`은 보통 wrap 자동.
- 디자인시스템 컴포넌트 동작 확인 → 잘리면 `dialogTitle: Text("...").lineLimit(3)` 형태로 보강 (만약 API가 지원할 때).

#### H. 시간 picker / "%d시" "%02d분"
- 한국어는 "7시" / "00분"처럼 단위가 붙고, 영어는 그냥 "7" / "00" 만으로도 충분.
- 영어 키는 단위 미포함 ("`%d`" / "`%02d`"). 픽셀 폭 동일.

### 7.3 화면별 점검 체크리스트

#### AlarmListView
- [ ] 헤더 "Alarms"가 + 버튼과 겹치지 않는지
- [ ] "Next alarm" 배너의 타이틀+서브타이틀이 한 카드에 들어가는지
- [ ] empty state 두 줄(title/subtitle)이 중앙 정렬 유지되는지

#### AlarmDetailView
- [ ] 탭바 placement title "Edit Alarm" / "New Alarm" 잘림 X
- [ ] alarmMode 토글 라벨 한 줄 OK (안 되면 2줄 wrap)
- [ ] silent 토글 라벨 OK
- [ ] footer 텍스트 multi-line wrap 정상
- [ ] 시간 picker — 영어 "AM/PM" 2자 + 시 + 분 폭 OK
- [ ] 저장 버튼 / 취소 버튼 폭 OK
- [ ] 알림창 "Save Failed" + "OK" OK

#### SettingsView
- [ ] 헤더 "Settings"
- [ ] 권한 섹션 — "Notifications" + "Allowed" + "Open Settings" 한 줄 OK
- [ ] AlarmKit 권한 — "AlarmKit" + 상태 + 버튼
- [ ] 잠금화면 위젯 권한 — 영어 라벨 잘림 시 VStack 분리
- [ ] 피드백/문의 행
- [ ] 버전 표시 우측 정렬

#### AlarmRingingView
- [ ] 시간 표시 자동 폰트 (largeTitle) — 영어 "10:30 AM" 폭 OK
- [ ] 알람 제목 lineLimit(2) OK
- [ ] 정지 버튼 (원형) OK
- [ ] 스누즈 버튼 (캡슐) — minWidth 200 으로 상향

#### WeeklyAlarmView
- [ ] 헤더 "Weekly Alarms"
- [ ] 요일 탭 7개 — 영어 "Sun/Mon/Tue/Wed/Thu/Fri/Sat" 3글자 OK
- [ ] empty state

#### AlarmRowView
- [ ] 시간 + 제목 + repeat description + chip(들)
- [ ] chip 가로 wrap 확인

#### AppIntents (잠금화면)
- [ ] AlarmKit 잠금화면 알림에 표시되는 "Stop" / "Snooze" 버튼은 `LocalizedStringResource` 키 → 시스템 로케일로 자동 표시

---

## 8. 구현 단계

### 단계 1: String Catalog 생성

위치: `BetterAlarm/Resources/Localizable.xcstrings`

```
Xcode에서:
1. New File → String Catalog → "Localizable" 생성
2. Languages 패널에서 한국어(Korean) 추가
3. 본 SPEC §5 의 모든 키를 입력 (ko, en 양쪽)
```

PROJECT_CONTEXT.md의 `Resources` 폴더는 `PBXFileSystemSynchronizedRootGroup`으로 자동 인덱싱되므로 별도 xcodeproj 수정 불필요.

### 단계 2: Info.plist 수정

```xml
<key>CFBundleDevelopmentRegion</key>
<string>en</string>
<key>CFBundleLocalizations</key>
<array>
    <string>en</string>
    <string>ko</string>
</array>
```

기존 한국어 string 값(`NSAlarmKitUsageDescription`)은 `InfoPlist.xcstrings`(또는 `InfoPlist.strings`)로 분리. Info.plist에서는 영어 default 두기.

### 단계 3: 모든 .swift 파일 교체 (Edit)

표 4의 모든 파일을 다음 패턴으로 수정:
- `Text("한국어")` → `Text("key")`
- `Button("한국어")` → `Button("key")`
- `String(...) where 한국어 hardcoded` → `String(localized: "key")`
- `LocalizedStringResource(stringLiteral: "한국어")` → `LocalizedStringResource("key")`
- `IntentDescription("한국어")` → `IntentDescription("key")`
- `accessibilityLabel("한국어")` → `accessibilityLabel(Text("key"))`

### 단계 4: 동적 포맷 메서드 교체

- `KoreanDateFormatters.timeDisplayString(hour:minute:)` 본문을 `Date.formatted(date: .omitted, time: .shortened)` 사용으로 변경 (이름 유지로 호출처 영향 없음).
- `KoreanDateFormatters.relativeDateString(for:)` 도 동일.
- `Weekday.shortName` 을 `String(localized:)` 사용으로 변경.
- `AlarmStore.nextAlarmDisplayString` 리팩토링 (위 6.5).
- `Alarm.repeatDescriptionWithoutSkip` 의 "1회"/"매일"/"주말"/"주중" → `String(localized:)`.
- `Alarm.displayTitle`의 "알람" 폴백 → `String(localized: "common_alarm_default_title")`.
- `AlarmDetailViewModel.ScheduleType`에 `displayName` computed property 추가, View에서는 `displayName` 사용.

### 단계 5: UI 잘림 점검 보강

위 7.2 의 수정 방침 적용. 시뮬레이터에서 영어 로케일로 빌드/실행하여 시각 확인.

### 단계 6: 빌드/시뮬레이터 검증

```bash
# 한국어 빌드 (기본)
xcodebuild -project BetterAlarm.xcodeproj -scheme BetterAlarm \
  -destination 'id=1CE14D49-DEB7-4BED-AFEE-AF349E430DB3' build

# 영어 시뮬레이터 실행 (-AppleLanguages 옵션):
xcrun simctl boot 1CE14D49-DEB7-4BED-AFEE-AF349E430DB3
xcrun simctl spawn 1CE14D49-DEB7-4BED-AFEE-AF349E430DB3 \
  launchctl setenv AppleLanguages "(en)"
```

---

## 9. 비대상 / 건드리지 않을 것

| 영역 | 사유 |
|------|------|
| `BetterAlarmWidget/` 폴더 (별도 타깃) | 본 SPEC 범위 밖. 위젯이 표시할 동적 텍스트는 메인 앱이 ContentState로 주입. |
| `Utils/Logger.swift` | 개발자 콘솔용 로그. i18n 대상 아님. |
| `Services/AudioService.swift` 의 `AppLogger.error("default_alarm 사운드…")` | 개발자 로그. |
| `Services/VolumeService.swift` 의 모든 로그 | 개발자 로그. |
| `Services/AppThemeManager.swift` 의 모든 로그 | 개발자 로그. |
| `Assets.xcassets` | 색상/이미지 자산은 변경 없음. |
| `Models/Alarm.swift` 의 `soundName == "default"` 비교 | "default"는 영구 식별자. UI 표시는 `alarm_detail_sound_default` 키로 별도 처리. |
| `Models/AlarmMode.swift` rawValue (`.alarmKit`, `.local`) | UserDefaults Codable 영구 식별자. 변경 불가. UI는 `displayName` 키로 처리. |
| `Weekday` rawValue (1~7) | Calendar weekday 컴포넌트 직접 매핑. 변경 불가. |
| `AlarmSchedule` Codable 영구 식별자 (`once/weekly/specificDate`) | 변경 불가. |
| 햅틱/사운드 트리거 코드 | UI 텍스트 아님. |
| `BetterAlarm/BetterAlarm.entitlements` | 변경 없음. |
| `Extensions/UIColor+Theme.swift`, `Extensions/UIView+Glass.swift` | 사용자 표시 문자열 없음. |

---

## 10. 위험 / 결정 사항

### 10.1 결정 사항

1. **String Catalog 채택** — Xcode 자동 추출, 단일 파일 관리, iOS 17+ 호환. iOS 17 이상에서 컴파일된 `.lproj/Localizable.strings`로 자동 변환되므로 런타임 호환 문제 없음.
2. **`AlarmDetailViewModel.ScheduleType.rawValue` 한국어 그대로 유지 가능** — UserDefaults에 저장된 알람의 스케줄 식별자가 아니므로 변경해도 무방하나, 안전하게 displayName 별도 분리 권장.
3. **Weekday/AlarmMode/AlarmSchedule rawValue는 영구 식별자** — Codable 호환성 위해 변경 금지. `displayName`/`shortName` computed로 i18n 처리.
4. **위젯은 손대지 않는다** — 위젯에 표시되는 모든 동적 문자열은 `LiveActivityManager`가 메인 앱에서 미리 포맷하여 ContentState에 넣는다. 위젯은 받은 문자열을 그대로 그린다.
5. **로그(AppLogger)는 i18n 대상 아님** — 개발자용. 한국어 로그 그대로 둠. (필요시 추후 영문화는 별도 라운드로.)
6. **AlarmKit `AlarmButton(text:)` 처리** — 시스템 잠금화면 표시이므로 `String(localized: "alarmkit_button_stop")` 형태로 디바이스 로케일 기준 문자열을 만들어 전달. 이렇게 하면 시스템 자체 i18n과 무관하게 정확한 번역 표시.

### 10.2 위험 요소

| 위험 | 대응 |
|------|------|
| 한국어 영구 식별자(rawValue)를 영어로 바꾸려는 유혹 | **금지** — 기존 사용자 데이터(`savedAlarms_v2`) 호환 깨짐. |
| String Catalog 키를 빌드 시 못 찾아 빈 문자열로 fallback | 키는 항상 카탈로그에 존재해야 함. Xcode가 누락 키를 노란색 warning으로 표시 → CI에서 catch. |
| Live Activity ContentState가 두 언어 동시 표시 안 됨 | 메인 앱이 현재 시스템 로케일 기준으로 만든 단일 문자열만 보냄 — 사용자가 시스템 언어 바꾸면 다음 update에서 반영. |
| AlarmKit이 iOS 26+에서 시스템 잠금화면에 노출하는 버튼 텍스트 | `AlarmButton(text: ...)`는 그냥 String이라 i18n 비대상. `String(localized: "alarmkit_button_stop")` 으로 직접 현지화하여 전달 → 디바이스 로케일 기준으로 표시. |
| `LocalizedStringResource(stringLiteral: ...)`는 동적이라 카탈로그 키가 인식 안 될 수 있음 | `LocalizedStringResource("intent_stop_title")` (key 형태 직접) 사용 권장. |
| 한국어 폰트와 영어 폰트의 line-height 차이 | SwiftUI가 자동 처리. `.dynamicTypeSize(...DynamicTypeSize.xxxLarge)` 한도는 그대로 유지. |
| 토스트의 type(.warning/.success)가 다국어 라벨에서 길어질 때 좌측 아이콘과 충돌 | type별 padding을 충분히 두고, 토스트 메시지에 `.lineLimit(nil)` (자동 wrap) 적용. |
| 라이브 액티비티가 위젯 타깃에 정의된 ContentState 구조체와 메인앱 측 정의가 어긋날 위험 | 본 SPEC은 ContentState **구조체 변경 없음**. 동일 필드(`nextAlarmTime`, `nextAlarmDate`, `alarmTitle`, `isSkipped`, `isEmpty`, `themeName`)에 들어가는 String 값만 메인앱 측에서 로케일 기반으로 만든다. |
| Info.plist 의 `NSAlarmKitUsageDescription` (한국어) | InfoPlist.strings/InfoPlist.xcstrings로 분리 — Xcode 16에서는 `InfoPlist.xcstrings` 자동 인식. |
| `AlarmDetailViewModel.ScheduleType.rawValue`를 segmented picker label로 사용 중 | rawValue는 그대로 두고 별도 `displayName` computed property를 추가하여 picker label로 사용. View 측 `Text(type.rawValue)` → `Text(type.displayName)`. |

---

## 마무리

> "Planner 완료: i18n SPEC v1 — 키 130개, 수정 대상 .swift 파일 24개, UI 잘림 점검 항목 27개"
