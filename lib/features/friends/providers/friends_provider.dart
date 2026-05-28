import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/friend.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

/// 내 친구 목록 (accepted). 인증 상태가 바뀌면 재조회.
final friendsListProvider = FutureProvider<List<Friend>>((ref) async {
  ref.watch(authStateProvider);
  return SupabaseService.listMyFriends();
});

/// 내가 받은 친구 요청 목록 (pending).
final pendingRequestsProvider = FutureProvider<List<Friend>>((ref) async {
  ref.watch(authStateProvider);
  return SupabaseService.listMyPendingRequests();
});
