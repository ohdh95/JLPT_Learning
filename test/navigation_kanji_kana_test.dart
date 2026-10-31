import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_study/data/kana.dart';
import 'package:jlpt_study/data/models.dart';
import 'package:jlpt_study/main.dart';
import 'package:jlpt_study/ui/cards.dart';
import 'package:jlpt_study/ui/common.dart';
import 'package:jlpt_study/ui/kana.dart';
import 'package:jlpt_study/ui/kanji_detail.dart';
import 'package:jlpt_study/ui/tests.dart';
import 'support.dart';
import 'widget_test.dart' show settle;

void main() {
  late Fixture f;
  setUp(() async {
    f = Fixture();
    await f.open();
  });
  tearDown(() async => f.close());

  testWidgets(
    'kanji detail steps keep bounds and reset related words and scroll',
    (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final entries = (await t.runAsync(
        () => f.repo.kanji('N5', false, ''),
      ))!.take(3).toList();
      await t.pumpWidget(
        MaterialApp(
          home: KanjiDetail(
            model: f.model,
            speech: SilentSpeech(),
            entries: entries,
            initial: 1,
          ),
        ),
      );
      await settle(t);
      final previous = find.byKey(const ValueKey('kanji-previous'));
      final next = find.byKey(const ValueKey('kanji-next'));
      expect(find.text('${entries[1]['character']} · 한자 상세'), findsOneWidget);
      expect(find.text('2 / 2383'), findsOneWidget);
      expect(find.text('한국식 훈 · 음'), findsNothing);
      await t.tap(find.text('정답 보기'));
      await settle(t);
      await t.ensureVisible(find.text('관련 단어'));
      await settle(t);
      await t.tap(find.text('관련 단어'));
      await settle(t);
      expect(find.byType(StarButton), findsWidgets);
      final scroll = t
          .widget<ListView>(find.byKey(const ValueKey('kanji-detail-scroll')))
          .controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await settle(t);
      expect(next.hitTestable(), findsOneWidget);
      await t.tap(next);
      await settle(t);
      expect(find.text('${entries[2]['character']} · 한자 상세'), findsOneWidget);
      expect(find.text('3 / 2383'), findsOneWidget);
      expect(t.widget<TextButton>(next).onPressed, isNotNull);
      expect(find.byType(StarButton), findsNothing);
      expect(scroll.offset, 0);
      await t.tap(previous);
      await settle(t);
      expect(find.byType(StarButton), findsNothing);
      await t.tap(previous);
      await settle(t);
      expect(find.text('1 / 2383'), findsOneWidget);
      expect(t.widget<TextButton>(previous).onPressed, isNull);
      expect(f.model.learned['kanji'], {entries[1]['character']});
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'kanji list filters stay in place while details browse the entire catalog',
    (t) async {
      await t.pumpWidget(JlptApp(model: f.model, speech: SilentSpeech()));
      await settle(t);
      await t.tap(find.text('한자').last);
      await settle(t);
      await t.tap(find.text('N5'));
      await settle(t);
      await t.tap(find.byType(DropdownButton<String>));
      await settle(t);
      await t.tap(find.text('N4').last);
      await settle(t);
      expect(find.byType(FilterChip), findsNothing);
      final grid = find.byKey(const ValueKey('kanji-list'));
      expect(
        find.descendant(of: grid, matching: find.text('N4')),
        findsNothing,
      );
      final expected = (await t.runAsync(() => f.repo.kanji('N4', false, '')))!;
      await t.tap(
        find.descendant(
          of: grid,
          matching: find.text(expected.first['character'] as String),
        ),
      );
      await settle(t);
      final catalog = (await t.runAsync(() => f.repo.kanji('N1', true, '')))!;
      final start = catalog.indexWhere(
        (k) => k['character'] == expected.first['character'],
      );
      expect(find.text('${start + 1} / ${catalog.length}'), findsOneWidget);
      expect(
        t
            .widget<TextButton>(find.byKey(const ValueKey('kanji-previous')))
            .onPressed,
        isNotNull,
      );
      await t.tap(find.byKey(const ValueKey('kanji-next')));
      await settle(t);
      expect(find.text('${expected[1]['character']} · 한자 상세'), findsOneWidget);
      await t.tap(find.byType(BackButton));
      await settle(t);
      await t.enterText(find.byType(TextField), '会');
      await settle(t);
      await t.tap(find.descendant(of: grid, matching: find.text('会')));
      await settle(t);
      final found = catalog.indexWhere((k) => k['character'] == '会');
      expect(find.text('${found + 1} / ${catalog.length}'), findsOneWidget);
      expect(
        t
            .widget<TextButton>(find.byKey(const ValueKey('kanji-previous')))
            .onPressed,
        isNotNull,
      );
      expect(
        t
            .widget<TextButton>(find.byKey(const ValueKey('kanji-next')))
            .onPressed,
        isNotNull,
      );
      await t.tap(find.byType(BackButton));
      await settle(t);
      expect(
        t.widget<TextField>(find.byType(TextField)).controller?.text ??
            t.widget<EditableText>(find.byType(EditableText)).controller.text,
        '会',
      );
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'word kanji links start at the tapped character and browse the whole catalog',
    (t) async {
      final page = (await t.runAsync(
        () => f.repo.words(const WordFilter(query: '映画館'), 0, 20),
      ))!;
      final word = page.words.firstWhere((w) => w.surface == '映画館');
      await t.pumpWidget(
        MaterialApp(
          home: StudyScreen(
            model: f.model,
            speech: SilentSpeech(),
            ids: [word.id],
          ),
        ),
      );
      await settle(t);
      await t.tap(find.text('정답 보기'));
      await settle(t);
      await t.tap(find.byType(KanjiLink).at(1));
      await settle(t);
      expect(find.text('画 · 한자 상세'), findsOneWidget);
      final catalog = (await t.runAsync(() => f.repo.kanji('N1', true, '')))!;
      final start = catalog.indexWhere((k) => k['character'] == '画');
      expect(find.text('${start + 1} / ${catalog.length}'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('kanji-next')));
      await settle(t);
      expect(
        find.text('${catalog[start + 1]['character']} · 한자 상세'),
        findsOneWidget,
      );
      expect(find.text('${start + 2} / ${catalog.length}'), findsOneWidget);
      await t.tap(find.byType(BackButton));
      await settle(t);
      expect(find.textContaining('/7811'), findsOneWidget);
      expect(find.text('정답 닫기'), findsOneWidget);
      expect(f.model.prefs['last_study'], word.id);
      expect(f.model.visibility('study').values.any((v) => v), false);
      expect(t.takeException(), null);
    },
  );

  testWidgets('five tabs retain kanji and preserve selections and stars', (
    t,
  ) async {
    await t.runAsync(() async {
      await f.model.select(['ada066edfd'], true);
      await f.model.star('ada066edfd');
    });
    await t.pumpWidget(JlptApp(model: f.model, speech: SilentSpeech()));
    await settle(t);
    expect(
      t
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .map((d) => d.label),
      ['단어', '한자', '가나', '별표', '문법'],
    );
    await t.tap(find.text('N5'));
    await settle(t);
    expect(find.text('단어장'), findsOneWidget);
    expect(find.text('する'), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await settle(t);
    await t.tap(find.text('한자').last);
    await settle(t);
    await t.tap(find.text('N5'));
    await settle(t);
    expect(find.text('이 급수의 신규 한자'), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    await t.enterText(find.byType(TextField), '日');
    await settle(t);
    await t.tap(
      find.descendant(
        of: find.byKey(const ValueKey('kanji-list')),
        matching: find.text('日'),
      ),
    );
    await settle(t);
    expect(find.text('日 · 한자 상세'), findsOneWidget);
    expect(find.byType(StarButton), findsNothing);
    await t.tap(find.byType(BackButton));
    await settle(t);
    await t.tap(find.byType(BackButton));
    await settle(t);
    await t.tap(find.text('가나').last);
    await settle(t);
    expect(find.text('あ'), findsOneWidget);
    expect(find.text('ア'), findsOneWidget);
    expect(find.text('아'), findsOneWidget);
    await t.tap(find.text('별표').last);
    await settle(t);
    expect(find.text('会う'), findsOneWidget);
    await t.tap(find.text('단어').last);
    await settle(t);
    expect(find.text('N5'), findsOneWidget);
    expect(f.model.selected, {'ada066edfd'});
    expect(f.model.starred, {'ada066edfd'});
    expect(t.takeException(), null);
  });

  testWidgets(
    'memorization default, kanji related words and back navigation retain card state',
    (t) async {
      await t.runAsync(() async {
        await f.model.select(['ada066edfd'], true);
        await f.model.star('ada066edfd');
      });
      final related = (await t.runAsync(() => f.repo.related('会')))!;
      final other = related.firstWhere((w) => w.id != 'ada066edfd');
      await t.pumpWidget(
        MaterialApp(
          home: StudyScreen(
            model: f.model,
            speech: SilentSpeech(),
            ids: const ['ada066edfd', 'ebec658463'],
          ),
        ),
      );
      await settle(t);
      expect(find.text('가나 읽기'), findsNothing);
      expect(find.byType(KanjiLink), findsNothing);
      expect(find.byTooltip('학습 정보 표시 설정'), findsNothing);
      await t.tap(find.text('정답 보기'));
      await settle(t);
      await t.tap(find.text('会 · 모일 회'));
      await settle(t);
      expect(find.text('会 · 한자 상세'), findsOneWidget);
      expect(find.text('모일 회'), findsNothing);
      await t.tap(find.text('정답 보기'));
      await settle(t);
      expect(find.text('모일 회'), findsOneWidget);
      final relatedRow = find.byKey(ValueKey('related-word:${other.id}'));
      expect(relatedRow, findsNothing);
      await t.scrollUntilVisible(
        find.text('관련 단어'),
        120,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('kanji-detail-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await settle(t);
      await t.tap(find.text('관련 단어'));
      await settle(t);
      await t.ensureVisible(relatedRow);
      await settle(t);
      await t.tap(relatedRow);
      await settle(t);
      expect(find.text('会 · 한자 상세'), findsNothing);
      expect(f.model.prefs['last_study'], 'ada066edfd');
      expect(f.model.isLearned('word', other.id), false);
      await t.tap(find.byType(BackButton));
      await settle(t);
      expect(relatedRow, findsOneWidget);
      await t.tap(find.byType(BackButton));
      await settle(t);
      final order = (await t.runAsync(
        () => f.repo.allIds(const WordFilter()),
      ))!;
      expect(
        find.text('단어 학습 · ${order.indexOf('ada066edfd') + 1}/${order.length}'),
        findsOneWidget,
      );
      expect(find.text('정답 닫기'), findsOneWidget);
      expect(f.model.visibility('study').values.any((v) => v), false);
      expect(f.model.prefs['last_study'], 'ada066edfd');
      expect(f.model.isLearned('word', other.id), false);
      expect(f.model.selected, {'ada066edfd'});
      expect(f.model.starred, {'ada066edfd'});
      await t.tap(find.text('会 · 모일 회'));
      await settle(t);
      expect(relatedRow, findsNothing);
      await t.tap(find.byType(BackButton));
      await settle(t);
      await t.tap(find.text('다음'));
      await settle(t);
      expect(find.text('가나 읽기'), findsNothing);
      final nextIndex = order.indexOf('ada066edfd') + 1;
      expect(
        find.text('단어 학습 · ${nextIndex + 1}/${order.length}'),
        findsOneWidget,
      );
      expect(
        t.widget<WordCard>(find.byType(WordCard)).word.id,
        order[nextIndex],
      );
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'kanji link on test back keeps position and does not advance the test',
    (t) async {
      await t.runAsync(() => f.model.allFields('test_front', true));
      final session = (await t.runAsync(() => f.repo.start(['ada066edfd'])))!;
      await t.pumpWidget(
        MaterialApp(
          home: TestScreen(
            model: f.model,
            speech: SilentSpeech(),
            sessionId: session.id,
          ),
        ),
      );
      await settle(t);
      expect(find.text('会 · 한자 풀이'), findsNothing);
      await t.tap(find.text('정답 확인 · 뒤집기'));
      await settle(t);
      await t.ensureVisible(find.text('会 · 한자 풀이'));
      await t.tap(find.text('会 · 한자 풀이'));
      await settle(t);
      expect(find.text('会 · 한자 상세'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('related-word:ada066edfd')),
        findsNothing,
      );
      await t.tap(find.byType(BackButton));
      await settle(t);
      final saved = (await t.runAsync(() => f.repo.session(session.id)))!;
      expect(saved.revealed, true);
      expect(saved.responses, isEmpty);
      expect(saved.index, 0);
      expect(find.text('모름'), findsNothing);
      expect(t.takeException(), null);
    },
  );

  testWidgets('supplemental kanji opens without invented level or reading', (
    t,
  ) async {
    expect(await t.runAsync(() => f.repo.kanjiEntry('不存在')), isNull);
    await t.pumpWidget(
      MaterialApp(
        home: StudyScreen(
          model: f.model,
          speech: SilentSpeech(),
          ids: const ['5d72771a3c'],
        ),
      ),
    );
    await settle(t);
    await t.tap(find.text('정답 보기'));
    await settle(t);
    await t.tap(find.byType(KanjiLink).first);
    await settle(t);
    expect(find.text('飴 · 한자 상세'), findsOneWidget);
    await t.tap(find.text('정답 보기'));
    await settle(t);
    expect(find.text('급수 미지정'), findsOneWidget);
    expect(find.text('읽기 정보 없음'), findsNWidgets(2));
    expect(t.takeException(), null);
  });

  testWidgets(
    'kana chart is readable at 320px and large font without changing user data',
    (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final before = await t.runAsync(f.repo.backup);
      for (final scale in [1.0, 1.5, 2.0]) {
        await t.pumpWidget(
          MaterialApp(
            key: ValueKey(scale),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text('가나 표')),
              body: const KanaScreen(),
            ),
          ),
        );
        await settle(t);
        for (final group in kanaGroups) {
          await t.tap(find.widgetWithText(ChoiceChip, group.title));
          await settle(t);
          final entries = group.rows
              .expand((r) => r)
              .whereType<KanaEntry>()
              .toList();
          await t.scrollUntilVisible(
            find.byKey(
              ValueKey(
                'kana:${entries.last.hiragana ?? entries.last.katakana}',
              ),
            ),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await settle(t);
          expect(find.text(entries.last.katakana), findsOneWidget);
          expect(find.text(entries.last.korean), findsWidgets);
          expect(t.takeException(), null, reason: '${group.title}, $scale');
        }
      }
      expect(await t.runAsync(f.repo.backup), before);
    },
  );
}
