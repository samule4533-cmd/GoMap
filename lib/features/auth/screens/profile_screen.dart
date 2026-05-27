import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/profile.dart';
import '../../../services/supabase_service.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _tagController = TextEditingController();

  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _startEdit(Profile profile) {
    _nicknameController.text = profile.nickname;
    _tagController.text = profile.tag;
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    setState(() => _editing = false);
  }

  Future<void> _saveEdit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await SupabaseService.updateMyProfile(
        nickname: _nicknameController.text.trim(),
        tag: _tagController.text.trim(),
      );
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      setState(() => _editing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('프로필이 수정되었습니다')));
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = e.code == '23505'
          ? '이미 사용 중인 닉네임#태그 조합입니다'
          : '수정 실패: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('수정 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SupabaseService.signOut();
      // 세션 종료 시 authStateProvider 가 변화 → AuthGate 가 LoginScreen 으로 전환.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그아웃 실패: $e')));
    }
  }

  String? _validateNickname(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '닉네임을 입력해주세요';
    if (v.length > 20) return '닉네임은 20자 이하';
    if (v.contains('#')) return '닉네임에 # 는 사용할 수 없습니다';
    return null;
  }

  String? _validateTag(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 2) return '태그는 2자 이상';
    if (v.length > 20) return '태그는 20자 이하';
    if (v.contains('#')) return '태그에 # 는 사용할 수 없습니다';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final email = SupabaseService.auth.currentUser?.email ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 프로필'),
        actions: [
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _cancelEdit,
              child: const Text('취소'),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('프로필을 불러올 수 없습니다: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('프로필이 없습니다.'));
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ReadOnlyField(label: '이메일', value: email),
                    const SizedBox(height: 16),
                    if (_editing) ...[
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
                    ] else ...[
                      _ReadOnlyField(label: '핸들', value: profile.handle),
                    ],
                    const SizedBox(height: 16),
                    _ReadOnlyField(
                      label: '가입일',
                      value: DateFormat(
                        'yyyy.MM.dd',
                      ).format(profile.createdAt.toLocal()),
                    ),
                    const SizedBox(height: 24),
                    if (_editing)
                      FilledButton(
                        onPressed: _saving ? null : _saveEdit,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('저장'),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: () => _startEdit(profile),
                        icon: const Icon(Icons.edit),
                        label: const Text('프로필 수정'),
                      ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _editing ? null : _confirmLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('로그아웃'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
