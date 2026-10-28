import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_study/data/models.dart';
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

  test(
    'kanji selection v3 backup and restart; v2 migration preserves learning marks',
    () async {
      final word = (await f.repo.allIds(const WordFilter())).first;
      await f.model.select([word], true);
      await f.model.star(word);
      await f.model.selectKanji(['一', '会'], true);
      await f.model.visit('kanji', '会');
      final backup = await f.repo.backup();
      await f.model.clearKanjiSelection();
      await f.repo.restore(backup);
      await f.model.load();
      expect(f.model.kanjiSelected, {'一', '会'});
      expect(f.model.selected, {word});
      expect(f.model.starred, {word});
      f.model.dispose();
      await f.repo.close();
      await f.reopen();
      expect(f.model.kanjiSelected, {'一', '会'});
      final v2 = jsonDecode(backup) as Map<String, dynamic>;
      v2['format'] = 'jlpt-user-v2';
      v2.remove('kanji_selection');
      await f.repo.restore(jsonEncode(v2));
      await f.model.load();
      expect(f.model.kanjiSelected, isEmpty);
      expect(f.model.learned['kanji'], {'会'});
      await f.repo.db.execute('DROP TABLE kanji_selection');
      await f.repo.db.setVersion(2);
      f.model.dispose();
      await f.repo.close();
      await f.reopen();
      expect(await f.repo.db.getVersion(), 3);
      expect(f.model.kanjiSelected, isEmpty);
      expect(f.model.learned['kanji'], {'会'});
      expect(f.model.selected, {word});
      expect(f.model.starred, {word});
    },
  );

  testWidgets(
    'word and kanji checkboxes bulk-clear only selected completed rows',
    (t) async {
      final words = (await t.runAsync(
        () => f.repo.allIds(const WordFilter()),
      ))!.take(2).toList();
      await t.runAsync(() async {
        for (final id in words) {
          await f.model.visit('word', id);
        }
        await f.model.star(words.first);
        for (final id in ['一', '万']) {
          await f.model.visit('kanji', id);
        }
      });
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
      expect(find.text('원본 순서'), findsNothing);
      expect(find.text('읽기 순서'), findsNothing);
      final tile = find.byKey(ValueKey('word-tile:${words.first}'));
      expect(t.widget<Material>(tile).color, const Color(0xFFE0E0E0));
      await t.tap(find.descendant(of: tile, matching: find.byType(Checkbox)));
      await settle(t);
      await t.tap(find.text('학습 표시 해제'));
      await settle(t);
      expect(f.model.learned['word'], {words.last});
      expect(f.model.selected, {words.first});
      expect(f.model.starred, {words.first});
      expect(t.widget<Material>(tile).color, Colors.transparent);
      expect(await t.runAsync(f.repo.firstUnlearnedWord), words.first);
      await t.pumpWidget(
        MaterialApp(
          key: const ValueKey('kanji'),
          home: Scaffold(
            body: KanjiScreen(model: f.model, speech: SilentSpeech()),
          ),
        ),
      );
      await settle(t);
      final kanjiTile = find.byKey(const ValueKey('kanji-tile:一'));
      expect(t.widget<Material>(kanjiTile).color, const Color(0xFFE0E0E0));
      await t.tap(find.byKey(const ValueKey('kanji-checkbox:一')));
      await settle(t);
      await t.tap(find.text('학습 표시 해제'));
      await settle(t);
      expect(f.model.learned['kanji'], {'万'});
      expect(f.model.kanjiSelected, {'一'});
      expect(t.widget<Material>(kanjiTile).color, Colors.transparent);
      expect(f.model.learned['word'], {words.last});
      expect(f.model.selected, {words.first});
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'kanji page selections survive paging and filtering; whole-grade selection ignores search',
    (t) async {
      final n5 = (await t.runAsync(() => f.repo.kanji('N5', false, '')))!;
      final n4 = (await t.runAsync(() => f.repo.kanji('N4', false, '')))!;
      await t.runAsync(() => f.model.setPageSize(2));
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KanjiScreen(model: f.model, speech: SilentSpeech()),
          ),
        ),
      );
      await settle(t);
      await t.tap(find.byKey(const ValueKey('kanji-page-checkbox')));
      await settle(t);
      expect(
        f.model.kanjiSelected,
        n5.take(2).map((k) => k['character']).toSet(),
      );
      await t.tap(find.byTooltip('다음 페이지'));
      await settle(t);
      await t.tap(find.byKey(ValueKey("kanji-checkbox:${n5[2]['character']}")));
      await settle(t);
      expect(f.model.kanjiSelected.length, 3);
      await t.enterText(find.byType(TextField), 'no-such-kanji');
      await settle(t);
      await t.tap(find.text('단계 전체 선택'));
      await settle(t);
      expect(f.model.kanjiSelected.length, 84);
      await t.tap(find.byType(DropdownButton<String>));
      await settle(t);
      await t.tap(find.text('N4').last);
      await settle(t);
      await t.enterText(find.byType(TextField), '');
      await settle(t);
      await t.tap(
        find.byKey(ValueKey("kanji-checkbox:${n4.first['character']}")),
      );
      await settle(t);
      expect(f.model.kanjiSelected.length, 85);
      expect(f.model.selected, isEmpty);
      await t.tap(find.text('선택 85개'));
      await settle(t);
      expect(find.text('선택한 한자'), findsOneWidget);
      expect(await t.runAsync(f.repo.kanjiSelection), f.model.kanjiSelected);
      expect(t.takeException(), null);
    },
  );

  testWidgets('kanji list supports dark mode and large text at 320px', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.runAsync(() => f.model.visit('kanji', '一'));
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: KanjiScreen(model: f.model, speech: SilentSpeech()),
        ),
      ),
    );
    await settle(t);
    expect(
      t.widget<Material>(find.byKey(const ValueKey('kanji-tile:一'))).color,
      const Color(0xFF424242),
    );
    expect(find.text('학습 표시 해제').hitTestable(), findsOneWidget);
    expect(t.takeException(), null);
  });
}
