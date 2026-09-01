import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/app_state.dart';
import '../kosher/kosher_card.dart';
import '../nutrition/add_food_to_catalog_screen.dart';
import '../nutrition/add_meal_sheet.dart';
import '../profile/profile_screen.dart';

/// "Energetic/playful" home screen -- the direction the product owner
/// picked out of three mockup options drafted for this redesign (saturated
/// accent colors per action, soft background blobs, bold Rubik display
/// type). See app/shell.dart for the matching floating bottom nav bar.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => Container(
        color: AppTheme.background,
        child: Stack(
          children: [
            // Soft decorative blobs, matching the chosen mockup -- purely
            // background texture, no interaction, so plain Positioned
            // circles rather than anything that competes for touch.
            Positioned(
              top: -60,
              left: -70,
              child: _Blob(color: const Color(0xFFFFE1A8), size: 220, opacity: .6),
            ),
            Positioned(
              top: 120,
              right: -90,
              child: _Blob(color: const Color(0xFFCFF3EA), size: 180, opacity: .7),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'היי, ${state.firstName}',
                            style: const TextStyle(
                              fontFamily: 'Rubik',
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                              color: AppTheme.ink,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'כל צעד קטן מצטרף לתמונה הגדולה',
                            style: TextStyle(fontSize: 14, color: AppTheme.warmMuted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => AppStateScope(
                            state: state,
                            child: const ProfileScreen(),
                          ),
                        ),
                      ),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFF9B6A), AppTheme.coral],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.coral.withValues(alpha: .35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person_outline, color: Colors.white),
                      ),
                    ),
                  ],
                ),

                // Quick actions -- per feedback, trimmed to the three the
                // product owner actually reaches for from this screen
                // (weight/workout/coach are still one tap away via the
                // bottom nav, so nothing is lost, just decluttered).
                SizedBox(
                  height: 128,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const SizedBox(width: 24),
                        _QuickActionTile(
                          color: AppTheme.coral,
                          icon: Icons.restaurant,
                          label: 'אכלתי',
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => AppStateScope(
                              state: state,
                              child: const AddMealSheet(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionTile(
                          key: const Key('water_metric_card'),
                          color: AppTheme.teal,
                          icon: Icons.water_drop_outlined,
                          label: 'כוסות מים',
                          value: '${state.waterCups}/${state.waterTarget}',
                          onTap: () => _addWater(context, state),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionTile(
                          color: AppTheme.mint,
                          icon: Icons.add_box_outlined,
                          label: 'הוסף מזון למאגר',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => AppStateScope(
                                state: state,
                                child: AddFoodToCatalogScreen(state: state),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Calorie hero
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 26, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Row(
                    children: [
                      _CalorieRing(eaten: state.caloriesEaten, target: state.calorieTarget),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${state.caloriesEaten}',
                              style: const TextStyle(
                                fontFamily: 'Rubik',
                                fontWeight: FontWeight.w900,
                                fontSize: 32,
                                color: AppTheme.ink,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'מתוך ${state.calorieTarget} קלוריות',
                              style: const TextStyle(fontSize: 13, color: AppTheme.warmMuted, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4EEE4),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${state.proteinEaten.toStringAsFixed(0)}/${state.proteinTarget}',
                                    style: const TextStyle(fontFamily: 'Rubik', fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.lavender),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('גרם חלבון', style: TextStyle(fontSize: 11, color: AppTheme.warmMuted, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Goal card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(color: AppTheme.softMint, borderRadius: BorderRadius.circular(24)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'התמונה האישית שלי',
                        style: TextStyle(fontFamily: 'Rubik', fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E5B3B)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${state.primaryGoal} · ${state.workoutDaysPerWeek} אימונים בשבוע · פעילות ${state.activityLevel}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF3D6B52), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.dailyInsight,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1E5B3B), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                const KosherCard(),
                const SizedBox(height: 14),

                // Recommendation card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, color: AppTheme.sunny, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'ההמלצה שלי עכשיו',
                            style: TextStyle(fontFamily: 'Rubik', fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.ink),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        state.coachResponse('מה כדאי לי לאכול עכשיו?'),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF5A4E3E), fontWeight: FontWeight.w600, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in state.smartFoodSuggestions.take(3).toList().asMap().entries)
                            _SuggestionChip(text: entry.value, colorIndex: entry.key),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Center(
                  child: TextButton.icon(
                    onPressed: () => _snack(context, state),
                    icon: const Icon(Icons.cookie_outlined, color: AppTheme.warmMuted),
                    label: const Text('בא לי לנשנש', style: TextStyle(color: AppTheme.warmMuted, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addWater(BuildContext context, AppState state) {
    final before = state.waterCups;
    state.addWater();
    final reachedGoal = before < state.waterTarget && state.waterCups >= state.waterTarget;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            reachedGoal
                ? 'מעולה! הגעת ליעד המים היומי שלך 💧'
                : 'נוספה כוס מים · ${state.waterCups}/${state.waterTarget}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _snack(BuildContext context, AppState state) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('מה אפשר לנשנש?'),
        content: Text(state.smartFoodSuggestions.join('\n\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('סגור'),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size, required this.opacity});
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: opacity), shape: BoxShape.circle),
      ),
    );
  }
}

/// Prominent, colorful tappable tile for a home-screen quick action -- a
/// filled accent-color pill (not a tinted-neutral card) with the icon in a
/// translucent white circle, matching the chosen "energetic" mockup.
class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.darkContent = false,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  // Sunny yellow is too light for white text/icons to stay legible -- that
  // tile alone uses a dark-on-light treatment instead.
  final bool darkContent;

  @override
  Widget build(BuildContext context) {
    final contentColor = darkContent ? const Color(0xFF5C4400) : Colors.white;
    return SizedBox(
      width: 98,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(22),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: .30), blurRadius: 16, offset: const Offset(0, 8)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: contentColor.withValues(alpha: darkContent ? .30 : .25),
                    ),
                    child: Icon(icon, color: contentColor, size: 17),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value ?? label,
                    textAlign: TextAlign.center,
                    // A value-less tile's label is the only line it shows,
                    // so a longer one (e.g. "הוסף מזון למאגר") gets to wrap
                    // instead of ellipsizing; a value tile keeps 1 line to
                    // leave room for its secondary label line below.
                    maxLines: value == null ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Rubik', fontWeight: FontWeight.w700, color: contentColor, fontSize: 12.5, height: 1.2),
                  ),
                  if (value != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: contentColor.withValues(alpha: .85), fontWeight: FontWeight.w600),
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

/// Circular calorie-progress ring for the hero card, in the coral accent.
class _CalorieRing extends StatelessWidget {
  const _CalorieRing({required this.eaten, required this.target});
  final int eaten;
  final int target;

  @override
  Widget build(BuildContext context) {
    final progress = target <= 0 ? 0.0 : (eaten / target).clamp(0, 1).toDouble();
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(value: 1, strokeWidth: 8, color: Color(0xFFFFE8D6)),
          ),
          SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              color: AppTheme.coral,
              backgroundColor: Colors.transparent,
            ),
          ),
          const Icon(Icons.local_fire_department, color: AppTheme.coral, size: 26),
        ],
      ),
    );
  }
}

/// Colored chip for a food suggestion in the recommendation card -- rotates
/// through the coral/teal/lavender accents so the row reads as playful
/// rather than a flat list.
class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.text, required this.colorIndex});
  final String text;
  final int colorIndex;

  static const _backgrounds = [Color(0xFFFFF3E4), Color(0xFFEAF6FF), Color(0xFFF3EEFF)];
  static const _foregrounds = [Color(0xFFB4620E), Color(0xFF1878A8), Color(0xFF6A4FC7)];

  @override
  Widget build(BuildContext context) {
    final i = colorIndex % _backgrounds.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: _backgrounds[i], borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: _foregrounds[i], fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}
