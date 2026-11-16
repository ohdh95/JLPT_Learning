import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_study/data/models.dart';
import 'package:jlpt_study/main.dart';
import 'package:jlpt_study/ui/cards.dart';
import 'support.dart';
import 'widget_test.dart' show settle;

void main() {
  late Fixture f;
  final previous = find.byKey(const ValueKey('study-previous'));
  final next = find.byKey(const ValueKey('study-next'));

  String current(WidgetTester t) =>
      t.widget<WordCard>(find.byType(WordCard)).word.id;

  setUp(() async {
    f = Fixture();
    await f.open();
  });
  tearDown(() async => f.close());

  testWidgets(
    'favorites tab browses all saved words across pages, filters and levels',
    (t) async {
      final favorites = (await t.runAsync(() async {
        final ids = <String>[];
        for (final level in ['N5', 'N4', 'N1']) {
          ids.add((await f.repo.allIds(WordFilter(level: level)))[10]);
        }
        for (final id in ids.reversed) {
          await f.model.star(id);
        }
        await f.model.setPageSize(1);
        await f.model.select([ids.first], true);
        return ids;
      }))!;
      await t.pumpWidget(JlptApp(model: f.model, speech: SilentSpeech()));
      await settle(t);
      expect(find.text('별표'), findsNothing);
      await t.tap(find.text('즐겨찾기'));
      await settle(t);
      expect(find.text('1 / 3 페이지'), findsOneWidget);
      await t.tap(find.byTooltip('다음 페이지'));
      await settle(t);
      expect(
        find.byKey(ValueKey('word-label:${favorites[1]}')),
        findsOneWidget,
      );
      await t.tap(find.byType(DropdownButton<String>).first);
      await settle(t);
      await t.tap(find.text('N4').last);
      await settle(t);
      expect(find.text('1 / 1 페이지'), findsOneWidget);
      final word = (await t.runAsync(() => f.repo.word(favorites[1])))!;
      await t.enterText(find.byType(TextField), word.surface);
      await t.pump(const Duration(milliseconds: 400));
      await settle(t);
      await t.tap(find.byKey(ValueKey('word-label:${favorites[1]}')));
      await settle(t);
      expect(current(t), favorites[1]);
      expect(find.text('즐겨찾기 학습 · 2/3'), findsOneWidget);
      await t.tap(find.text('정답 보기'));
      await settle(t);
      await t.tap(next);
      await settle(t);
      expect(current(t), favorites.last);
      expect(find.text('즐겨찾기 학습 · 3/3'), findsOneWidget);
      expect(find.text('정답 보기'), findsOneWidget);
      expect(t.widget<TextButton>(next).onPressed, isNull);
      await t.tap(previous);
      await settle(t);
      expect(current(t), favorites[1]);
      await t.tap(previous);
      await settle(t);
      expect(current(t), favorites.first);
      expect(t.widget<TextButton>(previous).onPressed, isNull);
      expect(f.model.selected, {favorites.first});
      expect(f.model.learned['word'], {favorites[1]});
      expect(await t.runAsync(f.repo.stars), favorites.toSet());
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'removing favorites updates both directions without losing the card',
    (t) async {
      final favorites = (await t.runAsync(() async {
        final all = await f.repo.allIds(const WordFilter());
        final ids = [all[2], all[9], all[25]];
        for (final id in ids) {
          await f.model.star(id);
        }
        return ids;
      }))!;
      await t.pumpWidget(
        MaterialApp(
          home: StudyScreen(
            model: f.model,
            speech: SilentSpeech(),
            ids: [favorites[1]],
            favoritesOnly: true,
          ),
        ),
      );
      await settle(t);
      await t.tap(find.text('정답 보기'));
      await settle(t);
      await t.tap(find.byTooltip('즐겨찾기 해제'));
      await settle(t);
      expect(current(t), favorites[1]);
      expect(find.text('정답 닫기'), findsOneWidget);
      expect(find.text('즐겨찾기 학습'), findsOneWidget);
      await t.tap(next);
      await settle(t);
      expect(current(t), favorites.last);
      expect(find.text('즐겨찾기 학습 · 2/2'), findsOneWidget);
      await t.tap(previous);
      await settle(t);
      expect(current(t), favorites.first);
      await t.tap(find.byTooltip('즐겨찾기 해제'));
      await settle(t);
      expect(t.widget<TextButton>(previous).onPressed, isNull);
      await t.tap(next);
      await settle(t);
      expect(current(t), favorites.last);
      expect(find.text('즐겨찾기 학습 · 1/1'), findsOneWidget);
      expect(t.widget<TextButton>(previous).onPressed, isNull);
      expect(t.widget<TextButton>(next).onPressed, isNull);
      await t.tap(find.byTooltip('즐겨찾기 해제'));
      await settle(t);
      expect(current(t), favorites.last);
      expect(f.model.starred, isEmpty);
      expect(find.text('즐겨찾기 학습'), findsOneWidget);
      expect(t.widget<TextButton>(previous).onPressed, isNull);
      expect(t.widget<TextButton>(next).onPressed, isNull);
      await t.tap(find.byTooltip('즐겨찾기 추가'));
      await settle(t);
      expect(find.text('즐겨찾기 학습 · 1/1'), findsOneWidget);
      await t.runAsync(() => f.model.star(favorites.first));
      await settle(t);
      await t.tap(previous);
      await settle(t);
      expect(current(t), favorites.first);
      expect(await t.runAsync(f.repo.stars), {favorites.first, favorites.last});
      expect(t.takeException(), null);
    },
  );

  testWidgets('regular study still navigates through unsaved words', (t) async {
    final order = (await t.runAsync(() async {
      final all = await f.repo.allIds(const WordFilter());
      await f.model.star(all[1]);
      await f.model.star(all[10]);
      return all;
    }))!;
    await t.pumpWidget(
      MaterialApp(
        home: StudyScreen(
          model: f.model,
          speech: SilentSpeech(),
          ids: [order[1]],
        ),
      ),
    );
    await settle(t);
    await t.tap(next);
    await settle(t);
    expect(current(t), order[2]);
    expect(find.text('단어 학습 · 3/7811'), findsOneWidget);
    await t.tap(previous);
    await settle(t);
    expect(current(t), order[1]);
    expect(t.takeException(), null);
  });
}
