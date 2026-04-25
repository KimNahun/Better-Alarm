# 백그라운드 무음 오디오 루프 기능 SPEC

## 개요

앱이 백그라운드 상태일 때도 알람이 정상적으로 울리도록 UIBackgroundModes:audio를 활용하여 앱 프로세스를 살려두는 기능.
알라미(Alarmy) 앱과 동일한 방식으로, 무음 오디오를 지속 재생하여 iOS가 앱을 suspend하지 못하게 한다.
이를 통해 `BetterAlarmApp.checkForImminentAlarm()` 루프가 백그라운드에서도 계속 실행되어 알람 시각을 감지할 수 있다.

## 수정 범위

이 SPEC은 **기존 파일 3개의 수정**만 다룬다. 신규 파일 생성 없음.

| 파일 | 수정 내용 |
|------|----------|
| `Services/AudioService.swift` | `startSilentLoop()` / `stopSilentLoop()` 메서드 추가 |
| `Delegates/AppDelegate.swift` | 백그라운드/포그라운드 생명주기에서 무음 루프 제어 + audioService DI 추가 |
| `App/BetterAlarmApp.swift` | AppDelegate.configure() 호출에 audioService 인자 추가 |
| `Services/AlarmStore.swift` | 변경 없음 (기존 `hasEnabledLocalAlarms` computed property 활용) |

## 전제조건

- `Info.plist`에 `UIBackgroundModes: audio`가 설정되어 있어야 함 (Xcode 프로젝트 Capabilities에서 별도 처리)
- 이 SPEC은 코드 수정만 다루며 Info.plist 수정은 범위 밖

## 타겟 플랫폼

- iOS 17.0+
- Swift 6 (strict concurrency)

---

## 기능 1: AudioService — 무음 오디오 루프

### 설명

AVAudioEngine + AVAudioPlayerNode를 사용하여 무음 PCM 버퍼를 무한 반복 재생한다.
별도 오디오 파일 없이 코드로 무음 버퍼를 생성하므로 번들에 파일을 추가할 필요가 없다.

### 수정 대상

`harness/output/Services/AudioService.swift`

### AudioServiceProtocol 확장

프로토콜에 다음 메서드를 추가한다:

```swift
func startSilentLoop() async
func stopSilentLoop() async
```

### 추가할 프로퍼티 (AudioService actor 내부)

```swift
private var silentEngine: AVAudioEngine?
private var silentPlayerNode: AVAudioPlayerNode?
private var isSilentLoopRunning: Bool = false
```

### 추가할 메서드

#### `func startSilentLoop()`

1. `isSilentLoopRunning`이 이미 `true`이면 즉시 리턴 (중복 실행 방지)
2. `AVAudioSession` 카테고리를 `.playback`으로 설정 (options: `.mixWithOthers` — 다른 오디오 방해 안 함)
3. `AVAudioSession.setActive(true)`
4. `AVAudioEngine` 인스턴스 생성
5. `AVAudioPlayerNode` 인스턴스 생성, 엔진에 attach
6. 포맷 정의: `AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)`
7. 엔진의 mainMixerNode와 playerNode를 connect (위 포맷 사용)
8. 무음 PCM 버퍼 생성:
   - `AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)` — 1초 분량
   - `buffer.frameLength = buffer.frameCapacity`
   - float 채널 데이터는 기본값 0 (무음)
9. `playerNode.scheduleBuffer(buffer, at: nil, options: .loops)`
10. `engine.prepare()` → `try engine.start()`
11. `playerNode.play()`
12. `engine.mainMixerNode.outputVolume = 0.0` — 실제 출력 볼륨 0 (스피커에서 소리 안 남)
13. 프로퍼티 저장: `silentEngine = engine`, `silentPlayerNode = playerNode`
14. `isSilentLoopRunning = true`
15. 로그: `AppLogger.info("Silent audio loop started", category: .alarm)`

**에러 처리**: try/catch로 감싸되 throw하지 않고 `AppLogger.error`로 로그만 남긴다 (백그라운드 진입 시 실패해도 앱이 크래시하면 안 됨).

#### `func stopSilentLoop()`

1. `isSilentLoopRunning`이 `false`이면 즉시 리턴
2. `silentPlayerNode?.stop()`
3. `silentEngine?.stop()`
4. `silentPlayerNode = nil`, `silentEngine = nil`
5. `isSilentLoopRunning = false`
6. 로그: `AppLogger.info("Silent audio loop stopped", category: .alarm)`

### 동시성 고려사항

- AudioService는 `actor`이므로 모든 프로퍼티/메서드 접근이 직렬화됨
- AVAudioEngine/AVAudioPlayerNode는 내부적으로 자체 스레드를 사용하므로 actor 격리와 충돌 없음
- `startSilentLoop()`/`stopSilentLoop()`는 actor-isolated 메서드로 구현 (async 키워드 불필요하지만 프로토콜 일관성을 위해 유지)

