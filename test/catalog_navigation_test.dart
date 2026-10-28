import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_study/data/models.dart';
import 'package:jlpt_study/main.dart';
import 'package:jlpt_study/ui/cards.dart';
import 'package:jlpt_study/ui/kanji_detail.dart';
import 'package:jlpt_study/ui/screens.dart';
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
    'word browsing crosses all four grade boundaries in both directions',
    (t) async {
      final order = (await t.runAsync(
        () => f.repo.allIds(const WordFilter()),
      ))!;
      final previous = find.byKey(const ValueKey('study-previous'));
      final next = find.byKey(const ValueKey('study-next'));
      for (var i = 0; i < levels.length - 1; i++) {
        final left = (await t.runAsync(
          () => f.repo.allIds(WordFilter(level: levels[i])),
        ))!;
        final right = (await t.runAsync(
          () => f.repo.allIds(WordFilter(level: levels[i + 1])),
        ))!;
        await t.pumpWidget(
          MaterialApp(
            key: ValueKey('word-$i'),
            home: StudyScreen(
              model: f.model,
              speech: SilentSpeech(),
              ids: [left.last],
            ),
          ),
        );
        await settle(t);
        expect(t.widget<WordCard>(find.byType(WordCard)).word.id, left.last);
        await t.tap(next);
        await settle(t);
        expect(t.widget<WordCard>(find.byType(WordCard)).word.id, right.first);
        expect(
          find.text(
            '단어 학습 · ${order.indexOf(right.first) + 1}/${order.length}',
          ),
          findsOneWidget,
        );
        await t.tap(previous);
        await settle(t);
        expect(t.widget<WordCard>(find.byType(WordCard)).word.id, left.last);
        expect(f.model.learned['word'], isEmpty);
      }
      for (final id in [order.first, order.last]) {
        await t.pumpWidget(
          MaterialApp(
            key: ValueKey('word-end-$id'),
            home: StudyScreen(
              model: f.model,
              speech: SilentSpeech(),
              ids: [id],
            ),
          ),
        );
        await settle(t);
        expect(
          t.widget<TextButton>(previous).onPressed == null,
          id == order.first,
        );
        expect(t.widget<TextButton>(next).onPressed == null, id == order.last);
      }
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'kanji browsing crosses all grade boundaries and stops only at catalog ends',
    (t) async {
      final order = (await t.runAsync(() => f.repo.kanji('N1', true, '')))!;
      final previous = find.byKey(const ValueKey('kanji-previous'));
      final next = find.byKey(const ValueKey('kanji-next'));
      for (var i = 0; i < levels.length - 1; i++) {
        final left = order.lastWhere((k) => k['jlpt_level'] == levels[i]);
        final right = order.firstWhere((k) => k['jlpt_level'] == levels[i + 1]);
        await t.pumpWidget(
          MaterialApp(
            key: ValueKey('kanji-$i'),
            home: KanjiDetail(
              model: f.model,
              speech: SilentSpeech(),
              entries: [left],
            ),
          ),
        );
        await settle(t);
        await t.tap(next);
        await settle(t);
        expect(find.text('${right['character']} · 한자 상세'), findsOneWidget);
        expect(
          find.text(
            '${order.indexWhere((k) => k['character'] == right['character']) + 1} / ${order.length}',
          ),
          findsOneWidget,
        );
        await t.tap(previous);
        await settle(t);
        expect(find.text('${left['character']} · 한자 상세'), findsOneWidget);
      }
      for (final entry in [order.first, order.last]) {
        await t.pumpWidget(
          MaterialApp(
            key: ValueKey('kanji-end-${entry['character']}'),
            home: KanjiDetail(
              model: f.model,
              speech: SilentSpeech(),
              entries: [entry],
            ),
          ),
        );
        await settle(t);
        expect(
          t.widget<TextButton>(previous).onPressed == null,
          entry['character'] == order.first['character'],
        );
        expect(
          t.widget<TextButton>(next).onPressed == null,
          entry['character'] == order.last['character'],
        );
      }
      expect(f.model.learned['kanji'], isEmpty);
      expect(f.model.selected, isEmpty);
      expect(await t.runAsync(f.repo.history), isEmpty);
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'level select ignores empty search and preserves other level selections',
    (t) async {
      final n5 = (await t.runAsync(
        () => f.repo.allIds(const WordFilter(level: 'N5')),
      ))!;
      final n4 = (await t.runAsync(
        () => f.repo.allIds(const WordFilter(level: 'N4')),
      ))!;
      await t.runAsync(() => f.model.select([n4.first], true));
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordsScreen(
              model: f.model,
              speech: SilentSpeech(),
              initialLevel: 'N5',
            ),
          ),
        ),
      );
      await settle(t);
      await t.enterText(find.byType(TextField), 'definitely-no-matching-word');
      await settle(t);
      expect(find.textContaining('해당하는 단어가 없습니다.'), findsOneWidget);
      await t.tap(find.text('단계 전체 선택'));
      await settle(t);
      expect(f.model.selected, {...n5, n4.first});
      expect(await t.runAsync(f.repo.selection), {...n5, n4.first});
      await t.tap(find.byType(DropdownButton<String>).first);
      await settle(t);
      await t.tap(find.text('모든 급수').last);
      await settle(t);
      await t.tap(find.text('전체 급수 선택'));
      await settle(t);
      expect(f.model.selected.length, 7811);
      expect(t.takeException(), null);
    },
  );

  testWidgets('resume opens the first unlearned word in canonical order', (
    t,
  ) async {
    final order = (await t.runAsync(() => f.repo.allIds(const WordFilter())))!;
    final id = order[1];
    await t.runAsync(() async {
      await f.model.visit('word', order.first);
      await f.model.visit('word', order[2]);
      await f.model.select([order.last], true);
    });
    await t.pumpWidget(JlptApp(model: f.model, speech: SilentSpeech()));
    await settle(t);
    await t.scrollUntilVisible(
      find.text('이어서 학습'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(t);
    await t.tap(find.text('이어서 학습'));
    await settle(t);
    expect(t.widget<WordCard>(find.byType(WordCard)).word.id, id);
    await t.tap(find.byKey(const ValueKey('study-next')));
    await settle(t);
    expect(t.widget<WordCard>(find.byType(WordCard)).word.id, order[2]);
    await t.tap(find.byKey(const ValueKey('study-previous')));
    await settle(t);
    expect(t.widget<WordCard>(find.byType(WordCard)).word.id, id);
    expect(await t.runAsync(f.repo.firstUnlearnedWord), id);
    await t.tap(find.text('정답 보기'));
    await settle(t);
    expect(await t.runAsync(f.repo.firstUnlearnedWord), order[3]);
    expect(f.model.selected, {order.last});
    expect(t.takeException(), null);
  });
}
