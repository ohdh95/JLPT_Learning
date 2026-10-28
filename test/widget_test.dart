import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_study/main.dart';
import 'package:jlpt_study/data/models.dart';
import 'package:jlpt_study/ui/cards.dart';
import 'package:jlpt_study/ui/tests.dart';
import 'package:jlpt_study/ui/screens.dart';
import 'support.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pumpAndSettle();
}

void main() {
  late Fixture f;
  late SilentSpeech speech;
  setUp(() async {
    f = Fixture();
    await f.open();
    speech = SilentSpeech();
  });
  tearDown(() async {
    await f.close();
  });
  testWidgets(
    'home, list selection, page change and stars connect to real SQLite',
    (t) async {
      await t.pumpWidget(JlptApp(model: f.model, speech: speech));
      await settle(t);
      expect(find.text('나의 학습 급수'), findsOneWidget);
      expect(find.text('데이터 안내'), findsNothing);
      await t.tap(find.text('N5'));
      await settle(t);
      await t.tap(find.byType(Checkbox).at(1));
      await settle(t);
      expect(f.model.selected.length, 1);
      await t.tap(find.byTooltip('다음 페이지'));
      await settle(t);
      await t.tap(find.byType(Checkbox).at(1));
      await settle(t);
      expect(f.model.selected.length, 2);
      await t.tap(find.byTooltip('별표 추가').first);
      await settle(t);
      expect(f.model.starred.length, 1);
      await t.tap(find.byType(BackButton));
      await settle(t);
      await t.tap(find.text('별표').last);
      await settle(t);
      expect(f.model.selected.length, 2);
      expect(find.textContaining('/ 1'), findsWidgets);
      expect(t.takeException(), null);
    },
  );
  testWidgets(
    'temporary study reveal resets on next card without changing profile',
    (t) async {
      final ids = (await t.runAsync(
        () => f.repo.allIds(const WordFilter()),
      ))!.take(2).toList();
      await t.runAsync(() => f.model.allFields('study', false));
      await t.pumpWidget(
        MaterialApp(
          home: StudyScreen(model: f.model, speech: speech, ids: ids),
        ),
      );
      await settle(t);
      expect(find.text('가나 읽기'), findsNothing);
      await t.tap(find.text('정답 보기'));
      await settle(t);
      expect(find.text('가나 읽기'), findsOneWidget);
      expect(f.model.visibility('study')['reading'], false);
      await t.tap(find.text('다음'));
      await settle(t);
      expect(find.text('가나 읽기'), findsNothing);
      expect(t.takeException(), null);
    },
  );
  testWidgets('compact study fits the 320x640 phone with examples collapsed', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPadding);
    final page = (await t.runAsync(
      () => f.repo.words(const WordFilter(level: 'N5'), 0, 20),
    ))!;
    await t.runAsync(() => f.model.allFields('study', true));
    final words = page.words.take(4).toList();
    for (final surface in ['明日', '映画館']) {
      final found = (await t.runAsync(
        () => f.repo.words(WordFilter(query: surface), 0, 20),
      ))!;
      words.add(found.words.firstWhere((w) => w.surface == surface));
    }
    final ids = words.map((w) => w.id).toList();
    for (var i = 0; i < ids.length; i++) {
      await t.pumpWidget(
        MaterialApp(
          key: ValueKey(ids[i]),
          home: StudyScreen(model: f.model, speech: speech, ids: [ids[i]]),
        ),
      );
      await settle(t);
      expect(find.text('가나 읽기'), findsNothing);
      await t.tap(find.text('정답 보기'));
      await settle(t);
      expect(find.text('비공식 학습 급수'), findsNothing);
      expect(find.text('일본어 예문'), findsNothing);
      expect(find.text('일반 학습'), findsNothing);
      expect(find.text('정답 닫기').hitTestable(), findsOneWidget);
      expect(find.text('다음').hitTestable(), findsOneWidget);
      expect(find.textContaining('예문 ·').hitTestable(), findsOneWidget);
      final scroll = t
          .widget<ListView>(find.byKey(const ValueKey('study-scroll')))
          .controller!;
      expect(scroll.position.maxScrollExtent, 0, reason: words[i].surface);
      expect(t.takeException(), null);
    }
  });
  testWidgets('examples expand on demand and reset when changing study words', (
    t,
  ) async {
    final ids = (await t.runAsync(
      () => f.repo.allIds(const WordFilter(level: 'N5')),
    ))!.take(2).toList();
    final examples = (await t.runAsync(() => f.repo.examples(ids.first)))!;
    final japanese = examples.first['text_ja'] as String;
    await t.runAsync(() => f.model.allFields('study', true));
    await t.pumpWidget(
      MaterialApp(
        home: StudyScreen(model: f.model, speech: speech, ids: ids),
      ),
    );
    await settle(t);
    expect(find.text(japanese), findsNothing);
    await t.tap(find.text('정답 보기'));
    await settle(t);
    await t.tap(find.textContaining('예문 ·'));
    await settle(t);
    expect(find.text(japanese), findsOneWidget);
    await t.ensureVisible(find.text('예문 듣기').first);
    await t.tap(find.text('예문 듣기').first);
    expect(speech.spoken, contains(japanese));
    await t.tap(find.text('다음'));
    await settle(t);
    expect(find.text('일본어 예문'), findsNothing);
    final scroll = t
        .widget<ListView>(find.byKey(const ValueKey('study-scroll')))
        .controller!;
    expect(scroll.offset, 0);
    await t.tap(find.text('이전'));
    await settle(t);
    expect(find.text(japanese), findsNothing);
    expect(f.model.visibility('study')['example'], false);
    expect(t.takeException(), null);
  });
  testWidgets(
    'study always starts hidden, reveals all, and has no display settings',
    (t) async {
      final id = (await t.runAsync(
        () => f.repo.allIds(const WordFilter()),
      ))!.first;
      await t.runAsync(() => f.model.allFields('study', true));
      await t.pumpWidget(
        MaterialApp(
          home: StudyScreen(model: f.model, speech: speech, ids: [id]),
        ),
      );
      await settle(t);
      expect(find.byTooltip('학습 정보 표시 설정'), findsNothing);
      expect(find.text('가나 읽기'), findsNothing);
      expect(find.textContaining('예문 ·'), findsNothing);
      expect(f.model.learned['word'], isEmpty);
      await t.tap(find.text('정답 보기'));
      await settle(t);
      expect(find.text('가나 읽기'), findsOneWidget);
      expect(find.text('한국어 뜻'), findsOneWidget);
      await t.tap(find.textContaining('예문 ·'));
      await settle(t);
      expect(find.text('해석 보기'), findsWidgets);
      final examples = (await t.runAsync(() => f.repo.examples(id)))!;
      final translation = examples.first['text_ko'] as String;
      expect(find.text(translation), findsNothing);
      await t.tap(find.text('해석 보기').first);
      await settle(t);
      expect(find.text(translation), findsOneWidget);
      await t.tap(find.text('정답 닫기'));
      await settle(t);
      expect(find.text('가나 읽기'), findsNothing);
      expect(find.textContaining('예문 ·'), findsNothing);
      expect(f.model.learned['word'], {id});
      expect(t.takeException(), null);
    },
  );
  testWidgets('fixed test front/back, next, result and retry work on screen', (
    t,
  ) async {
    final ids = (await t.runAsync(
      () => f.repo.allIds(const WordFilter()),
    ))!.take(1).toList();
    final s = (await t.runAsync(() => f.repo.start(ids)))!;
    await t.pumpWidget(
      MaterialApp(
        home: TestScreen(model: f.model, speech: speech, sessionId: s.id),
      ),
    );
    await settle(t);
    expect(find.text('모름'), findsNothing);
    await t.tap(find.text('정답 확인 · 뒤집기'));
    await settle(t);
    await t.tap(find.text('테스트 완료'));
    await settle(t);
    expect(find.text('테스트 완료'), findsOneWidget);
    expect(find.text('모름'), findsNothing);
    expect(find.text('앞면 정보 표시 설정'), findsNothing);
    expect((await t.runAsync(() => f.repo.session(s.id)))!.complete, true);
    await t.ensureVisible(find.text('전체 재시험'));
    await t.tap(find.text('전체 재시험'));
    await settle(t);
    expect(find.text('정답 확인 · 뒤집기'), findsOneWidget);
    expect(t.takeException(), null);
  });
  testWidgets(
    '320px mobile and large text, dark mode navigation do not overflow',
    (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(() => f.model.preference('theme', 'dark'));
      await t.pumpWidget(JlptApp(model: f.model, speech: speech));
      await settle(t);
      await t.tap(find.text('N5'));
      await settle(t);
      expect(t.takeException(), null);
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: WordsScreen(model: f.model, speech: speech),
            ),
          ),
        ),
      );
      await settle(t);
      expect(t.takeException(), null);
    },
  );
  testWidgets('page size custom input and fixed test settings', (t) async {
    await t.pumpWidget(MaterialApp(home: SettingsScreen(model: f.model)));
    await settle(t);
    expect(find.text('테스트 앞면 설정'), findsNothing);
    expect(find.text('테스트 뒷면 설정'), findsNothing);
    await t.tap(find.text('페이지당 항목 수'));
    await settle(t);
    await t.enterText(find.byType(TextField), '201');
    await t.tap(find.text('적용'));
    await settle(t);
    expect(find.text('1~200 사이의 정수를 입력하세요.'), findsOneWidget);
    await t.enterText(find.byType(TextField), '7');
    await t.tap(find.text('적용'));
    await settle(t);
    expect(f.model.pageSize, 7);
    expect(t.takeException(), null);
  });
}
