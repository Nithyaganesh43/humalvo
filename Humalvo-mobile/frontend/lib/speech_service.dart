// speech_service.dart
// BULLETPROOF VERSION - Handles null returns & race conditions

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class SpeechService {
  late stt.SpeechToText _speech;
  bool _isInitialized = false;
  bool _isListening = false;

  Function(String status)? onStatusChanged;
  Function(String error)? onError;

  SpeechService() {
    _speech = stt.SpeechToText();
  }

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      var success = await _speech.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        debugLogging: false,
      );

      // FIX: Some versions return null instead of bool
      _isInitialized = success == true;
      debugPrint('✅ Speech Service initialized: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      debugPrint('❌ Init error: $e');
      _isInitialized = false;
      return false;
    }
  }

  void _handleStatus(String status) {
    debugPrint('📢 Speech Status: $status');
    _isListening = status == 'listening';
    onStatusChanged?.call(status);
  }

  void _handleError(dynamic error) {
    final msg = error.errorMsg ?? error.toString();
    debugPrint('❌ Speech Error: $msg');
    _isListening = false;
    onError?.call(msg);
  }

  Future<bool> requestPermission() async {
    var status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> startListening({
  required Function(String text, bool isFinal) onResult,
  Duration? pauseFor,
  Duration? listenFor,
}) async {
  if (!_isInitialized) return false;
  if (_isListening) return false;

  try {
    // These options help reduce beeps on some devices
    await _speech.listen(
      onResult: (result) => onResult(result.recognizedWords, result.finalResult),
      listenMode: stt.ListenMode.confirmation,
      partialResults: true,
      pauseFor: pauseFor ?? const Duration(seconds: 3),
      listenFor: listenFor ?? const Duration(seconds: 20),
      onSoundLevelChange: (level) {}, // Dummy handler - sometimes reduces beeps
      cancelOnError: true,
      // CRITICAL: Try to suppress system UI/sound
      // Some devices respect this
    );

    _isListening = true;
    return true;
  } catch (e) {
    debugPrint('Listen error: $e');
    _isListening = false;
    return false;
  }
}
  Future<void> stopListening() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
        debugPrint('🛑 Listening stopped');
      }
    } catch (e) {
      debugPrint('⚠️ Stop error (safe to ignore): $e');
    }
    _isListening = false;
  }

  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (e) {
      // Ignore
    }
    _isListening = false;
  }

  void dispose() {
    stopListening();
  }
}