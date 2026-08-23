import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/app_state.dart';
import 'cloud_sync_service.dart';

class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key, required this.state});

  final AppState state;

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  String _message = '';
  bool _messageIsError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setMessage(String message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _messageIsError = error;
    });
  }

  bool _validateCredentials() {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') || !email.contains('.')) {
      _setMessage('יש להזין כתובת אימייל תקינה.', error: true);
      return false;
    }
    if (password.length < 6) {
      _setMessage('הסיסמה צריכה להכיל לפחות 6 תווים.', error: true);
      return false;
    }
    return true;
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = '';
      _messageIsError = false;
    });
    try {
      await action();
    } on AuthException catch (error) {
      _setMessage(_friendlyAuthMessage(error), error: true);
    } on PostgrestException catch (_) {
      _setMessage('לא הצלחתי לסנכרן מול הענן. נסה שוב בעוד רגע.', error: true);
    } on StateError catch (error) {
      if (error.message == 'cloud_sync_requires_sign_in') {
        _setMessage('יש להתחבר לחשבון לפני הסנכרון.', error: true);
      } else {
        _setMessage('אירעה שגיאה בסנכרון. הנתונים המקומיים נשארו שמורים.', error: true);
      }
    } catch (_) {
      _setMessage('אירעה שגיאה. הנתונים המקומיים נשארו שמורים במכשיר.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyAuthMessage(AuthException error) {
    final text = error.message.toLowerCase();
    if (text.contains('invalid login credentials')) {
      return 'האימייל או הסיסמה אינם נכונים.';
    }
    if (text.contains('email not confirmed')) {
      return 'צריך לאשר את כתובת האימייל לפני ההתחברות.';
    }
    if (text.contains('already registered') || text.contains('already been registered')) {
      return 'כבר קיים חשבון עם כתובת האימייל הזאת. אפשר להתחבר.';
    }
    if (text.contains('password')) {
      return 'הסיסמה אינה עומדת בדרישות. נסה סיסמה ארוכה יותר.';
    }
    if (text.contains('rate limit')) {
      return 'בוצעו יותר מדי ניסיונות בזמן קצר. המתן מעט ונסה שוב.';
    }
    return 'לא הצלחתי לבצע את פעולת החשבון. נסה שוב.';
  }

  Future<void> _signUp() => _runBusy(() async {
        if (!_validateCredentials()) return;
        final response = await CloudSyncService.signUp(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (!mounted) return;
        if (response.session == null) {
          _setMessage(
            'נשלח אליך מייל לאימות החשבון. אשר את האימייל, חזור למסך הזה ולחץ „התחבר”.',
          );
          return;
        }
        await _sync(showSignedInMessage: true);
      });

  Future<void> _signIn() => _runBusy(() async {
        if (!_validateCredentials()) return;
        await CloudSyncService.signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (!mounted) return;
        await _sync(showSignedInMessage: true);
      });

  Future<void> _sync({bool showSignedInMessage = false}) async {
    final result = await CloudSyncService.syncCustomFoods(widget.state);
    if (!mounted) return;
    final prefix = showSignedInMessage ? 'התחברת בהצלחה. ' : '';
    _setMessage(
      '$prefixהסנכרון הושלם: ${result.uploaded} הועלו, '
      '${result.downloaded} הורדו, ובסך הכול ${result.total} מזונות אישיים מסונכרנים.',
    );
    setState(() {});
  }

  Future<void> _syncNow() => _runBusy(() => _sync());

  Future<void> _signOut() => _runBusy(() async {
        await CloudSyncService.signOut();
        _setMessage(
          'התנתקת מהחשבון. המזונות שכבר נשמרו במכשיר נשארו זמינים.',
        );
        setState(() {});
      });

  @override
  Widget build(BuildContext context) {
    final user = CloudSyncService.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('חשבון וסנכרון')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_sync_outlined),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'סנכרון בין המחשב לטלפון',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'בשלב הראשון אנחנו מסנכרנים את המזונות האישיים שהוספת למאגר. '
                    'העותק המקומי נשאר במכשיר כגיבוי ואינו נמחק.',
                  ),
                  const SizedBox(height: 8),
                  Text('במכשיר הזה: ${widget.state.customFoods.length} מזונות אישיים'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (user == null) ...[
            TextField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'אימייל',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'סיסמה',
                helperText: 'לפחות 6 תווים',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _signIn,
              icon: const Icon(Icons.login),
              label: const Text('התחבר'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _signUp,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('צור חשבון חדש'),
            ),
          ] else ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_done_outlined),
                title: const Text('מחובר לענן'),
                subtitle: Text(user.email ?? 'חשבון מחובר'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _syncNow,
              icon: const Icon(Icons.sync),
              label: const Text('סנכרן עכשיו'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('התנתק'),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 14),
            const LinearProgressIndicator(),
          ],
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _messageIsError
                    ? Theme.of(context).colorScheme.errorContainer
                    : Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_message),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'בשלב הבא נרחיב את אותו מנגנון גם לפרופיל, ארוחות, מזווה ורשימת קניות. '
            'כרגע עריכה או מחיקה של אותו מזון משני מכשירים במקביל עדיין אינה מנוהלת כקונפליקט.',
          ),
        ],
      ),
    );
  }
}
