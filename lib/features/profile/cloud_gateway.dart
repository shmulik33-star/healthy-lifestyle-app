import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/storage/app_local_storage.dart';

class CloudUser {
  const CloudUser({required this.id, this.email});
  final String id;
  final String? email;
}

class CloudAuthResult {
  const CloudAuthResult(this.signedIn);
  final bool signedIn;
}

class CloudGatewayException implements Exception {
  const CloudGatewayException(this.code);
  final String code;
  @override
  String toString() => 'CloudGatewayException($code)';
}

String cloudGatewayMessage(String code) => switch (code) {
  'invalid_credentials' => 'האימייל או הסיסמה אינם נכונים.',
  'account_exists' => 'כבר קיים חשבון עם כתובת האימייל הזאת. אפשר להתחבר.',
  'password_too_short' => 'בהרשמה חדשה הסיסמה צריכה להכיל לפחות 8 תווים.',
  'authentication_required' => 'יש להתחבר לחשבון לפני הסנכרון.',
  'conflict' =>
    'הנתונים עודכנו במכשיר אחר. הסנכרון ינסה שוב בלי למחוק את העותק המקומי.',
  'food_conflict' =>
    'יש שתי גרסאות שונות למזון אישי. הסנכרון נעצר כדי לא לדרוס אף גרסה.',
  'rate_limited' => 'בוצעו יותר מדי ניסיונות. המתן מעט ונסה שוב.',
  _ => 'לא הצלחתי להתחבר לענן. הנתונים המקומיים נשארו שמורים.',
};

/// Appwrite is opt-in for migration preview. The default remains Supabase.
/// Appwrite credentials live only in a same-origin HttpOnly server cookie.
class CloudGateway {
  CloudGateway._();
  static const useAppwrite =
      String.fromEnvironment('CLOUD_BACKEND', defaultValue: 'supabase') ==
      'appwrite';
  static const _userKey = 'appwrite_offline_user_v1';
  static final _events = StreamController<CloudUser?>.broadcast();
  static CloudUser? _appwriteUser;
  static int _sessionGeneration = 0;
  static SupabaseClient get _supabase => Supabase.instance.client;
  static CloudUser? get currentUser {
    if (useAppwrite) return _appwriteUser;
    final user = _supabase.auth.currentUser;
    return user == null ? null : CloudUser(id: user.id, email: user.email);
  }

  static Stream<CloudUser?> get authChanges => useAppwrite
      ? _events.stream
      : _supabase.auth.onAuthStateChange.map((event) {
          final user = event.session?.user;
          return user == null
              ? null
              : CloudUser(id: user.id, email: user.email);
        });

  static Future<void> initialize() async {
    if (!useAppwrite) return;
    if (!kIsWeb) {
      throw UnsupportedError('Appwrite migration preview is web-only');
    }
    final cached = await AppLocalStorage.readString(_userKey);
    if (cached != null) {
      try {
        final user = jsonDecode(cached) as Map<String, dynamic>;
        _appwriteUser = CloudUser(
          id: user['id'] as String,
          email: user['email'] as String?,
        );
      } catch (_) {
        // An invalid offline identity never authorizes server requests.
      }
    }
    // Render local data immediately; network verification runs in background.
    unawaited(_refreshSession(_sessionGeneration));
  }

  static Future<void> _refreshSession(int generation) async {
    try {
      final result = await _request('session', method: 'GET');
      if (generation == _sessionGeneration) await _setUser(result['user']);
    } on CloudGatewayException catch (error) {
      if (error.code == 'authentication_required' &&
          generation == _sessionGeneration) {
        await _setUser(null);
      }
      // A transport/server outage must not erase the offline copy/session hint.
    } catch (_) {
      // Offline restart keeps the previously authenticated local experience.
    }
  }

  static Future<void> _setUser(dynamic raw) async {
    _appwriteUser = raw is Map
        ? CloudUser(id: raw['id'] as String, email: raw['email'] as String?)
        : null;
    if (_appwriteUser == null) {
      await AppLocalStorage.remove(_userKey);
    } else {
      await AppLocalStorage.writeString(
        _userKey,
        jsonEncode({'id': _appwriteUser!.id, 'email': _appwriteUser!.email}),
      );
    }
    _events.add(_appwriteUser);
  }

