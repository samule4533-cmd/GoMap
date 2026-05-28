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
      body: friendsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('친구 목록을 불러올 수 없습니다: $e')),
        data: (friends) {
          if (friends.isEmpty) return _buildEmpty(context);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(friendsListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: friends.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) =>
                  _FriendTile(friend: friends[i], ref: ref),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
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
      ),
    );
  }

  void _openSearch(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FriendSearchScreen()));
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
