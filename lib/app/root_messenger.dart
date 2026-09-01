import 'package:flutter/material.dart';

/// App-wide messenger, so a global notice (currently just the water
/// reminder in AppStateGate) can show a SnackBar regardless of which of
/// the bottom-nav tabs is on screen, without threading a BuildContext from
/// deep inside AppStateGate's own state. Its own file so app.dart and
/// app_state_gate.dart can both import it without an import cycle.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
