import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_study/data/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support.dart';

void main() {
  late Fixture f;
  setUp(() async {
    f = Fixture();
    await f.open();
  });
  tearDown(() async {
    await f.close();
  });
  test('real full content, integrity, search and stable pagination', () async {
    final a = await f.repo.audit();
    expect(a['total'], 7811);
    expect(a['integrity'], 'ok');
    expect(a['foreign_keys'], 0);
    final p = await f.repo.words(const WordFilter(level: 'N5'), 0, 20);
    expect(p.total, 674);
    expect(p.words.length, 20);
    final again = await f.repo.words(const WordFilter(level: 'N5'), 0, 20);
    expect(again.words.map((w) => w.id), p.words.map((w) => w.id));
    final search = await f.repo.words(const WordFilter(query: 'あした'), 0, 20);
    expect(search.words.any((w) => w.surface == '明日'), true);
    expect((await f.repo.words(const WordFilter(query: '%_'), 0, 20)).total, 0);
    expect(
      (await f.repo.words(const WordFilter(level: 'N5'), 999, 20)).page,
      33,
    );
    await expectLater(
      f.repo.words(const WordFilter(), 0, 201),
      throwsArgumentError,
    );
  });
  test(
    'localized content is searchable without certifying drafts or assigning supplemental levels',
    () async {
      final audit = await f.repo.audit();
      expect(audit['word_filled'], 7811);
      expect(audit['hanja_filled'], 2756);
      expect(audit['kanji_catalog'], 2383);
      expect(audit['examples_filled'], 13718);
      expect(audit['ko'], 0);
      expect(audit['hanja_reviewed'], 0);
      expect(audit['examples_reviewed'], 0);
      final meet = (await f.repo.words(
        const WordFilter(query: '만나다', level: 'N5'),
        0,
        20,
      )).words;
      expect(meet.any((w) => w.surface == '会う'), true);
      final components = await f.repo.components('5d72771a3c');
      expect(components.single['character'], '飴');
      expect(components.single['korean_hun'], isNotEmpty);
      expect(components.single['korean_hun_eum_status'], 'draft');
      expect(await f.repo.kanji('N1', true, '飴'), isEmpty);
      final examples = await f.repo.examples('4aab699864');
      expect(examples.last['text_ko'], '형/오빠는 아파트를 찾고 있습니다.');
      expect(examples.last['korean_translation_status'], 'draft');
      expect(
        (await f.repo.words(
          const WordFilter(status: 'unreviewed'),
          0,
          20,
        )).total,
        7811,
      );
    },
  );
  test(
    'selection survives pages, level, search, star list, size and restart; indeterminate',
    () async {
      final one = await f.repo.words(const WordFilter(level: 'N5'), 0, 20);
      final two = await f.repo.words(const WordFilter(level: 'N5'), 1, 20);
      final harder = await f.repo.words(const WordFilter(level: 'N1'), 0, 20);
      expect(f.model.pageSelected(one.words.map((w) => w.id)), false);
      await f.model.select([one.words.first.id], true);
      expect(f.model.pageSelected(one.words.map((w) => w.id)), null);
      await f.model.select(one.words.map((w) => w.id), true);
      expect(f.model.pageSelected(one.words.map((w) => w.id)), true);
      await f.model.select([
        two.words.first.id,
        harder.words.first.id,
        one.words.first.id,
      ], true);
      expect(f.model.selected.length, 22);
      for (final size in [1, 10, 30, 50, 100, 200]) {
        await f.model.setPageSize(size);
        await f.repo.words(const WordFilter(query: '明'), 0, size);
        expect(f.model.selected.length, 22);
      }
      await f.model.star(one.words.first.id);
      await f.repo.words(const WordFilter(starred: true), 0, 20);
      f.model.dispose();
      await f.repo.close();
      await f.reopen();
      expect(f.model.selected.length, 22);
      expect(f.model.pageSize, 200);
      expect(f.model.starred, contains(one.words.first.id));
      await f.model.select(one.words.map((w) => w.id), false);
      expect(f.model.selected.length, 2);
    },
  );
  test('entire result selection handles thousands and duplicate IDs', () async {
    final ids = await f.repo.allIds(const WordFilter());
    expect(ids.length, 7811);
    await f.model.select(ids, true);
    await f.model.select(ids.take(20), true);
    expect(f.model.selected.length, 7811);
    expect(
      (await f.repo.words(const WordFilter(selected: true), 0, 100)).total,
      7811,
    );
    await f.model.clearSelection();
    expect(await f.repo.selection(), isEmpty);
  });
  test(
    'fixed faces ignore legacy visibility preferences and validate page size',
    () async {
      expect(f.model.visibility('study').values.any((v) => v), false);
      expect(f.model.visibility('test_front').values.any((v) => v), false);
      for (final key in fields.keys) {
        await f.model.toggleField('study', key, true);
        expect(f.model.visibility('study')[key], false);
        expect(f.model.prefs['visibility_study'][key], true);
        await f.model.toggleField('study', key, false);
        expect(f.model.visibility('study')[key], false);
      }
      await f.model.allFields('test_front', true);
      expect(f.model.visibility('test_back').values.every((v) => v), true);
      await f.model.allFields('test_back', false);
      await f.model.allFields('study', true);
      f.model.dispose();
      await f.repo.close();
      await f.reopen();
      expect(f.model.visibility('test_back').values.every((v) => v), true);
      expect(f.model.visibility('test_front').values.any((v) => v), false);
      expect(f.model.visibility('study').values.any((v) => v), false);
      expect(
        (f.model.prefs['visibility_study'] as Map).values.every(
          (v) => v == true,
        ),
        true,
      );
      expect(() => f.model.setPageSize(0), throwsArgumentError);
      expect(() => f.model.setPageSize(201), throwsArgumentError);
    },
  );
  test(
    'shuffle deduplicates, reveal gates evaluation, crash resume and previous edit',
    () async {
      final ids = (await f.repo.allIds(
        const WordFilter(level: 'N5'),
      )).take(8).toList();
      var s = await f.repo.start([...ids, ...ids], random: Random(7));
      expect(s.order.toSet(), ids.toSet());
      expect(s.order, isNot(ids));
      final original = List<String>.from(s.order);
      await expectLater(
        f.repo.rate(s.id, s.order.first, 'known'),
        throwsStateError,
      );
      await f.repo.reveal(s.id);
      await f.repo.rate(s.id, s.order.first, 'unknown');
      await expectLater(
        f.repo.rate(s.id, s.order.first, 'known'),
        throwsStateError,
      );
      await f.repo.reveal(s.id);
      f.model.dispose();
      await f.repo.close();
      await f.reopen();
      s = await f.repo.session(s.id);
      expect(s.order, original);
      expect(s.index, 1);
      expect(s.revealed, true);
      expect(s.responses[s.order.first], 'unknown');
      await f.model.allFields('test_front', true);
      await f.repo.revisePrevious(s.id, 'uncertain');
      s = await f.repo.session(s.id);
      expect(s.index, 1);
      expect(s.order, original);
      expect(s.responses[s.order.first], 'uncertain');
      expect(f.model.starred, isEmpty);
    },
  );
  test(
    'completion, ratios, latest progress, star independence and filtered retries',
    () async {
      final ids = (await f.repo.allIds(
        const WordFilter(level: 'N5'),
      )).take(3).toList();
      var s = await f.repo.start(ids, random: Random(2));
      for (var i = 0; i < 3; i++) {
        await f.repo.reveal(s.id);
        await f.repo.rate(s.id, s.order[i], ratings.keys.elementAt(i));
      }
      s = await f.repo.session(s.id);
      expect(s.complete, true);
      expect(s.responses.length, 3);
      expect(s.index, 3);
      await f.model.star(s.order.first);
      expect((await f.repo.session(s.id)).responses, s.responses);
      expect(
        (await f.repo.words(const WordFilter(status: 'unknown'), 0, 20)).total,
        1,
      );
      final unknown = await f.repo.retry(s, {'unknown'});
      expect(unknown.order, [s.order.first]);
      final weak = await f.repo.retry(s, {'unknown', 'uncertain'});
      expect(weak.order.toSet(), s.order.take(2).toSet());
      final all = await f.repo.retry(s, ratings.keys.toSet());
      expect(all.order.toSet(), s.order.toSet());
      await f.repo.reveal(unknown.id);
      await f.repo.rate(unknown.id, unknown.order.single, 'known');
      expect(
        (await f.repo.words(const WordFilter(status: 'unknown'), 0, 20)).total,
        0,
      );
      expect(
        (await f.repo.progress()).first['studied'],
        0,
      ); // Only opened detail pages count as learned.
      expect((await f.repo.progress()).first['known'], 2);
      await expectLater(f.repo.start([]), throwsArgumentError);
    },
  );
  test(
    'content replacement preserves selected IDs, stars, histories and removed-word snapshots',
    () async {
      final id = (await f.repo.allIds(const WordFilter())).first;
      await f.model.select([id], true);
      await f.model.star(id);
      final s = await f.repo.start([id]);
      f.model.dispose();
      await f.repo.close();
      final content = await databaseFactoryFfiNoIsolate.openDatabase(
        '${f.dir.path}/content.sqlite',
      );
      for (final t in ['examples', 'word_kanji', 'validations']) {
        await content.delete(t, where: 'word_id=?', whereArgs: [id]);
      }
      await content.delete('vocab', where: 'word_id=?', whereArgs: [id]);
      await content.close();
      await f.reopen();
      expect(f.model.selected, contains(id));
      expect(f.model.starred, contains(id));
      expect(await f.repo.word(id), null);
      var resumed = await f.repo.session(s.id);
      expect(resumed.snapshot(id).surface, isNotEmpty);
      await f.repo.reveal(s.id);
      await f.repo.rate(s.id, id, 'unknown');
      resumed = await f.repo.session(s.id);
      expect((await f.repo.retry(resumed, {'unknown'})).order, [id]);
    },
  );
  test('backup round trip and invalid import rollback', () async {
    final id = (await f.repo.allIds(const WordFilter())).first;
    await f.model.select([id], true);
    await f.model.star(id);
    await f.repo.start([id]);
    final backup = await f.repo.backup();
    await f.model.clearSelection();
    await f.repo.restore(backup);
    await f.model.load();
    expect(f.model.selected, {id});
    final bad = jsonDecode(backup) as Map<String, dynamic>;
    bad['selection'] = [
      {'bad_column': 'oops'},
    ];
    await expectLater(
      f.repo.restore(jsonEncode(bad)),
      throwsA(isA<DatabaseException>()),
    );
    expect(await f.repo.selection(), {id});
  });
  test(
    'kanji cumulative and jukujikun do not invent reading alignment',
    () async {
      expect((await f.repo.kanji('N4', false, '')).length, 169);
      expect((await f.repo.kanji('N4', true, '')).length, 253);
      for (final surface in ['明日', '明後日']) {
        final words = await f.repo.words(WordFilter(query: surface), 0, 200);
        for (final w in words.words) {
          for (final k in await f.repo.components(w.id)) {
            expect(k['reading_in_word'], null);
            expect(k['reading_alignment_status'], 'not_verified');
          }
        }
      }
    },
  );
  test(
    'corrupt backup session and preferences rejected before replacement',
    () async {
      final id = (await f.repo.allIds(const WordFilter())).first;
      await f.repo.start([id]);
      await f.model.select([id], true);
      final data = jsonDecode(await f.repo.backup()) as Map<String, dynamic>;
      (data['test_sessions'] as List).first['current_index'] = 1;
      await expectLater(
        f.repo.restore(jsonEncode(data)),
        throwsFormatException,
      );
      expect(await f.repo.selection(), {id});
      final settings =
          jsonDecode(await f.repo.backup()) as Map<String, dynamic>;
      settings['preferences'] = [
        {'key': 'page_size', 'value': '0'},
      ];
      await expectLater(
        f.repo.restore(jsonEncode(settings)),
        throwsFormatException,
      );
      expect(await f.repo.selection(), {id});
    },
  );
}
