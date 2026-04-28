# Harness Engineering for iOS

**Claude Code 기반 iOS 앱 코드 생성 품질 보장 시스템**

3-Agent 파이프라인(Planner → Generator → Evaluator)으로 Swift 6 + SwiftUI + MVVM 코드를 자동 생성하고, 평가 기준표로 품질을 강제합니다.

어떤 iOS 프로젝트에도 `PROJECT_CONTEXT.md`만 수정하면 적용할 수 있습니다.

---

## 왜 필요한가?

일반적으로 AI에게 "앱 만들어줘"라고 하면 품질이 일정하지 않습니다.

| 문제 | 하네스 해결 방식 |
|------|-----------------|
| Swift 6 동시성 누락 (`@MainActor` 빠짐, `DispatchQueue` 섞임) | Evaluator가 전수검사, 위반 시 불합격 |
| MVVM 레이어 오염 (View에 로직, ViewModel에 SwiftUI) | 체크리스트 기반 감점 |
| 자기 코드에 관대한 평가 | Generator와 Evaluator를 다른 에이전트로 분리 |
| 매번 "Swift 6 써줘, MVVM으로 해줘" 반복 | rules/로 자동 적용 |

---

## 시스템 구성

```
harness/
├── CLAUDE.md                           # 오케스트레이터 (파이프라인 전체 흐름)
├── PROJECT_CONTEXT.md                  # 프로젝트별 설정
│
├── agents/                             # 서브에이전트
│   ├── planner.md                      #   아키텍처 설계 (opus)
│   ├── generator.md                    #   Swift 코드 생성 (sonnet)
│   ├── evaluator.md                    #   QA 검수 (opus)
│   ├── ios-reviewer.md                 #   피드백 수정 (opus)
│   └── evaluation_criteria.md          #   공통 평가 기준표
│
├── .claude/
│   ├── settings.json                   # 훅 설정 (시스템 레벨 강제)
│   ├── rules/                          # 코딩 규칙 (항상 자동 적용)
│   │   ├── swift-style.md              #   Swift 코딩 스타일
│   │   ├── swift-concurrency.md        #   Swift 6 동시성 규칙
│   │   ├── ios-security.md             #   iOS 보안 규칙
│   │   ├── hig.md                      #   Human Interface Guidelines
│   │   ├── testing.md                  #   테스트 규칙
│   │   └── workflow-enforcement.md     #   워크플로우 강제 규칙
│   └── commands/                       # 슬래시 커맨드
│       ├── harness.md                  #   /harness [설명]
│       ├── feedback.md                 #   /feedback [내용]
│       ├── build-fix.md                #   /build-fix
│       ├── evaluate.md                 #   /evaluate
│       └── tdd.md                      #   /tdd [대상]
│
├── skills/                             # 재사용 워크플로우
│   ├── harness-pipeline/SKILL.md       #   3-Agent 파이프라인
│   ├── feedback-loop/SKILL.md          #   사용자 피드백 루프
│   ├── ios-tdd/SKILL.md                #   TDD 워크플로우
│   └── build-fix/SKILL.md              #   빌드 에러 수정
│
├── scripts/hooks/                      # 시스템 훅 스크립트
│   ├── block-direct-write.js           #   프로젝트 폴더 직접 Write 차단
│   ├── swift-syntax-check.js           #   Swift 문법 검증 (파일별)
│   └── pre-commit-build.js             #   커밋 전 빌드 검증 + 자동 커밋
│
└── START.md                            # 시작 가이드
```

---

## 파이프라인 흐름

```
사용자: "레시피 관리 앱 만들어줘"
         │
         ▼
┌─ 단계 1: Planner (opus) ──────────────────┐
│  SPEC.md 생성                              │
│  아키텍처, 기능 목록, 화면 흐름, 동시성 경계 │
└────────────────────────────────────────────┘
         │
         ▼
┌─ 단계 2: Generator (sonnet) ──────────────┐
│  output/*.swift 생성                       │
│  View, ViewModel, Service, Model 전부      │
└────────────────────────────────────────────┘
         │
         ▼
┌─ 단계 2.5: 빌드 게이트 ──────────────────────┐
│  xcodebuild로 컴파일 + 테스트 통과 확인      │
│  실패 시 → Generator가 자동 수정             │
└────────────────────────────────────────────┘
         │
         ▼
┌─ 단계 3: Evaluator (opus) ────────────────┐
│  QA_REPORT.md 생성                         │
│  5개 항목 채점 → 7.0 미만이면 불합격        │
└────────────────────────────────────────────┘
         │
    합격? ─── No ──→ Generator로 복귀 (최대 3회)
         │
        Yes
         │
         ▼
┌─ 단계 5: Xcode 통합 ─────────────────────┐
│  output/ → 프로젝트 폴더 동기화            │
└────────────────────────────────────────────┘
```

---

## 평가 기준

| 항목 | 비중 | 핵심 기준 |
|------|------|-----------|
| **Swift 6 동시성** | 30% | `@MainActor`, `actor`, `Sendable`, 구버전 패턴 금지 |
| **MVVM 분리** | 25% | View↔ViewModel↔Service 단방향, 레이어 오염 금지 |
| **HIG 준수** | 20% | Dynamic Type, 44pt 터치 영역, 접근성, 로딩/에러 UI |
| **API 활용** | 15% | Apple Framework 올바른 사용, Service 레이어에서만 호출 |
| **기능성/가독성** | 10% | 완성도, 접근 제어자, 에러 타입 |

