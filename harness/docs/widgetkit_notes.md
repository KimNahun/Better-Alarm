# ActivityKit (Live Activity) API 레퍼런스 (NotebookLM MCP 수집)

## 개요
ActivityKit을 사용해 앱의 실시간 업데이트를 잠금화면, 다이나믹 아일랜드에 표시.
위젯과 달리 타임라인 기반이 아닌, 앱/서버에서 직접 push 방식으로 업데이트.

## ActivityAttributes 구조

정적 데이터 + 동적 데이터(ContentState)를 정의하는 프로토콜.

```swift
import ActivityKit

struct BetterAlarmAttributes: ActivityAttributes {
    // 동적 데이터 (시간에 따라 변함)
    public struct ContentState: Codable, Hashable {
        var nextAlarmTitle: String
        var nextAlarmDate: Date
        var isAlarming: Bool
    }

    // 정적 데이터 (생성 시 고정)
    var alarmID: String
}
```

## Live Activity 시작

앱이 포그라운드일 때만 시작 가능.

```swift
func startActivity(with alarm: Alarm) {
    let attributes = BetterAlarmAttributes(alarmID: alarm.id.uuidString)
    let initialState = BetterAlarmAttributes.ContentState(
        nextAlarmTitle: alarm.displayTitle,
        nextAlarmDate: alarm.nextTriggerDate() ?? Date(),
        isAlarming: false
    )
    let content = ActivityContent(state: initialState, staleDate: nil)

    do {
        let activity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
        // activity.id 저장
    } catch {
        // 에러 처리
    }
}
```

## Live Activity 업데이트

```swift
func updateActivity(with alarm: Alarm) async {
    guard let activity = Activity<BetterAlarmAttributes>.activities.first else { return }

    let updatedState = BetterAlarmAttributes.ContentState(
        nextAlarmTitle: alarm.displayTitle,
        nextAlarmDate: alarm.nextTriggerDate() ?? Date(),
        isAlarming: false
    )
    let content = ActivityContent(state: updatedState, staleDate: nil)
    await activity.update(content)
}
```

## Live Activity 종료

```swift
func endActivity() async {
    for activity in Activity<BetterAlarmAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
    }
}
```

## dismissalPolicy 옵션
- `.default` — 사용자가 직접 닫거나 최대 4시간 후 시스템이 제거
- `.immediate` — 즉시 잠금화면에서 사라짐
- `.after(Date)` — 지정 시각 이후 제거

## 핵심 규칙
- Activity 시작은 앱 포그라운드에서만 가능
- ContentState는 Codable + Hashable 필수
- Widget Extension 타겟에 SwiftUI 뷰 구현 필요
- Live Activity 뷰 내 버튼은 AppIntents와 연동
