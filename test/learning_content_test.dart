import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_study/data/grammar.dart';
import 'package:jlpt_study/data/models.dart';
import 'package:jlpt_study/data/parts_of_speech.dart';
import 'package:jlpt_study/main.dart';
import 'package:jlpt_study/ui/cards.dart';
import 'package:jlpt_study/ui/grammar.dart';
import 'support.dart';
import 'widget_test.dart' show settle;

void main() {
  test(
    'learner categories preserve multiple uses and do not treat vi as a class',
    () {
      PosClassification classify(
        List<String> codes, [
        String word = '',
        String reading = '',
      ]) => classifyPos(codes, surface: word, reading: reading);
      expect(PartOfSpeech.values.length, 12);
      expect(classify(['v5u', 'vi']).display, '5단동사');
      expect(classify(['v5u', 'vi']).tags, ['자동사']);
      expect(classify(['v1', 'vt']).display, '1단동사');
      expect(classify(['vs', 'n'], '勉強', 'べんきょう').categories, [
        PartOfSpeech.noun,
      ]);
      expect(classify(['vs'], 'コピーする', 'こぴーする').categories, [
        PartOfSpeech.irregular,
      ]);
      expect(classify(['vk'], '来る', 'くる').display, '불규칙동사');
      expect(classify(['n', 'adj-na']).display, '명사 · な형용사');
      expect(classify(['adj-pn']).display, '연체사');
      expect(classify(['adj-f']).categories, isEmpty);
      expect(classify(['aux-v', 'v1']).display, '1단동사');
      expect(classify(['aux-adj', 'adj-i']).display, 'い형용사');
      expect(classify(['aux'], '筈', 'はず').display, '명사');
      expect(classify(['aux', 'adj-na'], 'そう', 'そう').display, 'な형용사 · 조동사');
      expect(classify(['pref']).display, '접두사');
      expect(classify(['exp']).display, '구문·관용표현');
      expect(classify(['future-tag']).unknownCodes, ['future-tag']);
      expect(classify(['future-tag']).display, '품사 정보 확인 중');
    },
  );

  test(
    'hun and eum combine naturally while respecting each visibility flag',
    () {
      const k = {'korean_hun': '모일', 'korean_eum': '회'};
      expect(formatHunEum(k), '모일 회');
      expect(formatHunEum(k, showHun: false), '회');
      expect(formatHunEum(k, showEum: false), '모일');
      expect(formatHunEum(k, showHun: false, showEum: false), '');
      expect(formatHunEum({}), '훈음 준비 중');
      expect(formatHunEum({'korean_hun': ' ', 'korean_eum': '회'}), '훈 준비 중 회');
    },
  );

  test(
    'reference lessons include regular patterns, irregular readings and exceptions',
    () {
      GrammarLesson lesson(String id) =>
          grammarLessons.singleWhere((l) => l.id == id);
      String examples(String id) => lesson(
        id,
      ).sections.expand((s) => s.forms).map((f) => f.example).join('\n');
      expect(grammarLessons.length, 5);
      expect(examples('ichidan'), contains('食べられる'));
      expect(examples('ichidan'), contains('食べさせる'));
      for (final form in [
        '買って / 買った',
        '待って / 待った',
        '帰って / 帰った',
        '読んで / 読んだ',
        '遊んで / 遊んだ',
        '死んで / 死んだ',
        '書いて / 書いた',
        '泳いで / 泳いだ',
        '話して / 話した',
      ]) {
        expect(examples('godan'), contains(form));
      }
      for (final form in [
        'できる',
        'される',
        'させる',
        '来ない（こない）',
        '来て（きて）',
        '来られる（こられる）',
        '来させる（こさせる）',
        '来い（こい）',
      ]) {
        expect(examples('irregular'), contains(form));
      }
      expect(examples('i-adjective'), contains('よくない'));
      expect(examples('i-adjective'), contains('高かったです'));
      expect(examples('na-adjective'), contains('静かな部屋'));
      expect(examples('na-adjective'), contains('静かではありませんでした'));
      expect(lesson('godan').notes.join(), contains('行って・行った'));
      expect(lesson('godan').notes.join(), contains('買わない'));
      expect(lesson('na-adjective').notes.join(), contains('きれい'));
      for (final l in grammarLessons) {
        expect(l.sources, isNotEmpty);
        expect(l.sections.first.expanded, true);
        expect(
          l.sources.every((s) => Uri.parse(s.url).scheme == 'https'),
          true,
        );
      }
    },
  );

  test(
    'all corpus codes are handled and SQL filters match labels without changing selection',
    () async {
      final f = Fixture();
      await f.open();
      addTearDown(f.close);
      final words = (await f.repo.db.rawQuery(
        'SELECT * FROM content.vocab',
      )).map(Word.new).toList();
      expect(words.length, 7811);
      expect(words.expand((w) => w.pos).toSet().length, 47);
      for (final w in words) {
        expect(w.partOfSpeech.unknownCodes, isEmpty, reason: w.surface);
        if (w.pos.isNotEmpty) {
          expect(
            w.partOfSpeech.display,
            isNot('품사 정보 확인 중'),
            reason: w.surface,
          );
        } else {
          expect(w.partOfSpeech.display, '품사 정보 확인 중');
        }
      }
      expect(words.where((w) => w.pos.isEmpty).length, 11);
      await f.model.select([words.first.id], true);
      for (final category in PartOfSpeech.values) {
        final expected = words
            .where((w) => w.partOfSpeech.categories.contains(category))
            .map((w) => w.id)
            .toSet();
        final actual = await f.repo.allIds(WordFilter(partOfSpeech: category));
        expect(actual.toSet(), expected, reason: category.label);
        final page = await f.repo.words(
          WordFilter(partOfSpeech: category, level: 'N5'),
          0,
          20,
        );
        expect(
          page.words.every(
            (w) =>
                w.level == 'N5' && w.partOfSpeech.categories.contains(category),
          ),
          true,
        );
      }
      expect(f.model.selected, {words.first.id});
      expect((await f.repo.audit())['ko'], 0);
    },
  );

  testWidgets(
    'grammar replaces history navigation and does not write user data',
    (t) async {
      final f = Fixture();
      await t.runAsync(f.open);
      addTearDown(f.close);
      final before = await t.runAsync(f.repo.backup);
      await t.pumpWidget(JlptApp(model: f.model, speech: SilentSpeech()));
      await settle(t);
      expect(find.widgetWithText(NavigationDestination, '기록'), findsNothing);
      await t.tap(find.text('문법').last);
      await settle(t);
      for (final lesson in grammarLessons) {
        await t.scrollUntilVisible(
          find.byKey(ValueKey('grammar-${lesson.id}')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await t.tap(find.byKey(ValueKey('grammar-${lesson.id}')));
        await settle(t);
        expect(find.text('${lesson.title} 활용'), findsOneWidget);
        await t.tap(find.byType(BackButton));
        await settle(t);
      }
      final after = await t.runAsync(f.repo.backup);
      expect(after, before);
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'all grammar sections expand at 320px with large text without overflow',
    (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (final lesson in grammarLessons) {
        await t.pumpWidget(
          MaterialApp(
            key: ValueKey(lesson.id),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: GrammarDetail(lesson: lesson),
          ),
        );
        await t.pumpAndSettle();
        for (final section in lesson.sections) {
          await t.scrollUntilVisible(
            find.text(section.title),
            250,
            maxScrolls: 70,
            scrollable: find.byType(Scrollable).first,
          );
          await t.pumpAndSettle();
          if (!section.expanded) {
            await t.tap(find.text(section.title));
            await t.pumpAndSettle();
          }
          expect(find.text(section.forms.last.example), findsWidgets);
          expect(
            t.takeException(),
            null,
            reason: '${lesson.title}: ${section.title}',
          );
        }
        expect(find.text('참고 자료'), findsNothing);
        expect(t.takeException(), null);
      }
    },
  );

  testWidgets('POS filter affects real results and keeps selected IDs', (
    t,
  ) async {
    final f = Fixture();
    await t.runAsync(f.open);
    addTearDown(f.close);
    await t.pumpWidget(JlptApp(model: f.model, speech: SilentSpeech()));
    await settle(t);
    await t.tap(find.text('N5'));
    await settle(t);
    await t.tap(find.byType(Checkbox).at(1));
    await settle(t);
    final selected = Set<String>.from(f.model.selected);
    await t.tap(find.byKey(const ValueKey('pos-filter')));
    await t.pumpAndSettle();
    await t.tap(find.text('1단동사').last);
    await settle(t);
    final expected = await t.runAsync(
      () => f.repo.words(
        const WordFilter(level: 'N5', partOfSpeech: PartOfSpeech.ichidan),
        0,
        20,
      ),
    );
    expect(find.text(expected!.words.first.surface), findsOneWidget);
    expect(f.model.selected, selected);
    expect(t.takeException(), null);
  });

  testWidgets(
    'study and test cards show natural hun/eum and readable POS with tag details',
    (t) async {
      final f = Fixture();
      await t.runAsync(f.open);
      addTearDown(f.close);
      final rows = await t.runAsync(
        () => f.repo.words(const WordFilter(query: '会う'), 0, 20),
      );
      final w = rows!.words.firstWhere((w) => w.surface == '会う');
      await t.runAsync(() => f.model.allFields('study', true));
      for (final profile in ['study', 'test_back']) {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: WordCard(
                  model: f.model,
                  speech: SilentSpeech(),
                  word: w,
                  profile: profile,
                  temporaryReveal: profile == 'study',
                ),
              ),
            ),
          ),
        );
        await settle(t);
        expect(find.textContaining('모일 회'), findsOneWidget);
        expect(find.textContaining('훈 모일'), findsNothing);
        expect(find.textContaining('품사: 5단동사'), findsOneWidget);
        expect(find.textContaining('JMdict 원본 코드'), findsNothing);
        expect(find.text('자세히'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsNothing);
        await t.tap(find.byType(PosLabel));
        await settle(t);
        expect(find.text('자동사'), findsOneWidget);
        await t.tap(find.text('닫기'));
        await settle(t);
        expect(t.takeException(), null);
      }
    },
  );
}
