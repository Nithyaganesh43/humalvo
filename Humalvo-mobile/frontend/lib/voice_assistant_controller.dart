// voice_assistant_controller.dart
// ANDROID-OPTIMIZED VERSION - December 30, 2025 🍞✨
// FIXES: Word cutoffs + Wake word delays + Command extraction without wake word

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'speech_service.dart';
import 'tts_service.dart';
import 'storage_service.dart';
import 'ai_service.dart';

enum AssistantMode { idle, listening, speaking, naming }

class VoiceAssistantController extends ChangeNotifier {
  final SpeechService _speechService;
  final TtsService _ttsService;
  final StorageService _storageService;
  final AiService _aiService;

  AssistantMode _mode = AssistantMode.idle;
  bool _continuousListening = false;
  bool _isWakeWordDetected = false;
  String _assistantName = '';
  String _currentText = '';
  String _voiceNameBuffer = '';
  String _lastProcessedText = '';
  final List<Map<String, String>> _conversationHistory = [];

  DateTime? _wakeWordDetectedTime;
  bool _isSpeakingBlocked = false;

  // Command accumulation with Android buffering
  String _accumulatedCommand = '';
  String _previousPartialText = '';
  bool _waitingForCompleteCommand = false;
  Timer? _commandCompletionTimer;
  int _partialResultCount = 0;

  Timer? _restartTimer;
  bool _isProcessingStatus = false;

  // Android-specific settings
  late final bool _isAndroid;
  late final Duration _pauseDuration;
  late final Duration _completionDelay;
  late final Duration _restartDelay;

  VoiceAssistantController()
      : _speechService = SpeechService(),
        _ttsService = TtsService(),
        _storageService = StorageService(),
        _aiService = AiService() {
    // Detect platform and set optimal timings
    _isAndroid = !kIsWeb && Platform.isAndroid;
    _pauseDuration = _isAndroid 
        ? const Duration(seconds: 12)  // Android: longer pause tolerance
        : const Duration(seconds: 10);
    _completionDelay = _isAndroid
        ? const Duration(milliseconds: 3500)  // Android: wait longer for complete sentences
        : const Duration(seconds: 5);
    _restartDelay = _isAndroid
        ? const Duration(milliseconds: 400)  // Android: faster restart
        : const Duration(milliseconds: 500);
    
    debugPrint('🤖 Platform: ${_isAndroid ? "ANDROID" : "OTHER"}');
    debugPrint('⚙️ Settings: pause=${_pauseDuration.inSeconds}s, completion=${_completionDelay.inMilliseconds}ms');
    
    _setupCallbacks();
  }

  // ====================== GETTERS ======================
  AssistantMode get mode => _mode;
  bool get isListening => _mode == AssistantMode.listening || _mode == AssistantMode.naming;
  bool get isSpeaking => _mode == AssistantMode.speaking;
  bool get isNaming => _mode == AssistantMode.naming;
  bool get continuousListening => _continuousListening;
  bool get isWakeWordDetected => _isWakeWordDetected;
  bool get hasAssistantName => _assistantName.isNotEmpty;
  String get assistantName => _assistantName;
  String get currentText => _currentText;
  String get voiceNameBuffer => _voiceNameBuffer;
  List<Map<String, String>> get conversationHistory => List.unmodifiable(_conversationHistory);

  String get statusMessage {
    if (_mode == AssistantMode.speaking) return "Speaking...";
    if (_isWakeWordDetected) {
      return _isAndroid 
          ? "✅ Ready – Speak your full command" 
          : "✅ Ready – Speak command";
    }
    if (_mode == AssistantMode.listening || _continuousListening) return "🔴 Listening...";
    return "Tap mic to wake";
  }

  Color get statusColor {
    if (_isWakeWordDetected) return Colors.green;
    if (_mode == AssistantMode.speaking) return Colors.orange;
    if (_mode == AssistantMode.listening || _continuousListening) return Colors.blue;
    return Colors.grey;
  }

