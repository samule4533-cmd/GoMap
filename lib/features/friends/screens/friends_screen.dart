import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/friend.dart';
import '../../../services/supabase_service.dart';
import '../providers/friends_provider.dart';
import 'friend_search_screen.dart';

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsListProvider);
    final pendingAsync = ref.watch(pendingRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 친구'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: '친구 추가',
            onPressed: () => _openSearch(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(friendsListProvider);
          ref.invalidate(pendingRequestsProvider);
        },
        child: friendsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('친구 목록을 불러올 수 없습니다: $e')),
          data: (friends) {
            final pending = pendingAsync.maybeWhen(
              data: (list) => list,
              orElse: () => const <Friend>[],
            );
            if (friends.isEmpty && pending.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [_buildEmpty(context)],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (pending.isNotEmpty) ...[
                  _SectionHeader(title: '받은 친구 요청 ${pending.length}개'),
                  for (final f in pending)
                    _PendingRequestTile(friend: f, ref: ref),
                  const Divider(height: 24),
                ],
                if (friends.isNotEmpty) ...[
                  _SectionHeader(title: '친구 ${friends.length}명'),
                  for (final f in friends) _FriendTile(friend: f, ref: ref),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text('아직 친구가 없습니다', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '닉네임#태그로 친구를 검색해 추가해보세요.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _openSearch(context),
            icon: const Icon(Icons.person_add),
            label: const Text('친구 추가하기'),
          ),
        ],
      ),
    );
  }

  void _openSearch(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FriendSearchScreen()));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PendingRequestTile extends StatelessWidget {
  const _PendingRequestTile({required this.friend, required this.ref});

  final Friend friend;
  final WidgetRef ref;

  Future<void> _accept(BuildContext context) async {
    try {
      await SupabaseService.acceptFriendRequest(friend.id);
      ref.invalidate(friendsListProvider);
      ref.invalidate(pendingRequestsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${friend.handle} 님과 친구가 되었습니다')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('수락 실패: $e')));
    }
  }

  Future<void> _reject(BuildContext context) async {
    try {
      await SupabaseService.removeFriend(friend.id);
      ref.invalidate(pendingRequestsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('요청을 거절했습니다')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('거절 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(friend.nickname.characters.first)),
      title: Text(friend.nickname),
      subtitle: Text('#${friend.tag}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => _reject(context),
            child: const Text('거절'),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: () => _accept(context),
            child: const Text('수락'),
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.ref});

  final Friend friend;
  final WidgetRef ref;

  Future<void> _confirmRemove(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('친구 삭제'),
        content: Text('${friend.handle} 님을 친구에서 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.removeFriend(friend.id);
      ref.invalidate(friendsListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${friend.handle} 님을 삭제했습니다')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(friend.nickname.characters.first)),
      title: Text(friend.nickname),
      subtitle: Text(
        friend.addedAt != null
            ? '#${friend.tag} · ${DateFormat('yyyy.MM.dd').format(friend.addedAt!.toLocal())} 추가'
            : '#${friend.tag}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.person_remove_outlined),
        tooltip: '친구 삭제',
        onPressed: () => _confirmRemove(context),
      ),
    );
  }
}
