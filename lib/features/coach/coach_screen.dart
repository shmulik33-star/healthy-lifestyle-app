import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../shared/models/app_state.dart';
import 'coach_ai_service.dart';

// Desktop Chrome's speech synthesis has a well-known bug: a single utterance
// over roughly 200-250 characters (or ~15 seconds of speech) just stops
// mid-sentence. Speaking each sentence -- and, for a genuine run-on
// sentence, each word-wrapped piece of one -- as its own utterance keeps
// every individual utterance well under that threshold, so a longer coach
// reply is heard in full instead of getting cut off partway through.
// Top-level (not a private method) and `@visibleForTesting` so the pure
// splitting logic has direct unit test coverage without needing a real
// browser speech engine.
@visibleForTesting
const maxSpeechChunkLength = 200;

@visibleForTesting
List<String> splitReplyIntoSpeechChunks(String text) {
  final sentences = <String>[];
  final buffer = StringBuffer();
  for (final char in text.split('')) {
    buffer.write(char);
    if (char == '.' || char == '!' || char == '?' || char == '\n') {
      final sentence = buffer.toString().trim();
      if (sentence.isNotEmpty) sentences.add(sentence);
      buffer.clear();
    }
  }
  final remainder = buffer.toString().trim();
  if (remainder.isNotEmpty) sentences.add(remainder);

  return sentences.expand(_wrapIfTooLong).toList();
}

