import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/app_state.dart';
import '../profile/profile_goals_store.dart';

/// First-run onboarding wizard: welcome -> goals -> basic profile ->
/// equipment -> how-it-works explainer -> summary. Shown by AppStateGate
/// once the user is signed in but `state.onboardingCompleted` is still
/// false (a brand-new account, or an existing one that skipped/never saw
/// it before this feature shipped). "דלג" and the final "סיים" both mark
/// onboardingCompleted -- the only difference is whether the fields
/// entered so far are also saved.
class OnboardingWizardScreen extends StatefulWidget {
  const OnboardingWizardScreen({super.key, required this.state});
  final AppState state;

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  static const _pageCount = 6;
  final _pageController = PageController();
  int _page = 0;

  late final TextEditingController _nameController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _ageController;

  List<String> _goals = [];
  String? _primaryGoal;
  bool _goalsLoaded = false;

  @override
  void initState() {
    super.initState();
    final state = widget.state;
    _nameController = TextEditingController(text: state.firstName);
    _weightController =
        TextEditingController(text: state.currentWeight > 0 ? _fmt(state.currentWeight) : '');
    _heightController =
        TextEditingController(text: state.heightCm > 0 ? _fmt(state.heightCm) : '');
    _ageController = TextEditingController(text: state.age > 0 ? '${state.age}' : '');
    ProfileGoalsStore.load(fallbackGoal: state.primaryGoal).then((goals) {
      if (!mounted) return;
      setState(() {
        _goals = goals;
        _primaryGoal = ProfileGoalsStore.resolvePrimaryGoal(goals, preferred: state.primaryGoal);
        _goalsLoaded = true;
      });
    });
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    setState(() => _page = page.clamp(0, _pageCount - 1));
    _pageController.animateToPage(
      _page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish({required bool saveFields}) async {
    if (saveFields) {
      final state = widget.state;
      state.firstName = _nameController.text.trim().isEmpty
          ? state.firstName
          : _nameController.text.trim();
      final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));
      if (weight != null && weight > 0) state.currentWeight = weight;
      final height = double.tryParse(_heightController.text.replaceAll(',', '.'));
      if (height != null && height > 0) state.heightCm = height;
      final age = int.tryParse(_ageController.text);
      if (age != null && age > 0) state.age = age;
      if (_primaryGoal != null) state.primaryGoal = _primaryGoal!;
      if (_goals.isNotEmpty) await ProfileGoalsStore.save(_goals);
      state.generateWeeklyPlan();
      // "דלג" explicitly means "let me deal with this later" -- only
      // "סיים" (saveFields) should send the user straight to the profile
      // screen to review the computed calorie/protein suggestion and the
      // other settings the wizard doesn't cover.
      state.pendingOpenProfileAfterOnboarding = true;
    }
    widget.state.finishOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.screenBackground,
      body: SafeArea(
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                _ProgressDots(current: _page, count: _pageCount),
                Positioned(
                  left: 8,
                  child: TextButton(
                    onPressed: () => _finish(saveFields: false),
                    child: const Text('דלג'),
                  ),
                ),
              ],
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _WelcomePage(onStart: () => _goTo(1)),
                  _goalsPage(),
                  _profilePage(),
                  _equipmentPage(),
                  _howItWorksPage(),
                  _summaryPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalsPage() {
    if (!_goalsLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return _WizardPage(
      title: 'מה המטרות שלך?',
      subtitle: 'אפשר לבחור יותר ממטרה אחת. ירידה במשקל ושמירה על המשקל אינן נבחרות יחד.',
      onBack: () => _goTo(0),
      onNext: () => _goTo(2),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ProfileGoalsStore.options.map((goal) {
              final selected = _goals.contains(goal);
              return FilterChip(
                label: Text(goal),
                selected: selected,
                labelStyle: selected
                    ? const TextStyle(color: Colors.white, fontFamily: 'Rubik', fontSize: 13.5, fontWeight: FontWeight.w500)
                    : null,
                onSelected: (_) => setState(() {
                  _goals = ProfileGoalsStore.toggleGoal(_goals, goal);
                  _primaryGoal =
                      ProfileGoalsStore.resolvePrimaryGoal(_goals, preferred: _primaryGoal ?? goal);
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text('מטרה ראשית', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'כשיש כמה מטרות, זו המטרה שמקבלת עדיפות בהמלצות ובתוכניות.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.navy),
          ),
          const SizedBox(height: 10),
          ..._goals.map((goal) {
            final selected = goal == _primaryGoal;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => setState(() => _primaryGoal = goal),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: AppTheme.navy,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(goal, style: Theme.of(context).textTheme.titleSmall)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _profilePage() {
    return _WizardPage(
      title: 'קצת עליך',
      subtitle: 'הנתונים האלה עוזרים לנו לחשב יעד קלוריות וחלבון מתאים. אפשר לשנות בכל שלב מהפרופיל.',
      onBack: () => _goTo(1),
      onNext: () => _goTo(3),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'שם פרטי', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'משקל נוכחי (ק״ג)', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'גובה (ס״מ)', border: OutlineInputBorder()),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'גיל', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  Widget _equipmentPage() {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => _WizardPage(
        title: 'איזה ציוד יש לך?',
        subtitle: 'האימונים שנבנה עבורך יתאימו לציוד שסימנת. תמיד אפשר לעדכן בהמשך במסך "הציוד שלי".',
        onBack: () => _goTo(2),
        onNext: () => _goTo(4),
        body: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: widget.state.equipment.entries.map((entry) {
            return FilterChip(
              label: Text(entry.key),
              selected: entry.value,
              labelStyle: entry.value
                  ? const TextStyle(color: Colors.white, fontFamily: 'Rubik', fontSize: 13.5, fontWeight: FontWeight.w500)
                  : null,
              onSelected: (v) => widget.state.toggleEquipment(entry.key, v),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _howItWorksPage() {
    return _WizardPage(
      title: 'איך התזונה עובדת כאן',
      subtitle: 'שלושה מסכים שעובדים ביחד, כדי שתיעוד האוכל שלך יהיה מהיר ומדויק.',
      onBack: () => _goTo(3),
      onNext: () => _goTo(5),
      body: const Column(
        children: [
          _ExplainerRow(
            icon: Icons.restaurant_menu,
            iconColor: AppTheme.navy,
            title: 'מאגר מזון',
            text: 'כל המזונות שאפשר לתעד — כולל מזונות אישיים שאתה מוסיף, וסריקת ברקוד או תווית תזונה במצלמה.',
          ),
          SizedBox(height: 12),
          _ExplainerRow(
            icon: Icons.kitchen_outlined,
            iconColor: AppTheme.terracotta,
            title: 'המזווה שלי',
            text: 'מה שיש לך בבית עכשיו. ארוחה שמתועדת "מהבית" יורדת אוטומטית מהמלאי, כדי שתדע מה נגמר לך.',
          ),
          SizedBox(height: 12),
          _ExplainerRow(
            icon: Icons.shopping_cart_outlined,
            iconColor: AppTheme.softBlue,
            title: 'רשימת קניות',
            text: 'מוצרים שאזלו במזווה עוברים אליה אוטומטית — ואפשר גם להוסיף אליה ידנית מה שחסר.',
          ),
        ],
      ),
    );
  }

  Widget _summaryPage() {
    final equipmentCount = widget.state.equipment.values.where((v) => v).length;
    return _WizardPage(
      title: 'הכול מוכן!',
      subtitle: 'הגדרנו לך פרופיל, מטרות וציוד — אפשר תמיד לערוך את כל זה מאוחר יותר במסך הפרופיל.',
      onBack: () => _goTo(4),
      nextLabel: 'סיים',
      onNext: () => _finish(saveFields: true),
      body: Column(
        children: [
          if (_primaryGoal != null)
            _SummaryRow(text: 'מטרה: $_primaryGoal'),
          const SizedBox(height: 8),
          _SummaryRow(text: '$equipmentCount פריטי ציוד סומנו'),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 30),
      child: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppTheme.navy,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: AppTheme.pillShadow,
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 46),
                ),
                const SizedBox(height: 22),
                Text('בואו נכיר אותך',
                    style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                const Text(
                  'כמה שאלות קצרות על המטרות, הפרופיל והציוד שלך — כדי שנבנה בשבילך תוכנית תזונה ואימונים מדויקת.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.navy),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onStart, child: const Text('בוא נתחיל')),
          ),
        ],
      ),
    );
  }
}

class _WizardPage extends StatelessWidget {
  const _WizardPage({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.onBack,
    required this.onNext,
    this.nextLabel = 'הבא',
  });

  final String title;
  final String subtitle;
  final Widget body;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(fontSize: 13.5, color: AppTheme.navy)),
              const SizedBox(height: 18),
              body,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: onBack, child: const Text('חזרה')),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(onPressed: onNext, child: Text(nextLabel)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExplainerRow extends StatelessWidget {
  const _ExplainerRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: iconColor, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(text, style: const TextStyle(fontSize: 12.5, color: AppTheme.navy, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(color: AppTheme.navy, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.titleSmall)),
          ],
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.current, required this.count});
  final int current;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? AppTheme.navy : AppTheme.navyTint,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}
