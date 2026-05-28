import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_service.dart';
import '../providers/profile_provider.dart';

/// 회원가입 직후 nickname#tag 를 설정하는 화면.
/// 저장 성공 시 myProfileProvider 를 invalidate 해 AuthGate 가 MapScreen 으로 전환.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _tagController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  String? _validateNickname(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '닉네임을 입력해주세요';
    if (v.length > 20) return '닉네임은 20자 이하';
    if (RegExp(r'[#\s]').hasMatch(v)) {
      return '닉네임에 공백과 # 는 사용할 수 없습니다';
    }
    return null;
  }

  String? _validateTag(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 2) return '태그는 2자 이상';
    if (v.length > 20) return '태그는 20자 이하';
    if (RegExp(r'[#\s]').hasMatch(v)) {
      return '태그에 공백과 # 는 사용할 수 없습니다';
    }
    return null;
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('다른 계정으로 가입하기'),
        content: const Text(
          '현재 계정에서 로그아웃하시겠습니까?\n프로필을 설정하지 않은 채 로그아웃되며, 같은 이메일로는 다시 가입할 수 없습니다.',
        ),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await SupabaseService.createMyProfile(
        nickname: _nicknameController.text.trim(),
        tag: _tagController.text.trim(),
      );
      // 프로필 다시 읽도록 invalidate → AuthGate 가 MapScreen 으로 전환
      ref.invalidate(myProfileProvider);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = switch (e.code) {
        '23505' => '이미 사용 중인 닉네임#태그 조합입니다',
        '23514' => '닉네임과 태그에는 공백 또는 # 를 사용할 수 없습니다',
        _ => '프로필 저장 실패: ${e.message}',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('프로필 저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필 설정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: _submitting ? null : _confirmLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  '친구가 나를 찾을 때 사용하는 이름이에요.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
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
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('시작하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
