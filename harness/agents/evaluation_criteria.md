# 평가 기준표

Generator와 Evaluator가 공유하는 Swift 코드 품질 기준.

---

## 채점 항목

### 1. Swift 6 동시성 (비중: 30%)
Swift 6의 엄격한 동시성 모델을 올바르게 적용했는가?

**합격 기준:**
- 모든 ViewModel: `@MainActor` + `@Observable` 선언
- 모든 Service: `actor` 선언
- 모든 Model: `struct` + `Sendable` 준수
- `DispatchQueue`, `@Published`, `ObservableObject` 미사용
- Sendable 경계를 넘는 타입 전달 시 `Sendable` 준수
- 컴파일러 동시성 경고가 없을 것으로 예상됨

**불합격 기준:**
- ViewModel이 `@MainActor` 없음
- Service가 일반 `class`로 구현
- `DispatchQueue.main.async` 사용
- `@Published` + `ObservableObject` 패턴 사용 (구버전)
- Non-Sendable 타입을 actor 경계 넘어 전달

---

### 2. MVVM 아키텍처 분리 (비중: 25%)
레이어 간 관심사가 명확히 분리되어 있는가?

**합격 기준:**
- View: 순수 UI 선언만 포함, 비즈니스 로직 없음
- ViewModel: UI 상태 소유, `SwiftUI` import 없음, UI 타입(`Color`, `Font`) 없음
- Service: 외부 API 및 데이터 처리, ViewModel/View 참조 없음
- 의존성 단방향 흐름: View → ViewModel → Service
- Protocol 기반 Service 주입 (테스트 가능성)

**불합격 기준:**
- View에서 직접 `URLSession` 또는 Service 호출
- ViewModel에 `import SwiftUI` 또는 UI 타입 직접 사용
- Service에서 ViewModel 콜백 또는 참조
- 역방향 의존성 존재

---

### 3. HIG 준수 + 디자인 시스템 (비중: 20%)
Apple Human Interface Guidelines를 준수하고, PersonalColorDesignSystem 패키지를 올바르게 사용하는가?

**합격 기준:**
- Dynamic Type 지원 (semantic font size 사용)
- **`PersonalColorDesignSystem` 토큰 사용**: `UIColor.p*` / `Color.p*` / `UIFont.p*`
- **`GlassCardView`, `HapticManager` 등 패키지 컴포넌트 사용**
- 터치 영역 44×44pt 이상
- 로딩/에러 상태 UI 제공
- 접근성 레이블 주요 인터랙션에 추가
- 플랫폼 기본 내비게이션 패턴 사용 (`NavigationStack`, `sheet` 등)

**불합격 기준:**
- 하드코딩 폰트 크기 (`.font(.system(size: 17))`, `UIFont.systemFont(ofSize:)` 직접 사용)
- **하드코딩 색상** — `Color(red:green:blue:)`, `UIColor(red:green:blue:alpha:)` 직접 사용 (`PersonalColorDesignSystem` 토큰 대신 사용 시 즉시 감점)
- **`GlassCardView`, 햅틱 피드백을 자체 구현** (패키지 것 미사용)
- 44pt 미만 터치 영역
- 비동기 작업 중 UI 피드백 없음
- 에러 무시 (사용자에게 오류 미표시)

---

### 4. API 활용 (비중: 15%)
AlarmKit / AppIntent / WidgetKit을 올바르게 활용했는가?

**합격 기준:**
- SPEC에서 계획한 API를 실제로 구현
- 올바른 타입과 메서드 사용
- 권한 요청 흐름 구현
- API 호출이 Service 레이어에만 존재
- 에러 처리 구현

**불합격 기준:**
- SPEC에서 계획한 API를 구현하지 않음
- API 호출이 ViewModel 또는 View에 직접 존재
- 권한 요청 없음
- 에러 처리 없음

API를 사용하지 않는 앱: 이 항목 비중을 기능성으로 이동 (기능성 25%, API 0%)

---

### 5. 기능성 및 코드 가독성 (비중: 10%)
구현이 완성되어 있고 코드가 읽기 쉬운가?

**합격 기준:**
- SPEC의 모든 기능이 구현됨
- 접근 제어자 명시 (`private`, `private(set)`, `internal`)
- 에러 타입이 `enum [Domain]Error: Error`로 정의
- 불필요한 주석 없음, 필요한 곳에만 주석
- 파일명이 SPEC 컨벤션 일치 (`[Feature]View.swift` 등)
- 코드 중복 최소화 (재사용 컴포넌트 분리)

**불합격 기준:**
- SPEC 기능 중 절반 이상 미구현
- 접근 제어자 없음 (모두 public 또는 internal 기본값)
- 에러를 `print()` 만으로 처리
- 파일 하나에 모든 코드 뭉쳐있음

---

## 판정

```
가중 점수 = (동시성×0.30) + (MVVM×0.25) + (HIG×0.20) + (API×0.15) + (기능성×0.10)
```

- **7.0 이상** → 합격
- **5.0 ~ 6.9** → 조건부 합격 (피드백 반영 후 재검수)
- **5.0 미만** → 불합격
- **동시성 또는 MVVM 항목 4점 이하** → 무조건 불합격 (아키텍처 기반이 무너진 것)

---

## 피드백 형식

```
**전체 판정**: [합격 / 조건부 합격 / 불합격]
**가중 점수**: X.X / 10.0

**항목별 점수**:
- Swift 6 동시성: X/10 — [한 줄 코멘트 + 핵심 증거]
- MVVM 분리: X/10 — [한 줄 코멘트 + 핵심 증거]
- HIG 준수: X/10 — [한 줄 코멘트 + 핵심 증거]
- API 활용: X/10 — [한 줄 코멘트 + 핵심 증거]
- 기능성/가독성: X/10 — [한 줄 코멘트 + 핵심 증거]

**구체적 개선 지시**:
1. [파일명] [함수/타입명]: [무엇을 어떻게 수정할 것]
2. [파일명] [함수/타입명]: [무엇을 어떻게 수정할 것]
...

**방향 판단**: [현재 방향 유지] 또는 [아키텍처 재설계]
```
