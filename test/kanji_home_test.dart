import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_study/data/models.dart';
import 'package:jlpt_study/main.dart';
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

  Future<void> markAll(List<Map<String, Object?>> entries) async {
    await f.repo.db.transaction((tx) async {
      final batch = tx.batch();
      for (final entry in entries) {
        batch.insert('learning_visits', {
          'kind': 'kanji',
          'item_id': entry['character'],
          'visited_at': '2026-10-28T00:00:00Z',
        });
      }
      await batch.commit(noResult: true);
    });
  }

  test(
    'kanji progress and resume span every grade and exclude supplemental kanji',
    () async {
      final catalog = await f.repo.kanji('N1', true, '');
      final supplemental =
          (await f.repo.db.rawQuery(
                'SELECT character FROM content.kanji WHERE jlpt_level IS NULL LIMIT 1',
              )).single['character']
              as String;
      final word = (await f.repo.allIds(const WordFilter())).first;
      await f.model.visit('word', word);
      await f.model.visit('kanji', supplemental);
      final initial = await f.repo.kanjiProgress();
      expect(initial.map((r) => r['jlpt_level']), levels);
      expect(initial.fold<int>(0, (n, r) => n + (r['total'] as int)), 2383);
      expect(initial.every((r) => r['studied'] == 0), true);
      for (final level in levels) {
        final entries = catalog.where((k) => k['jlpt_level'] == level).toList();
        expect(await f.repo.firstUnlearnedKanji(), entries.first['character']);
        await markAll(entries);
        final row = (await f.repo.kanjiProgress()).firstWhere(
          (r) => r['jlpt_level'] == level,
        );
        expect(row['studied'], entries.length);
        expect(row['total'], entries.length);
      }
      expect(await f.repo.firstUnlearnedKanji(), isNull);
      final gap =
          catalog.firstWhere((k) => k['jlpt_level'] == 'N3')['character']
              as String;
      await f.model.clearVisitItems('kanji', [gap]);
      expect(await f.repo.firstUnlearnedKanji(), gap);
      expect(f.model.learned['word'], {word});
      await f.model.clearVisits('kanji');
      expect(await f.repo.firstUnlearnedKanji(), catalog.first['character']);
      expect(
        (await f.repo.kanjiProgress()).every((r) => r['studied'] == 0),
        true,
      );
    },
  );

  testWidgets(
    'kanji tab shows grade counts, opens selected grade and resumes first incomplete',
    (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final catalog = (await t.runAsync(() => f.repo.kanji('N1', true, '')))!;
      final first = catalog[0]['character'] as String;
      final second = catalog[1]['character'] as String;
      final third = catalog[2]['character'] as String;
      final n4 =
          catalog.firstWhere((k) => k['jlpt_level'] == 'N4')['character']
              as String;
      await t.runAsync(() async {
        await f.model.visit('kanji', first);
        await f.model.visit('kanji', third);
        await f.model.selectKanji([n4], true);
      });
      await t.pumpWidget(JlptApp(model: f.model, speech: SilentSpeech()));
      await settle(t);
      await t.tap(find.text('한자').last);
      await settle(t);
      expect(find.text('나의 학습 급수'), findsOneWidget);
      expect(find.text('2/84자 학습'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await t.tap(find.text('N4'));
      await settle(t);
      expect(find.text('한자장'), findsOneWidget);
      expect(
        t
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .value,
        'N4',
      );
      expect(find.byKey(ValueKey('kanji-label:$n4')), findsOneWidget);
      await t.tap(find.byType(BackButton));
      await settle(t);
      await t.scrollUntilVisible(find.text('이어서 학습'), 200);
      await settle(t);
      await t.ensureVisible(find.text('이어서 학습'));
      await settle(t);
      expect(find.text('이어서 학습').hitTestable(), findsOneWidget);
      await t.tap(find.text('이어서 학습'));
      await settle(t);
      expect(find.text('$second · 한자 상세'), findsOneWidget);
      expect(find.text('한국식 훈 · 음'), findsNothing);
      expect(f.model.learned['kanji'], {first, third});
      await t.tap(find.byKey(const ValueKey('kanji-next')));
      await settle(t);
      expect(find.text('$third · 한자 상세'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('kanji-previous')));
      await settle(t);
      await t.tap(find.text('정답 보기'));
      await settle(t);
      expect(
        await t.runAsync(f.repo.firstUnlearnedKanji),
        catalog[3]['character'],
      );
      await t.tap(find.byType(BackButton));
      await settle(t);
      await t.ensureVisible(find.text('3/84자 학습'));
      expect(find.text('3/84자 학습').hitTestable(), findsOneWidget);
      await t.runAsync(() => f.model.clearVisitItems('kanji', [first]));
      await settle(t);
      expect(find.text('2/84자 학습'), findsOneWidget);
      await t.scrollUntilVisible(find.text('이어서 학습'), 200);
      await settle(t);
      await t.ensureVisible(find.text('이어서 학습'));
      await settle(t);
      expect(find.text('이어서 학습').hitTestable(), findsOneWidget);
      await t.tap(find.text('이어서 학습'));
      await settle(t);
      expect(find.text('$first · 한자 상세'), findsOneWidget);
      expect(f.model.kanjiSelected, {n4});
      expect(f.model.selected, isEmpty);
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'fully learned kanji disable resume without affecting word resume',
    (t) async {
      final catalog = (await t.runAsync(() => f.repo.kanji('N1', true, '')))!;
      await t.runAsync(() => markAll(catalog));
      await t.runAsync(f.model.load);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              model: f.model,
              speech: SilentSpeech(),
              kanji: true,
              onLevel: (_) {},
            ),
          ),
        ),
      );
      await settle(t);
      await t.scrollUntilVisible(find.text('전체 학습 완료'), 200);
      final button = t.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '전체 학습 완료'),
      );
      expect(button.onPressed, isNull);
      expect(await t.runAsync(f.repo.firstUnlearnedWord), isNotNull);
      expect(f.model.learned['word'], isEmpty);
      expect(t.takeException(), null);
    },
  );
}
