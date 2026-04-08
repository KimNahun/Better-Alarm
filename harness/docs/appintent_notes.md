# AppIntents API 레퍼런스 (NotebookLM MCP 수집)

## LiveActivityIntent

Live Activity 내부 버튼/토글과 상호작용하기 위한 프로토콜.
앱이 포그라운드가 아니어도 백그라운드에서 perform()이 실행됨.

```swift
import AppIntents
import AlarmKit

struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "알람 정지"
    static var description = IntentDescription("알람을 정지합니다")

    @Parameter(title: "알람 ID")
    var alarmID: String

    init() { self.alarmID = "" }
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
        }
        return .result()
    }
}
```

## SnoozeAlarmIntent

```swift
struct SnoozeAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "스누즈"
    static var description = IntentDescription("알람을 스누즈합니다")
    static var openAppWhenRun = false

    @Parameter(title: "알람 ID")
    var alarmID: String

    init() { self.alarmID = "" }
    init(alarmID: String) { self.alarmID = alarmID }

    func perform() async throws -> some IntentResult {
        // 현재 알람 중지 후 5분 뒤 새 알람 등록
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
        }
        // 새 스누즈 알람 스케줄...
        return .result()
    }
}
```

## SwiftUI Live Activity 뷰에서 버튼 사용

```swift
// Widget Extension의 SwiftUI 뷰 내부
Button(intent: StopAlarmIntent(alarmID: context.attributes.alarmID)) {
    Text("정지")
}
Button(intent: SnoozeAlarmIntent(alarmID: context.attributes.alarmID)) {
    Text("스누즈")
}
```

## 핵심 규칙
- `@Parameter`: 인텐트 실행 시 외부에서 전달받을 입력값 정의
- `perform()`: 실제 동작 수행하는 async throws 메서드
- `LiveActivityIntent`는 앱 없이 잠금화면에서 바로 실행 가능
- AlarmKit API 호출은 Service 레이어에서만 — Intent에서 직접 호출 최소화
