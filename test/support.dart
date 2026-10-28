import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:jlpt_study/data/repository.dart';
import 'package:jlpt_study/data/speech.dart';
import 'package:jlpt_study/state/app_model.dart';

class Fixture {
  late Directory dir;
  late Repository repo;
  late AppModel model;
  Future<void> open() async {
    sqfliteFfiInit();
    dir = await Directory.systemTemp.createTemp('jlpt-test-');
    await File('assets/content.sqlite').copy('${dir.path}/content.sqlite');
    await reopen();
  }

  Future<void> reopen() async {
    repo = await Repository.open(
      databaseFactoryFfiNoIsolate,
      '${dir.path}/user.db',
      '${dir.path}/content.sqlite',
    );
    model = AppModel(repo);
    await model.load();
  }

  Future<void> close() async {
    model.dispose();
    await repo.close();
    await dir.delete(recursive: true);
  }
}

class SilentSpeech implements Speech {
  final List<String> spoken = [];
  @override
  Future<String?> speak(String text) async {
    spoken.add(text);
    return null;
  }

  @override
  Future<void> stop() async {}
}
