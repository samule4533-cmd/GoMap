import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/friend.dart';
import '../../../models/friend_relation.dart';
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
  bool _acting = false;
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
    if (!RegExp(r'^[가-힣A-Za-z0-9]+$').hasMatch(v)) {
      return '태그는 한글, 영문, 숫자만 입력해주세요';
    }
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

  /// 검색 결과 카드의 액션 버튼 처리. relation 별로 호출하는 RPC 가 다르다.
  Future<void> _act(Friend friend) async {
    setState(() => _acting = true);
    try {
      late final String message;
      switch (friend.relation) {
        case FriendRelation.none:
          await SupabaseService.requestFriend(friend.id);
          message = '${friend.handle} 님에게 친구 요청을 보냈습니다';
        case FriendRelation.pendingSent:
          await SupabaseService.removeFriend(friend.id);
          message = '친구 요청을 취소했습니다';
        case FriendRelation.pendingReceived:
          await SupabaseService.acceptFriendRequest(friend.id);
          message = '${friend.handle} 님과 친구가 되었습니다';
        case FriendRelation.accepted:
          return; // 버튼 비활성 상태라 여기 도달하지 않음
      }
      ref.invalidate(friendsListProvider);
      ref.invalidate(pendingRequestsProvider);
      if (!mounted) return;
      // 다시 검색해서 최신 relation 으로 갱신
      await _search();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('실패: $e')));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _reject(Friend friend) async {
    setState(() => _acting = true);
    try {
      await SupabaseService.removeFriend(friend.id);
      ref.invalidate(pendingRequestsProvider);
      if (!mounted) return;
      await _search();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('요청을 거절했습니다')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('실패: $e')));
    } finally {
      if (mounted) setState(() => _acting = false);
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
            _buildActions(friend),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(Friend friend) {
    if (_acting) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    switch (friend.relation) {
      case FriendRelation.none:
        return FilledButton(
          onPressed: () => _act(friend),
          child: const Text('친구 신청'),
        );
      case FriendRelation.pendingSent:
        return OutlinedButton(
          onPressed: () => _act(friend),
          child: const Text('요청 취소'),
        );
      case FriendRelation.pendingReceived:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => _reject(friend),
              child: const Text('거절'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: () => _act(friend),
              child: const Text('수락'),
            ),
          ],
        );
      case FriendRelation.accepted:
        return FilledButton(onPressed: null, child: const Text('이미 친구'));
    }
  }
}
