import 'package:flutter_tts/flutter_tts.dart';

abstract class Speech {
  Future<String?> speak(String text);
  Future<void> stop();
}

class DeviceSpeech implements Speech {
  final FlutterTts tts = FlutterTts();
  @override
  Future<String?> speak(String text) async {
    try {
      if (await tts.isLanguageAvailable('ja-JP') != true) {
        return '일본어 TTS가 없습니다. 기기 설정 → 텍스트 음성 변환에서 일본어 음성 데이터를 설치해주세요.';
      }
      await tts.stop();
      await tts.setLanguage('ja-JP');
      await tts.setSpeechRate(0.45);
      final voices = await tts.getVoices;
      if (voices is List) {
        final offline = voices.whereType<Map>().where(
          (v) =>
              v['locale'].toString().replaceAll('_', '-').startsWith('ja') &&
              v['network_required'] != true &&
              v['network_required'] != 'true',
        );
        if (offline.isNotEmpty) {
          final v = offline.first;
          await tts.setVoice({
            'name': v['name'].toString(),
            'locale': v['locale'].toString(),
          });
        }
      }
      final result = await tts.speak(text);
      return result == 1 ? null : '발음을 재생할 수 없습니다. 일본어 TTS 음성 설치 상태를 확인해주세요.';
    } catch (_) {
      return '일본어 발음 엔진을 사용할 수 없습니다. 기기 TTS 설정과 일본어 음성 다운로드를 확인해주세요.';
    }
  }

  @override
  Future<void> stop() async {
    try {
      await tts.stop();
    } catch (_) {
      /* Engine may be unavailable. */
    }
  }
}
