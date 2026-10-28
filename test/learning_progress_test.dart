import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt_study/data/models.dart';
import 'package:jlpt_study/main.dart';
import 'package:jlpt_study/ui/cards.dart';
import 'package:jlpt_study/ui/screens.dart';
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

  test(
    'visits survive restart and backup; clearing is independent of stars and selection',
    () async {
      final ids = (await f.repo.allIds(const WordFilter())).take(3).toList();
      await f.model.select(ids, true);
      await f.model.star(ids.first);
      await f.model.visit('word', ids[2]);
      await f.model.visit('word', ids.first);
      await f.model.visit('kanji', '会');
      expect(await f.repo.firstUnlearnedWord(), ids[1]);
      expect((await f.repo.progress()).first['studied'], 2);
      final backup = await f.repo.backup();
      f.model.dispose();
      await f.repo.close();
      await f.reopen();
      expect(f.model.learned['word'], {ids.first, ids[2]});
      expect(f.model.learned['kanji'], {'会'});
      await f.model.clearVisits('word', itemId: ids.first);
      expect(await f.repo.firstUnlearnedWord(), ids.first);
      expect(f.model.learned['word'], {ids[2]});
      await f.model.clearVisits('kanji');
      await f.model.clearVisits('word');
      expect(f.model.learned.values.every((s) => s.isEmpty), true);
      expect(f.model.selected, ids.toSet());
      expect(f.model.starred, {ids.first});
      await f.repo.restore(backup);
      await f.model.load();
      expect(f.model.learned['word'], {ids.first, ids[2]});
      expect(f.model.learned['kanji'], {'会'});
      expect(await f.repo.firstUnlearnedWord(), ids[1]);
      final bad = jsonDecode(backup) as Map<String, dynamic>;
      bad['learning_visits'][0]['visited_at'] = 'broken';
      await expectLater(f.repo.restore(jsonEncode(bad)), throwsFormatException);
      expect(await f.repo.backup(), backup);
    },
  );

  test(
    'first unlearned crosses every grade, fills holes and handles a completed catalog',
    () async {
      final all = await f.repo.allIds(const WordFilter());
      expect(await f.repo.firstUnlearnedWord(), all.first);
      for (final level in levels) {
        final ids = await f.repo.allIds(WordFilter(level: level));
        expect(await f.repo.firstUnlearnedWord(), ids.first);
        await f.repo.db.transaction((tx) async {
          final b = tx.batch();
          for (final id in ids) {
            b.insert('learning_visits', {
              'kind': 'word',
              'item_id': id,
              'visited_at': '2026-10-28T00:00:00Z',
            });
          }
          await b.commit(noResult: true);
        });
      }
      expect(await f.repo.firstUnlearnedWord(), isNull);
      expect(
        (await f.repo.progress()).every((r) => r['studied'] == r['total']),
        true,
      );
      final n3 = (await f.repo.allIds(const WordFilter(level: 'N3')))[7];
      await f.repo.clearVisits('word', itemId: n3);
      expect(await f.repo.firstUnlearnedWord(), n3);
      await f.repo.visit('word', n3);
      expect(await f.repo.firstUnlearnedWord(), isNull);
      await f.repo.clearVisits('word');
      expect(await f.repo.firstUnlearnedWord(), all.first);
    },
  );

  test(
    'word and kanji quiz advances are atomic, unrated, and back up with kind',
    () async {
      final word = (await f.repo.allIds(const WordFilter())).first;
      final ids = ['kanji:会', 'kanji:一'];
      var s = await f.repo.start(
        [...ids, ...ids],
        kind: 'kanji',
        random: Random(8),
      );
      expect(s.isKanji, true);
      expect(s.order.toSet(), ids.toSet());
      expect(
        s.kanjiSnapshot(s.order.first)['character'],
        s.order.first.substring(6),
      );
      await expectLater(f.repo.advance(s.id, s.order.first), throwsStateError);
      await f.repo.reveal(s.id);
      await expectLater(f.repo.advance(s.id, s.order.last), throwsStateError);
      final outcomes = await Future.wait([
        for (var i = 0; i < 2; i++)
          f.repo.advance(s.id, s.order.first).then((_) => true).catchError((
            Object e,
          ) {
            expect(e, isA<StateError>());
            return false;
          }),
      ]);
      expect(outcomes.where((v) => v).length, 1);
      s = await f.repo.session(s.id);
      expect(s.index, 1);
      expect(s.revealed, false);
      expect(s.responses.values, ['seen']);
      await f.repo.reveal(s.id);
      await f.repo.advance(s.id, s.order.last);
      s = await f.repo.session(s.id);
      expect(s.complete, true);
      final retry = await f.repo.retryAll(s);
      expect(retry.kind, 'kanji');
      expect(retry.order.toSet(), ids.toSet());
      expect(retry.responses, isEmpty);
      final words = await f.repo.start([word]);
      await f.repo.reveal(words.id);
      await f.repo.advance(words.id, word);
      expect((await f.repo.session(words.id)).responses, {word: 'seen'});
      expect((await f.repo.progress()).first['studied'], 0);
      final backup = await f.repo.backup();
      await f.repo.restore(backup);
      expect((await f.repo.session(s.id)).responses, s.responses);
      expect((await f.repo.session(retry.id)).kind, 'kanji');
      final n5 = await f.repo.startKanji('N5', random: Random(3));
      expect(n5.order.length, 84);
      expect(n5.order.toSet().length, 84);
      expect(n5.snapshots.values.every((r) => r['jlpt_level'] == 'N5'), true);
      expect(await f.repo.selection(), isEmpty);
    },
  );

  test(
    'v1 database upgrade and old backup preserve ratings, selections and preferences',
    () async {
      final ids = (await f.repo.allIds(const WordFilter())).take(2).toList();
      await f.model.select(ids, true);
      await f.model.star(ids.first);
      await f.model.preference('theme', 'dark');
      await f.model.preference('last_study', ids.first);
      final session = await f.repo.start(ids);
      await f.repo.reveal(session.id);
      await f.repo.rate(session.id, session.order.first, 'known');
      final old = jsonDecode(await f.repo.backup()) as Map<String, dynamic>;
      old['format'] = 'jlpt-user-v1';
      old.remove('learning_visits');
      for (final r in old['test_sessions']) {
        r.remove('kind');
      }
      f.model.dispose();
      await f.repo.close();
      await File('${f.dir.path}/user.db').delete();
      final v1 = await databaseFactoryFfiNoIsolate.openDatabase(
        '${f.dir.path}/user.db',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            for (final sql in [
              'CREATE TABLE preferences(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
              'CREATE TABLE selection(word_id TEXT PRIMARY KEY)',
              'CREATE TABLE user_word_state(word_id TEXT PRIMARY KEY,is_starred INTEGER NOT NULL DEFAULT 0)',
              "CREATE TABLE test_sessions(id TEXT PRIMARY KEY,started_at TEXT NOT NULL,completed_at TEXT,status TEXT NOT NULL DEFAULT 'in_progress',order_json TEXT NOT NULL,snapshots_json TEXT NOT NULL,current_index INTEGER NOT NULL DEFAULT 0,revealed INTEGER NOT NULL DEFAULT 0)",
              "CREATE TABLE test_responses(session_id TEXT NOT NULL REFERENCES test_sessions(id) ON DELETE CASCADE,word_id TEXT NOT NULL,rating TEXT NOT NULL CHECK(rating IN ('unknown','uncertain','known')),answered_at TEXT NOT NULL,PRIMARY KEY(session_id,word_id))",
              'CREATE INDEX responses_word_time ON test_responses(word_id,answered_at DESC)',
            ]) {
              await db.execute(sql);
            }
          },
        ),
      );
      for (final table in [
        'preferences',
        'selection',
        'user_word_state',
        'test_sessions',
        'test_responses',
      ]) {
        for (final row in old[table]) {
          await v1.insert(table, Map<String, Object?>.from(row));
        }
      }
      await v1.close();
      await f.reopen();
      expect(await f.repo.db.getVersion(), 3);
      expect(f.model.selected, ids.toSet());
      expect(f.model.starred, {ids.first});
      expect(f.model.theme, 'dark');
      expect(f.model.learned['word'], isEmpty);
      expect(await f.repo.firstUnlearnedWord(), ids.first);
      var resumed = await f.repo.session(session.id);
      expect(resumed.kind, 'word');
      expect(resumed.responses, {session.order.first: 'known'});
      expect(resumed.index, 1);
      expect(await f.repo.db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      await f.repo.reveal(session.id);
      await f.repo.advance(session.id, resumed.order.last);
      expect((await f.repo.session(session.id)).complete, true);
      await f.repo.restore(jsonEncode(old));
      await f.model.load();
      resumed = await f.repo.session(session.id);
      expect(resumed.index, 1);
      expect(resumed.responses, {session.order.first: 'known'});
      expect(f.model.learned['word'], isEmpty);
      expect(f.model.selected, ids.toSet());
    },
  );

  testWidgets(
    'only explicit answer reveal completes a word; reset and reopen remain unlearned',
    (t) async {
      final id = (await t.runAsync(
        () => f.repo.allIds(const WordFilter()),
      ))!.first;
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
      final label = find.byKey(ValueKey('word-label:$id'));
      expect(t.widget<Text>(label).style!.fontWeight, FontWeight.normal);
      expect(find.text('모든 상태'), findsNothing);
      await t.tap(label);
      await settle(t);
      expect(f.model.isLearned('word', id), false);
      expect(await t.runAsync(f.repo.firstUnlearnedWord), id);
      await t.tap(find.text('정답 보기'));
      await settle(t);
      expect(f.model.isLearned('word', id), true);
      await t.tap(find.byTooltip('학습 표시 해제'));
      await settle(t);
      expect(f.model.isLearned('word', id), false);
      await t.tap(find.byType(BackButton));
      await settle(t);
      expect(t.widget<Text>(label).style!.fontWeight, FontWeight.normal);
      await t.tap(label);
      await settle(t);
      expect(f.model.isLearned('word', id), false);
      await t.tap(find.text('정답 보기'));
      await settle(t);
      await t.tap(find.text('정답 닫기'));
      await settle(t);
      expect(f.model.isLearned('word', id), true);
      await t.tap(find.byType(BackButton));
      await settle(t);
      expect(t.widget<Text>(label).style!.fontWeight, FontWeight.normal);
      expect(
        t.widget<Material>(find.byKey(ValueKey('word-tile:$id'))).color,
        const Color(0xFFE0E0E0),
      );
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'kanji answer reveal marks the entire row; hide and next reset answer visibility',
    (t) async {
      await t.pumpWidget(JlptApp(model: f.model, speech: SilentSpeech()));
      await settle(t);
      await t.tap(find.text('한자').last);
      await settle(t);
      await t.tap(find.text('N5'));
      await settle(t);
      final label = find.byKey(const ValueKey('kanji-label:一'));
      expect(t.widget<Text>(label).style!.fontWeight, FontWeight.normal);
      await t.tap(label);
      await settle(t);
      expect(f.model.learned['kanji'], isEmpty);
      expect(find.text('한국식 훈 · 음'), findsNothing);
      await t.tap(find.text('정답 보기'));
      await settle(t);
      expect(f.model.learned['kanji'], {'一'});
      expect(find.text('한국식 훈 · 음'), findsOneWidget);
      await t.tap(find.text('정답 숨기기'));
      await settle(t);
      expect(find.text('한국식 훈 · 음'), findsNothing);
      expect(f.model.learned['kanji'], {'一'});
      await t.tap(find.byType(BackButton));
      await settle(t);
      expect(t.widget<Text>(label).style!.fontWeight, FontWeight.normal);
      expect(
        t.widget<Material>(find.byKey(const ValueKey('kanji-tile:一'))).color,
        const Color(0xFFE0E0E0),
      );
      await t.tap(label);
      await settle(t);
      await t.tap(find.byTooltip('학습 표시 해제'));
      await settle(t);
      await t.tap(find.byType(BackButton));
      await settle(t);
      expect(t.widget<Text>(label).style!.fontWeight, FontWeight.normal);
      expect(
        t.widget<Material>(find.byKey(const ValueKey('kanji-tile:一'))).color,
        Colors.transparent,
      );
      expect(f.model.learned['word'], isEmpty);
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'kanji test entry, fixed faces, next, finish and retry at 320px',
    (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
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
      await t.enterText(find.byType(TextField), '会');
      await settle(t);
      await t.tap(find.byKey(const ValueKey('kanji-checkbox:会')));
      await settle(t);
      await t.tap(find.byType(DropdownButton<String>));
      await settle(t);
      await t.tap(find.text('N5').last);
      await settle(t);
      await t.enterText(find.byType(TextField), '一');
      await settle(t);
      await t.tap(find.byKey(const ValueKey('kanji-checkbox:一')));
      await settle(t);
      await t.tap(find.text('한자 테스트'));
      await settle(t);
      expect(find.textContaining('한자 · 1 / 2 · 앞면'), findsOneWidget);
      expect(find.text('한국식 훈 · 음'), findsNothing);
      expect(find.textContaining('정보 표시 설정'), findsNothing);
      await t.tap(find.byKey(const ValueKey('test-action')));
      await settle(t);
      expect(find.text('한국식 훈 · 음'), findsOneWidget);
      expect(find.text('일본어 음독'), findsOneWidget);
      expect(find.text('일본어 훈독'), findsOneWidget);
      for (final rating in ratings.values) {
        expect(find.text(rating), findsNothing);
      }
      await t.tap(find.text('다음 문제'));
      await settle(t);
      expect(find.textContaining('한자 · 2 / 2 · 앞면'), findsOneWidget);
      expect(find.text('한국식 훈 · 음'), findsNothing);
      final one = (await t.runAsync(
        () => f.repo.start(['kanji:会'], kind: 'kanji'),
      ))!;
      await t.pumpWidget(
        MaterialApp(
          key: const ValueKey('one'),
          home: TestScreen(
            model: f.model,
            speech: SilentSpeech(),
            sessionId: one.id,
          ),
        ),
      );
      await settle(t);
      await t.tap(find.byKey(const ValueKey('test-action')));
      await settle(t);
      await t.tap(find.text('테스트 완료'));
      await settle(t);
      expect(find.text('한자 1개 확인'), findsOneWidget);
      await t.tap(find.text('전체 재시험'));
      await settle(t);
      expect(find.textContaining('한자 · 1 / 1 · 앞면'), findsOneWidget);
      expect(t.takeException(), null);
    },
  );

  testWidgets(
    'settings omit redundant learning reset and visibility; home continues at first incomplete word',
    (t) async {
      final ids = (await t.runAsync(
        () => f.repo.allIds(const WordFilter()),
      ))!.take(3).toList();
      await t.runAsync(() async {
        await f.model.visit('word', ids.first);
        await f.model.visit('kanji', '会');
        await f.model.select(ids, true);
        await f.model.star(ids.first);
        await f.repo.start(ids);
      });
      await t.pumpWidget(MaterialApp(home: SettingsScreen(model: f.model)));
      await settle(t);
      expect(find.text('단어 학습 표시 초기화'), findsNothing);
      expect(find.text('한자 학습 표시 초기화'), findsNothing);
      expect(find.text('학습 정보 표시 설정'), findsNothing);
      expect(f.model.learned['word'], {ids.first});
      expect(f.model.learned['kanji'], {'会'});
      expect(f.model.starred, {ids.first});
      expect(f.model.selected, ids.toSet());
      await t.pumpWidget(JlptApp(model: f.model, speech: SilentSpeech()));
      await settle(t);
      await t.scrollUntilVisible(
        find.text('이어서 학습'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(t);
      expect(find.text('이어서 테스트'), findsNothing);
      await t.tap(find.text('이어서 학습'));
      await settle(t);
      expect(t.widget<WordCard>(find.byType(WordCard)).word.id, ids[1]);
      expect(t.takeException(), null);
    },
  );
}
