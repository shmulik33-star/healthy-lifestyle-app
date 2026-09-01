import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/theme/app_theme.dart';
import 'app_state_gate.dart';
import 'root_messenger.dart';
import 'shell.dart';

class HealthyLifestyleApp extends StatelessWidget {
  const HealthyLifestyleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
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
      // AppStateGate loads AppState/starts its background services once
      // here, above every go_router route, then provides AppStateScope --
      // see that file for why this moved out of the old AppShell.
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: AppStateGate(child: child ?? const SizedBox.shrink()),
      ),
      routerConfig: appRouter,
    );
  }
}
