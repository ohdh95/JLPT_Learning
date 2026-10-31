import 'dart:io';
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
  tearDown(() async => f.close());

  test(
    'one curriculum orders pages, filters, related words and resume',
    () async {
      final all = await f.repo.allIds(const WordFilter());
      final expected = await f.repo.db.rawQuery(
        'SELECT word_id FROM content.word_learning_order ORDER BY jlpt_level DESC,rank',
      );
      expect(all, expected.map((r) => r['word_id']).toList());
      expect(all.toSet().length, 7811);
      expect((await f.repo.word(all.first))!.surface, 'する');
      // Removed sort preferences must not opt users out of the new default.
      expect(await f.repo.allIds(const WordFilter(sort: 'reading')), all);
      for (final level in levels) {
        final ids = await f.repo.allIds(WordFilter(level: level));
        final paged = <String>[];
        for (var page = 0; page * 137 < ids.length; page++) {
          final result = await f.repo.words(
            WordFilter(level: level),
            page,
            137,
          );
          paged.addAll(result.words.map((w) => w.id));
        }
        expect(paged, ids);
      }
      final chosen = [all.last, all[100], all.first];
      await f.model.select(chosen, true);
      for (final id in chosen) {
        await f.model.star(id);
      }
      final orderedChosen = all.where(chosen.contains).toList();
      expect(
        await f.repo.allIds(const WordFilter(selected: true)),
        orderedChosen,
      );
      expect(
        await f.repo.allIds(const WordFilter(starred: true)),
        orderedChosen,
      );
      final related = (await f.repo.related('会')).map((w) => w.id).toList();
      expect(related, all.where(related.contains).toList());
      await f.model.visit('word', all.first);
      expect(await f.repo.firstUnlearnedWord(), all[1]);
    },
  );

  test(
    'updating legacy content preserves all saved user data by stable ID',
    () async {
      f.model.dispose();
      await f.repo.close();
      final contentPath = '${f.dir.path}/content.sqlite';
      final oldContent = await databaseFactoryFfiNoIsolate.openDatabase(
        contentPath,
      );
      await oldContent.execute('DROP TABLE word_learning_order');
      await oldContent.close();
      await f.reopen();
      final oldOrder = await f.repo.allIds(const WordFilter());
      expect((await f.repo.word(oldOrder.first))!.surface, '会う');
      await f.model.select([oldOrder.first, oldOrder[50]], true);
      await f.model.star(oldOrder.first);
      await f.model.visit('word', oldOrder.first);
      await f.model.visit('kanji', '会');
      await f.repo.preference('sort', 'reading');
      final session = await f.repo.start([oldOrder.first, oldOrder[50]]);
      final backup = await f.repo.backup();
      f.model.dispose();
      await f.repo.close();
      await File('assets/content.sqlite').copy(contentPath);
      await f.reopen();
      final newOrder = await f.repo.allIds(const WordFilter());
      expect(newOrder, isNot(oldOrder));
      expect(newOrder.toSet(), oldOrder.toSet());
      expect(await f.repo.backup(), backup);
      expect(f.model.learned['word'], {oldOrder.first});
      expect(f.model.learned['kanji'], {'会'});
      expect(f.model.starred, {oldOrder.first});
      expect(f.model.selected, {oldOrder.first, oldOrder[50]});
      expect((await f.repo.session(session.id)).order, session.order);
      expect(await f.repo.firstUnlearnedWord(), newOrder.first);
    },
  );
}
