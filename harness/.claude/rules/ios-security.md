---
paths:
  - "**/*.swift"
---
# iOS Security Rules

## Secret Management

- **빌드 타임 시크릿**: `Secrets.xcconfig`에 저장. 이 파일은 `.gitignore`에 반드시 포함.
- **런타임 시크릿**: **Keychain Services** 사용 -- 토큰, 비밀번호, 키 등 민감 데이터
- `UserDefaults`에 민감 데이터 절대 저장 금지
- 소스 코드에 시크릿 하드코딩 절대 금지

### Secrets.xcconfig 패턴

```
# Secrets.xcconfig (절대 커밋하지 않음 — .gitignore 필수)
API_KEY = sk-xxxxxxxxxxxx
FIREBASE_KEY = AIzaxxxxxxxxxx
```

```swift
// Info.plist에서 읽기
let apiKey = Bundle.main.infoDictionary?["API_KEY"] as? String
```

### 커밋 전 민감사항 검사 (필수)

**git add/commit 전에 반드시 아래 항목을 확인한다:**

1. `Secrets.xcconfig`이 staged 되어 있지 않은지
2. 소스 코드에 API 키, 토큰, 비밀번호가 하드코딩되어 있지 않은지
3. `.env`, `.xcconfig` (Secrets 관련), `credentials`, `*.p12`, `*.pem` 파일이 포함되지 않았는지

```bash
# 이 명령어로 민감 파일이 staged 되어 있는지 확인
git diff --cached --name-only | grep -iE '(secret|credential|\.env|\.p12|\.pem|apikey)'
```

**위반 시 즉시 unstage하고 사용자에게 알린다.**

## Transport Security

- App Transport Security (ATS) 비활성화 금지
- 중요 엔드포인트에 Certificate Pinning 적용
- 모든 서버 인증서 검증

## Input Validation

- 사용자 입력은 표시 전 반드시 sanitize
- `URL(string:)` 사용 시 force-unwrap 금지
- 외부 데이터(API, 딥링크, 페이스트보드) 처리 전 유효성 검증

## Data at Rest

- 민감 파일은 `FileManager` + `Data.WritingOptions.completeFileProtection` 사용
- Core Data / SwiftData 암호화 검토
- 앱 스냅샷에 민감 정보 노출 방지 (`applicationWillResignActive`에서 마스킹)

## Authentication

- 생체인증(Face ID/Touch ID)은 `LAContext` 사용, 실패 시 폴백 제공
- 세션 토큰은 Keychain에 저장, 만료 시 자동 갱신 또는 로그아웃
