import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/models/app_state.dart';
import 'cloud_sync_service.dart';
import 'profile_goals_store.dart';

/// Mandatory sign-in/sign-up screen shown by AppStateGate when there is no
/// active Supabase session. `supabase_flutter` persists a session to local
/// storage by default and restores it synchronously on `Supabase.initialize`
/// (see main.dart), so once a device has signed in once, `currentSession`
/// is already populated before this screen would ever get a chance to
/// render again -- a returning user is never re-prompted, on or offline.
///
/// Sign-in/sign-up logic here mirrors CloudSyncScreen's (kept as the
/// separate "manage account" screen for an already-signed-in user), notably
/// the same reset-before-signUp ordering from CLAUDE.md golden rule #15 /
/// PR #51: CloudSyncService's automatic-sync auth listener fires the
/// instant Supabase creates a session, so any local-only data on this
/// device must be reset before signUp() is called, not after.
class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key, required this.state});

  final AppState state;

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
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
      _setMessage('לא הצלחתי להתחבר לענן. נסה שוב בעוד רגע.', error: true);
    } catch (_) {
      _setMessage('אירעה שגיאה. נסה שוב.', error: true);
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
        final hasLocalData = widget.state.firstName.isNotEmpty ||
            widget.state.customFoods.isNotEmpty ||
            widget.state.meals.isNotEmpty ||
            widget.state.pantryItems.isNotEmpty ||
            widget.state.weights.length > 1;
        if (hasLocalData) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('לאפס את הנתונים במכשיר הזה?'),
              content: const Text(
                'יש כבר נתונים מקומיים במכשיר הזה (שם, ארוחות, מזווה, משקל וכו׳). '
                'כדי שהחשבון החדש יתחיל נקי, הנתונים המקומיים יאופסו לפני היצירה. '
                'אם רצית להתחבר לחשבון קיים במקום זה, בטל ולחץ "התחבר".',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('ביטול'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('אפס והמשך'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;

          await widget.state.resetForNewAccount();
          await ProfileGoalsStore.save([widget.state.primaryGoal]);
          if (!mounted) return;
        }

        final response = await CloudSyncService.signUp(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (!mounted) return;

        if (response.session == null) {
          _setMessage(
            'נשלח אליך מייל לאימות החשבון. אשר את האימייל, חזור למסך הזה ולחץ „התחבר”.',
          );
        }
        // If a session came back immediately, AppStateGate's own auth
        // listener flips into the app on its own -- nothing else to do here.
      });

  Future<void> _signIn() => _runBusy(() async {
        if (!_validateCredentials()) return;
        await CloudSyncService.signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
        // AppStateGate's own auth listener flips into the app once the
        // session lands.
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.favorite, size: 48, color: Colors.pinkAccent),
                  const SizedBox(height: 12),
                  const Text(
                    'ברוכים הבאים',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'יש להתחבר או להירשם כדי להמשיך. '
                    'לאחר ההתחברות הראשונה תישארו מחוברים אוטומטית.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('auth_gate_email'),
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
                    key: const Key('auth_gate_password'),
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
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('auth_gate_sign_in'),
                    onPressed: _busy ? null : _signIn,
                    icon: const Icon(Icons.login),
                    label: const Text('התחבר'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('auth_gate_sign_up'),
                    onPressed: _busy ? null : _signUp,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('צור חשבון חדש'),
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _messageIsError
                            ? Theme.of(context).colorScheme.errorContainer
                            : Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_message, textAlign: TextAlign.center),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
