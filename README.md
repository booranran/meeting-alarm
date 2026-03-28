# 🔔 MeetingAlarm

> 회의 N초 전 BBC 뉴스 음악이 울리는 macOS 메뉴바 앱

---

## 설치 방법

### 1. 사전 준비

```bash
# Homebrew 설치 (이미 있으면 생략)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# yt-dlp 설치 (YouTube 음원 다운로드용)
brew install yt-dlp

# ffmpeg 설치 (mp3 변환용)
brew install ffmpeg
```

### 2. Xcode 프로젝트 생성

1. Xcode 열기 → **File > New > Project**
2. **macOS > App** 선택
3. 이름: `MeetingAlarm`
4. Interface: `SwiftUI`, Language: `Swift`
5. 생성된 기본 파일 삭제 후 이 폴더의 `.swift` 파일 4개 추가:
   - `MeetingAlarmApp.swift`
   - `AlarmManager.swift`
   - `AudioManager.swift`
   - `BannerWindowController.swift`
   - `ContentView.swift`

### 3. Info.plist 설정

`Info.plist`에 아래 항목 추가:

| Key | Value |
|-----|-------|
| `NSCalendarsFullAccessUsageDescription` | 회의 일정을 읽어 알림을 재생합니다 |
| `LSUIElement` | YES |

또는 제공된 `Info.plist`로 교체

### 4. Entitlements 설정

`MeetingAlarm.entitlements` 파일에 추가:
```xml
<key>com.apple.security.app-sandbox</key>
<false/>
```
> 샌드박스 OFF 필요 — yt-dlp 외부 프로세스 실행 때문

### 5. 빌드 & 실행

`Cmd+R`로 빌드하면 상단 메뉴바에 🔔 아이콘이 생깁니다.

---

## 사용법

### 음원 추가

1. 메뉴바 아이콘 클릭 → **음원 관리** 탭
2. BBC 뉴스 오프닝 YouTube URL 붙여넣기
   - 예: `https://www.youtube.com/watch?v=ATC2KyPnhAA`
3. 음원 이름 입력 (예: `bbc_news`)
4. **⬇ 다운로드** 클릭

### 알림 규칙 설정

1. **알림 규칙** 탭
2. 기본 규칙: "회의 10초 전" — 원하는 음원 선택
3. 토글로 ON/OFF
4. **+ 규칙 추가**로 매 정시 알림 등 추가 가능

### 테스트

**🔔 테스트** 버튼 클릭 → 배너 + 음원 즉시 재생

---

## 파일 구조

```
MeetingAlarm/
├── MeetingAlarmApp.swift       # 앱 진입점, 메뉴바 설정
├── AlarmManager.swift          # 캘린더 연동, 타이머, 규칙 관리
├── AudioManager.swift          # yt-dlp 다운로드, AVAudioPlayer 재생
├── BannerWindowController.swift # 상단 배너 윈도우 (슬라이드 애니메이션)
├── ContentView.swift           # 팝오버 UI (규칙/음원 탭)
└── Info.plist                  # 권한 설정
```

---

## 트러블슈팅

| 문제 | 해결 |
|------|------|
| `yt-dlp가 설치되어 있지 않습니다` | `brew install yt-dlp ffmpeg` |
| 캘린더 접근 안됨 | 시스템 설정 > 개인정보 보호 > 캘린더 → MeetingAlarm 허용 |
| 음원이 재생 안됨 | 음원 관리 탭에서 음원 선택(✓) 확인 |
| 배너가 안 보임 | 전체화면 앱 위에서는 배너가 가릴 수 있음 |
