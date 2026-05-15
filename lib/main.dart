import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/map/screens/map_screen.dart';
import 'services/mapbox_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MapboxService.init();
  await SupabaseService.init();

  runApp(const ProviderScope(child: GoMapApp()));
}

class GoMapApp extends StatelessWidget {
  const GoMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoMap',
      debugShowCheckedModeBanner: false,
      home: const MapScreen(),
    );
  }
}
