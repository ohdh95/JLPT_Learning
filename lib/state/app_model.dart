import 'package:flutter/foundation.dart';
import '../data/models.dart';
import '../data/repository.dart';

class AppModel extends ChangeNotifier {
  final Repository repo;
  Set<String> selected = {}, starred = {}, kanjiSelected = {};
  Map<String, dynamic> prefs = {};
  Map<String, Set<String>> learned = {'word': {}, 'kanji': {}};
  Future<void> _pending = Future.value();
  AppModel(this.repo);
  Future<void> load() async {
    selected = await repo.selection();
    kanjiSelected = await repo.kanjiSelection();
    starred = await repo.stars();
    prefs = await repo.preferences();
    learned = await repo.visits();
    notifyListeners();
  }

  int get pageSize =>
      (prefs['page_size'] is int ? prefs['page_size'] as int : 20).clamp(
        1,
        200,
      );
  String get theme => prefs['theme'] as String? ?? 'system';
  // Stored legacy visibility preferences are retained for backup compatibility.
  // Both study and quiz fronts are fixed; explicit reveal shows the answers.
  Map<String, bool> visibility(String profile) => {
    for (final key in fields.keys) key: profile == 'test_back',
  };

  Future<void> _write(Future<void> Function() action) {
    final next = _pending.then((_) async {
      await action();
      notifyListeners();
    });
    _pending = next.catchError((Object _) {});
    return next;
  }

  Future<void> preference(String key, Object? value) => _write(() async {
    await repo.preference(key, value);
    prefs[key] = value;
  });
  Future<void> setPageSize(int size) {
    if (size < 1 || size > 200) {
      throw ArgumentError('1~200 범위로 입력하세요.');
    }
    return preference('page_size', size);
  }

  Future<void> toggleField(String profile, String key, bool value) =>
      _write(() async {
        if (!fields.containsKey(key)) {
          throw ArgumentError(key);
        }
        final v = visibility(profile)..[key] = value;
        await repo.preference('visibility_$profile', v);
        prefs['visibility_$profile'] = v;
      });
  Future<void> allFields(String profile, bool value) => preference(
    'visibility_$profile',
    {for (final k in fields.keys) k: value},
  );
  Future<void> select(Iterable<String> ids, bool value) {
    final snapshot = ids.toSet();
    return _write(() async {
      await repo.select(snapshot, value);
      if (value) {
        selected.addAll(snapshot);
      } else {
        selected.removeAll(snapshot);
      }
    });
  }

  Future<void> clearSelection() => _write(() async {
    await repo.clearSelection();
    selected.clear();
  });
  Future<void> star(String id) => _write(() async {
    final value = !starred.contains(id);
    await repo.star(id, value);
    if (value) {
      starred.add(id);
    } else {
      starred.remove(id);
    }
  });
  Future<void> selectKanji(Iterable<String> ids, bool value) {
    final snapshot = ids.toSet();
    return _write(() async {
      await repo.selectKanji(snapshot, value);
      if (value) {
        kanjiSelected.addAll(snapshot);
      } else {
        kanjiSelected.removeAll(snapshot);
      }
    });
  }

  Future<void> clearKanjiSelection() => _write(() async {
    await repo.clearKanjiSelection();
    kanjiSelected.clear();
  });
  Future<void> clearVisitItems(String kind, Iterable<String> ids) {
    final snapshot = ids.toSet();
    return _write(() async {
      await repo.clearVisitItems(kind, snapshot);
      learned = await repo.visits();
      prefs = await repo.preferences();
    });
  }

  bool? pageSelected(Iterable<String> ids, {bool kanji = false}) {
    final list = ids.toList();
    final n = list.where((kanji ? kanjiSelected : selected).contains).length;
    return n == 0
        ? false
        : n == list.length
        ? true
        : null;
  }

  bool isLearned(String kind, String id) => learned[kind]?.contains(id) == true;
  Future<void> visit(String kind, String id) => _write(() async {
    await repo.visit(kind, id);
    learned = await repo.visits();
    prefs = await repo.preferences();
  });
  Future<void> clearVisits(String kind, {String? itemId}) => _write(() async {
    await repo.clearVisits(kind, itemId: itemId);
    learned = await repo.visits();
    prefs = await repo.preferences();
  });
  void refresh() => notifyListeners();
}
