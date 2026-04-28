# iOS Harness Engineering Orchestrator

이 프로젝트는 3-Agent 하네스 구조로 동작합니다.
사용자의 한 줄 프롬프트를 받아, **Planner -> Generator -> Evaluator** 파이프라인을 자동 실행합니다.

**타겟**: Swift 6 + SwiftUI + MVVM + 엄격한 동시성 + HIG 준수

---

## 사전 조건

파이프라인을 시작하기 전에 아래 파일이 존재해야 합니다:

| 파일 | 역할 | 없으면? |
|------|------|---------|
| `PROJECT_CONTEXT.md` | 프로젝트별 고정 요구사항 (앱 이름, 번들 ID, 디자인 시스템, 추가 기능) | 프로젝트에 맞게 수정하여 사용 |
| `agents/*.md` | 서브에이전트 지시서 | 이미 포함됨 |
| `agents/evaluation_criteria.md` | 공통 평가 기준 | 이미 포함됨 |

---

## 실행 흐름

```
[사용자 프롬프트]
       |
  0. API 문서 수집 (선택 — docs/ 에 이미 있으면 스킵)
       |
  1. Planner 서브에이전트 -> SPEC.md 생성
       |
  2. Generator 서브에이전트 -> output/ Swift 파일 생성
       |
  2.5 빌드 게이트 + 테스트 게이트 (오케스트레이터 직접 실행)
       |
  3. Evaluator 서브에이전트 -> QA_REPORT.md 작성
       |
  4. 판정 확인
     -> pass: 단계 5(Xcode 통합)로 진행
     -> conditional_pass / fail: 단계 2로 복귀 (최대 3회)
       |
  5. Xcode 프로젝트 통합 (output/ -> 프로젝트 폴더 동기화)
```

---

## 단계별 실행 지시

### 단계 -1: output/ 사전 동기화

**파이프라인 시작 전 항상 실행.**
PROJECT_CONTEXT.md의 `PROJECT_ROOT`와 `TARGET_DIR`을 읽고, 기존 소스를 output/에 동기화한다.
피드백 반영으로 프로젝트 폴더가 output/보다 최신일 수 있으므로 항상 동기화한다.

```bash
# PROJECT_CONTEXT.md에서 경로를 읽어 사용
SOURCE="$PROJECT_ROOT/$TARGET_DIR"
DEST="$HARNESS_ROOT/output"

# 존재하는 폴더만 동기화
for dir in App Models Services ViewModels Views Intents Delegates Shared Widgets; do
  [ -d "$SOURCE/$dir" ] && mkdir -p "$DEST/$dir" && cp -fR "$SOURCE/$dir/"* "$DEST/$dir/" 2>/dev/null
done
```

---

### 단계 0: API 문서 수집 (선택)

**스킵 조건**: docs/ 폴더에 .md 파일이 1개 이상 존재하고 비어있지 않으면 스킵.

PROJECT_CONTEXT.md의 `## API 문서 수집` 섹션에 정의된 질의 목록이 있으면,
NotebookLM MCP 또는 context7 MCP를 사용하여 API 문서를 수집하고 docs/에 저장한다.

질의 목록이 없으면 이 단계를 건너뛴다.

---

### 단계 1: Planner 호출

**Agent 도구 호출 -- `model: "opus"` 필수:**

```
description: "Planner: SPEC.md 설계"
model: "opus"
subagent_type: "general-purpose"
prompt: |
  PROJECT_CONTEXT.md 파일을 반드시 먼저 읽어라. 이것이 프로젝트 고정 요구사항이다.
  agents/planner.md 파일을 읽고, 그 지시를 따라라.
  agents/evaluation_criteria.md 파일도 읽고 참고하라.
  docs/ 폴더에 파일이 있으면 모두 읽어라 (API 레퍼런스).

  사용자 요청: [사용자가 준 프롬프트]

  PROJECT_CONTEXT.md의 요구사항을 사용자 프롬프트보다 우선 적용하라.
  결과를 SPEC.md 파일로 저장하라.
```

---

### 단계 2: Generator 호출

**최초 실행 -- `model: "sonnet"` 사용:**

