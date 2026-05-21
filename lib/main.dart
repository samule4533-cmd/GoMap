import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
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
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (state) {
        final session = state.session ?? SupabaseService.auth.currentSession;
        return session != null ? const MapScreen() : const LoginScreen();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('인증 상태 오류: $e'))),
    );
  }
}
