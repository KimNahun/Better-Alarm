# Swift 하네스 엔지니어링 오케스트레이터

이 프로젝트는 3-Agent 하네스 구조로 동작합니다.
사용자의 한 줄 프롬프트를 받아, **Planner → Generator → Evaluator** 파이프라인을 자동 실행합니다.

**타겟**: Swift 6 + SwiftUI + MVVM + 엄격한 동시성 + HIG 준수

---

## 작업 진행 현황 (다른 AI가 이어받을 때 여기서부터 확인)

> **마지막 업데이트**: 2026-04-08
> **현재 상태**: ✅ **파이프라인 완료 (합격 7.8/10)**

### 전체 작업 목록

| # | 단계 | 설명 | 상태 |
|---|------|------|------|
| 0 | API 문서 수집 | NotebookLM MCP → docs/ 저장 | ✅ 완료 |
| 1 | Planner | SPEC.md 생성 | ✅ 완료 |
| 2 | Generator R1 | output/ Swift 파일 생성 (기능 1~7) | ✅ 완료 |
| 2a | SPEC.md 보완 | 기능 8~11 추가 (LiveActivity, Settings, Weekly, TabBar) | ✅ 완료 |
| 2b | Generator R2 | 기능 8~11 파일 생성 (LiveActivity, Settings, Weekly, BetterAlarmApp) | ✅ 완료 |
| 3a | Evaluator R1 | 조건부 합격 6.6/10 → 피드백 15건 | ✅ 완료 |
| 2c | Generator R3 (피드백 반영) | QA 피드백 15건 전부 반영 | ✅ 완료 |
| 3b | Evaluator R2 | **합격 7.8/10** | ✅ 완료 |
| 4 | Xcode 통합 | output/ → BetterAlarm/ 동기화 완료 | ✅ 완료 |
| 5 | 완료 보고 | 아래 참고 | ✅ 완료 |

### 최종 output/ 폴더 상태

```
output/                                       ← 25개 Swift 파일, 모두 ✅
├── App/BetterAlarmApp.swift                  ✅ @main, TabView 3탭, DI 루트
├── Views/
│   ├── AlarmDetail/AlarmDetailView.swift     ✅
│   ├── AlarmList/AlarmListView.swift         ✅ (로딩/에러 UI 추가)
│   ├── Components/AlarmRowView.swift         ✅
│   ├── Settings/SettingsView.swift           ✅ (피드백 링크, 로딩 UI 추가)
│   └── Weekly/WeeklyAlarmView.swift          ✅
├── ViewModels/
│   ├── AlarmDetail/AlarmDetailViewModel.swift ✅
│   ├── AlarmList/AlarmListViewModel.swift     ✅
│   ├── Settings/SettingsViewModel.swift       ✅ (setLiveActivityEnabled 메서드 패턴)
│   └── Weekly/WeeklyAlarmViewModel.swift      ✅
├── Models/
│   ├── Alarm.swift               ✅ (Sendable, alarmMode, isSilentAlarm)
│   ├── AlarmError.swift          ✅
│   ├── AlarmMode.swift           ✅
│   └── AlarmSchedule.swift       ✅
├── Services/
│   ├── AlarmKitService.swift     ✅ (import AlarmKit, DI 주입)
│   ├── AlarmStore.swift          ✅ (LiveActivity 연동, AlarmKitService DI)
│   ├── AudioService.swift        ✅ (nonisolated 제거)
│   ├── LocalNotificationService.swift ✅
│   ├── LiveActivityManager.swift ✅ (#if os(iOS), actor)
│   └── VolumeService.swift       ✅
├── Intents/
│   ├── StopAlarmIntent.swift     ✅ (import AlarmKit)
│   └── SnoozeAlarmIntent.swift   ✅ (import AlarmKit)
├── Delegates/
│   └── AppDelegate.swift         ✅ (private(set), configure() 패턴)
└── Shared/
    └── AlarmMetadata.swift       ✅ (import AlarmKit)
```

---

## 각 단계 완료 시 커밋 규칙

**각 단계를 완료할 때마다 반드시 git commit을 실행한다.**

```bash
# 단계 0 완료 시
git add harness/docs/
git commit -m "harness: [단계0] API 문서 수집 완료 (alarmkit, appintent, widgetkit)"

# 단계 1 완료 시
git add harness/SPEC.md
git commit -m "harness: [단계1] Planner SPEC.md 생성 완료"

# 단계 2 완료 시 (Generator)
git add harness/output/ harness/SELF_CHECK.md
git commit -m "harness: [단계2] Generator R{N} - Swift 파일 생성 완료"
# N = 반복 회차 (1, 2, 3...)

# 단계 3 완료 시 (Evaluator)
git add harness/QA_REPORT.md
git commit -m "harness: [단계3] Evaluator QA_REPORT 생성 - {합격/조건부/불합격}"

# 최종 완료 시
git add harness/
git commit -m "harness: 파이프라인 완료 - 최종 점수 {X.X}/10"
```

