---
name: harness-pipeline
description: 3-Agent 하네스 파이프라인 (Planner -> Generator -> Evaluator) 자동 실행
origin: harness
---

# Harness Pipeline

## When to Use

- 신규 기능 개발 시 (0에서 코드 생성)
- 대규모 리팩토링이 필요할 때
- SPEC.md 기반의 체계적 코드 생성이 필요할 때

## When NOT to Use

- 단순 버그 수정 (직접 Edit)
- 기존 코드의 소규모 변경 (직접 Edit)
- 피드백 반영 (feedback-loop 스킬 사용)

## How It Works

### 사전 조건
1. `PROJECT_CONTEXT.md`��� 존재해야 함 (없으면 프로젝트에 맞게 수정 필요)
2. `agents/` 폴더에 planner.md, generator.md, evaluator.md 존재

### 파이프라인 흐름

```
단계 -1: output/ 사전 동기화 (기존 코드 -> output/)
단계 0:  API 문서 수집 (선택, docs/에 없을 때만)
단계 1:  Planner (opus) -> SPEC.md
단계 2:  Generator (sonnet) -> output/*.swift
단계 2.5: 빌드 게이트 + 테스트 게이트
단계 3:  Evaluator (opus) -> QA_REPORT.md
단계 4:  판정 -> pass면 단계 5, 아니면 단계 2로 복귀 (최대 3회)
단계 5:  Xcode 통합 (output/ -> 프로젝트 폴더)
```

### 각 단계의 입출력

| 단계 | 입력 | 출력 |
|------|------|------|
| Planner | 사용자 프롬프트 + PROJECT_CONTEXT.md + docs/ | SPEC.md |
| Generator | SPEC.md + PROJECT_CONTEXT.md + docs/ | output/*.swift |
| Build Gate | output/ + 프로젝트 | BUILD_RESULT.md |
| Evaluator | output/ + SPEC.md + evaluation_criteria.md | QA_REPORT.md |

### 모델 선택

| 단계 | 모델 | 이유 |
|------|------|------|
| 문서 수집 | haiku | 단순 질의, 추론 불필요 |
| Planner | opus | 아키텍처 설계 품질이 전체를 좌우 |
| Generator 1회차 | sonnet | 비용 대비 성능 최적 |
| Generator 2회차+ | opus | 복잡한 피드백 반�� |
| Evaluator | opus | 위반 사항 놓치면 안 됨 |

## Examples

```
/harness AlarmKit과 AppIntent를 활용한 스마트 알람 앱
/harness Core Data + CloudKit 동기화가 있는 할 일 관리 앱
/harness HealthKit 데이터를 차트로 보여주는 건강 대시보드 앱
```
