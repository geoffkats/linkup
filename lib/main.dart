import 'package:flutter/material.dart';
import 'package:linkup/linkup_app.dart';
import 'package:linkup/services/supabase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const LinkUpApp();
  }
}
