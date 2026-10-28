import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_study/data/speech.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'missing Japanese voice returns actionable message instead of throwing',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => call.method == 'isLanguageAvailable' ? false : 1,
          );
      final speech = DeviceSpeech();
      expect(await speech.speak('あした'), contains('일본어 TTS가 없습니다'));
      await speech.stop();
    },
  );
  test('platform failure is contained', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'NO_ENGINE'),
        );
    final speech = DeviceSpeech();
    expect(await speech.speak('あした'), contains('사용할 수 없습니다'));
    await speech.stop();
  });
  test(
    'Japanese locale, offline voice and supplied utterance reach engine',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'isLanguageAvailable') {
              return true;
            }
            if (call.method == 'getVoices') {
              return [
                {
                  'name': 'ja-local',
                  'locale': 'ja-JP',
                  'network_required': false,
                },
              ];
            }
            return 1;
          });
      final speech = DeviceSpeech();
      expect(await speech.speak('あした'), null);
      expect(
        calls.any((c) => c.method == 'setLanguage' && c.arguments == 'ja-JP'),
        true,
      );
      expect(calls.any((c) => c.method == 'speak'), true);
    },
  );
}