**커밋 타이밍 규칙**:
1. 서브에이전트가 파일을 생성/수정한 직후 오케스트레이터가 커밋을 실행한다
2. 다음 단계를 시작하기 전에 반드시 이전 단계 커밋이 완료되어 있어야 한다
3. 커밋 실패 시 원인을 확인하고 해결한 뒤 재시도한다 (--no-verify 사용 금지)

---

---

## 실행 흐름

```
[사용자 프롬프트]
       ↓
  ① API 문서 수집 (NotebookLM MCP)
     → docs/ 저장
       ↓
  ② Planner 서브에이전트
     → SPEC.md 생성
       ↓
  ③ Generator 서브에이전트
     → output/ Swift 파일 생성 + SELF_CHECK.md 작성
       ↓
  ④ Evaluator 서브에이전트
     → QA_REPORT.md 작성
       ↓
  ⑤ 판정 확인
     → 합격: 완료 보고
     → 불합격/조건부: ③으로 돌아가 피드백 반영 (최대 3회 반복)
```

---

## 단계별 실행 지시

### 단계 0: API 문서 수집 (NotebookLM MCP) ← 필수, 건너뛰기 금지

**오케스트레이터가 직접 실행. 이 단계를 완료하지 않으면 Planner를 호출하지 마라.**

NotebookLM MCP의 `mcp__notebooklm__ask_question` 도구를 사용하여
노트북 ID `alarmkit-scheduling-and-managi` 에서 아래 3가지 질문을 순서대로 질의한다.
응답 내용을 각각 파일로 저장한다.

1. **AlarmKit 문서 수집**
   - 질문: "AlarmKit의 AlarmManager, AlarmAttributes, AlarmSchedule(fixed/relative), AlarmButton, AlarmPresentation, requestAuthorization, alarmUpdates 스트림에 대해 코드 예제 포함해서 상세히 설명해줘"
   - 저장: `docs/alarmkit_notes.md`

2. **AppIntent 문서 수집**
   - 질문: "AppIntents의 LiveActivityIntent, IntentDescription, @Parameter, perform() 구현 방법과 AlarmKit과 함께 사용하는 패턴을 코드 예제 포함해서 설명해줘"
   - 저장: `docs/appintent_notes.md`

3. **ActivityKit(WidgetKit) 문서 수집**
   - 질문: "ActivityKit의 Live Activity 시작, 업데이트, 종료 방법과 ActivityAttributes, ActivityContent 구조를 코드 예제 포함해서 설명해줘"
   - 저장: `docs/widgetkit_notes.md`

MCP 호출이 실패하거나 노트북을 찾을 수 없는 경우에만 `docs/` 폴더에 빈 파일을 만들고 이유를 기록한 뒤 다음 단계로 진행한다.
**성공적으로 응답을 받았다면 반드시 파일로 저장한 후에 Planner를 호출하라.**


### 단계 1: Planner 호출

서브에이전트에게 아래 내용을 전달한다:

```
PROJECT_CONTEXT.md 파일을 반드시 먼저 읽어라. 이것이 프로젝트 고정 요구사항이다.
agents/planner.md 파일을 읽고, 그 지시를 따라라.
agents/evaluation_criteria.md 파일도 읽고 참고하라.
docs/ 폴더에 파일이 있으면 모두 읽어라 (API 레퍼런스).

사용자 요청: [사용자가 준 프롬프트]

PROJECT_CONTEXT.md의 요구사항을 사용자 프롬프트보다 우선 적용하라.
결과를 SPEC.md 파일로 저장하라.
```

Planner 서브에이전트가 SPEC.md를 생성하면, 다음 단계로 진행한다.


### 단계 2: Generator 호출

**최초 실행 시:**

```
PROJECT_CONTEXT.md 파일을 반드시 먼저 읽어라. 이것이 프로젝트 고정 요구사항이다.
agents/generator.md 파일을 읽고, 그 지시를 따라라.
agents/evaluation_criteria.md 파일도 읽고 참고하라.
SPEC.md 파일을 읽고, 전체 기능을 구현하라.
docs/ 폴더에 파일이 있으면 모두 읽어라 (API 레퍼런스).

PROJECT_CONTEXT.md의 디자인 시스템, 아키텍처 요구사항을 반드시 준수하라.
output/ 폴더 아래에 파일 구조에 따라 Swift 파일들을 생성하라.
완료 후 SELF_CHECK.md를 작성하라.
```

**피드백 반영 시 (2회차 이상):**

```
PROJECT_CONTEXT.md 파일을 반드시 먼저 읽어라. 이것이 프로젝트 고정 요구사항이다.
agents/generator.md 파일을 읽고, 그 지시를 따라라.
agents/evaluation_criteria.md 파일도 읽고 참고하라.
SPEC.md 파일을 읽어라.
output/ 폴더의 모든 Swift 파일을 읽어라. 이것이 현재 코드다.
QA_REPORT.md 파일을 읽어라. 이것이 QA 피드백이다.
docs/ 폴더에 파일이 있으면 모두 읽어라 (API 레퍼런스).

QA 피드백의 "구체적 개선 지시"를 모두 반영하여 코드를 수정하라.
"방향 판단"이 "아키텍처 재설계"이면 레이어 구조 자체를 다시 잡아라.
완료 후 SELF_CHECK.md를 업데이트하라.
```


