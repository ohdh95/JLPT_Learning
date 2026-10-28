import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';
import 'parts_of_speech.dart';

/// Two physical databases: content is immutable and replaceable; user.db is durable.
class Repository {
  static const _visitsSchema =
      "CREATE TABLE learning_visits(kind TEXT NOT NULL CHECK(kind IN ('word','kanji')), item_id TEXT NOT NULL, visited_at TEXT NOT NULL, PRIMARY KEY(kind,item_id))";
  final Database db;
  Repository._(this.db);
  static Future<Repository> bundled() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final bytes = (await rootBundle.load(
      'assets/content.sqlite',
    )).buffer.asUint8List();
    final hash = sha256.convert(bytes).toString();
    final content = File(p.join(dir.path, 'content-$hash.sqlite'));
    if (!await content.exists() ||
        sha256.convert(await content.readAsBytes()).toString() != hash) {
      final tmp = File('${content.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(content.path);
    }
    return open(databaseFactory, p.join(dir.path, 'user.db'), content.path);
  }

  static Future<Repository> open(
    DatabaseFactory factory,
    String userPath,
    String contentPath,
  ) async {
    final db = await factory.openDatabase(
      userPath,
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys=ON');
        },
        onCreate: (db, version) async {
          for (final sql in [
            'CREATE TABLE preferences(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
            'CREATE TABLE selection(word_id TEXT PRIMARY KEY)',
            'CREATE TABLE kanji_selection(character TEXT PRIMARY KEY)',
            _visitsSchema,
            'CREATE TABLE user_word_state(word_id TEXT PRIMARY KEY, is_starred INTEGER NOT NULL DEFAULT 0)',
            "CREATE TABLE test_sessions(id TEXT PRIMARY KEY, started_at TEXT NOT NULL, completed_at TEXT, status TEXT NOT NULL DEFAULT 'in_progress', order_json TEXT NOT NULL, snapshots_json TEXT NOT NULL, current_index INTEGER NOT NULL DEFAULT 0, revealed INTEGER NOT NULL DEFAULT 0, kind TEXT NOT NULL DEFAULT 'word')",
            "CREATE TABLE test_responses(session_id TEXT NOT NULL REFERENCES test_sessions(id) ON DELETE CASCADE, word_id TEXT NOT NULL, rating TEXT NOT NULL CHECK(rating IN ('unknown','uncertain','known','seen')), answered_at TEXT NOT NULL, PRIMARY KEY(session_id,word_id))",
            'CREATE INDEX responses_word_time ON test_responses(word_id,answered_at DESC)',
          ]) {
            await db.execute(sql);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              "ALTER TABLE test_sessions ADD COLUMN kind TEXT NOT NULL DEFAULT 'word'",
            );
            await db.execute(
              'ALTER TABLE test_responses RENAME TO test_responses_v1',
            );
            await db.execute(
              "CREATE TABLE test_responses(session_id TEXT NOT NULL REFERENCES test_sessions(id) ON DELETE CASCADE, word_id TEXT NOT NULL, rating TEXT NOT NULL CHECK(rating IN ('unknown','uncertain','known','seen')), answered_at TEXT NOT NULL, PRIMARY KEY(session_id,word_id))",
            );
            await db.execute(
              'INSERT INTO test_responses SELECT * FROM test_responses_v1',
            );
            await db.execute('DROP TABLE test_responses_v1');
            await db.execute(
              'CREATE INDEX responses_word_time ON test_responses(word_id,answered_at DESC)',
            );
            await db.execute(_visitsSchema);
            // v1 did not record explicit answer reveals; never infer completion
            // from a last-viewed preference or legacy self-rating.
          }
          if (oldVersion < 3) {
            await db.execute(
              'CREATE TABLE kanji_selection(character TEXT PRIMARY KEY)',
            );
          }
        },
      ),
    );
    await db.execute('ATTACH DATABASE ? AS content', [contentPath]);
    final integrity = await db.rawQuery('PRAGMA content.quick_check');
    if (integrity.single.values.first != 'ok') {
      await db.close();
      throw StateError('콘텐츠 DB 무결성 오류');
    }
    return Repository._(db);
  }

  Future<void> close() => db.close();
  Future<Map<String, dynamic>> preferences() async => {
    for (final r in await db.query('preferences'))
      r['key'] as String: jsonDecode(r['value'] as String),
  };
  Future<void> preference(String key, Object? value) async => db.insert(
    'preferences',
    {'key': key, 'value': jsonEncode(value)},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  Future<Set<String>> selection() async =>
      (await db.query('selection')).map((r) => r['word_id'] as String).toSet();
  Future<Set<String>> kanjiSelection() async => (await db.query(
    'kanji_selection',
  )).map((r) => r['character'] as String).toSet();
  Future<void> selectKanji(Iterable<String> characters, bool value) =>
      db.transaction((tx) async {
        final batch = tx.batch();
        for (final character in characters.toSet()) {
          if (value) {
            batch.insert('kanji_selection', {
              'character': character,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          } else {
            batch.delete(
              'kanji_selection',
              where: 'character=?',
              whereArgs: [character],
            );
          }
        }
        await batch.commit(noResult: true);
      });
  Future<void> clearKanjiSelection() async {
    await db.delete('kanji_selection');
  }

  Future<Set<String>> stars() async => (await db.query(
    'user_word_state',
    where: 'is_starred=1',
  )).map((r) => r['word_id'] as String).toSet();
  Future<void> select(Iterable<String> ids, bool value) =>
      db.transaction((tx) async {
        final batch = tx.batch();
        for (final id in ids.toSet()) {
          if (value) {
            batch.insert('selection', {
              'word_id': id,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          } else {
            batch.delete('selection', where: 'word_id=?', whereArgs: [id]);
          }
        }
        await batch.commit(noResult: true);
      });
  Future<void> clearSelection() async {
    await db.delete('selection');
  }

  Future<void> star(String id, bool value) async {
    await db.insert('user_word_state', {
      'word_id': id,
      'is_starred': value ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Set<String>>> visits() async {
    final result = <String, Set<String>>{'word': {}, 'kanji': {}};
    for (final row in await db.query('learning_visits')) {
      result[row['kind']]!.add(row['item_id'] as String);
    }
    return result;
  }

  Future<void> visit(String kind, String itemId) async {
    if (!['word', 'kanji'].contains(kind)) throw ArgumentError('학습 종류 오류');
    // Do not mark removed or missing content as having been opened.
    final exists = kind == 'word'
        ? await word(itemId) != null
        : await kanjiEntry(itemId) != null;
    if (!exists) return;
    await db.transaction((tx) async {
      await tx.insert('learning_visits', {
        'kind': kind,
        'item_id': itemId,
        'visited_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (kind == 'word') {
        await tx.insert('preferences', {
          'key': 'last_study',
          'value': jsonEncode(itemId),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> clearVisits(String kind, {String? itemId}) =>
      _clearVisits(kind, itemId == null ? null : {itemId});
  Future<void> clearVisitItems(String kind, Iterable<String> ids) =>
      _clearVisits(kind, ids.toSet());
  Future<void> _clearVisits(String kind, Set<String>? ids) => db.transaction((
    tx,
  ) async {
    if (!['word', 'kanji'].contains(kind)) throw ArgumentError('학습 종류 오류');
    if (ids == null) {
      await tx.delete('learning_visits', where: 'kind=?', whereArgs: [kind]);
    } else {
      final batch = tx.batch();
      for (final id in ids) {
        batch.delete(
          'learning_visits',
          where: 'kind=? AND item_id=?',
          whereArgs: [kind, id],
        );
      }
      await batch.commit(noResult: true);
    }
    if (kind == 'word') {
      final latest = await tx.query(
        'learning_visits',
        where: 'kind=?',
        whereArgs: ['word'],
        orderBy: 'visited_at DESC,rowid DESC',
        limit: 1,
      );
      await tx.delete('preferences', where: 'key=?', whereArgs: ['last_study']);
      if (latest.isNotEmpty) {
        await tx.insert('preferences', {
          'key': 'last_study',
          'value': jsonEncode(latest.single['item_id']),
        });
      }
    }
  });

  static const latestRating =
      '(SELECT r.rating FROM test_responses r WHERE r.word_id=v.word_id ORDER BY r.answered_at DESC,r.rowid DESC LIMIT 1)';
  (String, List<Object?>) _where(WordFilter filter) {
    final clauses = <String>['1=1'];
    final args = <Object?>[];
    if (filter.partOfSpeech != null) {
      clauses.add(partOfSpeechSql(filter.partOfSpeech!));
    }
    if (filter.level != null) {
      clauses.add('v.jlpt_level=?');
      args.add(filter.level);
    }
    if (filter.query.trim().isNotEmpty) {
      clauses.add(
        "(v.surface LIKE ? ESCAPE '\\' OR v.reading_kana LIKE ? ESCAPE '\\' OR v.meanings_ko_json LIKE ? ESCAPE '\\')",
      );
      final term =
          '%${filter.query.trim().replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%';
      args.addAll([term, term, term]);
    }
    if (filter.starred) {
      clauses.add(
        'EXISTS(SELECT 1 FROM user_word_state s WHERE s.word_id=v.word_id AND s.is_starred=1)',
      );
    }
    if (filter.selected) {
      clauses.add(
        'EXISTS(SELECT 1 FROM selection s WHERE s.word_id=v.word_id)',
      );
    }
    if (filter.status == 'unseen') {
      clauses.add('$latestRating IS NULL');
    } else if (ratings.containsKey(filter.status)) {
      clauses.add('$latestRating=?');
      args.add(filter.status);
    } else if (filter.status == 'unreviewed') {
      clauses.add("v.korean_meaning_status!='human_reviewed'");
    }
    return (clauses.join(' AND '), args);
  }

  String _order(WordFilter f) => f.sort == 'reading'
      ? 'v.reading_kana,v.surface,v.word_id'
      : 'v.jlpt_level DESC,v.source_index,v.word_id';
  Future<WordPage> words(WordFilter filter, int page, int size) async {
    if (size < 1 || size > 200) {
      throw ArgumentError('페이지 크기는 1~200');
    }
    final (where, args) = _where(filter);
    final total = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM content.vocab v WHERE $where',
        args,
      ),
    )!;
    final safePage = page.clamp(0, max(0, (total / size).ceil() - 1));
    final rows = await db.rawQuery(
      'SELECT v.*,$latestRating AS last_rating FROM content.vocab v WHERE $where ORDER BY ${_order(filter)} LIMIT ? OFFSET ?',
      [...args, size, safePage * size],
    );
    return WordPage(rows.map(Word.new).toList(), total, safePage.toInt(), size);
  }

  Future<List<String>> allIds(WordFilter filter) async {
    final (where, args) = _where(filter);
    return (await db.rawQuery(
      'SELECT v.word_id FROM content.vocab v WHERE $where ORDER BY ${_order(filter)}',
      args,
    )).map((r) => r['word_id'] as String).toList();
  }

  Future<String?> firstUnlearnedWord() async {
    final rows = await db.rawQuery(
      "SELECT v.word_id FROM content.vocab v WHERE NOT EXISTS(SELECT 1 FROM learning_visits l WHERE l.kind='word' AND l.item_id=v.word_id) ORDER BY ${_order(const WordFilter())} LIMIT 1",
    );
    return rows.isEmpty ? null : rows.single['word_id'] as String;
  }

  Future<Word?> word(String id) async {
    final rows = await db.rawQuery(
      'SELECT * FROM content.vocab WHERE word_id=?',
      [id],
    );
    return rows.isEmpty ? null : Word(rows.first);
  }

  Future<List<Map<String, Object?>>> components(String id) => db.rawQuery(
    'SELECT w.*, k.korean_hun,k.korean_eum,k.korean_hun_eum_status FROM content.word_kanji w LEFT JOIN content.kanji k ON k.character=w.character WHERE word_id=? ORDER BY surface_pos',
    [id],
  );
  Future<List<Map<String, Object?>>> examples(String id) async {
    final examples = await db.rawQuery(
      'SELECT * FROM content.examples WHERE word_id=? ORDER BY sequence',
      [id],
    );
    final links = await db.rawQuery(
      'SELECT l.* FROM content.example_word_links l JOIN content.examples e USING(example_id) WHERE e.word_id=? ORDER BY l.start_offset,l.end_offset,l.word_id',
      [id],
    );
    return [
      for (final ex in examples)
        {
          ...ex,
          'links': [
            for (final link in links)
              if (link['example_id'] == ex['example_id']) link,
          ],
        },
    ];
  }

  Future<List<Map<String, Object?>>> kanji(
    String level,
    bool cumulative,
    String query,
  ) => db.rawQuery(
    'SELECT * FROM content.kanji WHERE jlpt_level ${cumulative ? '>=' : '='} ? AND (instr(character,?)>0 OR instr(COALESCE(korean_hun,\'\'),?)>0 OR instr(COALESCE(korean_eum,\'\'),?)>0) ORDER BY jlpt_level DESC,character',
    [level, query, query, query],
  );
  Future<Map<String, Object?>?> kanjiEntry(String character) async {
    final rows = await db.rawQuery(
      'SELECT * FROM content.kanji WHERE character=?',
      [character],
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<List<Map<String, Object?>>> kanjiComponents(String character) =>
      db.rawQuery(
        'SELECT c.*,k.korean_hun,k.korean_eum '
        'FROM content.kanji_components c '
        'LEFT JOIN content.kanji k ON k.character=c.target_character '
        'WHERE c.character=? ORDER BY c.sequence',
        [character],
      );

  Future<String?> firstUnlearnedKanji() async {
    final rows = await db.rawQuery(
      "SELECT k.character FROM content.kanji k WHERE k.jlpt_level IN ('N5','N4','N3','N2','N1') AND NOT EXISTS(SELECT 1 FROM learning_visits l WHERE l.kind='kanji' AND l.item_id=k.character) ORDER BY k.jlpt_level DESC,k.character LIMIT 1",
    );
    return rows.isEmpty ? null : rows.single['character'] as String;
  }

  Future<List<Map<String, Object?>>> kanjiProgress() => db.rawQuery(
    "SELECT k.jlpt_level,COUNT(*) AS total,SUM(CASE WHEN EXISTS(SELECT 1 FROM learning_visits l WHERE l.kind='kanji' AND l.item_id=k.character) THEN 1 ELSE 0 END) AS studied FROM content.kanji k WHERE k.jlpt_level IN ('N5','N4','N3','N2','N1') GROUP BY k.jlpt_level ORDER BY k.jlpt_level DESC",
  );

  Future<List<Word>> related(String character) async => (await db.rawQuery(
    'SELECT DISTINCT v.* FROM content.vocab v JOIN content.word_kanji w ON v.word_id=w.word_id WHERE w.character=? ORDER BY v.jlpt_level DESC,v.source_index',
    [character],
  )).map(Word.new).toList();
  Future<List<Map<String, Object?>>> progress() => db.rawQuery(
    'SELECT v.jlpt_level,COUNT(*) AS total,SUM(CASE WHEN EXISTS(SELECT 1 FROM learning_visits l WHERE l.kind=\'word\' AND l.item_id=v.word_id) THEN 1 ELSE 0 END) AS studied,SUM(CASE WHEN $latestRating=\'known\' THEN 1 ELSE 0 END) AS known FROM content.vocab v GROUP BY v.jlpt_level ORDER BY v.jlpt_level DESC',
  );
  Future<List<Map<String, Object?>>> history() => db.rawQuery(
    'SELECT s.*, (SELECT COUNT(*) FROM test_responses r WHERE r.session_id=s.id) AS answered FROM test_sessions s ORDER BY started_at DESC,id DESC',
  );
  Future<TestSession> session(String id) async {
    final r = (await db.query(
      'test_sessions',
      where: 'id=?',
      whereArgs: [id],
    )).single;
    final responses = await db.query(
      'test_responses',
      where: 'session_id=?',
      whereArgs: [id],
    );
    return TestSession(
      id: id,
      kind: r['kind'] as String,
      startedAt: r['started_at'] as String,
      status: r['status'] as String,
      order: strings(r['order_json']),
      snapshots:
          jsonDecode(r['snapshots_json'] as String) as Map<String, dynamic>,
      responses: {
        for (final r in responses)
          r['word_id'] as String: r['rating'] as String,
      },
      index: r['current_index'] as int,
      revealed: r['revealed'] == 1,
    );
  }

  Future<TestSession> start(
    Iterable<String> ids, {
    Random? random,
    Map<String, dynamic>? fallback,
    String kind = 'word',
  }) async {
    if (!['word', 'kanji'].contains(kind)) throw ArgumentError('테스트 종류 오류');
    final order = ids.toSet().toList();
    if (order.isEmpty) {
      throw ArgumentError('단어를 먼저 선택하세요.');
    }
    final snapshots = <String, Object?>{};
    // Chunk to remain below Android SQLite's bound-variable limit.
    for (var offset = 0; offset < order.length; offset += 400) {
      final chunk = order.sublist(offset, min(offset + 400, order.length));
      for (final r in await db.rawQuery(
        "SELECT * FROM content.${kind == 'word' ? 'vocab' : 'kanji'} WHERE ${kind == 'word' ? 'word_id' : 'character'} IN (${List.filled(chunk.length, '?').join(',')})",
        kind == 'word'
            ? chunk
            : chunk.map((id) => id.replaceFirst('kanji:', '')).toList(),
      )) {
        snapshots[kind == 'word'
                ? r['word_id'] as String
                : "kanji:${r['character']}"] =
            r;
      }
    }
    for (final id in order) {
      if (!snapshots.containsKey(id) && fallback?[id] != null) {
        snapshots[id] = fallback![id];
      }
    }
    if (order.any((id) => !snapshots.containsKey(id))) {
      throw StateError('현재 콘텐츠에 없는 선택 항목이 있습니다. 선택 목록에서 해제해주세요.');
    }
    order.shuffle(random ?? Random.secure());
    final now = DateTime.now().toUtc().toIso8601String();
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    await db.insert('test_sessions', {
      'id': id,
      'kind': kind,
      'started_at': now,
      'order_json': jsonEncode(order),
      'snapshots_json': jsonEncode(snapshots),
    });
    return session(id);
  }

  Future<TestSession> startKanji(String level, {Random? random}) async {
    if (!levels.contains(level)) throw ArgumentError('급수 오류');
    final rows = await kanji(level, false, '');
    return start(
      rows.map((k) => "kanji:${k['character']}"),
      kind: 'kanji',
      random: random,
    );
  }

  Future<TestSession> retryAll(TestSession previous) =>
      start(previous.order, kind: previous.kind, fallback: previous.snapshots);

  Future<void> advance(String id, String itemId) =>
      _respond(id, itemId, 'seen');

  Future<void> reveal(String id) async {
    await db.update(
      'test_sessions',
      {'revealed': 1},
      where: "id=? AND status='in_progress'",
      whereArgs: [id],
    );
  }

  // Legacy ratings remain readable/restorable; the app now records only 'seen'.
  Future<void> rate(String id, String wordId, String rating) {
    if (!ratings.containsKey(rating)) throw ArgumentError('평가 오류');
    return _respond(id, wordId, rating);
  }

  Future<void> _respond(String id, String wordId, String rating) =>
      db.transaction((tx) async {
        final s = (await tx.query(
          'test_sessions',
          where: 'id=?',
          whereArgs: [id],
        )).single;
        final order = strings(s['order_json']);
        final index = s['current_index'] as int;
        if (s['status'] != 'in_progress' ||
            s['revealed'] != 1 ||
            index >= order.length ||
            order[index] != wordId) {
          throw StateError('현재 카드의 뒷면을 먼저 확인하세요.');
        }
        final now = DateTime.now().toUtc().toIso8601String();
        await tx.insert('test_responses', {
          'session_id': id,
          'word_id': wordId,
          'rating': rating,
          'answered_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await tx.update(
          'test_sessions',
          {
            'current_index': index + 1,
            'revealed': 0,
            'status': index + 1 == order.length ? 'completed' : 'in_progress',
            'completed_at': index + 1 == order.length ? now : null,
          },
          where: 'id=?',
          whereArgs: [id],
        );
      });
  Future<void> revisePrevious(String id, String rating) => db.transaction((
    tx,
  ) async {
    if (!ratings.containsKey(rating)) {
      throw ArgumentError('평가 오류');
    }
    final s = (await tx.query(
      'test_sessions',
      where: 'id=?',
      whereArgs: [id],
    )).single;
    final index = s['current_index'] as int;
    if (index == 0) {
      throw StateError('직전 평가가 없습니다.');
    }
    // Keep answered_at: editing an old session must not supersede a newer test.
    await tx.update(
      'test_responses',
      {'rating': rating},
      where: 'session_id=? AND word_id=?',
      whereArgs: [id, strings(s['order_json'])[index - 1]],
    );
  });
  Future<TestSession> retry(TestSession previous, Set<String> include) => start(
    previous.order.where((id) => include.contains(previous.responses[id])),
    fallback: previous.snapshots,
    kind: previous.kind,
  );
  Future<Map<String, Object?>> audit() async {
    final rows = await db.rawQuery(
      "SELECT COUNT(*) total,SUM(reading_check='direct_jmdict_verified') verified,SUM(korean_meaning_status='human_reviewed') ko,SUM(COALESCE(meanings_ko_json,'[]')!='[]') word_filled FROM content.vocab",
    );
    final kanji = (await db.rawQuery(
      "SELECT COUNT(*) kanji_total,SUM(jlpt_level IS NOT NULL) kanji_catalog,SUM(COALESCE(korean_hun,'')!='' AND COALESCE(korean_eum,'')!='') hanja_filled,SUM(korean_hun_eum_status='human_reviewed') hanja_reviewed FROM content.kanji",
    )).single;
    final examples = (await db.rawQuery(
      "SELECT COUNT(*) examples_total,SUM(COALESCE(text_ko,'')!='') examples_filled,SUM(korean_translation_status='human_reviewed') examples_reviewed FROM content.examples",
    )).single;
    final sources = await db.rawQuery('SELECT * FROM content.source_info');
    return {
      ...rows.single,
      ...kanji,
      ...examples,
      'integrity': (await db.rawQuery(
        'PRAGMA content.integrity_check',
      )).first.values.first,
      'foreign_keys': (await db.rawQuery(
        'PRAGMA content.foreign_key_check',
      )).length,
      'sources': {for (final r in sources) r['key']: r['value']},
    };
  }

  Future<String> backup() async {
    return db.transaction(
      (tx) async => jsonEncode({
        'format': 'jlpt-user-v3',
        for (final table in [
          'preferences',
          'selection',
          'kanji_selection',
          'user_word_state',
          'learning_visits',
          'test_sessions',
          'test_responses',
        ])
          table: await tx.query(table),
      }),
    );
  }

  Future<void> restore(String text) async {
    final data = jsonDecode(text) as Map<String, dynamic>;
    if (![
      'jlpt-user-v1',
      'jlpt-user-v2',
      'jlpt-user-v3',
    ].contains(data['format'])) {
      throw const FormatException('지원하지 않는 백업');
    }
    if (data['format'] == 'jlpt-user-v1') {
      data['learning_visits'] = <Map<String, Object?>>[];
    }
    if (data['format'] != 'jlpt-user-v3') {
      data['kanji_selection'] = <Map<String, Object?>>[];
    }
    // Validate before replacing anything. Transaction rolls back on any error.
    for (final t in [
      'preferences',
      'selection',
      'kanji_selection',
      'user_word_state',
      'learning_visits',
      'test_sessions',
      'test_responses',
    ]) {
      if (data[t] is! List) {
        throw FormatException('$t 누락');
      }
    }
    for (final v in data['learning_visits'] as List) {
      if (!['word', 'kanji'].contains(v['kind']) ||
          v['item_id'] is! String ||
          (v['item_id'] as String).isEmpty ||
          v['visited_at'] is! String ||
          DateTime.tryParse(v['visited_at'] as String) == null) {
        throw const FormatException('학습 표시 손상');
      }
    }
    for (final s in data['test_sessions'] as List) {
      if (!['word', 'kanji'].contains(s['kind'] ?? 'word')) {
        throw const FormatException('테스트 종류 오류');
      }
      final order = strings(s['order_json']);
      final i = s['current_index'];
      final snapshots = jsonDecode(s['snapshots_json'] as String) as Map;
      if (order.isEmpty ||
          order.toSet().length != order.length ||
          i is! int ||
          i < 0 ||
          i > order.length ||
          order.any((id) => !snapshots.containsKey(id)) ||
          !['completed', 'in_progress'].contains(s['status'])) {
        throw const FormatException('테스트 세션 손상');
      }
    }
    final sessions = {
      for (final s in data['test_sessions'] as List) s['id']: s,
    };
    for (final s in sessions.values) {
      final order = strings(s['order_json']);
      final index = s['current_index'] as int;
      if ((s['status'] == 'completed' && index != order.length) ||
          (s['status'] == 'in_progress' && index == order.length) ||
          ![0, 1].contains(s['revealed'])) {
        throw const FormatException('세션 진행 위치가 올바르지 않습니다.');
      }
      final snapshots = jsonDecode(s['snapshots_json'] as String) as Map;
      for (final id in order) {
        final w = snapshots[id];
        final isKanji = s['kind'] == 'kanji';
        if (w is! Map ||
            !levels.contains(w['jlpt_level']) ||
            (isKanji
                ? (w['character'] is! String || id != "kanji:${w['character']}")
                : (w['word_id'] != id ||
                      w['surface'] is! String ||
                      w['reading_kana'] is! String))) {
          throw const FormatException('테스트 스냅샷 손상');
        }
        for (final key
            in isKanji
                ? ['onyomi_json', 'kunyomi_json']
                : ['gloss_en_json', 'pos_codes_json', 'meanings_ko_json']) {
          strings(w[key]);
        }
      }
      final responses = (data['test_responses'] as List)
          .where((r) => r['session_id'] == s['id'])
          .toList();
      if (responses.length != index ||
          responses.map((r) => r['word_id']).toSet().length != index ||
          responses.any(
            (r) =>
                !order.take(index).contains(r['word_id']) ||
                (!ratings.containsKey(r['rating']) && r['rating'] != 'seen') ||
                DateTime.tryParse(r['answered_at'] as String) == null,
          )) {
        throw const FormatException('평가 기록과 진행 위치가 다릅니다.');
      }
    }
    for (final r in data['test_responses'] as List) {
      if (!sessions.containsKey(r['session_id'])) {
        throw const FormatException('평가의 세션이 없습니다.');
      }
    }
    for (final pref in data['preferences'] as List) {
      final value = jsonDecode(pref['value'] as String);
      if (pref['key'] == 'page_size' &&
          (value is! int || value < 1 || value > 200)) {
        throw const FormatException('페이지 크기 손상');
      }
    }
    await db.transaction((tx) async {
      for (final t in [
        'test_responses',
        'test_sessions',
        'selection',
        'kanji_selection',
        'preferences',
        'user_word_state',
        'learning_visits',
      ]) {
        await tx.delete(t);
      }
      for (final t in [
        'preferences',
        'selection',
        'kanji_selection',
        'user_word_state',
        'learning_visits',
        'test_sessions',
        'test_responses',
      ]) {
        for (final r in data[t] as List) {
          await tx.insert(t, Map<String, Object?>.from(r as Map));
        }
      }
    });
  }
}
