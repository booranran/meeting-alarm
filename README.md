# MeetingAlarm 🔔

macOS 메뉴바에서 캘린더 회의 시작 전 음악을 틀어주는 앱


---

## 미리보기

- 회의 N초 전부터 메뉴바에 카운트다운 표시
- 10초 전부터 깜빡임, 3초 전부터 빠르게 깜빡임
- 설정한 음원 자동 재생
- 회의 시작 시 `회의명 is live!` 표시

---

## 요구사항

- macOS 13 이상
- Xcode 14 이상
- [Homebrew](https://brew.sh)

---

## 설치

### 1. 의존성 설치

```bash
brew install yt-dlp ffmpeg
```

### 2. Xcode 프로젝트 설정

1. Xcode에서 새 macOS App 프로젝트 생성 (이름: `MeetingAlarm`, SwiftUI)
2. 아래 파일들을 프로젝트에 추가:
   - `MeetingAlarmApp.swift`
   - `AlarmManager.swift`
   - `AudioManager.swift`
   - `BannerWindowController.swift`
   - `ContentView.swift`
3. **Signing & Capabilities** 탭에서 App Sandbox 🗑️ 삭제
4. **Info** 탭에서 아래 키 추가:

   | Key | Value |
   |-----|-------|
   | Privacy - Calendars Full Access Usage Description | 회의 일정을 읽어 알림을 재생합니다 |

5. `Cmd+R`로 빌드 & 실행

### 3. 음원 추가

1. 메뉴바 아이콘 클릭 → **음원 관리** 탭
2. YouTube URL 입력 후 **⬇ 다운로드**
3. 다운로드된 음원 옆 ✓ 클릭해서 선택

### 4. 알림 규칙 설정

1. **알림 규칙** 탭
2. 규칙 옆 드롭다운에서 음원 선택
3. 토글로 ON/OFF

### 5. 최종 빌드 (항시 사용)

1. **Product > Archive**
2. Organizer에서 **Distribute App > Custom > Copy App**
3. 생성된 `MeetingAlarm.app`을 `/Applications`로 이동
4. 시스템 설정 > 일반 > 로그인 항목에 추가

---

## 트러블슈팅

| 문제 | 해결 |
|------|------|
| 캘린더 접근 요청이 안 뜸 | `tccutil reset Calendar boran.MeetingAlarm` 후 재실행 |
| 음원 다운로드 실패 | `brew install yt-dlp ffmpeg` 확인, ffmpeg 경로 문제 시 `AudioManager.swift`에 `--ffmpeg-location /opt/homebrew/bin/ffmpeg` 추가 |
| 음원이 재생 안 됨 | 음원 관리 탭에서 음원에 ✓ 체크 되어 있는지 확인 |
| 캘린더 연동 안 됨 | 시스템 설정 > 개인정보 보호 > 캘린더에서 MeetingAlarm 허용 |
| Archive 시 signing 오류 | Signing & Capabilities에서 Automatically manage signing 체크 확인 |

## 주의사항
> ⚠️ Bundle Identifier는 반드시 본인 것으로 변경해주세요.
> Xcode > Signing & Capabilities > Bundle Identifier
> 형식: com.{이름}.MeetingAlarm
