import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/group.dart';
import '../../../models/group_member.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

/// 내 그룹 목록.
final groupsListProvider = FutureProvider<List<Group>>((ref) async {
  ref.watch(authStateProvider);
  return SupabaseService.listMyGroups();
});

/// 특정 그룹의 멤버 목록. groupId 별로 캐시.
final groupMembersProvider = FutureProvider.family<List<GroupMember>, String>((
  ref,
  groupId,
) async {
  ref.watch(authStateProvider);
  return SupabaseService.listGroupMembers(groupId);
});
