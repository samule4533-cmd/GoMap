import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/map/screens/map_screen.dart';
import 'services/mapbox_service.dart';
// import 'services/supabase_service.dart'; // Supabase 셋업 후 활성화

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MapboxService.init();
  // Supabase 셋업 전까지 비활성. 로컬 Supabase 환경 구성 + .env 값 채운 뒤 다시 활성화.
  // await SupabaseService.init();

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
