# 실행 방법

## 프로젝트 구조

```
harness-project/
├── CLAUDE.md                      ← 오케스트레이터 (Claude Code가 자동으로 읽음)
├── agents/
│   ├── evaluation_criteria.md     ← Swift 품질 평가 기준
│   ├── planner.md                 ← Planner 서브에이전트 지시서
│   ├── generator.md               ← Generator 서브에이전트 지시서
│   └── evaluator.md               ← Evaluator 서브에이전트 지시서
├── docs/                          ← NotebookLM MCP에서 읽어온 API 레퍼런스 (자동 생성)
│   ├── alarmkit_notes.md
│   ├── appintent_notes.md
│   └── widget_notes.md
├── output/                        ← 생성된 Swift 파일들
│   ├── [AppName]App.swift
│   ├── Views/
│   ├── ViewModels/
│   ├── Models/
│   ├── Services/
│   ├── Intents/                   ← AppIntent 있을 경우
│   └── Widgets/                   ← WidgetKit 있을 경우
├── SPEC.md                        ← Planner가 생성 (실행 후 생김)
├── SELF_CHECK.md                  ← Generator가 생성 (실행 후 생김)
├── QA_REPORT.md                   ← Evaluator가 생성 (실행 후 생김)
└── START.md                       ← 지금 이 파일
```

---

## 실행 방법

### 1단계: 이 폴더에서 Claude Code를 실행합니다

```bash
cd harness-project
claude
```

Claude Code가 CLAUDE.md를 자동으로 읽고 오케스트레이터 역할을 합니다.

### 2단계: 프롬프트 한 줄을 입력합니다

```
AlarmKit과 AppIntent를 활용한 스마트 알람 앱을 만들어줘
```

이것만 치면 됩니다.
CLAUDE.md의 지시에 따라 자동으로:

1. NotebookLM MCP에서 AlarmKit / AppIntent / WidgetKit 문서를 읽어옵니다
2. Planner 서브에이전트가 SPEC.md (Swift 6 + MVVM 설계서)를 생성합니다
3. Generator 서브에이전트가 output/ 폴더에 Swift 파일들을 생성합니다
4. Evaluator 서브에이전트가 QA_REPORT.md를 생성합니다
5. 불합격이면 Generator가 피드백을 반영하여 재작업합니다
6. 합격이면 완료 보고가 나옵니다

### 3단계: 결과를 확인합니다

```bash
# output/ 폴더 파일을 Xcode에서 열기
open output/
```

---

## 예시 프롬프트

```
AlarmKit으로 수면 추적 기능이 있는 알람 앱 만들어줘
```

```
AppIntent와 WidgetKit을 활용한 할 일 관리 앱 만들어줘
```

```
AlarmKit + AppIntent로 약 복용 알림 앱 만들어줘
```

```
WidgetKit으로 홈 화면 위젯이 있는 타이머 앱 만들어줘
```

---

## 평가 항목 (Swift 특화)

| 항목 | 비중 | 핵심 기준 |
|------|------|-----------|
| Swift 6 동시성 | 30% | @MainActor, actor, Sendable |
| MVVM 분리 | 25% | View↔VM↔Service 단방향 의존 |
| HIG 준수 | 20% | Dynamic Type, Semantic Color, 접근성 |
| API 활용 | 15% | AlarmKit / AppIntent / WidgetKit |
| 기능성/가독성 | 10% | 완성도, 접근 제어자, 에러 타입 |

**합격 기준**: 가중 점수 7.0 이상 (동시성 또는 MVVM 4점 이하 시 무조건 불합격)

---

## Solo 비교 실험

```bash
mkdir solo-test && cd solo-test
claude

# 같은 프롬프트 입력
> AlarmKit과 AppIntent를 활용한 스마트 알람 앱을 만들어줘. Swift 6 + SwiftUI로.
```

하네스 결과와 Solo 결과를 비교하면 아키텍처 품질 차이가 명확히 보입니다.
