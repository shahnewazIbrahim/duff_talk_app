import 'package:flutter_tts/flutter_tts.dart';

import '../models/prediction_result.dart';

class TextToSpeechService {
  TextToSpeechService() : _tts = FlutterTts();

  final FlutterTts _tts;

  Future<void> initialize() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1);
  }

  Future<void> speak(PredictionResult result) {
    final text = result.label.toLowerCase() == 'nothing'
        ? 'No sign detected'
        : result.displayLabel;
    return _tts.speak(text);
  }

  Future<void> dispose() => _tts.stop();
}