### 단계 3: Evaluator 호출

서브에이전트에게 아래 내용을 전달한다:

```
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


### 단계 4: 판정 확인

QA_REPORT.md를 읽고 판정을 확인한다.

- **"합격"** → 단계 5(Xcode 통합)로 진행.
- **"조건부 합격"** 또는 **"불합격"** → 단계 2로 돌아가 피드백 반영.
- **최대 반복 횟수**: 3회. 3회 후에도 불합격이면 현재 상태로 전달하고 이슈를 보고.

### 단계 5: Xcode 프로젝트 통합 ← QA 합격 후 반드시 실행

**이 프로젝트는 `PBXFileSystemSynchronizedRootGroup`을 사용하므로 `BetterAlarm/` 폴더에 파일을 복사하면 Xcode가 자동으로 빌드 대상에 포함한다. xcodeproj 파일 직접 수정 불필요.**

오케스트레이터가 직접 실행:

```bash
PROJECT_ROOT="/Users/kimnahun/Desktop/Side-Project/BetterAlarm"
OUTPUT="$PROJECT_ROOT/harness/output"
TARGET="$PROJECT_ROOT/BetterAlarm"

# 필요한 폴더 생성
mkdir -p "$TARGET/App" "$TARGET/Models" "$TARGET/Services" \
         "$TARGET/ViewModels/AlarmList" "$TARGET/ViewModels/AlarmDetail" \
         "$TARGET/ViewModels/Settings" "$TARGET/ViewModels/Weekly" \
         "$TARGET/Views/AlarmList" "$TARGET/Views/AlarmDetail" \
         "$TARGET/Views/Components" "$TARGET/Views/Settings" "$TARGET/Views/Weekly" \
         "$TARGET/Intents" "$TARGET/Delegates" "$TARGET/Shared"

# output/ → BetterAlarm/ 복사 (덮어쓰기)
[ -d "$OUTPUT/App" ] && cp -fR "$OUTPUT/App/"* "$TARGET/App/" 2>/dev/null
cp -fR "$OUTPUT/Models/"* "$TARGET/Models/"
cp -fR "$OUTPUT/Services/"* "$TARGET/Services/"
cp -fR "$OUTPUT/ViewModels/"* "$TARGET/ViewModels/"
cp -fR "$OUTPUT/Views/"* "$TARGET/Views/"
cp -fR "$OUTPUT/Intents/"* "$TARGET/Intents/"
cp -fR "$OUTPUT/Delegates/"* "$TARGET/Delegates/"
cp -fR "$OUTPUT/Shared/"* "$TARGET/Shared/"

echo "Xcode 통합 완료."
```

**주의**:
- `BetterAlarm/Utils/Logger.swift` — 덮어쓰지 않음 (기존 파일 유지)
- `BetterAlarmWidget/` 폴더 — 건드리지 않음 (기존 위젯 그대로)
- 통합 후 `xcodebuild -scheme BetterAlarm -destination 'generic/platform=iOS Simulator' build` 로 빌드 확인

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
4. Generator R2: [수정 내용 한 줄] (있는 경우)
5. Evaluator R2: [판정 결과] (있는 경우)
...

**주요 파일**:
- output/[AppName]App.swift
- output/Views/[주요 뷰 목록]
- output/ViewModels/[주요 뷰모델 목록]
```

---

## 서브에이전트 모델 선택 기준

각 단계마다 작업 유형에 맞는 모델을 명시적으로 지정하라.

| 단계 | 모델 | 이유 |
|------|------|------|
| 단계 0 (MCP 수집) | **haiku** | 질의 후 파일 저장, 추론 불필요. 빠르고 저렴함 |
| 단계 1 Planner | **opus** | 전체 아키텍처 설계. 구조를 잘못 잡으면 Generator/Evaluator 모두 망함 |
| 단계 2 Generator (최초) | **sonnet** | 일반 Swift 코딩. 비용 대비 성능 최적 |
| 단계 2 Generator (피드백 반영) | **opus** | QA 피드백 + 전체 코드 맥락 동시 처리. 복잡한 디버깅 |
| 단계 3 Evaluator | **opus** | 동시성·MVVM·보안 위반 탐지. 놓치면 안 됨 |

Agent 도구 호출 시 `model` 파라미터를 반드시 지정하라:
- `"model": "haiku"` — 탐색, 문서 저장
- `"model": "sonnet"` — 1회차 코드 생성
- `"model": "opus"` — 설계, QA, 피드백 반영

---

## 주의사항

- Generator와 Evaluator는 반드시 다른 서브에이전트로 호출할 것 (분리가 핵심)
- 각 단계 완료 후 생성된 파일이 존재하는지 확인할 것
- output/ 폴더가 없으면 생성할 것
- docs/ 폴더가 없으면 생성할 것
