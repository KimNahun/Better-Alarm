---
description: 사용자 피드백 처리 (Phase 2 피드백 루프)
argument-hint: [R1~R6 라운드 또는 피드백 내용]
---

skills/feedback-loop/SKILL.md를 읽고 그 워크플로우를 따라라.
PROJECT_CONTEXT.md를 먼저 읽어 프로젝트 컨텍스트를 파악하라.

피드백 처리 핵심 규칙:
- 1개씩 처리, 1개 = 1커밋
- ios-reviewer 에이전트(agents/ios-reviewer.md)를 호출하여 코드 수정 위임
- 빌드 확인 후 커밋
- FEEDBACK_LOG.md에 기록

사용자 입력: $ARGUMENTS
