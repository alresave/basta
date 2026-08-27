import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/remote/supabase_config.dart';
import 'presentation/game_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }
  runApp(const BastaApp());
}

class BastaApp extends StatelessWidget {
  const BastaApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(debugShowCheckedModeBanner: false, home: GamePage());
}
