# iOS Harness Engineering - 시작 가이드

## 이것은 무엇인가?

3-Agent 파이프라인(Planner -> Generator -> Evaluator)으로 **Swift 6 + SwiftUI + MVVM** 코드를 자동 생성하고 품질을 보장하는 하네스 엔지니어링 시스템입니다.

**어떤 iOS 프로젝트에도 적용 가능**합니다.

---

## 디렉토리 구조

```
harness/
├── CLAUDE.md                           # 오케스트레이터 (Claude Code가 자동으로 읽음)
├── PROJECT_CONTEXT.md                  # 프로젝트별 설정
├── START.md                            # 이 파일
│
├── agents/                             # 서브에이전트 지시서
│   ├── planner.md                      #   설계 전문 (opus)
│   ├── generator.md                    #   구현 전문 (sonnet/opus)
│   ├── evaluator.md                    #   QA 전문 (opus)
│   ├── ios-reviewer.md                 #   피드백 수정 전문 (opus)
│   └── evaluation_criteria.md          #   공통 평가 기준
│
├── skills/                             # 재사용 워크플로우
│   ├── harness-pipeline/SKILL.md       #   전체 파이프라인 ��름
│   ├── feedback-loop/SKILL.md          #   Phase 2 피드백 루프
│   ├── ios-tdd/SKILL.md                #   TDD 워크플로우
│   └── build-fix/SKILL.md              #   빌드 에러 수정
│
├── .claude/
│   ├── settings.json                   # 훅 설정
│   ├── rules/                          # 코딩 규칙 (항상 적용)
│   │   ├── swift-style.md
│   │   ├── swift-concurrency.md
│   │   ├── ios-security.md
│   │   ├── testing.md
│   │   └── hig.md
│   └── commands/                       # 슬래시 커맨드
│       ├── harness.md                  #   /harness [프롬프트]
│       ├── feedback.md                 #   /feedback [내용]
│       ├── build-fix.md                #   /build-fix
│       ├── evaluate.md                 #   /evaluate
│       ���── tdd.md                      #   /tdd [대상]
│
├── scripts/hooks/                      # 훅 스크립트
│   ├── block-direct-write.js
│   ├── swift-syntax-check.js
│   └── auto-commit.js
│
├── docs/                               # API 레퍼런스 (자동 생성)
├── output/                             # 생성된 Swift 파일
├── SPEC.md                             # Planner 출력 (자동 생성)
├── QA_REPORT.md                        # Evaluator 출력 (자동 생성)
├── BUILD_RESULT.md                     # 빌드/테스트 결과 (자동 생성)
└── FEEDBACK_LOG.md                     # 피드백 기록 (자동 생성)
```

---

## 새 프로젝트에 적용하는 방법

### 1단계: PROJECT_CONTEXT.md 작성

`PROJECT_CONTEXT.md`를 열고 프로젝트에 맞게 수정:
- 앱 이름, 번들 ID, 타겟 OS
- 프로젝트 경로 (`PROJECT_ROOT`, `TARGET_DIR`)
- 빌드/테스트 명령어
- 디자인 시스템 (있으면)
- 추가 기능 요구사항

### 2단계: Claude Code 실행

```bash
cd harness
claude
```

### 3단계: 프롬프트 입력

```
/harness AlarmKit과 AppIntent를 활용한 스마트 알람 앱을 만들어줘
```

자동으로:
1. Planner가 SPEC.md 생성
2. Generator가 output/ 에 Swift 파일 생성
3. 빌드 게이트 통과 확인
4. Evaluator가 QA_REPORT.md 생성
5. 합격이면 프로젝트 폴더에 통합

### 4단계: 피드백 루프 (Phase 2)

앱을 실행해보고:

```
/feedback R1 시작
/feedback [버그] 알람 생성 후 목록에 안 뜸
```

---

## 슬래시 커맨드

| 커맨드 | 용도 |
|--------|------|
| `/harness [설명]` | 전체 파이프라인 실행 |
| `/feedback [내용]` | 피드백 처리 (Phase 2) |
| `/build-fix` | 빌드 에러 수정 |
| `/evaluate` | Evaluator만 단독 실행 |
| `/tdd [대상]` | TDD 워크플로우 |

---

## 환경변수 (훅 제어용)

| 변수 | 용도 | 예시 |
|------|------|------|
| `HARNESS_TARGET_DIR` | Write 차단 대상 폴더 | `/path/to/YourApp` |
| `HARNESS_PROJECT_ROOT` | 자동 커밋 대상 git 루트 | `/path/to/project` |

---

## 평가 항목

| 항목 | 비중 | 핵심 기준 |
|------|------|-----------|
| Swift 6 동시성 | 30% | @MainActor, actor, Sendable |
| MVVM 분리 | 25% | View - ViewModel - Service 단방향 의존 |
| HIG 준수 | 20% | Dynamic Type, Semantic Color, 접근성 |
| API 활용 | 15% | Apple Framework 올바른 사용 |
| 기능성/가독성 | 10% | 완성도, 접근 제어자, 에러 타입 |

**합격 기준**: 가중 점수 7.0 이상 (동시성 또는 MVVM 4점 이하 시 무조건 불합격)

---

## 예시 프롬프트

```
/harness Core Data + CloudKit 동기화가 있는 할 일 관리 앱
/harness HealthKit 데이터를 차트로 보여주는 건강 대시보드
/harness MapKit + CoreLocation 기반 주변 맛집 추천 앱
/harness StoreKit 2 결제가 있는 구독형 메모 앱
```
