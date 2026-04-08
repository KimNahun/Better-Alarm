# AlarmKit API 레퍼런스 (NotebookLM MCP 수집)

## 주요 구성 요소

### AlarmManager
알람 스케줄링, 스누즈, 취소 등 핵심 기능을 담당하는 객체.
- `AlarmManager.shared` — 싱글톤 인스턴스
- `requestAuthorization()` — 비동기 권한 요청 (async throws)
- `schedule(id:configuration:)` — 알람 스케줄 등록
- `stop(id:)` — 알람 중지
- `alarms` — 현재 등록된 알람 목록
- `alarmUpdates` — AsyncSequence 기반 상태 변화 스트림

### AlarmAttributes
알람 UI를 구성하는 필수 정보를 담는 객체.
```swift
AlarmAttributes(
    presentation: AlarmPresentation(alert: alert),
    tintColor: .blue
)
```

### AlarmSchedule
알람 발생 시점을 정의하는 타입.
- `.fixed(Date)` — 고정 시각 (1회성, 특정 날짜)
- `.relative(Relative)` — 상대적 반복 (주간 반복 등)

```swift
// Fixed 예시
let schedule = AlarmSchedule.fixed(triggerDate)

// Relative 예시 (주간 반복)
let time = AlarmSchedule.Relative.Time(hour: 7, minute: 30)
let recurrence = AlarmSchedule.Relative.Recurrence.weekly([.monday, .wednesday])
let relativeSchedule = AlarmSchedule.Relative(time: time, repeats: recurrence)
let schedule = AlarmSchedule.relative(relativeSchedule)
```

### AlarmButton
알람 UI 버튼 외관 정의.
```swift
AlarmButton(
    text: "정지",
    textColor: .white,
    systemImageName: "stop.fill"
)
```

### AlarmPresentation
알람 UI에 표시할 콘텐츠 정의.
```swift
let alert = AlarmPresentation.Alert(
    title: LocalizedStringResource(stringLiteral: "알람 제목"),
    stopButton: AlarmButton(text: "정지", textColor: .white, systemImageName: "stop.fill"),
    secondaryButton: AlarmButton(text: "스누즈", textColor: .white, systemImageName: "moon.zzz.fill"),
    secondaryButtonBehavior: .custom
)
let presentation = AlarmPresentation(alert: alert)
```

### AlarmManager.AlarmConfiguration
알람 스케줄 등록 시 사용하는 설정 타입.
```swift
typealias Config = AlarmManager.AlarmConfiguration<MyMetadata>
let config = Config(
    schedule: schedule,
    attributes: attributes,
    stopIntent: StopAlarmIntent(alarmID: id.uuidString),
    secondaryIntent: SnoozeAlarmIntent(alarmID: id.uuidString)
)
_ = try await manager.schedule(id: id, configuration: config)
```

### AlarmMetadata
커스텀 메타데이터 프로토콜. nonisolated struct로 구현.
```swift
nonisolated struct MyAlarmMetadata: AlarmMetadata {}
```

### alarmUpdates 스트림
AsyncSequence로 알람 상태 변화 실시간 수신.
```swift
for await alarms in manager.alarmUpdates {
    for alarm in alarms where alarm.state == .alerting {
        // 알람이 울리는 상태
    }
    if alarms.isEmpty {
        // 알람 종료
    }
}
```

## 가용 iOS 버전
- **AlarmKit은 iOS 26.0 이상에서만 사용 가능**
- 모든 AlarmKit 코드에 `@available(iOS 26.0, *)` 가드 필수