  static Future<Map<String, dynamic>> _request(
    String action, {
    String method = 'POST',
    Map<String, dynamic>? body,
    String? expectedUserId,
  }) async {
    final uri = Uri.base.resolve('/api/cloud/$action');
    final headers = <String, String>{
      'content-type': 'application/json',
      if (expectedUserId != null) 'x-fit-expected-user': expectedUserId,
    };
    final response = method == 'GET'
        ? await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20))
        : await http
              .post(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 30));
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (expectedUserId != null && currentUser?.id != expectedUserId) {
      throw const CloudGatewayException('authentication_required');
    }
    if (response.statusCode >= 400) {
      throw CloudGatewayException(
        result['error'] as String? ?? 'cloud_unavailable',
      );
    }
    return result;
  }

  static Future<CloudAuthResult> signUp(String email, String password) async {
    if (!useAppwrite) {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: kIsWeb ? Uri.base.origin : null,
      );
      return CloudAuthResult(response.session != null);
    }
    _sessionGeneration++;
    final response = await _request(
      'sign-up',
      body: {'email': email, 'password': password},
    );
    await _setUser(response['user']);
    return CloudAuthResult(_appwriteUser != null);
  }

  static Future<CloudAuthResult> signIn(String email, String password) async {
    if (!useAppwrite) {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return CloudAuthResult(response.session != null);
    }
    _sessionGeneration++;
    final response = await _request(
      'sign-in',
      body: {'email': email, 'password': password},
    );
    await _setUser(response['user']);
    return CloudAuthResult(_appwriteUser != null);
  }

  static Future<void> signOut() async {
    if (!useAppwrite) return _supabase.auth.signOut();
    _sessionGeneration++;
    try {
      await _request('sign-out');
    } on CloudGatewayException catch (error) {
      if (error.code != 'authentication_required') rethrow;
      // An expired server session must not trap the user behind sign-out.
    }
    await _setUser(null);
  }

  static Future<Map<String, dynamic>?> readState(String userId) async {
    if (!useAppwrite) {
      return _supabase
          .from('user_app_state')
          .select('payload,revision,updated_at')
          .eq('user_id', userId)
          .maybeSingle();
    }
    return (await _request(
          'state',
          method: 'GET',
          expectedUserId: userId,
        ))['row']
        as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>> writeState(
    String userId,
    Map<String, dynamic> payload,
    int expectedRevision,
  ) async {
    if (!useAppwrite) {
      return _supabase
          .from('user_app_state')
          .upsert({
            'user_id': userId,
            'payload': payload,
          }, onConflict: 'user_id')
          .select('payload,revision,updated_at')
          .single();
    }
    return (await _request(
          'state',
          expectedUserId: userId,
          body: {'payload': payload, 'expectedRevision': expectedRevision},
        ))['row']
        as Map<String, dynamic>;
  }

  static Future<List<dynamic>> readFoods(String userId) async => !useAppwrite
      ? await _supabase
            .from('user_custom_foods')
            .select('food_id,payload,updated_at')
      : (await _request('foods', method: 'GET', expectedUserId: userId))['rows']
            as List<dynamic>;

  static Future<void> writeFoods(List<Map<String, dynamic>> rows) async {
    if (!useAppwrite) {
      await _supabase
          .from('user_custom_foods')
          .upsert(rows, onConflict: 'user_id,food_id');
    } else {
      if (rows.isEmpty) return;
      await _request(
        'foods',
        expectedUserId: rows.first['user_id'] as String,
        body: {
          'rows': rows
              .map(
                (row) => {
                  'food_id': row['food_id'],
                  'payload': row['payload'],
                  'expectedUpdatedAt': row['expectedUpdatedAt'],
                  'expectedPayload': row['expectedPayload'],
                },
              )
              .toList(),
        },
      );
    }
  }

  static Future<void> deleteFoods(String userId, List<String> ids) async {
    if (!useAppwrite) {
      await _supabase
          .from('user_custom_foods')
          .delete()
          .eq('user_id', userId)
          .inFilter('food_id', ids);
    } else {
      await _request(
        'delete-foods',
        expectedUserId: userId,
        body: {'ids': ids},
      );
    }
  }

  static Future<List<dynamic>> readDaily(String userId) async => !useAppwrite
      ? await _supabase
            .from('user_daily_progress')
            .select('day_key,water_cups,steps,workout_completed')
      : (await _request('daily', method: 'GET', expectedUserId: userId))['rows']
            as List<dynamic>;

  static Future<void> mergeDaily(
    Map<String, dynamic> params,
    String userId,
  ) async {
    if (!useAppwrite) {
      await _supabase.rpc('merge_user_daily_progress', params: params);
    } else {
      await _request(
        'daily',
        expectedUserId: userId,
        body: {
          'day_key': params['p_day_key'],
          'water_cups': params['p_water_cups'],
          'steps': params['p_steps'],
          'workout_completed': params['p_workout_completed'],
        },
      );
    }
  }
}