- **7.0 이상** → 합격
- **5.0 ~ 6.9** → 조건부 합격 (피드백 반영 후 재검수)
- **5.0 미만** → 불합격
- **동시성 또는 MVVM 4점 이하** → 무조건 불합격

---

## 시스템 레벨 강제 규칙

슬래시 커맨드 없이도 **항상 자동 적용**되는 규칙:

| 규칙 | 강제 방식 |
|------|-----------|
| 신규 기능 → 테스트 코드 필수 | rule (AI 행동 지침) |
| 신규 기능 → 로그 필수 | rule |
| 기능 완료/버그 수정 → 커밋 필수 | rule + hook (Stop 시 자동) |
| 시뮬레이터 고정 (신규 생성 금지) | rule |
| 디자인 시스템 사용 강제 | rule |
| 빌드 오류 검사 | rule + hook 2중 (파일별 syntax + 커밋 전 전체 빌드) |
| 프로젝트 폴더 직접 Write 차단 | hook (PreToolUse) |

---

## 빠른 시작

### 1. 프로젝트 설정

```bash
cd harness
# PROJECT_CONTEXT.md를 열고 앱 이름, 경로, 빌드 명령어 등 작성
```

### 2. 파이프라인 실행

```bash
claude
```

```
/harness Core Data 기반 레시피 관리 앱 만들어줘
```

### 3. 피드백 루프 (앱을 써보고)

```
/feedback [버그] 저장 후 목록에 안 뜸
/feedback [UI] 다크모드에서 텍스트 안 보임
```

---

## 커맨드

| 커맨드 | 용도 |
|--------|------|
| `/harness [설명]` | 3-Agent 파이프라인 전체 실행 |
| `/feedback [내용]` | 피드백 1건씩 처리 + 커밋 |
| `/build-fix` | Xcode 빌드 에러 진단/수정 |
| `/evaluate` | Evaluator만 단독 실행 (점수 확인) |
| `/tdd [대상]` | TDD 워크플로우 (Red→Green→Refactor) |

자연어로 말해도 rules/가 자동 적용되므로 동일한 품질 규칙이 적용됩니다.

---

## 다른 프로젝트에 적용

**`PROJECT_CONTEXT.md` 이 파일 하나만 바꾸면 됩니다.** 나머지는 전부 공용입니다.

### 공용 vs 프로젝트별

```
공용 (안 바꿈)                    프로젝트별 (이것만 바꿈)
─────────────                   ──────────────────
agents/planner.md               PROJECT_CONTEXT.md
agents/generator.md
agents/evaluator.md
agents/ios-reviewer.md
agents/evaluation_criteria.md
.claude/rules/*
.claude/commands/*
skills/*
scripts/hooks/*
```

### PROJECT_CONTEXT.md에서 바꿀 항목

| 섹션 | 바꿀 내용 | 예시 |
|------|-----------|------|
| **앱 이름 / 번들 ID** | 프로젝트 기본 정보 | `MyRecipeApp`, `com.nahun.MyRecipeApp` |
| **프로젝트 경로** | `PROJECT_ROOT`, `TARGET_DIR`, `HARNESS_ROOT` | `/Users/you/Desktop/MyRecipeApp` |
| **빌드 / 테스트 명령어** | `BUILD_COMMAND`, `TEST_COMMAND` | scheme, destination 변경 |
| **Xcode 통합 방식** | `SYNC_METHOD` | `auto` (파일 복사만) 또는 `manual` |
| **디자인 시스템** | 커스텀 SPM 패키지 (없으면 삭제) | `PersonalColorDesignSystem` |
| **추가 기능 요구사항** | 프로젝트 고유 기능/제약 | "Core Data 사용", "AlarmKit 연동" |
| **API 문서 수집** | NotebookLM/context7 질의 목록 (없으면 삭제) | 노트북 ID, 질문 |
| **기존 코드 참고** | Generator가 참고할 기존 파일 경로 | `Services/AuthService.swift` |
| **보존 파일** | 덮어쓰면 안 되는 파일 | `Utils/Logger.swift` |

### 예시: 레시피 앱

```markdown
## 대상 프로젝트
- 앱 이름: MyRecipeApp
- 번들 ID: com.nahun.MyRecipeApp
- 최소 타겟 iOS: 17.0

## 프로젝트 경로
PROJECT_ROOT="/Users/haesuyoun/Desktop/MyRecipeApp"
TARGET_DIR="MyRecipeApp"
HARNESS_ROOT="/Users/haesuyoun/Desktop/NahunPersonalFolder/harness"

## 빌드 / 테스트 명령어
BUILD_COMMAND="xcodebuild -project $PROJECT_ROOT/MyRecipeApp.xcodeproj \
  -scheme MyRecipeApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'"

## 사용자 추가 요구사항
#### 1. Core Data + CloudKit 동기화
- 레시피 모델을 Core Data로 저장
- CloudKit으로 디바이스 간 동기화
```

### 예시: 건강 대시보드 앱

```markdown
## 대상 프로젝트
- 앱 이름: HealthDash
- 번들 ID: com.nahun.HealthDash
- 최소 타겟 iOS: 17.0

## 사용자 추가 요구사항
#### 1. HealthKit 데이터 읽기
- 걸음 수, 심박수, 수면 데이터
- HealthKit 권한 요청 흐름

#### 2. Swift Charts로 시각화
- 일/주/월 단위 차트
```

---

## 기반 기술

- [Claude Code](https://claude.ai/code) — Anthropic의 AI 코딩 CLI
- [Everything Claude Code](https://github.com/affaan-m/everything-claude-code) — Claude Code 플러그인 프레임워크

## License

MIT
