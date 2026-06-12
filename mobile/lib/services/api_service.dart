import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show Platform, SocketException;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String get baseUrl {
    return 'https://familyguard-znbt.onrender.com/api/v1';
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<int?> getParentId() async {
    final token = await getToken();
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload);
      return int.tryParse(data['sub'].toString());
    } catch (e) {
      debugPrint('Failed to decode JWT: $e');
      return null;
    }
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    
    // Sync token with native Android for Background Geofencing
    if (Platform.isAndroid) {
      try {
        const platform = MethodChannel('com.familyguard/geofence');
        final currentProfileId = prefs.getInt('current_profile_id') ?? -1;
        await platform.invokeMethod('syncAuthData', {
          'token': token,
          'profileId': currentProfileId,
          'baseUrl': baseUrl,
        });
      } catch (e) {
        debugPrint('Failed to sync auth data: $e');
      }
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  // ── Network Helper with Retry & Friendly Errors ──
  static Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() requestFunc, {
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        attempts++;
        final response = await requestFunc();
        return response;
      } on SocketException catch (_) {
        if (attempts >= maxRetries) {
          throw Exception('Pas de connexion internet. Vérifiez votre réseau.');
        }
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      } catch (e) {
        if (attempts >= maxRetries) {
          throw Exception('Impossible de joindre le serveur.');
        }
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    throw Exception('Erreur réseau.');
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _requestWithRetry(() => http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'username': username,
        'password': password,
      },
    ));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await setToken(data['access_token']);
      return data;
    } else {
      String errorMessage = 'Erreur de connexion';
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['detail'] ?? errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  static Future<Map<String, dynamic>> register(String email, String password) async {
    final response = await _requestWithRetry(() => http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    ));

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Erreur d\'inscription';
      try {
        final errorData = jsonDecode(response.body);
        errorMessage = errorData['detail'] ?? errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  static Future<List<dynamic>> getProfiles() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Non autorisé');
    }

    final response = await _requestWithRetry(() => http.get(
      Uri.parse('$baseUrl/profiles/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      if (response.statusCode == 401) {
        await logout();
      }
      throw Exception('Erreur lors du chargement des profils');
    }
  }

  static Future<Map<String, dynamic>> createProfile({
    required String name,
    required int age,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');

    final response = await _requestWithRetry(() => http.post(
      Uri.parse('$baseUrl/profiles/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': name, 'age': age}),
    ));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Erreur lors de la création';
      try {
        final data = jsonDecode(response.body);
        errorMessage = data['detail'] ?? errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  static Future<Map<String, dynamic>> updateProfile(int id, {
    String? name,
    int? age,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');

    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (age != null) body['age'] = age;

    final response = await _requestWithRetry(() => http.put(
      Uri.parse('$baseUrl/profiles/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Erreur lors de la modification';
      try {
        final data = jsonDecode(response.body);
        errorMessage = data['detail'] ?? errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  static Future<void> deleteProfile(int id) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');

    final response = await _requestWithRetry(() => http.delete(
      Uri.parse('$baseUrl/profiles/$id'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    ));

    if (response.statusCode != 200) {
      String errorMessage = 'Erreur lors de la suppression';
      try {
        final data = jsonDecode(response.body);
        errorMessage = data['detail'] ?? errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  static Future<Map<String, dynamic>> getTimeStatus(int profileId) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');

    final response = await http.get(
      Uri.parse('$baseUrl/profiles/$profileId/time-status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors du chargement du statut');
    }
  }

  static Future<Map<String, dynamic>> triggerSos(int profileId) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');

    final response = await http.post(
      Uri.parse('$baseUrl/profiles/$profileId/sos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors de l\'envoi de l\'alerte SOS');
    }
  }

  static Future<List<dynamic>> getAllLogs() async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');

    final response = await http.get(
      Uri.parse('$baseUrl/profiles/logs/all'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors du chargement de l\'historique');
    }
  }

  static Future<void> reportTimeUsage(int profileId, int minutes) async {
    final token = await getToken();
    if (token == null) return; // Silent fail

    await http.post(
      Uri.parse('$baseUrl/profiles/$profileId/time-usage'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'minutes': minutes,
      }),
    );
  }

  static Future<void> logBlockedDomain(int profileId, String url) async {
    final token = await getToken();
    if (token == null) return; // Silent fail for telemetry

    await http.post(
      Uri.parse('$baseUrl/filtering/log'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'profile_id': profileId,
        'url': url,
        'reason': 'Bloom Filter'
      }),
    );
  }

  static Future<Uint8List> downloadBloomFilter() async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');

    final response = await http.get(
      Uri.parse('$baseUrl/filtering/filter.bin'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Erreur lors du téléchargement du Bloom Filter');
    }
  }

  // ─── PIN Code Management ───

  static Future<bool> hasPin(int profileId) async {
    final token = await getToken();
    if (token == null) return false;

    final response = await http.get(
      Uri.parse('$baseUrl/profiles/$profileId/has-pin'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['has_pin'] ?? false;
    }
    return false;
  }

  static Future<bool> verifyPin(int profileId, String pin) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');

    final response = await http.post(
      Uri.parse('$baseUrl/profiles/$profileId/verify-pin'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'pin': pin}),
    );

    if (response.statusCode == 200) {
      return true;
    } else if (response.statusCode == 403) {
      return false;
    } else {
      throw Exception('Erreur de vérification');
    }
  }

  static Future<void> setPin(int profileId, String pin) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');

    final response = await http.put(
      Uri.parse('$baseUrl/profiles/$profileId/pin'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'pin': pin}),
    );

    if (response.statusCode != 200) {
      String errorMessage = 'Erreur';
      try {
        final data = jsonDecode(response.body);
        errorMessage = data['detail'] ?? errorMessage;
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  // ─── Instant Lock & Weekly Usage ───

  static Future<void> toggleLock(int profileId, bool isLocked) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');

    final response = await http.put(
      Uri.parse('$baseUrl/profiles/$profileId/lock'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'is_locked': isLocked}),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors du verrouillage');
    }
  }

  static Future<List<dynamic>> getWeeklyUsage(int profileId) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');

    final response = await http.get(
      Uri.parse('$baseUrl/profiles/$profileId/weekly-usage'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors du chargement des statistiques');
    }
  }

  // ──────────────────────────────────────────────────────────
  // GAMIFICATION
  // ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getGamificationSummary(int profileId) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');
    
    final response = await _requestWithRetry(() => http.get(
      Uri.parse('$baseUrl/gamification/$profileId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load gamification summary');
    }
  }

  static Future<List<dynamic>> getRewards(int profileId) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');
    
    final response = await _requestWithRetry(() => http.get(
      Uri.parse('$baseUrl/gamification/$profileId/rewards'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load rewards');
    }
  }

  static Future<void> claimReward(int profileId, int rewardId) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');
    
    final response = await _requestWithRetry(() => http.post(
      Uri.parse('$baseUrl/gamification/$profileId/rewards/$rewardId/claim'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ));

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to claim reward');
    }
  }

  // ──────────────────────────────────────────────────────────
  // PUSH NOTIFICATIONS
  // ──────────────────────────────────────────────────────────

  static Future<void> updateFcmToken(String token) async {
    final authToken = await getToken();
    if (authToken == null) throw Exception('Non autorisé');
    
    final response = await _requestWithRetry(() => http.post(
      Uri.parse('$baseUrl/auth/fcm-token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({'token': token}),
    ));

    if (response.statusCode != 200) {
      throw Exception('Failed to update FCM token');
    }
  }

  // ──────────────────────────────────────────────────────────
  // GEOFENCING
  // ──────────────────────────────────────────────────────────

  static Future<void> sendLocationUpdate(int profileId, double latitude, double longitude) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');
    
    final response = await _requestWithRetry(() => http.post(
      Uri.parse('$baseUrl/profiles/$profileId/location'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
      }),
    ));

    if (response.statusCode != 200) {
      throw Exception('Failed to send location update');
    }
  }

  // ──────────────────────────────────────────────────────────
  // CYBERBULLYING
  // ──────────────────────────────────────────────────────────

  static Future<void> reportCyberbullying(int profileId, String appPackage) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');
    
    final response = await _requestWithRetry(() => http.post(
      Uri.parse('$baseUrl/profiles/$profileId/harassment-alert'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'app_package': appPackage,
      }),
    ));

    if (response.statusCode != 200) {
      throw Exception('Failed to report cyberbullying');
    }
  }

  static Future<Map<String, dynamic>> disconnectEarly(int profileId) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');
    
    final response = await http.post(
      Uri.parse('$baseUrl/gamification/$profileId/disconnect-early'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      String errorMsg = 'Erreur lors de la déconnexion';
      try {
        final data = jsonDecode(response.body);
        errorMsg = data['detail'] ?? errorMsg;
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  // ── Quests API ──

  static Future<List<dynamic>> getQuests(int profileId) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');

    final response = await http.get(
      Uri.parse('$baseUrl/gamification/$profileId/quests'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erreur lors du chargement des quêtes');
    }
  }

  static Future<void> completeQuest(int questId) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');

    final response = await http.put(
      Uri.parse('$baseUrl/gamification/quests/$questId/complete'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la validation de la quête');
    }
  }

  static Future<void> validateQuest(int questId) async {
    final token = await getToken();
    if (token == null) throw Exception('Non autorisé');

    final response = await http.put(
      Uri.parse('$baseUrl/gamification/quests/$questId/validate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur lors de la validation parentale de la quête');
    }
  }

  static Future<List<Map<String, dynamic>>> getSafeZones(int profileId) async {
    final token = await getToken();
    if (token == null) throw Exception('Non authentifié');

    final response = await _requestWithRetry(() => http.get(
      Uri.parse('$baseUrl/profiles/$profileId/safe-zones'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    ));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Erreur lors de la récupération des zones de sécurité');
    }
  }
}

