---
paths:
  - "**/*.swift"
  - "**/*Tests*/**"
---
# iOS Testing Rules

## Framework

Swift Testing (`import Testing`) 우선 사용. `@Test`와 `#expect`:

```swift
@Test("User creation validates email")
func userCreationValidatesEmail() throws {
    #expect(throws: ValidationError.invalidEmail) {
        try User(email: "not-an-email")
    }
}
```

기존 XCTest 코드가 있으면 유지하되, 신규 테스트는 Swift Testing으로 작성.

## Test Isolation

- 각 테스트는 독립 인스턴스 -- `init`에서 setup, `deinit`에서 teardown
- 테스트 간 공유 가변 상태 금지

## MVVM 테스트 전략

### ViewModel 테스트
```swift
@Test("ViewModel loads items from service")
func viewModelLoadsItems() async {
    let mockService = MockItemService(items: [.fixture])
    let vm = await ItemListViewModel(service: mockService)
    await vm.loadItems()
    await #expect(vm.items.count == 1)
}
```

### Service 테스트
```swift
@Test("Service fetches and decodes items")
func serviceFetchesItems() async throws {
    let service = ItemService(urlSession: mockSession)
    let items = try await service.fetchItems()
    #expect(items.count > 0)
}
```

### View 테스트
- UI 테스트는 XCUITest로 E2E 검증
- 스냅샷 테스트는 선택사항

## Protocol 기반 DI

테스트 가능성을 위해 Service는 Protocol로 주입:

```swift
protocol ItemServiceProtocol: Sendable {
    func fetchItems() async throws -> [Item]
}

// 프로덕션
actor ItemService: ItemServiceProtocol { ... }

// 테스트
struct MockItemService: ItemServiceProtocol {
    var items: [Item] = []
    func fetchItems() async throws -> [Item] { items }
}
```

## Parameterized Tests

```swift
@Test("Validates formats", arguments: ["json", "xml", "csv"])
func validatesFormat(format: String) throws {
    let parser = try Parser(format: format)
    #expect(parser.isValid)
}
```

## Coverage

```bash
# xcodebuild
xcodebuild test -scheme [Scheme] -destination [Dest] -enableCodeCoverage YES

# SPM
swift test --enable-code-coverage
```