```
description: "Generator R1: Swift 파일 생성"
model: "sonnet"
subagent_type: "general-purpose"
prompt: |
  PROJECT_CONTEXT.md 파일을 반드시 먼저 읽어라. 이것이 프로젝트 고정 요구사항이다.
  agents/generator.md 파일을 읽고, 그 지시를 따라라.
  agents/evaluation_criteria.md 파일도 읽고 참고하라.
  SPEC.md 파일을 읽고, 전체 기능을 구현하라.
  docs/ 폴더에 파일이 있으면 모두 읽어라 (API 레퍼런스).

  PROJECT_CONTEXT.md의 디자인 시스템, 아키텍처 요구사항을 반드시 준수하라.
  output/ 폴더 아래에 파일 구조에 따라 Swift 파일들을 생성하라.
```

**피드백 반영 시 (2회차 이상) -- `model: "sonnet"` 사용:**

```
description: "Generator R{N}: QA 피드백 반영"
model: "sonnet"
subagent_type: "general-purpose"
prompt: |
  PROJECT_CONTEXT.md 파일을 반드시 먼저 읽어라. 이것이 프로젝트 고정 요구사항이다.
  agents/generator.md 파일을 읽고, 그 지시를 따라라.
  agents/evaluation_criteria.md 파일도 읽고 참고하라.
  SPEC.md 파일을 읽어라.
  output/ 폴더의 모든 Swift 파일을 읽어라. 이것이 현재 코드다.
  QA_REPORT.md 파일을 읽어라. 이것이 QA 피드백이다.
  docs/ 폴더에 파일이 있으면 모두 읽어라 (API 레퍼런스).

  QA 피드백의 "구체적 개선 지시"를 모두 반영하여 코드를 수정하라.
  "방향 판단"이 "아키텍처 재설계"이면 레이어 구조 자체를 다시 잡아라.
```

---

### 단계 2.5: 빌드 게이트 + 테스트 게이트

**오케스트레이터가 직접 실행. Evaluator 호출 전 필수.**

PROJECT_CONTEXT.md에서 빌드/테스트 명령어를 읽어 실행한다.

**1. 빌드 게이트:**
```bash
# output/ -> 프로젝트 폴더 임시 통합
cp -fR "$HARNESS_ROOT/output/"* "$PROJECT_ROOT/$TARGET_DIR/" 2>/dev/null || true

# PROJECT_CONTEXT.md의 BUILD_COMMAND 실행
BUILD_LOG=$($BUILD_COMMAND 2>&1)
BUILD_RESULT=$(echo "$BUILD_LOG" | grep -E "BUILD (SUCCEEDED|FAILED)" | tail -1)
echo "$BUILD_RESULT"
```

- **BUILD SUCCEEDED** -> 테스트 게이트로 진행
- **BUILD FAILED** -> 에러 추출 후 Generator R{N+1}에 전달, 단계 2로 복귀

**2. 테스트 게이트:**
```bash
# PROJECT_CONTEXT.md의 TEST_COMMAND 실행
TEST_LOG=$($TEST_COMMAND 2>&1)
FAIL_COUNT=$(echo "$TEST_LOG" | grep -c " FAILED")
```

- **0 failures** -> 단계 3(Evaluator) 호출
- **실패 있음** -> 실패 목록을 Generator R{N+1}에 전달, 단계 2로 복귀

**결과 기록**: `BUILD_RESULT.md`에 저장.

---

### 단계 3: Evaluator 호출

**Agent 도구 호출 -- `model: "opus"` 필수:**

```
description: "Evaluator: QA_REPORT 작성"
model: "opus"
isolation: "worktree"
subagent_type: "general-purpose"
prompt: |
  PROJECT_CONTEXT.md 파일을 반드시 먼저 읽어라. 이것이 프로젝트 고정 요구사항이다.
  agents/evaluator.md 파일을 읽고, 그 지시를 따라라.
  agents/evaluation_criteria.md 파일을 읽어라. 이것이 채점 기준이다.
  SPEC.md 파일을 읽어라. 이것이 설계서다.
  output/ 폴더의 모든 Swift 파일을 읽어라. 이것이 검수 대상이다.

  검수 절차:
  1. output/ 코드를 분석하라
  2. SPEC.md의 기능이 구현되었는지 확인하라
  3. evaluation_criteria.md에 따라 5개 항목을 채점하라
  4. 최종 판정(합격/조건부/불합격)을 내려라
  5. 불합격 또는 조건부 시, 구체적 개선 지시를 작성하라

  결과를 QA_REPORT.md 파일로 저장하라.
```

---

### 단계 4: 판정 확인

```bash
VERDICT=$(grep "^RESULT:" QA_REPORT.md | cut -d' ' -f2)
echo "판정: $VERDICT"
```

