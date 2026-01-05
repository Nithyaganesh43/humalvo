import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _nameKey = 'assistant_name';

  Future<bool> saveAssistantName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_nameKey, name);
    } catch (e) {
      print('Error saving name: $e');
      return false;
    }
  }

  Future<String?> loadAssistantName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_nameKey);
    } catch (e) {
      print('Error loading name: $e');
      return null;
    }
  }

  Future<bool> clearAssistantName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_nameKey);
    } catch (e) {
      print('Error clearing name: $e');
      return false;
    }
  }
}