// ai_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// AI Service
// - Resolves AI endpoint from Central IP Server
// - Falls back to last-known / local endpoint
// - Caches resolved endpoint
class AiService {
  static const String _ipServer =
      "http://192.168.4.1:5000"; // 🔴 CHANGE WHEN READY

  // 🔁 Fallback (dev / demo / offline)
  static const String _fallbackEndpoint =
      "http://127.0.0.1:5001/predict";

  String? _cachedEndpoint;

  /// Resolve AI endpoint
  Future<String> _resolveEndpoint() async {
    // 1️⃣ Return cached endpoint if available
    if (_cachedEndpoint != null) {
      return _cachedEndpoint!;
    }

    final prefs = await SharedPreferences.getInstance();

    // 2️⃣ Try central IP server
    try {
      final r = await http
          .get(Uri.parse("$_ipServer/resolve/AI"))
          .timeout(const Duration(seconds: 4));

      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final url = "${data["url"]}/predict";

        _cachedEndpoint = url;
        await prefs.setString("ai_last_endpoint", url);

        print("✅ AI resolved from IP server: $url");
        return url;
      }
    } catch (e) {
      print("⚠ IP server unreachable, using fallback");
    }

    // 3️⃣ Try last-known endpoint
    final last = prefs.getString("ai_last_endpoint");
    if (last != null) {
      _cachedEndpoint = last;
      print("♻ Using cached AI endpoint: $last");
      return last;
    }

    // 4️⃣ Final fallback
    _cachedEndpoint = _fallbackEndpoint;
    print("🚨 Using fallback AI endpoint: $_fallbackEndpoint");
    return _fallbackEndpoint;
  }

  /// Clear cached endpoint (call if you want force re-resolve)
  void clearCache() {
    _cachedEndpoint = null;
  }

  /// Send text to AI server
  Future<String> getResponse(
    String text, {
    Duration timeout = const Duration(seconds: 7),
  }) async {
    final endpoint = await _resolveEndpoint();
    final uri = Uri.parse(endpoint);

    print("🤖 AI Request → $endpoint");
    print("📝 Text → $text");

    try {
      final resp = await http
          .post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"text": text}),
          )
          .timeout(timeout);

      print("✅ AI Status: ${resp.statusCode}");

      if (resp.statusCode != 200) {
        throw Exception("AI returned ${resp.statusCode}");
      }

      final contentType = resp.headers["content-type"] ?? "";

      if (contentType.contains("application/json")) {
        final data = jsonDecode(resp.body);

        if (data is Map) {
          return data["response"] ??
              data["prediction"] ??
              data["text"] ??
              data["answer"] ??
              data.toString();
        }
      }

      return resp.body;
    } catch (e) {
      print("❌ AI Error: $e");
      rethrow;
    }
  }

  /// Test AI availability
  Future<bool> testConnection() async {
    try {
      final res = await getResponse(
        "ping",
        timeout: const Duration(seconds: 5),
      );
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }  

  /// For UI / debugging
  Future<String> getCurrentEndpoint() async {
    return await _resolveEndpoint();
  }

}
