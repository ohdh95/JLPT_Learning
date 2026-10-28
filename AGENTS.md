# JLPT 앱 개발 기준

- 앱 표시 이름은 일본어 완전정복, 부제는 가나부터 JLPT N1까지다. 하단 단어·한자·가나·별표·문법 메뉴 이름은 유지한다. 아이콘은 벚꽃색 배경의 あ와 작은 벚꽃이며 design/app_icon.svg를 원본으로 Android/iOS 리소스를 생성한다.
- 화면/행동은 docs/JLPT_App_Spec_v1_4.md, 데이터는 docs/JLPT_App_Data_Update_v1_5.md를 따른다.
- lib/data는 SQLite와 TTS, lib/state는 영속 사용자 상태, lib/ui는 Flutter 화면이다. 상태 변경은 저장 성공 뒤 반영한다.
- 콘텐츠 assets/content.sqlite와 기기 user.db를 분리한다. 단어는 OpenJLPT stable ID로 연결한다. 업데이트/마이그레이션에서 사용자 DB를 삭제하지 않는다.
- 선택은 ID 집합이다. 필터/페이지 크기/급수/별표 이동이 선택을 지우면 안 된다.
- 학습·테스트 정보 표시 설정 UI는 제공하지 않는다. 단어 학습은 표제어만, 한자 상세는 한 글자만 기본 표시하며 정답 보기로 정보를 연다. 이전에 저장한 표시 설정은 화면에 적용하지 않는다. 테스트 앞면은 문제만, 뒷면은 모든 정답 정보로 고정하며 예문·해석은 기본 접힘을 유지한다.
- 테스트는 자기 평가 없이 뒤집기/다음으로 진행한다. 뒤집은 현재 카드만 원자적으로 진행시키며 새 응답은 seen으로 저장한다. 구형 평가 기록은 보존한다. 이어서 테스트와 상태 필터는 제공하지 않는다.
- 단어는 학습 화면의 정답 보기를 눌렀을 때만, 한자는 정답 보기 시 learning_visits에 학습 표시를 저장하고 목록의 칸 전체를 회색 배경으로 표시한다. 단어 열람/이전·다음/구형 마지막 방문 기록만으로 완료를 추정하지 않는다. 단어·한자 모두 체크박스 선택 후 일괄 학습 표시 해제를 지원한다. 개별/선택 학습 표시 해제는 별표/선택에 영향을 주지 않는다. 설정의 학습 표시 전체 초기화는 제거하고 전체 선택 후 학습 표시 해제로 처리한다. 선택을 비우는 버튼 이름은 선택 해제다. 한자 선택은 kanji_selection에 별도 저장하며 체크한 한자만 테스트한다. 한자 상세도 기본 정답 숨김이다. 단어·한자 탭의 첫 화면에는 각각 급수 선택과 해당 종류의 완료 수/전체 수를 표시한다. 이어서 학습은 N5→N1 전체 순서에서 해당 종류의 첫 미학습 항목을 연다. 한자 진도/이어서 학습은 급수 지정 한자만 대상으로 하고 보충 한자는 제외한다. 상세 이전/다음은 필터/페이지와 관계없이 급수 경계를 넘는다.
- 한국어 필드는 검수 근거가 없으면 not_provided 또는 draft. JMdict 표기·읽기·ID 일치와 한국어/품사/문맥 검수를 혼동하지 않는다.
- 한자별 읽기 자동 추측 금지. 明日/明後日은 검증된 분해가 없으면 전체 읽기만 표시한다.
- Android 기본 SQLite에 FTS5가 있다고 가정하지 않는다. 이 데이터량에서는 매개변수화 LIKE + LIMIT/OFFSET과 인덱스를 사용한다.
- 검증: flutter analyze; flutter test; python -m unittest discover -s pipeline/tests -v; python pipeline/self_test.py; python pipeline/audit_report.py --db assets/content.sqlite --outdir reports/audit; flutter build apk --debug.
- Windows/Linux 테스트는 sqflite_common_ffi를 사용한다. Widget 테스트는 실제 DB I/O를 위한 runAsync/settle이 필요하다. SQL을 가짜 성공으로 대체하지 않는다.
- release_gate.py --strict가 실패하는 현재 데이터는 미검수 미리보기다. 검수 완료 배포본이라고 표시하지 않는다.
- 테스트/빌드 결과와 실기기 미확인 범위를 README 및 reports에 사실대로 기록한다. 원격 푸시/외부 배포는 요청 없이 하지 않는다.
