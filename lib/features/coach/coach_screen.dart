import 'package:flutter/material.dart';
import '../../shared/models/app_state.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final input = TextEditingController();
  final messages = <String>['המאמן: שלום! אני כבר משתמש בנתוני היום, במצב הכשרות, בתפריט ובציוד שסימנת.'];

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
            children: messages.map((message) => Align(
              alignment: Alignment.centerRight,
              child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(message))),
            )).toList(),
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
                  onPressed: () {
                    final q = input.text.trim();
                    if(q.isEmpty) return;
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

  void _ask(AppState state, String question) {
    setState(() {
      messages.add('אתה: $question');
      messages.add('המאמן: ${state.coachResponse(question)}');
    });
  }
}
