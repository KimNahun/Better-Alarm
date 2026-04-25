---
name: 알람 소리/볼륨 문제
description: 알람 울림 화면까지는 가지만 볼륨 80% 조절과 소리 재생이 실제로 동작하지 않음. 백그라운드에서도 울려야 함.
type: feedback
---

알람 울림 화면 진입은 되지만 실제 소리가 나지 않고 볼륨 자동 조절도 동작하지 않는 문제.
백그라운드/다른 앱 사용 중에도 알람이 울려야 함.

**Why:** 실기기 테스트에서 소리 미출력 확인됨. AVAudioSession 설정, VolumeService 호출 순서 등 확인 필요.
**How to apply:** AudioService/VolumeService 수정 시 반드시 실기기에서 소리 출력 테스트.