  bool get isReadyForCommand => _isWakeWordDetected;

  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(_restartDelay, () {
      if (_continuousListening &&
          !_ttsService.isSpeaking &&
          !_isSpeakingBlocked &&
          !_speechService.isListening &&
          _mode != AssistantMode.naming &&
          _mode != AssistantMode.speaking) {
        debugPrint('🔄 [${_isAndroid ? "ANDROID" : "OTHER"}] Restarting...');
        startListening();
      }
    });
  }

  void _setupCallbacks() {
    _speechService.onStatusChanged = (status) {
      debugPrint('📢 Speech Status: $status');
      if (_isProcessingStatus) return;
      _isProcessingStatus = true;

      try {
        if (status == 'notListening' || status == 'done') {
          // ANDROID FIX: More aggressive restart during wake word window
          if (_isWakeWordDetected) {
            debugPrint('👂 [ANDROID] Wake word active - PRIORITY restart');
            if (_mode != AssistantMode.speaking && _mode != AssistantMode.naming) {
              _mode = AssistantMode.idle;
            }
            // Immediate restart on Android to prevent timeout
            if (_isAndroid) {
              Future.delayed(const Duration(milliseconds: 200), () {
                if (_continuousListening && !_speechService.isListening) {
                  startListening();
                }
              });
            } else {
              _scheduleRestart();
            }
            return;
          }

          if (_mode != AssistantMode.speaking && _mode != AssistantMode.naming) {
            _mode = AssistantMode.idle;
          }
          _scheduleRestart();
        }
      } finally {
        _isProcessingStatus = false;
        notifyListeners();
      }
    };

    _speechService.onError = (error) {
      debugPrint('❌ Speech error: $error');
      _scheduleRestart();
    };

    _ttsService.onStart = () {
      debugPrint('🗣️ TTS Started');
      _isSpeakingBlocked = true;
      _mode = AssistantMode.speaking;
      _speechService.stopListening();
      notifyListeners();
    };

    _ttsService.onComplete = () {
      debugPrint('✅ TTS Completed');
      _mode = AssistantMode.idle;
      Future.delayed(const Duration(milliseconds: 1000), () {
        _isSpeakingBlocked = false;
        _scheduleRestart();
        notifyListeners();
      });
    };

    _ttsService.onError = (error) {
      debugPrint('❌ TTS error: $error');
      _mode = AssistantMode.idle;
      _isSpeakingBlocked = false;
      _scheduleRestart();
      notifyListeners();
    };
  }

  Future<bool> initialize() async {
    debugPrint('🚀 Initializing Voice Assistant...');
    await _ttsService.initialize();
    final speechOk = await _speechService.initialize();
    if (!speechOk) {
      debugPrint('❌ Speech initialization failed');
      return false;
    }
    final savedName = await _storageService.loadAssistantName();
    if (savedName != null && savedName.isNotEmpty) {
      _assistantName = savedName;
      debugPrint('✅ Loaded name: $_assistantName');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
      await speak("Hello! I'm $_assistantName. Say my name to wake me up!", addToHistory: false);
    }
    return true;
  }

  Future<bool> startListening() async {
    if (_speechService.isListening) {
      debugPrint('⚠️ Already listening');
      return true;
    }
    if (_ttsService.isSpeaking || _isSpeakingBlocked || _mode == AssistantMode.naming) {
      debugPrint('⚠️ Cannot start - blocked');
      return false;
    }

    final hasPermission = await _speechService.requestPermission();
    if (!hasPermission) {
      debugPrint('❌ No microphone permission');
      return false;
    }

    await Future.delayed(const Duration(milliseconds: 300));
    _mode = AssistantMode.listening;
    _currentText = '';
    _partialResultCount = 0;
    _previousPartialText = '';
    notifyListeners();

    final started = await _speechService.startListening(
      onResult: (text, isFinal) {
        if (_mode != AssistantMode.listening) return;

        final trimmedText = text.trim();
        if (trimmedText.isEmpty) return;

        // DON'T update display here - let _handleUserInput do it
        // Extract clean command (without wake word) for display
        final cleanCommand = _extractCleanCommand(trimmedText);
        
        // Only show text if wake word already detected (command phase)
        if (_isWakeWordDetected && cleanCommand.isNotEmpty) {
          _currentText = cleanCommand;
          notifyListeners();
        }

        if (_isAndroid) {
          // ========== ANDROID-OPTIMIZED LOGIC ==========
          
          if (!isFinal) {
            // Track partial results
            _partialResultCount++;
            debugPrint('👂 [ANDROID] Partial #$_partialResultCount: "$trimmedText" → Clean: "$cleanCommand"');
            
            // Check for wake word in partials (immediate activation)
            if (!_isWakeWordDetected) {
              if (_containsWakeWord(trimmedText)) {
                debugPrint('🚨 [ANDROID] Wake word detected in partial!');
                _handleUserInput(trimmedText);
                return;
              }
            }
            
            // During wake word window: accumulate ALL partials
            if (_isWakeWordDetected) {
              // Only update if text is growing (Android sometimes repeats)
              if (trimmedText.length > _previousPartialText.length) {
                _previousPartialText = trimmedText;
                _handleUserInput(trimmedText);
              }
            }
          } else {
            // FINAL result - most reliable on Android
            debugPrint('✅ [ANDROID] FINAL (#$_partialResultCount): "$trimmedText" → Clean: "$cleanCommand"');
            _partialResultCount = 0;
            _previousPartialText = '';
            
            // Process if different from last
            if (trimmedText != _lastProcessedText) {
              _lastProcessedText = trimmedText;
              _handleUserInput(trimmedText);
            }
          }
        } else {
          // ========== CHROME/WEB LOGIC (original) ==========
          debugPrint('👂 Heard: "$trimmedText" → Clean: "$cleanCommand" (Final: $isFinal)');

          if (isFinal && trimmedText != _lastProcessedText) {
            debugPrint('✨ FINAL: "$trimmedText"');
            _lastProcessedText = trimmedText;
            _handleUserInput(trimmedText);
          } else if (!isFinal) {
            if (_containsWakeWord(trimmedText) && trimmedText != _lastProcessedText) {
              debugPrint('🚨 Wake word in partial: "$trimmedText"');
              _lastProcessedText = trimmedText;
              _handleUserInput(trimmedText);
            }
          }
        }
      },
      pauseFor: _pauseDuration,  // Platform-optimized
      listenFor: const Duration(hours: 1),
    );

    if (!started) {
      debugPrint('⚠️ Start failed');
      _mode = AssistantMode.idle;
      notifyListeners();
      return false;
    }
    debugPrint('✅ Listening started');
    return true;
  }

  // ========== NEW: Extract command without wake word ==========
  String _extractCleanCommand(String text) {
    if (_assistantName.isEmpty) return text;
    
    final lowerText = text.toLowerCase();
    final lowerName = _assistantName.toLowerCase().trim();
    
    // Find wake word position
    int wakeWordIndex = lowerText.indexOf(lowerName);
    
    // If wake word not found, try fuzzy matching on words
    if (wakeWordIndex == -1) {
      final words = text.split(' ');
      for (int i = 0; i < words.length; i++) {
        if (_isSimilar(words[i].toLowerCase(), lowerName)) {
          // Found fuzzy match - reconstruct without this word
          final beforeWake = words.sublist(0, i).join(' ');
          final afterWake = words.sublist(i + 1).join(' ');
          final result = '$beforeWake $afterWake'.trim();
          
          // Safety: Don't return assistant name itself
          if (result.toLowerCase() == lowerName) return '';
          return result;
        }
      }
      return text; // No wake word found
    }
    
    // Extract text after wake word
    final afterWakeWord = text.substring(wakeWordIndex + lowerName.length).trim();
    
    // If there's content before wake word, keep it too (rare but possible)
    final beforeWakeWord = text.substring(0, wakeWordIndex).trim();
    
    // Combine before and after, prioritizing after
    String result = '';
    if (afterWakeWord.isNotEmpty && beforeWakeWord.isNotEmpty) {
      result = '$afterWakeWord $beforeWakeWord'.trim();
    } else if (afterWakeWord.isNotEmpty) {
      result = afterWakeWord;
    } else if (beforeWakeWord.isNotEmpty) {
      result = beforeWakeWord;
    }
    
    // Safety: If result is just the wake word again, return empty
    if (result.toLowerCase() == lowerName) return '';
    
    return result;
  }

  bool _containsWakeWord(String text) {
    if (_assistantName.isEmpty) return false;
    final lowerText = text.toLowerCase();
    final lowerName = _assistantName.toLowerCase().trim();
    
    // Direct match
    if (lowerText.contains(lowerName)) return true;
    
    // Fuzzy word match
    return lowerText.split(' ').any((word) => _isSimilar(word, lowerName));
  }

  Future<bool> startVoiceNaming() async {
    debugPrint('🎤 Starting voice naming...');
    _continuousListening = false;
    final hasPermission = await _speechService.requestPermission();
    if (!hasPermission) {
      await speak("Please allow microphone access to set your name.", addToHistory: false);
      return false;
    }
    if (_speechService.isListening) {
      await _speechService.stopListening();
      await Future.delayed(const Duration(milliseconds: 600));
    }
    _mode = AssistantMode.naming;
    _currentText = '';
    _voiceNameBuffer = '';
    notifyListeners();

    final started = await _speechService.startListening(
      onResult: (text, isFinal) {
        if (_mode != AssistantMode.naming) return;
        debugPrint('👂 Name: "$text" (Final: $isFinal)');
        _currentText = text;
        notifyListeners();
        
        // ANDROID FIX: Accept both partial and final (more forgiving)
        if (text.trim().isNotEmpty && text.trim().length >= 2) {
          if (isFinal || (_isAndroid && text.trim().length >= 3)) {
            _voiceNameBuffer = text.trim();
            debugPrint('✅ Name captured: "$_voiceNameBuffer"');
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (_mode == AssistantMode.naming) saveVoiceName();
            });
          }
        }
      },
      pauseFor: const Duration(seconds: 4),
      listenFor: const Duration(seconds: 25),
    );
    return started;
  }

  Future<void> saveVoiceName() async {
    if (_voiceNameBuffer.isEmpty || _voiceNameBuffer.length < 2) {
      await speak("I didn't catch that. Please try again.", addToHistory: false);
      await Future.delayed(const Duration(milliseconds: 500));
      startVoiceNaming();
      return;
    }
    await _speechService.stopListening();
    final wasRenamed = _assistantName.isNotEmpty;
    _assistantName = _voiceNameBuffer;
    _voiceNameBuffer = '';
    _currentText = '';
    _mode = AssistantMode.idle;
    await _storageService.saveAssistantName(_assistantName);
    notifyListeners();
    if (wasRenamed) {
      await speak("Great! You can now call me $_assistantName.", addToHistory: false);
    } else {
      await speak("Perfect! I'm $_assistantName. Just say my name to wake me up.", addToHistory: false);
    }
    startContinuousListening();
  }

  void _handleUserInput(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final hasWakeWord = _containsWakeWord(trimmed);

    if (hasWakeWord && !_isWakeWordDetected) {
      // ========== WAKE WORD ACTIVATION ==========
      debugPrint('✅ [${_isAndroid ? "ANDROID" : "OTHER"}] Wake word detected: "$trimmed"');
      _isWakeWordDetected = true;
      _wakeWordDetectedTime = DateTime.now();
      _waitingForCompleteCommand = true;

      // Extract clean command (without wake word)
      final cleanCommand = _extractCleanCommand(trimmed);
      
      if (cleanCommand.isNotEmpty && cleanCommand.length > 2) {
        // User said wake word + command in one breath
        _accumulatedCommand = cleanCommand;
        _currentText = cleanCommand;
        debugPrint('🎯 Immediate command (clean): "$cleanCommand"');
      } else {
        // User said ONLY wake word - wait for command
        _accumulatedCommand = '';
        _currentText = ''; // Don't show anything yet!
        debugPrint('👂 Wake word only - waiting for command...');
      }
      
      notifyListeners();
      _startCommandCompletionTimer();
      return;
    }

    // ========== COMMAND ACCUMULATION (after wake word) ==========
    if (_isWakeWordDetected && _wakeWordDetectedTime != null) {
      final secondsSinceWake = DateTime.now().difference(_wakeWordDetectedTime!).inSeconds;
      
      // ANDROID FIX: Extend timeout to 25s (gives more time for complete sentences)
      final timeout = _isAndroid ? 25 : 20;
      if (secondsSinceWake > timeout) {
        debugPrint('⏰ [${_isAndroid ? "ANDROID" : "OTHER"}] ${timeout}s timeout - resetting');
        _resetWakeWordState();
        // Don't return - let it continue processing as potential new wake word
        // Check if this text contains wake word for new activation
        if (_containsWakeWord(trimmed)) {
          _handleUserInput(trimmed); // Recursive call to process as new wake word
        }
        return;
      }

      // Always use clean command (without wake word)
      final cleanCommand = _extractCleanCommand(trimmed);

      // Skip if command is empty or just whitespace
      if (cleanCommand.isEmpty) {
        debugPrint('⚠️ Empty command after extraction, skipping');
        return;
      }

      // ANDROID FIX: Smart accumulation strategy
      if (_isAndroid) {
        // Take the LONGEST version seen (prevents cutoffs)
        if (cleanCommand.length > _accumulatedCommand.length) {
          _accumulatedCommand = cleanCommand;
          _currentText = _accumulatedCommand;
          debugPrint('📝 [ANDROID] Updated to longer: "$_accumulatedCommand" (${cleanCommand.length} chars)');
        } else if (cleanCommand.length == _accumulatedCommand.length && cleanCommand != _accumulatedCommand) {
          // Same length but different text - take newer
          _accumulatedCommand = cleanCommand;
          _currentText = _accumulatedCommand;
          debugPrint('📝 [ANDROID] Updated (same length): "$_accumulatedCommand"');
        }
      } else {
        // Original logic for Chrome
        _accumulatedCommand = cleanCommand;
        _currentText = _accumulatedCommand;
        debugPrint('✅ Accumulated (clean): "$_accumulatedCommand"');
      }
      
      notifyListeners();
      _startCommandCompletionTimer();
    }
  }

  void _startCommandCompletionTimer() {
    _commandCompletionTimer?.cancel();
    _commandCompletionTimer = Timer(_completionDelay, () {
      if (_waitingForCompleteCommand && _accumulatedCommand.trim().isNotEmpty) {
        final cmd = _accumulatedCommand.trim();
        debugPrint('⏱️ [${_isAndroid ? "ANDROID" : "OTHER"}] Completion timer → Processing: "$cmd"');
        _resetWakeWordState();
        _processAndRespond(cmd);
      }
    });
    debugPrint('⏱️ Timer: ${_completionDelay.inMilliseconds}ms');
  }

  void _resetWakeWordState() {
    _isWakeWordDetected = false;
    _wakeWordDetectedTime = null;
    _waitingForCompleteCommand = false;
    _accumulatedCommand = '';
    _previousPartialText = '';
    _partialResultCount = 0;
    _commandCompletionTimer?.cancel();
    _commandCompletionTimer = null;
    _currentText = '';
    _lastProcessedText = '';
    notifyListeners();
  }

  bool _isSimilar(String a, String b) {
    if (a == b) return true;
    if (a.length < 3 || b.length < 3) return false;
    
    // ANDROID FIX: More lenient fuzzy matching (70% → 65%)
    int matches = 0;
    for (int i = 0; i < a.length && i < b.length; i++) {
      if (a[i] == b[i]) matches++;
    }
    final max = a.length > b.length ? a.length : b.length;
    final threshold = _isAndroid ? 0.65 : 0.7;
    return matches / max >= threshold;
  }

  Future<void> _processAndRespond(String command) async {
    debugPrint('🎯 FINAL Processing (clean command): "$command"');
    _currentText = '';
    await _speechService.stopListening();
    
    // Add to history WITHOUT wake word
    _conversationHistory.add({'type': 'user', 'text': command});
    notifyListeners();
    await _processCommand(command);
  }

  Future<void> _processCommand(String command) async {
    debugPrint('💬 Responding to: "$command"');
    _conversationHistory.add({'type': 'assistant', 'text': 'Processing...'});
    notifyListeners();

    try {
      final reply = await _aiService.getResponse(command);
      if (_conversationHistory.isNotEmpty && _conversationHistory.last['text'] == 'Processing...') {
        _conversationHistory.removeLast();
      }
      final assistantText = reply.trim().isNotEmpty ? reply : 'Sorry, no response.';
      _conversationHistory.add({'type': 'assistant', 'text': assistantText});
      notifyListeners();
      await speak(assistantText, addToHistory: false);
    } catch (e) {
      debugPrint('❌ AI error: $e');
      if (_conversationHistory.isNotEmpty && _conversationHistory.last['text'] == 'Processing...') {
        _conversationHistory.removeLast();
      }
      final errMsg = 'Sorry, I could not reach the server.';
      _conversationHistory.add({'type': 'assistant', 'text': errMsg});
      notifyListeners();
      await speak(errMsg, addToHistory: false);
    }
  }

  Future<void> speak(String text, {bool addToHistory = true}) async {
    debugPrint('🗣️ Speaking: "$text"');
    _isSpeakingBlocked = true;
    if (_speechService.isListening) await _speechService.stopListening();
    _mode = AssistantMode.speaking;
    if (addToHistory) {
      _conversationHistory.add({'type': 'assistant', 'text': text});
    }
    notifyListeners();
    await _ttsService.speak(text);
  }

  void startContinuousListening() {
    debugPrint('🔁 Starting continuous listening');
    _continuousListening = true;
    _resetWakeWordState();
    startListening();
  }

  Future<void> stopListening() async {
    debugPrint('🛑 Stopping listening');
    _restartTimer?.cancel();
    _commandCompletionTimer?.cancel();
    _restartTimer = null;
    _commandCompletionTimer = null;
    _continuousListening = false;
    _resetWakeWordState();
    _mode = AssistantMode.idle;
    await _speechService.stopListening();
    notifyListeners();
  }

  Future<void> setAssistantName(String name) async {
    await _speechService.stopListening();
    final wasRenamed = _assistantName.isNotEmpty;
    _assistantName = name.trim();
    _mode = AssistantMode.idle;
    await _storageService.saveAssistantName(_assistantName);
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));
    await speak(wasRenamed ? "Okay, I'm now $_assistantName!" : "Hi! I am $_assistantName.", addToHistory: false);
  }

  void clearHistory() {
    _conversationHistory.clear();
    notifyListeners();
  }

  Future<void> resetAssistant() async {
    _restartTimer?.cancel();
    _commandCompletionTimer?.cancel();
    _assistantName = '';
    _conversationHistory.clear();
    _continuousListening = false;
    _resetWakeWordState();
    _isSpeakingBlocked = false;
    _mode = AssistantMode.idle;
    await _storageService.clearAssistantName();
    await _speechService.stopListening();
    notifyListeners();
  }

  Future<void> cancelVoiceNaming() async {
    debugPrint('❌ Canceling voice naming');
    _mode = AssistantMode.idle;
    _voiceNameBuffer = '';
    _currentText = '';
    await _speechService.stopListening();
    notifyListeners();
    startContinuousListening();
  }

  @override
  void dispose() {
    _restartTimer?.cancel();
    _commandCompletionTimer?.cancel();
    _speechService.dispose();
    _ttsService.dispose();
    super.dispose();
  }
}