import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/theme/app_theme.dart';
import 'shell.dart';

/// App-wide messenger, so a global notice (currently just the water
/// reminder in AppShell) can show a SnackBar regardless of which of the
/// bottom-nav tabs is on screen, without threading a BuildContext from deep
/// inside AppShell's own state.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class HealthyLifestyleApp extends StatelessWidget {
  const HealthyLifestyleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'אורח חיים בריא',
      locale: const Locale('he', 'IL'),
      supportedLocales: const [Locale('he', 'IL')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AppShell(),
    );
  }
}
