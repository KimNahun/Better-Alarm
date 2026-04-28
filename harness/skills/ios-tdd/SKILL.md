---
name: ios-tdd
description: iOS TDD (Test-Driven Development) 워크플로우. 테스트 먼저 작성 -> 구현 -> 리팩토링.
origin: harness
---

# iOS TDD Workflow

## When to Use

- 새로운 Service 또는 ViewModel 구현 시
- 복잡한 비즈니스 로직 구현 시
- 버그 수정 시 (회귀 테스트 먼저 작성)

## When NOT to Use

- 순수 UI 작업 (View만 변경)
- 설정/구성 변경
- 문서 작업

## How It Works

### Red -> Green -> Refactor

```
1. RED: 실패하는 테스트 먼저 작성
   -> xcodebuild test -> FAIL 확인

2. GREEN: 테스트를 통과하는 최소 구현
   -> xcodebuild test -> PASS 확인

3. REFACTOR: 중복 제거, 네이밍 개선
   -> xcodebuild test -> 여전히 PASS 확인
```

### 테스트 작성 패턴

```swift
import Testing

@Test("ViewModel loads items from service")
func viewModelLoadsItems() async {
    // Given
    let mockService = MockItemService(items: [.fixture])
    let vm = await ItemListViewModel(service: mockService)

    // When
    await vm.loadItems()

    // Then
    await #expect(vm.items.count == 1)
    await #expect(vm.isLoading == false)
}

@Test("ViewModel handles service error")
func viewModelHandlesError() async {
    // Given
    let mockService = MockItemService(error: .networkError)
    let vm = await ItemListViewModel(service: mockService)

    // When
    await vm.loadItems()

    // Then
    await #expect(vm.items.isEmpty)
    await #expect(vm.errorMessage != nil)
}
```

### Mock 패턴

```swift
struct MockItemService: ItemServiceProtocol {
    var items: [Item] = []
    var error: ItemError?

    func fetchItems() async throws -> [Item] {
        if let error { throw error }
        return items
    }
}
```

## Examples

```
/tdd AlarmStore의 알람 생성 기능
/tdd UserService의 로그인 로직
```
