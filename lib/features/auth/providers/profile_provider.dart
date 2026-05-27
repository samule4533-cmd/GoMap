import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/profile.dart';
import '../../../services/supabase_service.dart';
import 'auth_provider.dart';

/// 현재 로그인된 사용자의 프로필. 없으면 null.
/// 인증 상태가 바뀌면 자동으로 재조회.
final myProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateProvider);
  return SupabaseService.fetchMyProfile();
});
