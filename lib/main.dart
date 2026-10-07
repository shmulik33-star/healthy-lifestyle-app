import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'features/profile/cloud_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!CloudGateway.useAppwrite) {
    await Supabase.initialize(
      url: 'https://efhdmatwcmqqqdjdhfly.supabase.co',
      publishableKey: 'sb_publishable_5pJiwX-8a2u-bDT9pVC9Vw_BBruFGMu',
    );
  }
  await CloudGateway.initialize();
  runApp(const HealthyLifestyleApp());
}
