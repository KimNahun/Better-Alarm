---
paths:
  - "**/*.swift"
---
# Swift 6 Concurrency Rules

Swift 6 엄격 동시성 모드를 반드시 준수한다. 컴파일러 경고 0개가 목표.

## Layer별 동시성 모델

### View
```swift
// @MainActor (struct는 SwiftUI에서 자동 추론)
struct FeatureView: View {
    @State private var viewModel = FeatureViewModel()
    var body: some View { ... }
}
```

### ViewModel
```swift
// 반드시 @MainActor + @Observable
@MainActor
@Observable
final class FeatureViewModel {
    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let service: ItemServiceProtocol

    init(service: ItemServiceProtocol = ItemService()) {
        self.service = service
    }

    func loadItems() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await service.fetchItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### Service
```swift
// 반드시 actor + protocol
protocol ItemServiceProtocol: Sendable {
    func fetchItems() async throws -> [Item]
}

actor ItemService: ItemServiceProtocol {
    func fetchItems() async throws -> [Item] { ... }
}
```

### Model
```swift
// 반드시 struct + Sendable
struct Item: Identifiable, Sendable, Codable {
    let id: UUID
    var title: String
}
```

## 금지 사항

```swift
// 1. DispatchQueue 사용 금지 -- @MainActor 사용
DispatchQueue.main.async { }

// 2. @Published + ObservableObject 금지 -- @Observable 사용
class VM: ObservableObject { @Published var x = 0 }

// 3. Task { @MainActor in } 중복 래핑 금지
Task { @MainActor in self.value = newValue }

// 4. nonisolated 남용 금지
nonisolated func something() { }

// 5. Non-Sendable 타입을 actor 경계 넘어 전달 금지
// 6. ViewModel에서 View import 금지
// 7. View에서 직접 Service 접근 금지
```

## Structured Concurrency 선호

```swift
// async let (병렬 실행)
async let users = userService.fetchAll()
async let posts = postService.fetchAll()
let (userList, postList) = try await (users, posts)

// TaskGroup (동적 병렬)
await withTaskGroup(of: Item.self) { group in
    for id in ids {
        group.addTask { await fetchItem(id) }
    }
    ...
}
```

## Actor Pattern

공유 가변 상태는 lock/DispatchQueue 대신 actor 사용:

```swift
actor Cache<Key: Hashable & Sendable, Value: Sendable> {
    private var storage: [Key: Value] = [:]
    func get(_ key: Key) -> Value? { storage[key] }
    func set(_ key: Key, value: Value) { storage[key] = value }
}
```
