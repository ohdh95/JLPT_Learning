import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jlpt_study/data/repository.dart';
import 'package:jlpt_study/data/models.dart';
import 'package:jlpt_study/main.dart';
import 'package:jlpt_study/state/app_model.dart';
import '../test/support.dart' show SilentSpeech;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android full asset SQLite, selection and persisted card workflow',
    (tester) async {
      final repo = await Repository.bundled();
      final model = AppModel(repo);
      await model.load();
      await model.clearSelection();
      expect((await repo.audit())['total'], 7811);
      await tester.pumpWidget(JlptApp(model: model, speech: SilentSpeech()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('N5'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('다음 페이지'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      expect(model.selected.length, 2);
      await tester.tap(find.text('테스트').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('테스트 시작'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('정답 확인 · 뒤집기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음 문제'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('정답 확인 · 뒤집기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('테스트 완료'));
      await tester.pumpAndSettle();
      expect(find.text('테스트 완료'), findsOneWidget);
      final rows = await repo.history();
      final id = rows.first['id'] as String;
      expect((await repo.session(id)).complete, true);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await repo.close();
      final reopened = await Repository.bundled();
      expect((await reopened.selection()).length, 2);
      expect((await reopened.session(id)).responses.length, 2);
      expect(
        (await reopened.words(const WordFilter(level: 'N5'), 0, 20)).total,
        674,
      );
      await reopened.close();
    },
  );
}