| VERDICT 값 | 다음 단계 |
|------------|----------|
| `pass` | 단계 5(Xcode 통합)로 진행 |
| `conditional_pass` | 단계 2로 복귀 (QA_REPORT.md의 BLOCKERS 전달) |
| `fail` | 단계 2로 복귀 (QA_REPORT.md의 BLOCKERS 전달) |

**최대 반복 횟수**: 3회. 3회 후에도 pass가 아니면 현재 상태로 전달하고 이슈를 보고.

---

### 단계 5: Xcode 프로젝트 통합

**PBXFileSystemSynchronizedRootGroup 사용 프로젝트**: 폴더에 파일 복사만으로 Xcode가 자동 인식.
**일반 프로젝트**: xcodeproj 수정이 필요할 수 있음. PROJECT_CONTEXT.md의 `SYNC_METHOD` 참조.

```bash
SOURCE="$HARNESS_ROOT/output"
TARGET="$PROJECT_ROOT/$TARGET_DIR"

# 존재하는 폴더만 동기화
for dir in App Models Services ViewModels Views Intents Delegates Shared Widgets; do
  [ -d "$SOURCE/$dir" ] && mkdir -p "$TARGET/$dir" && cp -fR "$SOURCE/$dir/"* "$TARGET/$dir/" 2>/dev/null
done

# 빌드 확인
$BUILD_COMMAND
```

---

## 각 단계 완료 시 커밋 규칙

```bash
# 단계 0: git commit -m "harness: [단계0] API 문서 수집 완료"
# 단계 1: git commit -m "harness: [단계1] Planner SPEC.md 생성 완료"
# 단계 2: git commit -m "harness: [단계2] Generator R{N} - Swift 파일 생성 완료"
# 단계 3: git commit -m "harness: [단계3] Evaluator QA_REPORT 생성 - {합격/조건부/불합격}"
# 최종:   git commit -m "harness: 파이프라인 완료 - 최종 점수 {X.X}/10"
```

**커밋 타이밍 규칙**:
1. 서브에이전트가 파일을 생성/수정한 직후 오케스트레이터가 커밋
2. 다음 단계 시작 전에 이전 단계 커밋 완료 필수
3. 커밋 실패 시 원인 확인 후 재시도 (--no-verify 금지)

---

## 서브에이전트 모델 선택 기준

| 단계 | 모델 | 이유 |
|------|------|------|
| 단계 0 (문서 수집) | **haiku** | 질의 후 파일 저장, 추론 불필요 |
| 단계 1 Planner | **opus** | 전체 아키텍처 설계. 구조를 잘못 잡으면 전체가 망함 |
| 단계 2 Generator (최초) | **sonnet** | 일반 Swift 코딩. 비용 대비 성능 최적 |
| 단계 2 Generator (피드백 반영) | **sonnet** | QA 피드백 반영 코딩. sonnet 4.6이면 충분 |
| 단계 3 Evaluator | **opus** | 동시성/MVVM/보안 위반 탐지. 놓치면 안 됨 |

---

## 완료 보고 형식

```
## 하네스 실행 완료

**결과물**: output/ 폴더
**Planner 설계 기능 수**: X개
**QA 반복 횟수**: X회
**최종 점수**: 동시성 X/10, MVVM X/10, HIG X/10, API X/10, 기능 X/10 (가중 X.X/10)

**실행 흐름**:
1. Planner: [설계 요약 한 줄]
2. Generator R1: [구현 결과 한 줄]
3. Evaluator R1: [판정 + 핵심 피드백 한 줄]
...

**주요 파일**:
- output/[AppName]App.swift
- output/Views/[주요 뷰 목록]
- output/ViewModels/[주요 뷰모델 목록]
```

---

## Phase 2: 사용자 테스트 & 피드백 루프

> 하네스 자동 파이프라인(Phase 1)이 완료된 후, 사용자가 실기기/시뮬레이터에서 직접 앱을 사용해보며 피드백을 주는 단계.

자세한 워크플로우는 `skills/feedback-loop/SKILL.md` 참조.
`/feedback` 커맨드로 실행.

---

## 주의사항

- Generator와 Evaluator는 반드시 다른 서브에이전트로 호출할 것 (분리가 핵심)
- 각 단계 완료 후 생성된 파일이 존재하는지 확인할 것
- output/ 폴더가 없으면 생성할 것
- docs/ 폴더가 없으면 생성할 것
- PROJECT_CONTEXT.md가 없으면 파이프라인을 시작하지 마라 -- 사용자에게 안내
