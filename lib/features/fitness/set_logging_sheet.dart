import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../shared/models/app_state.dart';

/// Default rest duration between sets (spec section 0/6 originally proposed
/// 90s; lowered to 60s per user sign-off in the PR discussion). Tapping a
/// running timer still stacks a full extra round for anyone who wants more.
const kDefaultRestSeconds = 60;

/// Set-logging bottom sheet for one exercise: a weight+reps row per set
/// (pre-filled from `AppState.lastSetFor`/the plan's default reps), a
/// "סיום סט" button per row that logs the set and starts the rest timer,
/// and a rest timer with background motivational music. Opened with
/// `useRootNavigator: false` by the caller (see fitness_screen.dart) --
/// this app uses go_router's per-tab Navigator (rule #14/PR #51), so a
/// root-navigator sheet here would silently "stick" on close.
class SetLoggingSheet extends StatefulWidget {
  const SetLoggingSheet({super.key, required this.state, required this.exercise});

  final AppState state;
  final WorkoutExercise exercise;

  @override
  State<SetLoggingSheet> createState() => _SetLoggingSheetState();
}

class _SetLoggingSheetState extends State<SetLoggingSheet> {
  late final List<TextEditingController> _weightControllers;
  late final List<TextEditingController> _repsControllers;
  final Set<int> _completedIndices = {};
  // Two independent channels (per spec section 0): channel 1 is the
  // background motivational loop, playing throughout the workout; channel 2
  // is a short spoken "5, 4, 3, 2, 1" clip fired once when the last-5-second
  // window starts, instead of a per-second flutter_tts call.
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _countdown = AudioPlayer();

  Timer? _restTicker;
  int _restSecondsRemaining = 0;
  bool _countdownPlayed = false;
  bool _musicStarted = false;

  @override
  void initState() {
    super.initState();
    final lastSet = widget.state.lastSetFor(widget.exercise.name);
    final todaysSets = widget.state.todaysSetsFor(widget.exercise.name);
    _weightControllers = List.generate(widget.exercise.sets, (index) {
      final logged = todaysSets[index];
      final defaultWeight = logged?.weightKg ?? lastSet?.weightKg ?? 0;
      return TextEditingController(
        text: defaultWeight > 0 ? _formatWeight(defaultWeight) : '',
      );
    });
    _repsControllers = List.generate(widget.exercise.sets, (index) {
      final logged = todaysSets[index];
      final defaultReps = logged?.reps ?? lastSet?.reps ?? widget.exercise.reps;
      return TextEditingController(text: defaultReps.toString());
    });
    _completedIndices.addAll(todaysSets.keys);
  }

  @override
  void dispose() {
    _restTicker?.cancel();
    _music.stop();
    _music.dispose();
    _countdown.stop();
    _countdown.dispose();
    for (final c in _weightControllers) {
      c.dispose();
    }
    for (final c in _repsControllers) {
      c.dispose();
    }
    super.dispose();
  }

  String _formatWeight(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  Future<void> _ensureMusicPlaying() async {
    if (_musicStarted) return;
    _musicStarted = true;
    // This call chain always originates from a user tap (opening the sheet,
    // or finishing a set), which is what Flutter Web requires to allow audio
    // playback -- see spec section 5.
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.play(AssetSource('audio/workout_background_music.mp3'), volume: 0.35);
    } catch (_) {
      // Audio is a motivational extra, not core functionality -- a device
      // without audio output or an unsupported format must never block
      // set-logging or the rest timer.
    }
  }

  void _finishSet(int index) {
    final weight = double.tryParse(_weightControllers[index].text.replaceAll(',', '.')) ?? 0;
    final reps = int.tryParse(_repsControllers[index].text) ?? widget.exercise.reps;
    widget.state.logSet(
      exerciseName: widget.exercise.name,
      setIndex: index,
      weightKg: weight,
      reps: reps,
    );
    _ensureMusicPlaying();
    setState(() => _completedIndices.add(index));
    final isLastSet = index >= widget.exercise.sets - 1;
    if (!isLastSet) _startRest(kDefaultRestSeconds);
  }

  void _startRest(int seconds) {
    _restTicker?.cancel();
    setState(() {
      _restSecondsRemaining = seconds;
      _countdownPlayed = seconds > 5 ? false : _countdownPlayed;
    });
    _restTicker = Timer.periodic(const Duration(seconds: 1), (_) => _tickRest());
  }

  void _tickRest() {
    if (!mounted) return;
    setState(() => _restSecondsRemaining -= 1);
    if (_restSecondsRemaining <= 0) {
      _restTicker?.cancel();
      setState(() => _restSecondsRemaining = 0);
      return;
    }
    // The countdown clip itself narrates "5, 4, 3, 2, 1" (channel 2), so it
    // plays once at the start of the last-5-second window rather than once
    // per second.
    if (_restSecondsRemaining == 5 && !_countdownPlayed) {
      _countdownPlayed = true;
      _playCountdownClip();
    }
  }

  Future<void> _playCountdownClip() async {
    try {
      await _countdown.stop();
      await _countdown.play(AssetSource('audio/rest_countdown_5to1.mp3'), volume: 0.9);
    } catch (_) {
      // Same "never block the timer" rule as the background music above.
    }
  }

  /// Tapping the running timer adds one more full rest cycle (stacking, per
  /// spec section 0) rather than just a few extra seconds.
  void _addRestRound() {
    if (_restSecondsRemaining <= 0) return;
    _startRest(_restSecondsRemaining + kDefaultRestSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final resting = _restSecondsRemaining > 0;
    final countingDown = _restSecondsRemaining > 0 && _restSecondsRemaining <= 5;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.exercise.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${widget.exercise.sets} סטים × ${widget.exercise.reps} חזרות · ${widget.exercise.equipment}'),
            const SizedBox(height: 16),
            if (resting)
              _RestTimerCard(
                secondsRemaining: _restSecondsRemaining,
                countingDown: countingDown,
                onTap: _addRestRound,
              )
            else
              ...List.generate(widget.exercise.sets, (index) {
                final done = _completedIndices.contains(index);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(width: 28, child: Text('${index + 1}')),
                      Expanded(
                        child: TextField(
                          controller: _weightControllers[index],
                          enabled: !done,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'משקל (ק"ג)', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _repsControllers[index],
                          enabled: !done,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'חזרות', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      done
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : FilledButton(
                              onPressed: () => _finishSet(index),
                              child: const Text('סיום סט'),
                            ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            if (_completedIndices.length >= widget.exercise.sets && !resting)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'כל הסטים הושלמו לתרגיל זה!',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RestTimerCard extends StatelessWidget {
  const _RestTimerCard({
    required this.secondsRemaining,
    required this.countingDown,
    required this.onTap,
  });

  final int secondsRemaining;
  final bool countingDown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final minutes = secondsRemaining ~/ 60;
    final seconds = secondsRemaining % 60;
    final label = '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: countingDown
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            const Icon(Icons.timer_outlined, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: countingDown ? 64 : 48,
                fontWeight: FontWeight.bold,
                color: countingDown ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
            const SizedBox(height: 6),
            const Text('מנוחה בין סטים · לחיצה מוסיפה עוד סיבוב מנוחה'),
          ],
        ),
      ),
    );
  }
}
