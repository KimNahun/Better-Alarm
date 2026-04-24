# BetterAlarm

Swift 6 + SwiftUI로 만든 iOS 알람 앱. 정확한 타이밍, 계절 테마, 잠금화면 위젯까지 지원합니다.

## 주요 기능

### 알람
- **1회 알람** / **요일 반복** / **특정 날짜** 알람
- **AlarmKit 모드** (iOS 26+): 앱을 종료해도 알람이 울림
- **로컬 모드** (iOS 17+): 포그라운드/백그라운드에서 알림으로 동작
- **스누즈** (5분) / **1회 건너뛰기** / 빠른 ON·OFF 토글

### 소리 & 볼륨
- 기본 알람음 + 커스텀 사운드(MP3) 지원
- **이어폰 전용 알람**: 연결된 이어폰으로만 소리 출력 (조용한 알람)
- **자동 볼륨 관리**: 알람 시 80% 이상 유지, 종료 후 원래 볼륨 복원

### 잠금화면 & Dynamic Island
- **Live Activity** (iOS 17+): 잠금화면에 다음 알람 표시
- **Dynamic Island**: 알람 정보를 상단에 표시
- 잠금화면에서 바로 중지/스누즈 가능

### 계절 테마
봄 / 여름 / 가을 / 겨울 — 4가지 테마 지원. 테마 변경 시 앱 아이콘도 함께 바뀝니다.

## 스크린 구성

| 탭 | 설명 |
|----|------|
| 알람 목록 | 전체 알람 목록 + 다음 알람 배너 |
| 요일별 알람 | 요일 기준 필터링 뷰 |
| 설정 | 테마 선택, 알림 권한, 잠금화면 위젯 토글 |

그 외 **알람 생성/편집** 화면, **알람 울림** 전체화면이 있습니다.

## 기술 스택

| 항목 | 내용 |
|------|------|
| 언어 | Swift 6 (Strict Concurrency) |
| UI | SwiftUI, Dark Mode 전용 |
| 아키텍처 | MVVM (`@Observable` ViewModel + `actor` Service) |
| 디자인 시스템 | [PersonalColorDesignSystem](https://github.com/KimNahun) (Glass Morphism + Haptic) |
| 알람 | AlarmKit (iOS 26+) / UserNotifications (iOS 17+) |
| 오디오 | AVFoundation + MediaPlayer |
| 위젯 | WidgetKit + ActivityKit (Live Activity) |
| 데이터 | UserDefaults (JSON Codable) |

## 요구 사항

- iOS 17.0+
- Xcode 26+
- AlarmKit 기능은 iOS 26+ 에서만 활성화 (이하 버전은 로컬 모드로 자동 폴백)

## 빌드

```bash
xcodebuild -project BetterAlarm.xcodeproj \
  -scheme BetterAlarm \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

## 프로젝트 구조

```
BetterAlarm/
├── App/                  # 앱 진입점, TabView, DI
├── Views/                # SwiftUI 화면
│   ├── AlarmList/        # 알람 목록
│   ├── AlarmDetail/      # 생성/편집
│   ├── AlarmRinging/     # 알람 울림 전체화면
│   ├── Weekly/           # 요일별 알람
│   ├── Settings/         # 설정
│   └── Components/       # 공용 컴포넌트
├── ViewModels/           # @MainActor @Observable
├── Services/             # actor 기반 비즈니스 로직
│   ├── AlarmStore        # CRUD + 영속화
│   ├── AlarmKitService   # iOS 26+ 시스템 알람
│   ├── AudioService      # 사운드 재생
│   ├── VolumeService     # 볼륨 제어
│   └── LiveActivityManager # 잠금화면 위젯
├── Models/               # Codable & Sendable 구조체
├── Intents/              # 잠금화면 액션 (Stop/Snooze)
└── Extensions/

BetterAlarmWidget/        # 위젯 익스텐션 (Live Activity)
BetterAlarmTests/         # 유닛 + 통합 + 회귀 테스트
```

## 라이선스

Private repository.