---

## 기능 2: AppDelegate — 생명주기 연동

### 설명

앱이 백그라운드로 진입할 때 활성 local 모드 알람이 있으면 무음 루프를 시작하고,
포그라운드로 복귀하거나 앱이 종료될 때 무음 루프를 정지한다.

### 수정 대상

`harness/output/Delegates/AppDelegate.swift`

### 추가할 프로퍼티

```swift
private(set) var audioService: AudioService?
```

### configure() 시그니처 수정

기존:
```swift
func configure(alarmStore: AlarmStore, localNotificationService: LocalNotificationService)
```

수정:
```swift
func configure(alarmStore: AlarmStore, localNotificationService: LocalNotificationService, audioService: AudioService)
```

본문에 `self.audioService = audioService` 추가.

### applicationDidEnterBackground 수정

기존 Task 블록 내부, `guard hasLocal else { return }` 통과 후 (리마인더 등록 로직 뒤에) 무음 루프 시작 추가:

```swift
// 무음 루프 시작 (백그라운드 유지)
await audioService?.startSilentLoop()
```

활성 local 알람이 **없으면** guard에서 이미 return하므로 무음 루프도 시작되지 않음 (배터리 최적화).

### applicationWillEnterForeground 수정

기존 Task 블록 내부, 리마인더 취소 뒤에 추가:

```swift
await audioService?.stopSilentLoop()
```

### applicationWillTerminate 수정

기존 DispatchGroup 로직 **앞에**, 동기적으로 처리할 수 있도록 별도 Task+group 패턴 또는 기존 group 내부에 추가:

기존 `group.enter()` Task 내부에 `await audioService?.stopSilentLoop()`를 첫 줄로 추가.

---

## 기능 3: BetterAlarmApp — DI 연결

### 설명

AppDelegate.configure() 호출 시 audioService를 함께 전달하도록 수정.

### 수정 대상

`harness/output/App/BetterAlarmApp.swift`

### 수정 내용

`.task` 블록 내의 `appDelegate.configure(...)` 호출을 수정:

기존:
```swift
appDelegate.configure(alarmStore: alarmStore, localNotificationService: localNotificationService)
```

수정:
```swift
appDelegate.configure(alarmStore: alarmStore, localNotificationService: localNotificationService, audioService: audioService)
```

---

## 동작 흐름

```
[앱 실행 중 — 포그라운드]
  checkForImminentAlarm() 루프가 10초마다 실행
  무음 루프: 꺼짐

[사용자가 앱을 백그라운드로 보냄]
  AppDelegate.applicationDidEnterBackground 호출
  → hasEnabledLocalAlarms 확인
  → true → audioService.startSilentLoop() 호출
    → AVAudioEngine이 무음 버퍼를 .loops로 재생
    → iOS가 앱을 audio 백그라운드 모드로 유지 (suspend 방지)
  → checkForImminentAlarm() 루프가 계속 실행됨
  → 알람 시각 도달 시 ringingAlarm 설정 → 울림

[사용자가 앱을 포그라운드로 복귀]
  AppDelegate.applicationWillEnterForeground 호출
  → audioService.stopSilentLoop() 호출
  → 무음 루프 정지 (배터리 절약)

[앱 종료]
  AppDelegate.applicationWillTerminate 호출
  → audioService.stopSilentLoop() 호출
  → 이후 기존 로직(UNCalendar 알림 재등록)으로 폴백
```

## 배터리 최적화

- 무음 루프는 활성 local 모드 알람이 있을 때**만** 시작 (`hasEnabledLocalAlarms` 체크)
- 포그라운드 복귀 시 즉시 정지
- 앱 종료 시 정지
- `.mixWithOthers` 옵션으로 다른 앱 오디오에 영향 없음
- `mainMixerNode.outputVolume = 0.0`으로 스피커/이어폰에서 소리 없음
- 44100Hz 1채널 무음 버퍼 — 최소한의 CPU 사용

## 코드 컨벤션

- Swift 6 strict concurrency 준수
- AudioService는 기존 `actor` 구조 유지
- 새 메서드는 actor-isolated (기본)
- `DispatchQueue` 사용 금지 (기존 applicationWillTerminate의 DispatchGroup은 유지)
- 에러는 throw 대신 `AppLogger`로 로그만 남김 (무음 루프 실패가 앱 크래시를 유발하면 안 됨)
- 접근 제어자 명시 (`private`, `private(set)`)

## 테스트 고려사항

- `AudioServiceProtocol`에 `startSilentLoop()`, `stopSilentLoop()` 추가하여 Mock에서 테스트 가능
- Mock 구현에서는 `startSilentLoopCalled: Bool`, `stopSilentLoopCalled: Bool` 플래그로 호출 여부 확인 가능
- AppDelegate의 생명주기 메서드는 Mock AudioService를 주입하여 단위 테스트 가능
