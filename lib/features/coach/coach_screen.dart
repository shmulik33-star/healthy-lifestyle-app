import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../shared/models/app_state.dart';
import 'coach_ai_service.dart';

/// How CoachScreen asks the AI coach for a reply. The real implementation
/// is CoachAiService.ask; tests substitute a function that resolves or
/// throws directly, so the "AI call fails -> silently fall back to
/// coachResponse()" path is exercised without needing real network.
typedef CoachAsk = Future<String> Function({
  required String question,
  required List<CoachMessage> history,
  required Map<String, dynamic> context,
});

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, this.askAi = CoachAiService.ask});

  final CoachAsk askAi;

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final input = TextEditingController();
  final messages = <CoachMessage>[
    const CoachMessage(
      role: CoachRole.coach,
      text: 'שלום! אני כבר משתמש בנתוני היום, במצב הכשרות, בתפריט ובציוד שסימנת.',
    ),
  ];
  bool _asking = false;

  // Voice chat: mic input via the browser's speech-recognition engine
  // (Web Speech API under the hood -- solid on Chrome/Edge, spotty on
  // Safari, absent on Firefox), coach replies read aloud via the browser's
  // speech-synthesis engine (near-universal support, unlike recognition).
  // Both degrade silently: if recognition never becomes available the mic
  // button just never appears, typing keeps working exactly as before.
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  bool _speechAvailable = false;
  bool _listening = false;
  bool _speakRepliesAloud = true;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _runSafely(() => _tts.setLanguage('he-IL'));
  }

  // Both plugins reach a real browser API (Web Speech recognition/
  // synthesis) that's simply absent in the widget-test environment, and can
  // throw there (missing plugin) rather than just returning false -- caught
  // the same as a genuinely unsupported browser would be, so the mic button
  // just never appears and speaking a reply aloud is silently skipped,
  // instead of crashing the screen.
  static Future<void> _runSafely(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Deliberately swallowed -- see comment above.
    }
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'notListening' || status == 'done') {
            setState(() => _listening = false);
          }
        },
        // Recognition failing (denied mic permission, unsupported browser,
        // no speech detected) should never surface as an app error -- the
        // mic button simply stops listening and typing still works.
        onError: (_) {
          if (!mounted) return;
          setState(() => _listening = false);
        },
      );
      if (!mounted) return;
      setState(() => _speechAvailable = available);
    } catch (_) {
      if (!mounted) return;
      setState(() => _speechAvailable = false);
    }
  }

  @override
  void dispose() {
    input.dispose();
    _runSafely(_speech.stop);
    _runSafely(_tts.stop);
    super.dispose();
  }

  Future<void> _toggleListening(AppState state) async {
    if (_listening) {
      await _runSafely(_speech.stop);
      setState(() => _listening = false);
      return;
    }
    // A fresh mic tap always cancels any reply still being read aloud --
    // talking over the coach while it's speaking is confusing.
    await _runSafely(_tts.stop);
    setState(() => _listening = true);
    await _runSafely(() => _speech.listen(
          listenOptions: SpeechListenOptions(localeId: 'he_IL'),
          onResult: (result) {
            input.text = result.recognizedWords;
            input.selection = TextSelection.collapsed(offset: input.text.length);
            if (result.finalResult) {
              setState(() => _listening = false);
              final q = input.text.trim();
              if (q.isNotEmpty) {
                _ask(state, q);
                input.clear();
              }
            }
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                tooltip: _speakRepliesAloud ? 'השתק הקראת תשובות' : 'הקרא תשובות בקול',
                onPressed: () {
                  if (_speakRepliesAloud) _runSafely(_tts.stop);
                  setState(() => _speakRepliesAloud = !_speakRepliesAloud);
                },
                icon: Icon(_speakRepliesAloud ? Icons.volume_up : Icons.volume_off),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('המאמן שלי', style: Theme.of(context).textTheme.headlineSmall),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(label: const Text('אני רעב'), onPressed: () => _ask(state, 'אני רעב, מה כדאי לאכול?')),
              ActionChip(label: const Text('מה עם האימון?'), onPressed: () => _ask(state, 'מה האימון שלי היום?')),
              ActionChip(label: const Text('איך נראה השבוע?'), onPressed: () => _ask(state, 'ספר לי על התפריט והקניות לשבוע')),
              ActionChip(label: const Text('מה היעד שלי?'), onPressed: () => _ask(state, 'מה היעד והמטרה שלי?')),
              ActionChip(label: const Text('איך ההתקדמות?'), onPressed: () => _ask(state, 'איך ההתקדמות והמשקל שלי?')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              ...messages.map((message) => Align(
                    alignment: Alignment.centerRight,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '${message.role == CoachRole.user ? 'אתה' : 'המאמן'}: ${message.text}',
                        ),
                      ),
                    ),
                  )),
              if (_asking)
                const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: _listening ? 'מקשיב...' : 'כתוב למאמן...',
                    ),
                  ),
                ),
                if (_speechAvailable) ...[
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _asking ? null : () => _toggleListening(state),
                    style: _listening
                        ? IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error)
                        : null,
                    icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _asking
                      ? null
                      : () {
                          final q = input.text.trim();
                          if (q.isEmpty) return;
                          _ask(state, q);
                          input.clear();
                        },
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _ask(AppState state, String question) async {
    // The conversation so far, before this turn's question -- sent as
    // `history` so the coach's answer isn't asked to guess this question
    // twice (once as history's last entry, once as the question itself).
    final priorHistory = List<CoachMessage>.from(messages);

    setState(() {
      messages.add(CoachMessage(role: CoachRole.user, text: question));
      _asking = true;
    });

    String reply;
    try {
      reply = await widget.askAi(
        question: question,
        history: priorHistory,
        context: state.coachAiContext(),
      );
    } catch (_) {
      // Silent fallback to the rule-based coach on any AI failure (network,
      // timeout, malformed response, ...) -- the user never sees an error,
      // by design (see PR description).
      reply = state.coachResponse(question);
    }

    if (!mounted) return;
    setState(() {
      messages.add(CoachMessage(role: CoachRole.coach, text: reply));
      _asking = false;
    });
    if (_speakRepliesAloud) _runSafely(() => _tts.speak(reply));
  }
}
