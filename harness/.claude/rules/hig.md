---
paths:
  - "**/*.swift"
  - "**/Views/**"
---
# Human Interface Guidelines (HIG) Rules

## Typography

- Dynamic Type 지원 필수 -- `.font(.headline)` 등 semantic size 사용
- 하드코딩 폰트 크기 금지: `.font(.system(size: 17))` 사용 금지
- 커스텀 디자인 시스템이 있으면 해당 토큰 사용 (PROJECT_CONTEXT.md 참조)

## Color

- Semantic Color 우선: `.primary`, `Color(.systemBackground)` 등
- 하드코딩 색상 금지: `Color(red:green:blue:)` 직접 사용 금지
- 다크모드 대응 필수 -- `Color(.label)`, `Color(.systemBackground)` 등 adaptive color
- 커스텀 디자인 시스템이 있으면 해당 토큰 사용 (PROJECT_CONTEXT.md 참조)

## Touch Targets

- 최소 터치 영역: **44x44pt** 이상
- 버튼, 탭 가능 요소 모두 적용

## Safe Area

- `.ignoresSafeArea` 는 배경 확장 등 명확한 이유가 있을 때만
- 콘텐츠는 항상 Safe Area 내에 배치

## Navigation Patterns

- 계층 구조: `NavigationStack`
- 모달: `sheet`, `fullScreenCover` (dismiss 제공 필수)
- 탭: `TabView` (최대 5개)
- 컨텍스트 메뉴: `contextMenu`, `swipeActions`
- 검색: `.searchable` modifier

## Accessibility

- 주요 인터랙션에 `.accessibilityLabel`, `.accessibilityHint` 추가
- 이미지에 `.accessibilityLabel` 또는 `.accessibilityHidden(true)`
- 커스텀 컨트롤에 `.accessibilityAddTraits`

## Feedback

- 비동기 작업 중 로딩 UI 제공 (`ProgressView` 등)
- 에러 발생 시 사용자에게 명확한 메시지 표시
- 성공/실패 햅틱 피드백 (해당 시)
- 빈 상태(Empty State)에 적절한 안내 제공

## 금지

```swift
// 하드코딩 색상
Color(red: 0.2, green: 0.3, blue: 0.8)
UIColor(red: 0.7, green: 0.5, blue: 1.0, alpha: 1.0)

// 하드코딩 폰트
.font(.system(size: 17))
UIFont.systemFont(ofSize: 17, weight: .medium)

// 이유 없는 Safe Area 무시
.edgesIgnoringSafeArea(.all)

// 44pt 미만 터치 영역
Button("X").frame(width: 20, height: 20)
```
