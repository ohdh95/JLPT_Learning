import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'branding.dart';
import 'data/repository.dart';
import 'data/speech.dart';
import 'state/app_model.dart';
import 'ui/screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<AppModel> future;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<AppModel> load() async {
    final m = AppModel(await Repository.bundled());
    await m.load();
    return m;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppModel>(
    future: future,
    builder: (context, s) {
      if (s.hasData) {
        return JlptApp(model: s.data!, speech: DeviceSpeech());
      }
      return MaterialApp(
        title: appName,
        home: Scaffold(
          body: Center(
            child: s.hasError
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('학습 DB를 열지 못했습니다. 저장 공간과 앱 설치 상태를 확인해주세요.'),
                        Text('${s.error}'),
                        FilledButton(
                          onPressed: () => setState(() {
                            future = load();
                          }),
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}

class JlptApp extends StatelessWidget {
  final AppModel model;
  final Speech speech;
  const JlptApp({super.key, required this.model, required this.speech});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      themeMode: switch (model.theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff246b57)),
        scaffoldBackgroundColor: const Color(0xfff7f8f2),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff89d5b6),
          brightness: Brightness.dark,
        ),
      ),
      home: Shell(model: model, speech: speech),
    ),
  );
}
