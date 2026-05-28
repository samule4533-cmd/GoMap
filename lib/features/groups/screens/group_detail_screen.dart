import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/friend.dart';
import '../../../models/group.dart';
import '../../../models/group_member.dart';
import '../../../services/supabase_service.dart';
import '../../friends/providers/friends_provider.dart';
import '../providers/groups_provider.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsListProvider);
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    final group = groupsAsync.maybeWhen(
      data: (list) => list.where((g) => g.id == groupId).isEmpty
          ? null
          : list.firstWhere((g) => g.id == groupId),
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(group?.name ?? '그룹'),
        actions: [
          if (group != null)
            PopupMenuButton<_MenuAction>(
              onSelected: (action) => _handleMenu(context, ref, group, action),
              itemBuilder: (_) => [
                if (group.isOwner)
                  const PopupMenuItem(
                    value: _MenuAction.rename,
                    child: Text('이름 변경'),
                  ),
                if (group.isOwner)
                  const PopupMenuItem(
                    value: _MenuAction.transfer,
                    child: Text('모임장 위임'),
                  ),
                if (group.isOwner)
                  const PopupMenuItem(
                    value: _MenuAction.delete,
                    child: Text('그룹 삭제'),
                  ),
                const PopupMenuItem(
                  value: _MenuAction.leave,
                  child: Text('그룹 나가기'),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(groupMembersProvider(groupId));
          ref.invalidate(groupsListProvider);
        },
        child: membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('멤버를 불러올 수 없습니다: $e')),
          data: (members) {
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: members.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      '멤버 ${members.length}명',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final m = members[i - 1];
                return _MemberTile(member: m, group: group, groupId: groupId);
              },
            );
          },
        ),
      ),
      floatingActionButton: group?.isOwner == true
          ? FloatingActionButton.extended(
              onPressed: () => _openAddMembers(context, ref, group!),
              icon: const Icon(Icons.person_add),
              label: const Text('멤버 추가'),
            )
          : null,
    );
  }

  Future<void> _handleMenu(
    BuildContext context,
    WidgetRef ref,
    Group group,
    _MenuAction action,
  ) async {
    switch (action) {
      case _MenuAction.rename:
        await _renameDialog(context, ref, group);
      case _MenuAction.transfer:
        await _transferDialog(context, ref, group);
      case _MenuAction.delete:
        await _confirmDelete(context, ref, group);
      case _MenuAction.leave:
        await _confirmLeave(context, ref, group);
    }
  }

  Future<void> _renameDialog(
    BuildContext context,
    WidgetRef ref,
    Group group,
  ) async {
    final controller = TextEditingController(text: group.name);
    final String? newName;
    try {
      newName = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('이름 변경'),
          content: TextField(
            controller: controller,
            maxLength: 30,
            decoration: const InputDecoration(labelText: '그룹 이름'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('저장'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
    if (newName == null || newName.isEmpty || newName == group.name) return;
    try {
      await SupabaseService.renameGroup(groupId: group.id, newName: newName);
      ref.invalidate(groupsListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이름을 변경했습니다')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('변경 실패: $e')));
    }
  }

  Future<void> _transferDialog(
    BuildContext context,
    WidgetRef ref,
    Group group,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final List<GroupMember> candidates;
    try {
      final members = await ref.read(groupMembersProvider(group.id).future);
      candidates = members.where((m) => !m.isOwner).toList();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('멤버 목록 로딩 실패: $e')));
      return;
    }
    if (!context.mounted) return;
    if (candidates.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('위임할 다른 멤버가 없습니다')));
      return;
    }
    final picked = await showDialog<GroupMember>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('새 모임장 선택'),
        children: [
          for (final m in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(m),
              child: Text(m.handle),
            ),
        ],
      ),
    );
    if (picked == null) return;
    try {
      await SupabaseService.transferGroupOwnership(
        groupId: group.id,
        newOwnerId: picked.userId,
      );
      ref.invalidate(groupsListProvider);
      ref.invalidate(groupMembersProvider(group.id));
      messenger.showSnackBar(
        SnackBar(content: Text('${picked.handle} 님에게 위임했습니다')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('위임 실패: $e')));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Group group,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('그룹 삭제'),
        content: Text('${group.name} 그룹을 삭제하시겠습니까?\n모든 멤버가 그룹에서 나가게 됩니다.'),
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
      await SupabaseService.deleteGroup(group.id);
      ref.invalidate(groupsListProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('${group.name} 을 삭제했습니다')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    Group group,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('그룹 나가기'),
        content: Text(
          group.isOwner
              ? '모임장이 나가면 가장 오래된 멤버에게 자동 위임됩니다. 멤버가 본인뿐이면 그룹이 삭제됩니다.'
              : '${group.name} 그룹에서 나가시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.leaveGroup(group.id);
      ref.invalidate(groupsListProvider);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('그룹에서 나갔습니다')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('나가기 실패: $e')));
    }
  }

  Future<void> _openAddMembers(
    BuildContext context,
    WidgetRef ref,
    Group group,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final List<Friend> candidates;
    try {
      final friends = await ref.read(friendsListProvider.future);
      final existing = (await ref.read(
        groupMembersProvider(group.id).future,
      )).map((m) => m.userId).toSet();
      candidates = friends.where((f) => !existing.contains(f.id)).toList();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('친구 목록 로딩 실패: $e')));
      return;
    }
    if (!context.mounted) return;
    if (candidates.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('추가할 친구가 없습니다')));
      return;
    }
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddMembersSheet(candidates: candidates),
    );
    if (picked == null || picked.isEmpty) return;
    try {
      await SupabaseService.addGroupMembers(
        groupId: group.id,
        memberUserIds: picked,
      );
      ref.invalidate(groupsListProvider);
      ref.invalidate(groupMembersProvider(group.id));
      messenger.showSnackBar(
        SnackBar(content: Text('${picked.length}명을 추가했습니다')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('추가 실패: $e')));
    }
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.member,
    required this.group,
    required this.groupId,
  });

  final GroupMember member;
  final Group? group;
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canKick = group?.isOwner == true && !member.isOwner;
    return ListTile(
      leading: CircleAvatar(
        child: Text((member.nickname?.characters.first ?? '?')),
      ),
      title: Row(
        children: [
          Flexible(child: Text(member.handle)),
          if (member.isOwner) ...[
            const SizedBox(width: 8),
            const Icon(Icons.shield, size: 16),
          ],
        ],
      ),
      subtitle: Text(
        '${DateFormat('yyyy.MM.dd').format(member.joinedAt.toLocal())} 가입',
      ),
      trailing: canKick
          ? IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: '내보내기',
              onPressed: () => _confirmKick(context, ref),
            )
          : null,
    );
  }

  Future<void> _confirmKick(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('멤버 내보내기'),
        content: Text('${member.handle} 님을 내보내시겠습니까?'),
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
            child: const Text('내보내기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.removeGroupMember(
        groupId: groupId,
        targetUserId: member.userId,
      );
      ref.invalidate(groupMembersProvider(groupId));
      ref.invalidate(groupsListProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${member.handle} 을 내보냈습니다')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('실패: $e')));
    }
  }
}

class _AddMembersSheet extends StatefulWidget {
  const _AddMembersSheet({required this.candidates});

  final List<Friend> candidates;

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final Set<String> _selected = {};

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '추가할 친구 선택 (${_selected.length}명)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_selected.toList()),
                    child: const Text('추가'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.candidates.length,
                itemBuilder: (_, i) {
                  final f = widget.candidates[i];
                  return CheckboxListTile(
                    value: _selected.contains(f.id),
                    onChanged: (_) => _toggle(f.id),
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: CircleAvatar(
                      child: Text(f.nickname.characters.first),
                    ),
                    title: Text(f.nickname),
                    subtitle: Text('#${f.tag}'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MenuAction { rename, transfer, delete, leave }