List<String> _wrapIfTooLong(String sentence) {
  if (sentence.length <= maxSpeechChunkLength) return [sentence];
  final chunks = <String>[];
  final buffer = StringBuffer();
  for (final word in sentence.split(' ')) {
    if (buffer.isNotEmpty && buffer.length + word.length + 1 > maxSpeechChunkLength) {
      chunks.add(buffer.toString());
      buffer.clear();
    }
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(word);
  }
  if (buffer.isNotEmpty) chunks.add(buffer.toString());
  return chunks;
}

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
  // speech-synthesis engine. Both degrade silently: if recognition never
  // becomes available the mic button just never appears, typing keeps
  // working exactly as before; if no Hebrew voice is installed for
  // speech-synthesis (a real desktop-Chrome gap depending on the OS'
  // installed voices -- unlike mobile, which normally ships one), the
  // speaker toggle never appears either, instead of reading Hebrew text out
  // loud in whatever English voice the browser happened to fall back to.
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  bool _speechAvailable = false;
  bool _ttsAvailable = false;
  bool _listening = false;
  bool _speakRepliesAloud = true;

  // "Voice conversation" mode (the ChatGPT-style back-and-forth the product
  // owner actually asked for): once turned on with the mic button, each
  // turn auto-chains into the next -- recognized speech is sent, the reply
  // is spoken, and listening restarts on its own -- until the user taps the
  // mic again to stop. `_finalResultHandledThisSession` distinguishes "the
  // user said something and it's being handled" from "this listen session
  // ended with nothing recognized" so silence doesn't retrigger the
  // already-in-flight ask/speak chain a second time; `_consecutiveEmptyListens`
  // bounds the silent-retry loop so a stuck mic (denied permission, no
  // speech ever detected) can't restart forever.
  bool _voiceConversationActive = false;
  bool _finalResultHandledThisSession = false;
  int _consecutiveEmptyListens = 0;
  static const _maxConsecutiveEmptyListens = 3;

  // AppStateScope.of(context) is only safe to call during/after build (via
  // didChangeDependencies), never eagerly in initState -- but onStatus/
  // onError below are long-lived callbacks that can fire long after any
  // particular build, so the state they need is grabbed once here and
  // reused, instead of calling AppStateScope.of(context) from inside them.
  late AppState _appState;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = AppStateScope.of(context);
  }

  // Chrome's `he-IL` Web Speech Synthesis voice isn't installed on every
  // desktop by default (it normally is on mobile), so setLanguage() alone
  // can silently succeed while actually leaving the browser on its default
  // English voice -- which then reads Hebrew text as a handful of mangled
  // English-sounding words plus whatever digits happen to be in it (digits
  // read fine in any language). Checking isLanguageAvailable first means a
  // machine without Hebrew TTS gets the button hidden -- same graceful
  // degradation as the mic -- instead of garbled speech.
  Future<void> _initTts() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      // Real-world Hebrew locale tags vary: `he-IL` is current BCP-47, but
      // some engines still answer to the older ISO code `iw`, and web
      // implementations are inconsistent about hyphen vs underscore.
      const candidates = ['he-IL', 'he_IL', 'iw-IL', 'iw_IL'];
      String? workingLocale;
      for (final candidate in candidates) {
        final result = await _tts.isLanguageAvailable(candidate);
        if (result == true || result == 1) {
          workingLocale = candidate;
          break;
        }
      }
      if (workingLocale == null) {
        if (!mounted) return;
        setState(() => _ttsAvailable = false);
        return;
      }
      await _tts.setLanguage(workingLocale);
      // Best-effort: prefer an explicit Hebrew voice over whatever
      // setLanguage's own matching picked, when the platform exposes voice
      // selection. Never lets a failure here (e.g. web builds that don't
      // support setVoice) affect availability -- setLanguage above already
      // found a genuinely working locale.
      await _runSafely(() async {
        final voices = await _tts.getVoices() as List<dynamic>?;
        final hebrewVoice = voices?.firstWhere(
              (voice) {
                final locale = (voice is Map ? voice['locale'] : null)?.toString().toLowerCase() ?? '';
                return locale.startsWith('he') || locale.startsWith('iw');
              },
              orElse: () => null,
            );
        if (hebrewVoice is Map) {
          await _tts.setVoice(hebrewVoice.map((k, v) => MapEntry(k.toString(), v.toString())));
        }
      });
      if (!mounted) return;
      setState(() => _ttsAvailable = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _ttsAvailable = false);
    }
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

  Future<void> _speakReply(String text) async {
    for (final chunk in splitReplyIntoSpeechChunks(text)) {
      if (!_speakRepliesAloud) return;
      await _runSafely(() => _tts.speak(chunk));
    }
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'notListening' || status == 'done') {
            setState(() => _listening = false);
            _onListenSessionEnded(_appState);
          }
        },
        // Recognition failing (denied mic permission, unsupported browser,
        // no speech detected) should never surface as an app error -- the
        // mic button simply stops listening and typing still works.
        onError: (_) {
          if (!mounted) return;
          setState(() => _listening = false);
          _onListenSessionEnded(_appState);
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

  // The mic button is a single on/off switch for the whole conversation,
  // not a per-turn record button: tapping it while active stops everything
  // (recognition + any reply still being read aloud) instead of only
  // ending the current listen, since the product owner wants a real
  // ChatGPT-style back-and-forth -- talk, get a spoken reply, keep talking
  // -- not "press the mic before every single thing you say".
  Future<void> _toggleVoiceConversation(AppState state) async {
    if (_voiceConversationActive) {
      // Flipped immediately (not inside setState) so the retry logic in
      // _onListenSessionEnded, which can run while the stop calls below are
      // still in flight, already sees the conversation as stopped and
      // doesn't restart listening out from under this.
      _voiceConversationActive = false;
      await _runSafely(_speech.stop);
      await _runSafely(_tts.stop);
      if (!mounted) return;
      setState(() => _listening = false);
      return;
    }
    setState(() {
      _voiceConversationActive = true;
      _consecutiveEmptyListens = 0;
    });
    await _startListening(state);
  }

  Future<void> _startListening(AppState state) async {
    if (!_voiceConversationActive) return;
    // A fresh listen always cancels any reply still being read aloud --
    // talking over the coach while it's speaking is confusing.
    await _runSafely(_tts.stop);
    _finalResultHandledThisSession = false;
    setState(() => _listening = true);
    await _runSafely(() => _speech.listen(
          // BCP-47 format (hyphen) -- the browser's SpeechRecognition.lang
          // expects this exact shape. The underscore form ("he_IL") is
          // invalid here and made the recognizer silently fall back to the
          // browser's own language instead of listening for Hebrew.
          listenOptions: SpeechListenOptions(localeId: 'he-IL'),
          onResult: (result) {
            input.text = result.recognizedWords;
            input.selection = TextSelection.collapsed(offset: input.text.length);
            if (result.finalResult) {
              final q = input.text.trim();
              if (q.isEmpty) return;
              _finalResultHandledThisSession = true;
              _consecutiveEmptyListens = 0;
              setState(() => _listening = false);
              input.clear();
              _handleVoiceTurn(state, q);
            }
          },
        ));
  }

  // One full turn of the conversation loop: send what was heard, speak the
  // reply, then listen again -- unless the user stopped the conversation
  // (or muted replies aloud) while that was happening.
  Future<void> _handleVoiceTurn(AppState state, String question) async {
    await _ask(state, question);
    if (!mounted || !_voiceConversationActive) return;
    await _startListening(state);
  }

  // Recognition ending with nothing recognized (silence, a permission
  // hiccup) isn't a turn -- _handleVoiceTurn never ran, so nothing will
  // resume listening on its own. Retry a bounded number of times instead of
  // just going quiet, but give up (and turn the conversation off) rather
  // than retry forever against, say, a denied mic permission.
  void _onListenSessionEnded(AppState state) {
    if (!_voiceConversationActive || _finalResultHandledThisSession) return;
    _consecutiveEmptyListens++;
    if (_consecutiveEmptyListens > _maxConsecutiveEmptyListens) {
      setState(() => _voiceConversationActive = false);
      return;
    }
    _startListening(state);
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
              if (_ttsAvailable)
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
                      hintText: _listening
                          ? 'מקשיב...'
                          : (_voiceConversationActive ? 'ממתין לתשובה...' : 'כתוב למאמן...'),
                    ),
                  ),
                ),
                if (_speechAvailable) ...[
                  const SizedBox(width: 8),
                  IconButton.filled(
                    // Disabled only for a plain one-off ask already in
                    // flight (e.g. from an ActionChip) -- once the voice
                    // conversation itself is active, the button must stay
                    // tappable throughout so the user can always stop it,
                    // including mid-reply.
                    onPressed: (!_voiceConversationActive && _asking) ? null : () => _toggleVoiceConversation(state),
                    tooltip: _voiceConversationActive ? 'עצור שיחה קולית' : 'התחל שיחה קולית',
                    style: _listening
                        ? IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error)
                        : (_voiceConversationActive
                            ? IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary)
                            : null),
                    icon: Icon(_voiceConversationActive ? Icons.mic : Icons.mic_none),
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
    // Awaited (not fire-and-forget) so the voice-conversation loop in
    // _handleVoiceTurn only starts listening again once the coach has
    // actually finished talking -- otherwise the mic could pick up the
    // reply being read out of the speakers as if the user said it.
    if (_speakRepliesAloud && _ttsAvailable) await _speakReply(reply);
  }
}
