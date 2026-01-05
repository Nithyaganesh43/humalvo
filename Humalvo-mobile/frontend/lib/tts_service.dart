import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
class TtsService {
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;

  Function()? onStart;
  Function()? onComplete;
  Function(String error)? onError;

  TtsService() {
    _flutterTts = FlutterTts();
  }

  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    await _flutterTts.setLanguage("en-IN");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
      onStart?.call();
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      onComplete?.call();
    });

    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      onError?.call(msg);
    });
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  void dispose() {
    _flutterTts.stop();
  }
}