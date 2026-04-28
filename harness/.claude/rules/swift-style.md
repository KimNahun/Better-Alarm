---
paths:
  - "**/*.swift"
  - "**/Package.swift"
---
# Swift Coding Style

## Formatting

- **SwiftLint** 적용, **SwiftFormat** 권장
- `swift-format` (Xcode 16+ 내장) 대안으로 사용 가능

## Immutability

- `let` 우선 -- 컴파일러가 요구할 때만 `var`
- `struct` 기본 -- `class`는 identity/reference semantics 필요 시에만
- `private(set)` 으로 외부 변이 차단

## Naming

Apple API Design Guidelines 준수:
- 사용 지점의 명확성 -- 불필요한 단어 생략
- 역할 기반 이름 (타입 기반 X)
- `static let` 으로 상수 정의 (전역 상수 X)

## File Structure

```
[AppName]/
├── App/              # @main, DI 루트
├── Views/            # SwiftUI View (Feature별 하위 폴더)
│   └── [Feature]/
├── ViewModels/       # @MainActor @Observable (Feature별 하위 폴더)
│   └── [Feature]/
├── Models/           # struct Sendable
├── Services/         # actor, protocol 기반
├── Intents/          # AppIntent (해당 시)
├── Widgets/          # WidgetKit (해당 시)
├── Delegates/        # AppDelegate 등
└── Shared/           # 유틸리티, 확장
```

## File Naming

- PascalCase: `AlarmListView.swift`, `AlarmStore.swift`
- Feature 단위 그룹핑: `Views/AlarmList/AlarmListView.swift`
- View: `[Feature]View.swift`
- ViewModel: `[Feature]ViewModel.swift`
- Service: `[Feature]Service.swift`
- Model: `[ModelName].swift`

## Access Control

- 모든 public/internal 프로퍼티에 접근 제어자 명시
- `private(set)` 으로 외부 변이 차단
- 에러 타입은 `enum [Domain]Error: Error` 로 정의

## Error Handling

Swift 6+ typed throws 사용:

```swift
func load(id: String) throws(LoadError) -> Item {
    guard let data = try? read(from: path) else {
        throw .fileNotFound(id)
    }
    return try decode(data)
}
```
