import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('המאמן שלי', style: Theme.of(context).textTheme.headlineSmall),
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
                Expanded(child: TextField(controller: input, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'כתוב למאמן...'))),
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
  }
}
