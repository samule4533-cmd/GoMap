import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/friend.dart';
import '../../../services/supabase_service.dart';
import '../providers/friends_provider.dart';

class FriendSearchScreen extends ConsumerStatefulWidget {
  const FriendSearchScreen({super.key});

  @override
  ConsumerState<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends ConsumerState<FriendSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _tagController = TextEditingController();

  bool _searching = false;
  bool _adding = false;
  Friend? _result;
  bool _searched = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  String? _validateNickname(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '닉네임을 입력해주세요';
    return null;
  }

  String? _validateTag(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '태그를 입력해주세요';
    return null;
  }

  Future<void> _search() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _searching = true;
      _result = null;
      _searched = false;
    });
    try {
      final friend = await SupabaseService.searchProfileByHandle(
        nickname: _nicknameController.text.trim(),
        tag: _tagController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _result = friend;
        _searched = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('검색 실패: $e')));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _addFriend(Friend friend) async {
    setState(() => _adding = true);
    try {
      await SupabaseService.addFriend(friend.id);
      ref.invalidate(friendsListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${friend.handle} 님을 친구로 추가했습니다')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('친구 추가 실패: $e')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('친구 추가')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '친구의 닉네임과 태그를 정확히 입력해주세요.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nicknameController,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        labelText: '닉네임',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateNickname,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tagController,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        labelText: '태그',
                        prefixText: '# ',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateTag,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _searching ? null : _search,
                      icon: _searching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: const Text('검색'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_searched) _buildResult(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    if (_result == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 40,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            const Text('일치하는 사용자가 없습니다.'),
            const SizedBox(height: 4),
            Text(
              '닉네임과 태그를 다시 확인해주세요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final friend = _result!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              child: Text(
                friend.nickname.characters.first,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.nickname,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '#${friend.tag}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: (friend.isFriend || _adding)
                  ? null
                  : () => _addFriend(friend),
              child: friend.isFriend
                  ? const Text('이미 친구')
                  : (_adding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('친구 추가')),
            ),
          ],
        ),
      ),
    );
  }
}
