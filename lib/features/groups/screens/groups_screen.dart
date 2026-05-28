import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/group.dart';
import '../providers/groups_provider.dart';
import 'group_create_screen.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 그룹'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: '새 그룹 만들기',
            onPressed: () => _openCreate(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(groupsListProvider);
        },
        child: groupsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('그룹 목록을 불러올 수 없습니다: $e')),
          data: (groups) {
            if (groups.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [_buildEmpty(context)],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: groups.length,
              itemBuilder: (_, i) => _GroupTile(group: groups[i]),
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
            Icons.groups_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text('아직 그룹이 없습니다', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '친구들과 함께할 그룹을 만들어보세요.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _openCreate(context),
            icon: const Icon(Icons.group_add),
            label: const Text('새 그룹 만들기'),
          ),
        ],
      ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GroupCreateScreen()));
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(group.name.characters.first)),
      title: Text(group.name),
      subtitle: Text(
        group.isOwner
            ? '모임장 · 멤버 ${group.memberCount}명'
            : '모임장 ${group.ownerHandle} · 멤버 ${group.memberCount}명',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: group.id)),
      ),
    );
  }
}
