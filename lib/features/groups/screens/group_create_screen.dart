import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/friend.dart';
import '../../../services/supabase_service.dart';
import '../../friends/providers/friends_provider.dart';
import '../providers/groups_provider.dart';
import 'group_detail_screen.dart';

class GroupCreateScreen extends ConsumerStatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  ConsumerState<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends ConsumerState<GroupCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final Set<String> _selected = {};
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '그룹 이름을 입력해주세요';
    if (v.length > 30) return '그룹 이름은 30자 이하';
    return null;
  }

  void _toggle(String userId) {
    setState(() {
      if (_selected.contains(userId)) {
        _selected.remove(userId);
      } else {
        _selected.add(userId);
      }
    });
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _creating = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = _nameController.text.trim();
    try {
      final groupId = await SupabaseService.createGroup(
        name: name,
        memberUserIds: _selected.toList(),
      );
      ref.invalidate(groupsListProvider);
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)),
      );
      messenger.showSnackBar(SnackBar(content: Text('$name 그룹을 만들었습니다')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('생성 실패: $e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('새 그룹 만들기'),
        actions: [
          TextButton(
            onPressed: _creating ? null : _create,
            child: _creating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('만들기'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: TextFormField(
                  controller: _nameController,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: '그룹 이름',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateName,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '멤버 선택',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      _selected.isEmpty ? '나만 참여' : '${_selected.length}명 선택',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: friendsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('친구 목록을 불러올 수 없습니다: $e')),
                  data: (friends) {
                    if (friends.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            '아직 친구가 없습니다.\n친구 없이 나만의 그룹도 만들 수 있습니다.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (_, i) => _FriendCheckTile(
                        friend: friends[i],
                        selected: _selected.contains(friends[i].id),
                        onToggle: () => _toggle(friends[i].id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendCheckTile extends StatelessWidget {
  const _FriendCheckTile({
    required this.friend,
    required this.selected,
    required this.onToggle,
  });

  final Friend friend;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: selected,
      onChanged: (_) => onToggle(),
      controlAffinity: ListTileControlAffinity.leading,
      secondary: CircleAvatar(child: Text(friend.nickname.characters.first)),
      title: Text(friend.nickname),
      subtitle: Text('#${friend.tag}'),
    );
  }
}
