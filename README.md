# 일본어 완전정복

**가나부터 JLPT N1까지**

## V1 미리보기 다운로드 · 1.0.13

[**APK·ZIP 다운로드 (GitHub Releases)**](https://github.com/ohdh95/JLPT_Learning/releases/tag/v1.0.13-beta.1)

- `jlpt-study-release.apk`: 범용 Android APK. 기기 종류가 불확실하면 이 파일을 사용하세요.
- `jlpt-study-arm64-release.apk`: ARM64 Android 휴대폰용 APK. 범용판과 기능이 같고 파일이 작습니다.
- 각각의 `.apk.zip`도 제공합니다. ZIP은 압축을 풀고 안의 APK를 설치하세요.

두 APK는 디버그 빌드가 아닌 **release 빌드이며 별도의 배포 키로 서명**합니다. 버전은 `1.0.13+14`입니다. 기존 디버그 앱에서 전환할 때는 서명이 달라 업데이트 설치가 거부되므로 **기존 앱 설정에서 백업 → 기존 앱 삭제 → release APK 설치 → 백업 복원** 순서로 옮기세요. 백업 파일을 먼저 안전하게 저장하고 확인하세요. 이후 이 저장소의 release APK는 같은 키로 서명합니다.

기능을 사용할 수 있는 미리보기입니다. 한국어 뜻·한자 훈음·예문은 모두 입력되어 있고 AI 검토를 진행했으나 **독립된 사람 검수는 완료되지 않았습니다**. 실제 안드로이드 휴대폰 및 iOS 확인도 남아 있습니다. [현재 배포 검증 결과](docs/V1_RELEASE_STATUS.md)와 [배포용 APK 빌드·서명 방법](docs/ANDROID_RELEASE.md)을 참고하세요. 아래의 버전별 기록은 개발 이력입니다.

1.0.12+13에서 한자 탭에도 **급수 선택·급수별 학습 완료 수/전체 수·이어서 학습**을 추가했습니다. 이어서 학습은 N5→N1 순서의 첫 미학습 한자를 엽니다. 앱 이름·부제와 벚꽃색 **あ** 아이콘을 유지합니다. 최신 검사 및 빌드 결과: [reports/KANJI_HOME_UPDATE.md](reports/KANJI_HOME_UPDATE.md). 아이콘 변경: [reports/ICON_UPDATE.md](reports/ICON_UPDATE.md).

Flutter/Dart로 만든 Android 우선 오프라인 단어·한자 학습 앱입니다. iOS 프로젝트도 포함합니다. 사용자 계정, 서버, API 키 없이 동작하며 콘텐츠와 사용자 기록을 별도 SQLite 파일에 저장합니다.

**1.0.9+10: 학습 표시와 이어서 학습을 정리하고 한자 테스트를 추가했습니다.** 정답 보기를 누른 단어·한자는 목록의 칸 전체를 회색 배경으로 표시하며 상세의 체크 버튼으로 개별 해제하거나 목록에서 체크한 항목의 **학습 표시 해제**로 일괄 해제할 수 있습니다. 글자는 기본 굵기를 유지합니다. **이어서 학습은 N5 첫 단어부터 N1 마지막 단어까지 순서대로, 아직 학습하지 않은 첫 단어를 엽니다.** 단어·한자 상세는 목록/검색/페이지와 관계없이 급수 경계를 넘어 이동합니다. 상태 필터·이어서 테스트·자기 평가·테스트 앞뒷면 설정은 제거했습니다. 하단은 **단어 · 한자 · 가나 · 별표 · 문법**입니다. 최신 변경과 실제 검사: [reports/LEARNING_FLOW_UPDATE.md](reports/LEARNING_FLOW_UPDATE.md).

**1.0.5+6: N5~N1 예문 13,718개 전체에 대해 AI 의미·문장 검토를 완료했습니다.** 일본어와 기존 한국어가 같은 예문을 묶은 12,615개 문장쌍을 순서대로 읽고, 3,819쌍(실제 예문 행 4,134개)의 오역·어색한 표현을 고쳤습니다. 한국어 뜻 7,811개와 한자 훈음 2,542자를 제공하며 예문 단어 이동과 별도의 해석 펼치기를 유지합니다. `공개 닫기`는 **정답 닫기**로 바꾸고 `단어 발음은 가나 읽기를 참고하세요` 문구를 삭제했습니다. 독립된 사람 검수는 완료되지 않았고 원문 확인 94건(예문 ID 97개)이 남아 있습니다. 예문 검토 내역: [reports/FULL_EXAMPLE_REVIEW.md](reports/FULL_EXAMPLE_REVIEW.md).

## 빠르게 실행

이미 생성한 `assets/content.sqlite`가 있으므로 일반 앱 실행에는 Python이나 데이터 다운로드가 필요 없습니다.

```powershell
cd C:\projects\jlpt_study
flutter pub get
flutter run
```

설치 파일은 상단의 GitHub Releases에서 받습니다. 소스를 실행하려면 저장소를 clone한 폴더에서 `flutter pub get`, `flutter run`을 실행하세요. `assets/content.sqlite`가 포함되어 처음 실행할 때도 콘텐츠 다운로드가 필요 없습니다. 개발용 debug APK와 배포용 release APK의 서명은 다릅니다. 소스 ZIP에는 Git으로 관리하는 공개 소스·콘텐츠 DB·검수 자료만 포함하며 서명 키와 개인 학습 기록은 포함하지 않습니다.

## 구현한 기능

- 단어 탭(첫 화면): N5~N1 선택, 정답 보기를 누른 단어 수에 따른 진도, 첫 미학습 단어로 이어서 학습. 모든 단어를 학습하면 버튼은 전체 학습 완료로 비활성화됩니다. 중간 단어의 학습 표시를 지우면 다시 이어서 학습 대상이 됩니다.
- 단어/별표 목록: 일본어·가나·한국어 뜻 검색, 급수·품사 필터, 원본 순서로 고정하며 정렬 선택 칸은 없습니다. 상태 필터와 평가 표시는 없습니다.
- 10/20/30/50/100 또는 직접 입력 1~200개 페이지 크기 저장. 이전/다음·페이지 번호 이동·표시 범위/총 건수.
- 현재 페이지 선택/해제, 부분 선택 표시. **단계 전체 선택**은 검색·품사·별표·페이지에 관계없이 선택 급수의 모든 단어를 선택하며 기존 선택을 보존합니다. 모든 급수에서는 **전체 급수 선택**으로 7,811개를 선택합니다. 선택 목록의 개별 해제/선택 해제/테스트도 지원합니다.
- 단어는 학습 화면에서 **정답 보기**를 눌렀을 때 학습 완료로 저장합니다. 열거나 이전/다음으로 넘기기만 해서는 완료되지 않습니다. 한자도 정답 보기를 눌렀을 때 학습 완료로 저장합니다. 완료한 항목은 목록의 칸 전체를 회색 배경으로 표시합니다. 단어는 안정적인 word_id, 한자는 문자로 구분합니다. 상세 상단 체크 버튼으로 개별 표시를 해제하고, 목록에서 체크한 항목의 **학습 표시 해제**로 일괄 해제합니다. 전체를 선택하면 전체 표시를 해제할 수 있으므로 설정의 별도 전체 초기화는 제거했습니다. 별표·선택·시험 기록과 독립적입니다. 단어의 정답을 닫아도 완료 표시는 유지됩니다. 개별 표시를 해제한 뒤 다시 정답 보기를 누르면 완료됩니다. 테스트 진행은 이 학습 완료 표시와 독립적입니다.
- 단어·한자 모두 체크박스로 여러 항목을 고른 뒤 **학습 표시 해제**를 누르면 선택한 완료 항목만 미학습으로 되돌립니다. 배경이 원래대로 돌아오고 단어의 이어서 학습에도 반영합니다. 선택 집합과 별표는 유지합니다.
- 한자 상세는 처음에 한자만 보이며 **정답 보기 / 정답 숨기기**로 정보 전체를 열고 닫습니다. 다음 한자는 다시 정답을 숨깁니다.
- 단어 상세는 N5→N4→N3→N2→N1의 원본 순서, 한자 상세는 동일한 급수 순서 안에서 문자 순서로 전체 카탈로그를 이동합니다. 목록 필터/페이지와 관계없이 급수 마지막에서 다음 급수 첫 항목으로 이어지며, 전체 첫/끝에서만 해당 방향 버튼을 끕니다. 급수 미지정 보충 한자는 단독 상세로 표시합니다.
- 학습 상세: 표제어, 읽기, 여러 한국어 뜻, 한국어 품사 분류, 한자 훈음, 검증된 한자별 읽기만 표시, 예문·후리가나·번역·별표·TTS. 학습 카드의 급수는 생략하고 훈음은 **모일 회**처럼 표시합니다.
- 학습 정보 표시 설정을 제거했습니다. 단어 학습은 표제어(한자·가나)만, 한자 상세는 한자 한 글자만 보이는 암기 방식으로 고정합니다. 이전에 저장한 표시 설정도 적용하지 않습니다. **정답 보기**로 읽기·뜻·훈음 등을 열고, 다음 항목으로 이동하면 다시 숨깁니다. 예문과 해석은 각각 기본 접힘입니다. 이전/다음/정답 버튼은 하단에 고정합니다.
- 예문은 기본 접힘입니다. 펼쳐도 번역은 각 문장의 **해석 보기**로 따로 엽니다. 예문을 접거나 다른 단어로 이동하면 해석도 접힙니다. 밑줄 친 예문 단어를 누르면 상세로 이동하며 같은 표기에 여러 후보가 있으면 읽기·뜻을 보고 선택합니다.
- 단어의 한자 풀이를 누르면 해당 한자 상세를 엽니다. 관련 단어는 기본 접힘이며 다른 한자로 이동하면 다시 접고 스크롤을 맨 위로 돌립니다. 돌아오면 원래 단어 카드의 임시 정답 표시·선택·별표·설정을 유지합니다.
- 한자 탭 첫 화면: N5~N1 급수 선택과 각 급수의 완료 수/전체 수, 진도 막대, **이어서 학습**을 제공합니다. 급수를 선택하면 해당 한자 목록을 엽니다. 이어서 학습은 전체 N5→N1 순서의 첫 미학습 한자를 열며, 정답 보기를 눌러야 완료됩니다. 완료 후 첫 화면의 진도가 갱신되며 모두 완료하면 버튼을 비활성화합니다. 한자·한국식 훈·음 검색, 칸에는 한자와 훈음만 표시합니다. **한자 테스트**는 체크박스로 선택한 한자만 급수와 페이지를 넘나들며 모아 무작위로 출제합니다.
- 단어·한자 테스트: 중복 없이 무작위 출제 → 앞면에는 문제만 → 뒤집으면 정답 정보 표시 → 다음 문제 → 완료 후 **전체 재시험**. 앞면/뒷면 설정, 모름/애매함/알고 있음, 점수·비율·평가별 재시험은 없습니다. 단어 뒷면의 예문/해석은 학습 화면과 동일하게 필요할 때 펼칩니다.
- 이어서 테스트와 기록 화면은 제공하지 않습니다. 기존 시험 데이터는 삭제하지 않으며 새 시험은 정답 확인 후 진행한 사실만 저장합니다. 별표는 시험 결과와 독립적입니다.
- 가나 탭: 기본 46개, 탁음·반탁음 25개, 요음 36개는 히라가나/가타카나/한글 발음, 외래어 33개는 가타카나/한글 발음으로 표시합니다. ファ·ティ·ヴァ 등을 포함하며 한글은 근사 발음입니다.
- 시스템/밝은/어두운 테마, 글자 크기 확장, 버튼 접근성 설명, 일본어 기기 TTS. 일본어 음성이 없거나 플랫폼 오류가 발생하면 안내합니다.
- 사용자 데이터 JSON 백업/복원에 학습 표시도 포함하며 이전 버전 백업도 읽습니다. 기존 버전에는 정답 보기 누름 기록이 없으므로 마지막 방문 위치나 자기 평가만으로 완료를 추정하지 않습니다.
- 데이터 안내·참고 자료·검수 현황 화면은 제거했습니다. 출처·라이선스 고지와 내부 검수 근거는 유지합니다.

## 품사·활용 문법 · 1.0.2+3

- 학습용 분류: 명사, 1단동사, 5단동사, 불규칙동사, い형용사, な형용사, 부사, 연체사, 접속사, 조사, 감동사, 조동사. 단어/별표 목록에서 필터링할 수 있고 여러 용법은 중복 분류합니다. 필터를 바꿔도 기존 선택은 유지합니다.
- 카드에서 품사 옆 **자세히**를 누르면 자동사·타동사, 접두사·접미사·관용표현 등 보조 태그를 볼 수 있습니다. 예: `v5u, vi` → **5단동사**, 상세 태그 **자동사**. 원본 코드는 DB에 보존합니다.
- `vs`는 「する와 결합하는 명사」일 수 있으므로 勉強 자체를 무조건 불규칙동사로 표시하지 않습니다. 실제 する로 끝나는 동사와 구별합니다. `aux-v`/`aux-adj`는 보조동사/보조형용사로 처리하며 조동사에 일괄 편입하지 않습니다. 筈(はず)는 형식명사로 구분합니다. 원본의 품사 누락 11개는 임의로 검증 완료 처리하지 않습니다.
- **문법 탭**: 1단·5단·불규칙동사, い·な형용사의 활용표를 오프라인으로 제공합니다. 기본 활용은 펼쳐 두고 정중형, 가능·수동·사역·조건·의지 등은 필요할 때 펼칩니다. 문법 열람 기록은 저장하지 않습니다.
- 5단동사 て/た형 어미별 규칙, 行く/ある/う어미의 예외, 来る의 읽기 변화, いい의 예외, きれい/嫌い의 な형용사 분류를 설명합니다. 대표형의 학습 자료이며 모든 단어의 활용을 자동 생성하는 기능은 아닙니다.
- 한자 훈음은 **모일 회**처럼 표시합니다. 훈만/음만 숨기기를 유지하며 1.0.4부터 학습 화면의 미검수 표시는 생략합니다. 예문 기본 접힘·급수 제거·하단 이동 버튼 고정도 유지합니다.
- 문법 참고 자료의 화면 표시는 제거하고 자료 근거는 소스와 문서에 보관합니다. [도쿄외국어대 문법 모듈](https://www.coelang.tufs.ac.jp/mt/ja/gmod/), [국립국어연구소 동사 핸드북](https://www2.ninjal.ac.jp/verbhandbook/), [국제교류기금 문법 해설](https://www.jpf.go.jp/j/urawa/j_rsorcs/textbook/dl/setsumei/setsumei_all.pdf)의 규칙을 대조해 한국어 학습 설명을 작성했습니다. 사전 DB의 한국어 검수 완료를 의미하지 않습니다.

문법 변경 당시 검사: [reports/GRAMMAR_UPDATE.md](reports/GRAMMAR_UPDATE.md). 전체 예문 검토: [reports/FULL_EXAMPLE_REVIEW.md](reports/FULL_EXAMPLE_REVIEW.md).

## 데이터와 검증 현황

전체 데이터의 실제 수입 결과이며 8개 샘플 DB를 전체 데이터로 사용하지 않았습니다.

| 급수 | 단어 | 신규 한자 |
|---|---:|---:|
| N5 | 674 | 84 |
| N4 | 630 | 169 |
| N3 | 1,659 | 387 |
| N2 | 1,778 | 398 |
| N1 | 3,070 | 1,345 |
| 합계 | **7,811** | **2,383** |

- 일본어 예문 **13,718개**. 원본 JSON의 예문/후리가나/Tatoeba ID 유지.
- 원본 `data/json/meta.json`의 v0.3.0 건수와 일치. JSON 묶음 SHA-256: `f76ef66975760a30c323ef81937930ca2a293d541f9fdbc73200b57ec1fd19df`.
- JMdict 원본 **218,969개 항목**을 실제 읽고 7,811개 단어를 대조: 표기+읽기+ID 일치 **7,788**, 조합 미발견 **21**, ID 불일치 **2**. `reports/jmdict.json`, `reports/audit/issues.csv`에 기록.
- JMdict 원본 SHA-256: `aacc8703771759ad302f01199db13e83043fdf8cabb2357df742e9e758e8aa8d`.
- 한국어 뜻 **7,811/7,811개** 입력. 일본어 표기·읽기와 원본 영어 풀이를 참고해 AI가 작성하고 검토했습니다. 현재 JMdict의 의미·읽기 제한도 추가 대조했으나 독립된 한국어 사전 검수 완료를 뜻하지 않습니다.
- 한국식 훈음 **2,542/2,542자** 입력. 위 급수 한자 2,383자와 단어에만 등장하는 159자를 포함합니다. 보충 한자에는 임의의 JLPT 급수나 일본어 음독·훈독을 생성하지 않았습니다. 11,182개 단어–한자 연결에서 훈음 누락 0입니다.
- libhangul 훈음과 Unicode 17.0 Unihan을 비교하고 대표 훈음/이체자를 수정했습니다. 한국음 자동 대조: 일치 2,520자, 비교값 없음 21자, 불일치 1자(涸). 일치는 한국어 훈·문맥의 정확성을 인증하지 않습니다.
- 한국어 예문 **13,718/13,718개** 반영. 원본 영어 풀이를 Google Translate로 번역하고, 기존 일본어 대조 교정과 이번 추가 교정을 우선 적용했습니다. 요청 문장과 응답 원문 구간을 완전히 대조하여 번역이 다른 예문에 붙는 것을 차단합니다. 동일한 일본어 **및 영어** 문장에만 교정을 공유합니다.
- 기존 M2M100 후보 13,713개와 시험한 MADLAD 후보는 품질 문제로 **앱에 수입하지 않았습니다**. 현재 사용한 번역 방식은 항목별 `localization_provenance`에 기록합니다. 자동 형식 검사 통과가 모든 의미·문맥의 정확성을 보장하지는 않습니다.
- 한국어 뜻·한자 훈음·예문 번역 **사람 검수 완료는 각각 0개**이며 DB 상태는 `draft`입니다. 학습 화면의 상태 배지와 설정의 데이터 검수 화면은 생략하고 보고서·DB 검수 이력은 유지합니다. 원문과 사전 연결의 모순은 `source_review`에 남깁니다.
- `明日`, `明後日` 등 글자별 읽기는 임의 분해하지 않습니다. 현재 분해 데이터는 `not_verified`; 음독/훈독 목록은 특정 단어에서의 실제 발음과 구분합니다.
- JMdict 대조는 표기/읽기/ID에 한정됩니다. 품사·의미 구분, 한국어 정확성, 예문 자연스러움, 급수 정확성을 인증하지 않습니다.
- `release_gate.py --strict`는 현재 **종료 코드 2로 차단**합니다. 확정 배포 가능 단어 0개. 학습용 콘텐츠 제공과 독립된 편집 검수 완료는 구분합니다.

## Windows 설치·실행·APK 생성

Linux PC에서 이미 만든 APK를 실행하려면 아래 **Linux PC · Android 에뮬레이터** 절을 사용하세요. 이 절의 Windows 명령은 Android 앱 개발·실행용이며 Windows 전용 EXE가 아닙니다.

### 1. 개발 환경

1. [Git for Windows](https://git-scm.com/downloads/win)와 [Flutter SDK](https://docs.flutter.dev/install/manual)를 설치합니다. 이 프로젝트는 **Flutter 3.47.8 / Dart 3.13.7**로 검사했습니다. SDK를 예컨대 `C:\dev\flutter`에 풀고 `C:\dev\flutter\bin`을 PATH에 추가한 뒤 PowerShell을 새로 엽니다.
2. [Android Studio](https://developer.android.com/studio)를 설치하고 SDK Manager에서 **Android SDK Platform 36, Platform 35, Build-Tools 36.0.0, Platform-Tools, Command-line Tools**를 설치합니다. 기본 NDK는 **28.2.13676358**이며 Gradle에서 필요 시 설치합니다.
3. Android Studio의 호환 JDK 또는 **JDK 17**을 사용합니다. Java 11은 이 프로젝트 Gradle과 호환되지 않습니다.
4. 경로는 설치 위치에 맞게 설정합니다. 아래 사용자 경로를 그대로 복사하지 말고 자신의 설치 위치로 바꿉니다.

```powershell
flutter --version
flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"
# JDK 17을 별도로 설치한 경우 실제 설치 폴더를 지정
flutter config --jdk-dir "C:\dev\jdk-17"
flutter doctor --android-licenses
flutter doctor -v
```

### 2. 휴대폰 또는 에뮬레이터

- 휴대폰: 개발자 옵션과 USB 디버깅을 켜고 연결한 뒤 휴대폰에서 해당 PC를 허용합니다. 필요하면 제조사 USB 드라이버를 설치합니다.
- 에뮬레이터: Android Studio Device Manager에서 API 36 기기를 생성하고 시작합니다.

```powershell
cd C:\projects\jlpt_study
flutter pub get
flutter devices
flutter run -d <기기_ID>
```

일본어 발음은 Android 설정의 텍스트 음성 변환에서 일본어 음성 데이터를 설치한 뒤 확인합니다. 음성 데이터가 준비되어야 오프라인에서도 재생할 수 있습니다. 녹음 파일이나 유료 음성 API는 사용하지 않습니다.

### 3. 검사와 APK

```powershell
flutter analyze
flutter test
flutter test integration_test/app_test.dart -d <기기_ID>
flutter build apk --debug
```

초기 버전에서는 Flutter CLI의 DDS/VM 연결 및 golden stream 오류가 있어 Android instrumentation으로 **1개 통과**를 확인했습니다. 1.0.9에서는 Flutter 호스트 테스트 59개를 실행했으며, 실제 사용 중인 에뮬레이터의 선택 데이터를 바꾸는 instrumentation 테스트는 재실행하지 않았습니다. 아래 통합 테스트는 별도의 테스트 기기에서 실행하세요. 동일한 오류가 나면 다음 경로를 사용할 수 있습니다.

```powershell
cd android
.\gradlew.bat app:connectedAndroidTest -Ptarget=integration_test/app_test.dart
cd ..
# 통합 테스트 APK와 일반 앱 APK는 다릅니다. 전달용 APK를 다시 생성합니다.
flutter build apk --debug
```

생성 파일: `build\app\outputs\flutter-apk\app-debug.apk`. 설치:

```powershell
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

`-r` 업데이트는 동일한 앱 ID와 서명에서 사용자 DB를 유지합니다. 앱을 먼저 삭제하면 내부 기록도 삭제되므로 설정의 백업 기능을 사용하세요. 새 PC에서 만든 디버그 서명이 다르면 업데이트 설치가 거부될 수 있습니다.

1.0.13부터 release는 별도의 배포 키로 서명합니다. `android/key.properties`가 없으면 release 빌드를 차단하며 debug 키로 대체하지 않습니다. 공개 저장소에는 개인 키를 포함하지 않으므로 [배포 빌드 안내](docs/ANDROID_RELEASE.md)에 따라 설정해야 합니다. Google Play 등록은 수행하지 않았습니다.

현재 `file_picker`, `flutter_tts`가 기존 Kotlin Gradle 플러그인을 사용한다는 Flutter 호환성 경고가 출력됩니다. 현재 빌드 결과와 향후 Flutter 버전 호환성은 구분해야 합니다. `pubspec.lock`을 유지하고 SDK 변경 시 다시 검사하세요.

### 4. iOS

`ios/`를 생성했으며 Dart 도메인·SQLite·TTS 코드가 Android 전용 API에 묶이지 않습니다. 실제 iOS 빌드/설치는 미실행입니다. **아이폰에는 APK를 설치할 수 없습니다.** iOS 앱은 macOS의 Xcode에서 별도로 빌드·서명해야 하며, 보통 TestFlight 또는 App Store로 설치합니다. 현재 Linux PC만으로 로컬 iOS 빌드를 완료할 수는 없습니다([Flutter 공식 안내](https://docs.flutter.dev/deployment/ios), [Apple TestFlight](https://developer.apple.com/testflight/)). macOS + Xcode + CocoaPods 환경에서 서명 설정 후 `flutter run -d <iPhone_ID>` 또는 `flutter build ios --no-codesign`으로 별도 확인해야 합니다.

## Linux PC · Android 에뮬레이터

이 PC(Ubuntu 22.04, x86_64)에는 Android API 36 에뮬레이터와 범용 APK가 준비되어 있습니다. Android Studio나 Flutter를 새로 설치하지 않고 다음으로 실행합니다.

```bash
cd /home/ohdh95/graph/jlpt_study
./run-emulator.sh
```

앱 메뉴의 **일본어 완전정복 (Android)** 바로가기로도 실행할 수 있습니다. 에뮬레이터 창에서 마우스로 조작합니다. 가상 기기를 종료한 뒤에도 다시 같은 기기를 사용하며 학습 기록을 유지합니다. 실행 스크립트는 기존 기기를 재사용하고 `adb install -r`로 앱을 갱신합니다. 앱 삭제나 가상 기기 초기화는 하지 않습니다.

- SDK: `~/.local/share/jlpt-study/android-sdk/`.
- 가상 기기: `~/.local/share/jlpt-study/avd/jlpt_test_device.avd/`.
- 실행 로그: `~/.local/share/jlpt-study/emulator.log`.
- 이 PC의 재부팅 후에도 사용할 수 있도록 임시 폴더 밖에 보관했습니다.
- PC용 가상 기기가 x86_64이므로 **범용 APK**를 사용합니다. ARM64 전용 APK는 이 구성의 선택 대상이 아닙니다.
- 원래 APK의 데이터 검수 상태와 기능은 동일합니다. 일본어 TTS 음성이 설치돼 있지 않으면 Android의 음성 설정에서 별도로 설치해야 합니다.

다른 Linux PC에서는 [Android Studio](https://developer.android.com/studio)를 설치하고 Device Manager에서 가상 기기를 만든 뒤, 범용 APK를 가상 기기 화면으로 끌어다 놓아 설치할 수 있습니다([공식 안내](https://developer.android.com/studio/run/emulator-install-add-files)). 위 스크립트를 재사용한다면 `JLPT_ANDROID_SDK`에 SDK 경로, `JLPT_AVD_NAME`에 생성한 가상 기기 이름을 지정하세요. 새 PC에서는 KVM 사용 권한도 확인해야 합니다.

별도로 시도한 Linux 전용 데스크톱 변경은 `dist/jlpt-linux-desktop-wip-source.zip`에 보관했습니다. 사용자의 에뮬레이터 선호에 따라 앱 소스는 기존 Android 구현으로 되돌렸으며, 미완료 데스크톱 버전을 정식 실행 파일로 제공하지 않습니다.

## 전체 원본 재다운로드와 DB 재생성

Python **3.10 이상**이 필요합니다. 원본 수입·사전 대조·저장된 번역 재적용에는 외부 Python 패키지가 필요 없습니다. 예문 단어 연결 재생성에는 아래 Sudachi 의존성이 별도로 필요합니다. 명령은 프로젝트 루트에서 실행합니다.

```powershell
py -3 pipeline/fetch_sources.py --out downloads
py -3 pipeline/build_database.py --archive downloads/OpenJLPT-main.zip --out assets/content.sqlite --progress-out downloads/example_user.sqlite --report reports/import.json
py -3 pipeline/verify_jmdict.py --db assets/content.sqlite --jmdict downloads/JMdict_e.gz --report reports/jmdict.json
```

`downloads/source_manifest.json`에 다운로드 URL·시각·바이트 수·SHA-256을 기록합니다. 원본 ZIP 및 JMdict 파일은 downloads에 보관합니다. 첨부 CSV 초안을 함께 넣으려면:

```powershell
py -3 pipeline/seed_supplied_drafts.py --db assets/content.sqlite --sample-db pipeline/fixtures/supplied_v1_4/jlpt_learning_sample.sqlite
```

다른 수입 경로:

```powershell
py -3 pipeline/build_database.py --download --out assets/content.sqlite --report reports/import.json
py -3 pipeline/build_database.py --source-dir C:\data\OpenJLPT --out assets/content.sqlite --report reports/import.json
```

- `--download`는 원본을 임시 디렉터리에 내려받습니다. 원본 보존과 재현성을 위해 `fetch_sources.py` + `--archive` 조합을 권장합니다.
- 다운로드한 메타데이터와 실제 급수별 건수가 다르면 전체 수입을 실패 처리합니다. 새 버전은 원본 메타데이터와 비교하고, 기존 v0.3.0 기준과의 차이를 알립니다.
- `--allow-partial`은 오직 테스트용입니다. 누락된 파일/중복 ID/필수값/ZIP 경로 탈출/과도한 압축 해제를 검증합니다.
- 콘텐츠 DB는 임시 파일에 구축 후 정상 완료 시 교체합니다. 기존 사용자 DB 경로가 존재하면 보존합니다. Python의 example_user.sqlite는 명세 참고용이며, 앱은 자체 스키마의 user.db를 생성합니다.
- 새 콘텐츠 구축은 이전 현지화 내용을 자동 병합하지 않습니다. **작성한 원본 검수 CSV를 별도 보관한 뒤 새 DB에 재수입**하세요. 이미 작성한 CSV 폴더에 빈 템플릿을 덮어쓰지 마세요.
- 재구축 후 앱을 다시 빌드/설치하면 자산 전체 해시가 다른 새 콘텐츠 파일을 복사하고 user.db를 그대로 엽니다. 앱 내 임의 콘텐츠 파일 가져오기 UI는 제공하지 않습니다.

JMdict 다운로드에서 `ftp.edrdg.org` HTTPS 인증서 호스트 불일치를 실제로 확인하여, 인증서 검증이 정상인 공식 `www.edrdg.org/pub/Nihongo/JMdict_e.gz`로 받았습니다. TLS 검증을 끄거나 실패한 다운로드를 성공 처리하지 않습니다. 네트워크 장애 시 마지막 정상 DB를 보존하고 명령을 다시 실행하세요.

## 한국어 현지화 재적용 · 1.0.5+6

단어·훈음 원본은 `pipeline/localization/word_meanings_ko.jsonl`, `hanja_candidates.jsonl`입니다. 전체 예문 최종본은 `example_full_review.jsonl`이며 `full_review/input.jsonl`에 수정 전 원문, `decisions.jsonl`에 전수 검토 결정, `source_issues.jsonl`에 미해결 원문 문제, `manifest.json`에 전체 건수와 SHA-256을 기록합니다. 이전 `example_service_drafts.jsonl`, `example_editorial_drafts.jsonl`, `example_corrections.jsonl`은 변경 이력과 초기 번역 재현용으로 보존합니다. 전체 검토본이 최종 우선 적용됩니다. 원본을 다시 구축한 뒤 다음을 실행하면 저장된 번역을 재수입합니다. 번역 재적용에는 인터넷·계정·번역 모델이 필요 없습니다.

```powershell
py -3 pipeline/apply_localization.py --db assets/content.sqlite
py -3 pipeline/apply_example_translations.py --db assets/content.sqlite
py -3 -m pip install SudachiPy==0.6.11 SudachiDict-core==20260723
py -3 pipeline/build_example_links.py --db assets/content.sqlite --jmdict downloads/JMdict_e.gz
py -3 pipeline/audit_report.py --db assets/content.sqlite --outdir reports/audit
py -3 pipeline/korean_localization.py --db assets/content.sqlite --export review_templates_next
```

- stable ID 전체 집합과 일본어 표기·읽기·급수가 같아야 단어 초안을 수입합니다. 원문이 바뀌면 중단하고 재검토합니다.
- 구성 한자 159자는 급수/일본어 읽기 없이 보충합니다. 초기 예문 교정은 일본어와 영어가 모두 같을 때 공유합니다. 이번 전수 검토는 **일본어와 기존 한국어가 같은 문장쌍**을 묶어 일본어에 직접 대조했으며, 각 ID의 영어 원문도 따로 보존·검증합니다. ID 누락·중복, 원문 변경, 부분 검토, 해시 불일치가 있으면 최종 검토본 수입을 중단합니다.
- 자동 수입기는 `human_reviewed`를 생성할 수 없고 기존 사람 검수 값을 덮어쓰지 않습니다. 값과 근거가 같으면 반복 실행해도 이력을 추가하지 않습니다.
- 근거/원문/이체자/대안 훈음/AI 작성 방식은 `localization_provenance`, 변경 전후는 `localization_history`에 보존합니다. 폐기한 모델 후보와 모델 가중치는 앱 자산에 넣지 않습니다.
- 최신 수정 번역을 담은 사람 검수용 CSV: `review_templates/full_examples_20261028/`. 이전 예문 템플릿: `review_templates/examples_20261028/`. 이전 버전 템플릿은 `review_templates/localization_20261028/`에 보존합니다.
- 추가 데이터 파일의 URL·크기·SHA-256: `reports/localization-sources.json`. libhangul hanja.txt의 **파일별 BSD 3-Clause**, Unicode 라이선스, Tatoeba 한국어 문장 저자·ID·CC BY 2.0 FR 고지는 앱의 출처 화면과 `assets/LOCALIZATION_NOTICE.txt`에 포함합니다.

현재 JMdict 의미를 다시 추출해 비교하려면 공식 JMdict 파일을 먼저 내려받고 실행합니다. 영어 풀이의 문자열 차이는 오류 확정 수가 아닙니다.

```powershell
py -3 pipeline/compare_jmdict_senses.py --db assets/content.sqlite --jmdict downloads/JMdict_e.gz
```

한자 생성기는 `pipeline/localize_hanja.py`입니다. 원본 `libhangul-hanja.txt`와 Unicode 17.0 `unihan-fields.json`, 편집한 `kanji_variants.json`/`hanja_overrides.json`을 사용합니다. 앱 재빌드에는 이미 포함된 후보 JSONL만 있으면 됩니다. 신자체 대응/다음자의 대표음 선택은 검수 대상입니다.

1.0.4의 초기 전체 번역 생성기는 `pipeline/translate_examples_service.py`입니다. 1.0.5 전수 검토에서는 새 번역 API나 모델을 호출하지 않고 저장된 일본어와 한국어를 읽어 교정했습니다. 공개된 원자료의 영어 풀이만 Google Translate 웹 엔드포인트에 보내며 사용자 학습 기록은 보내지 않습니다. 계정·유료 API는 사용하지 않았습니다. 이 웹 엔드포인트는 안정성이 보장되는 계약형 API가 아니므로 서비스 변경·실패 시 중단하며, 저장된 결과로 재현하는 것을 권장합니다. 재생성이 필요하면 별도 가상환경에 `requests`를 설치한 뒤 `python pipeline/translate_examples_service.py --db assets/content.sqlite`를 실행합니다. 요청 간격·재시도·원문 구간 대조·재개 캐시를 포함합니다. 기존 M2M100/MADLAD 스크립트와 후보는 비교 기록이며 현재 번역 수입 경로가 아닙니다.

예문 연결은 Sudachi 형태소 분석의 단어 경계와 사전형, 같은 JMdict ID에서 읽기 제한을 만족하는 대체 표기로 만듭니다. 현재 13,718개 예문 모두에 연결이 있고 72,895개 단어 연결을 저장했습니다. Dart 문자열과 맞는 UTF-16 위치를 저장해 앱에서는 사전 엔진 없이 오프라인으로 표시합니다. 형태소 분석·동형이의어의 문맥 판정은 완벽하지 않으며 이 수치는 문맥 검수 완료 수가 아닙니다. Sudachi 사전 자체를 APK에 넣지 않으며 관련 Apache 2.0 고지를 포함합니다.

## 한국어·편집 검수 절차

```powershell
py -3 pipeline/korean_localization.py --db assets/content.sqlite --export review_templates_new
```

- `word_meanings_review.csv`: 한국어 뜻. 여러 뜻은 세미콜론으로 구분.
- `kanji_huneum_review.csv`: 한국식 훈과 음.
- `example_translation_review.csv`: **해당 일본어 문장**의 한국어 번역.

`reviewed=1`만으로 검수 완료가 되지 않습니다. `reference_url`, `cross_reference_url` 두 HTTP(S) 출처(서로 다른 호스트), `reviewer`, ISO 형식 `reviewed_at`, `evidence_note`를 모두 기록해야 `human_reviewed`가 됩니다. 출처의 재사용 조건을 확인하고 실제 의미·문맥·훈음을 대조해야 합니다. 이 필드 검사는 근거 기록의 형식을 확인하며 사람의 검수 사실이나 내용의 정확성을 자동 판정하지 않습니다.

```powershell
py -3 pipeline/korean_localization.py --db assets/content.sqlite --import-word reviews/word_meanings_review.csv
py -3 pipeline/korean_localization.py --db assets/content.sqlite --import-kanji reviews/kanji_huneum_review.csv
py -3 pipeline/korean_localization.py --db assets/content.sqlite --import-example reviews/example_translation_review.csv
```

근거가 부족하면 `draft`; 빈 값은 건너뛰고 알 수 없는 ID는 invalid로 집계합니다. `localization_checks`에 최근 상태, `localization_history`에 변경 전/후 값과 근거를 누적 보존합니다. 수정한 텍스트는 이전 검수 상태를 자동 상속하지 않습니다.

품사/의미 구분, 비공식 급수 근거, 일본어 예문 자연스러움의 별도 편집 검수:

```powershell
py -3 pipeline/editorial_review.py --db assets/content.sqlite --export editorial_review.csv
# 내용을 실제 검토하고 근거를 작성한 뒤
py -3 pipeline/editorial_review.py --db assets/content.sqlite --import-csv editorial_review.csv
```

한자별 읽기 분해 데이터는 현재 모두 미검증입니다. 향후 전문 검수자가 실제 대응을 확인한 경우에만 `reading_in_word`와 `reading_alignment_status=verified`를 수입해야 합니다. 분해 불가한 단어는 `whole_word_only_reviewed`로 검토 결과를 기록할 수 있으나 글자별 읽기를 생성하면 안 됩니다. 이 수동 분해 검수의 전용 편집 UI는 아직 없습니다.

## 감사·출시 게이트·테스트

```powershell
py -3 -m unittest discover -s pipeline/tests -v
py -3 pipeline/self_test.py
py -3 pipeline/audit_report.py --db assets/content.sqlite --outdir reports/audit
py -3 pipeline/release_gate.py --db assets/content.sqlite --report reports/release_gate.json
# 모든 필수 편집 검수가 끝났을 때만 종료 코드 0
py -3 pipeline/release_gate.py --db assets/content.sqlite --strict
```

`self_test.py`의 작은 합성 JMdict는 파서 테스트일 뿐입니다. 합성 테스트 옵션은 DB에 `test_fixture_only`를 기록하므로 실제 사전 검증 완료로 둔갑하지 않습니다. 전체 검증 결과는 별도 `reports/jmdict.json`에 있습니다.

검사 범위: 전체 원본 건수/무결성/외래키, 부분 데이터 차단, ZIP 안전성, 사용자 DB 보존, 증거 없는 검수 차단, 변경 이력, JMdict 읽기 제한, 합성 검증 격리, 수천 ID 선택·중복 방지, 페이지·급수·검색·별표 이동, 정답 보기 기준 완료·표시 초기화·첫 미학습 탐색, 고정된 학습·테스트 앞뒷면과 구형 표시 설정 무시, 한자 테스트·재시험·v1 DB 마이그레이션·콘텐츠 갱신·구형 백업 복원, 한국어 모바일 UI와 TTS 실패 처리.

## 구조와 설계 결정

```text
lib/data/         SQLite 저장소, 모델, 기기 TTS 어댑터
lib/state/        ChangeNotifier 기반 사용자 상태와 쓰기 순서 보장
lib/ui/           단어, 카드, 한자, 가나 표, 활용 문법, 설정
assets/           전체 콘텐츠 SQLite와 라이선스 고지
pipeline/         원본 수입, JMdict 대조, 검수 CSV, 감사 및 출시 게이트
review_templates/ 전체 검수 대상 템플릿
reports/          실행한 검사·데이터 감사 결과
android/, ios/    플랫폼 프로젝트
integration_test/ Android 실제 SQLite와 UI 통합 테스트
```

- 상태관리: Flutter 기본 `ChangeNotifier` + `ListenableBuilder`. 전역 선택·별표·프로필이 작은 앱이므로 별도 프레임워크 없이 상태 갱신 경로를 명시했습니다. DB 쓰기를 직렬화하고 성공한 내용만 상태에 반영합니다.
- 라우팅: 기본 `Navigator`와 화면별 route. 계정/서버/웹 딥링크 요구가 없어 추가 라우터를 두지 않았습니다.
- SQLite: Android/iOS는 `sqflite`, 호스트 테스트는 같은 SQL을 `sqflite_common_ffi`로 실행합니다. 검색은 바인딩된 LIKE/instr + 인덱스 + LIMIT/OFFSET입니다. Android SQLite에서 FTS5를 보장하지 않으므로 FTS5 테이블을 제거했습니다.
- 콘텐츠는 SHA-256 이름으로 앱 전용 디렉터리에 복사합니다. 쓰기 쿼리는 user.db에만 수행하고 콘텐츠는 ATTACH로 조회합니다. 사용자 테이블에 콘텐츠 외래키를 걸어 업데이트 시 기록을 삭제하는 동작을 피합니다.
- 세션 시작 시 단어 정보 스냅샷도 저장하므로 원본에서 단어가 사라져도 순서와 평가 기록을 읽을 수 있습니다. 오래된 스냅샷의 예문/한자 부가정보는 현재 콘텐츠에서 조회하므로 제거된 데이터는 표시되지 않을 수 있습니다.
- user.db v3는 `learning_visits`, 한자 선택 `kanji_selection`, 시험 종류 `kind`를 추가합니다. 새 시험 응답은 `seen`이며 평가를 추정하지 않습니다. 구형 평가 값은 마이그레이션과 백업 복원에서 그대로 보존하되 화면에는 표시하지 않습니다. 이어서 학습은 콘텐츠 순서와 학습 완료 집합의 차집합에서 첫 항목을 조회합니다.
- 수천 단어의 선택은 DB 배치 트랜잭션으로, 세션의 대량 조회는 400개씩 나누어 Android 바인딩 한도를 지킵니다. 준비/결과 화면은 미리보기를 제한하고 전체 목록은 필요할 때 지연 생성합니다.

## 명세 충돌과 남은 작업

- v1.4의 네이버 기반 수집 논의보다 v1.5의 OpenJLPT 원천 정책을 우선했습니다. 네이버 자동 수집/우회는 하지 않았습니다.
- 초기 명세의 일반 학습/자기 평가 방식보다 최신 사용자 요청을 우선합니다. 학습 기본값은 모두 숨김이며 테스트 앞면/뒷면은 각각 문제만/정답 정보 모두 표시로 고정합니다. 상태 필터·기록 탭·이어서 테스트는 제공하지 않습니다.
- v1.4의 확정 콘텐츠 출시 게이트와 v1.5의 미검수 미리보기를 분리했습니다. 최신 요청에 따라 학습 화면의 초안·미검수 표시는 제거했으며 DB 상태·내부 보고서와 strict 게이트는 유지하며 앱의 검수 화면은 제거했습니다.
- 한국어 전체 뜻·훈음·예문 번역은 입력했습니다. 예문 전체의 AI 문맥·관용표현 검토를 한 차례 마쳤습니다. 독립된 사람의 내용 검수, 미해결 원문 94건, 동형이의어 연결 검토는 남아 있습니다. 입력 건수와 검수 완료 건수를 혼동하지 않습니다.
- 21개 JMdict 조합 미발견, 2개 ID 충돌 및 카탈로그에 없는 한자 연결 등의 검수 큐를 사람이 해결해야 합니다. 원본을 근거 없이 수정하지 않았습니다.
- 품사 코드 47종은 학습용 분류/보조 태그로 표시합니다. 원본에 품사가 없는 11개 단어는 확인 중으로 남겼습니다. 품사·뜻별 문맥 검수, 풍부한 루비 표시, 한자 획순 애니메이션은 남아 있습니다.
- 실물 Android 기기에서의 음질·설치 엔진별 TTS, 파일 선택기의 제조사별 백업/복원 동작 및 iOS 빌드는 별도 확인이 필요합니다.

## 출처·라이선스

데이터 원본: [OpenJLPT](https://github.com/evanclan/OpenJLPT), [원본 NOTICE](https://github.com/evanclan/OpenJLPT/blob/main/NOTICE.md), [EDRDG JMdict](https://www.edrdg.org/jmdict/j_jmdict.html), [EDRDG 이용 조건](https://www.edrdg.org/edrdg/licence.html), [Jonathan Waller](https://www.tanos.co.uk/jlpt/), [Tatoeba](https://tatoeba.org).

파생 콘텐츠 DB: CC BY-SA 4.0. Tatoeba 문장: CC BY 2.0 FR 및 문장별 기여자 표기. 신규 앱 소스: MIT. 제공된 원본 스크립트/참고 자료의 권리를 변경하지 않습니다. 전체 고지를 `assets/OPENJLPT_NOTICE.txt`, 한국어 안내를 `assets/DATA_NOTICE.txt` 및 앱 설정에서 확인할 수 있습니다. 녹음 음성은 배포하지 않습니다.

## 아이콘 원본

`design/app_icon.svg`가 벡터 원본이며 `design/app_icon.png`로 미리 볼 수 있습니다. `あ` 글자는 Noto Sans CJK JP Bold의 윤곽선을 포함하므로 기기에 폰트를 설치할 필요가 없습니다. 폰트 출처와 라이선스는 `design/ICON_NOTICE.txt`, `design/NOTO_FONT_LICENSE.txt`에 보존합니다. 아이콘을 다시 내보내려면 별도 Python 환경에 `cairosvg`, `Pillow`를 설치하고 `python tool/export_app_icon.py`를 실행합니다. 일반 Flutter 빌드에서는 이미 생성된 리소스를 사용하므로 이 도구가 필요하지 않습니다.
