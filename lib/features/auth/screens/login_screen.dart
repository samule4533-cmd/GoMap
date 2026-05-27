import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/auth_local_storage.dart';
import '../../../services/supabase_service.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _rememberEmail = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final saved = await AuthLocalStorage.getRememberedEmail();
    if (!mounted) return;
    if (saved != null && saved.isNotEmpty) {
      _emailController.text = saved;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final email = _emailController.text.trim();
    try {
      await SupabaseService.signInWithPassword(
        email: email,
        password: _passwordController.text,
      );
      if (_rememberEmail) {
        await AuthLocalStorage.saveEmail(email);
      } else {
        await AuthLocalStorage.clearEmail();
      }
      // 성공 시 authStateProvider 가 세션 변화를 받아 AuthGate 가 자동 전환.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = '로그인 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _goToSignup() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignupScreen()));
  }

  // TODO: 출시 전 deep link 기반 비밀번호 재설정으로 교체.
  Future<void> _showResetPasswordNotice() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('비밀번호 찾기'),
        content: const Text(
          '아직 자동 재설정을 지원하지 않습니다.\n'
          '비밀번호를 잊으셨다면 운영자에게 문의해주세요.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'GoMap',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return '이메일을 입력하세요';
                        }
                        if (!v.contains('@')) return '올바른 이메일을 입력하세요';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: '비밀번호',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      validator: (v) {
                        if (v == null || v.isEmpty) return '비밀번호를 입력하세요';
                        return null;
                      },
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberEmail,
                          onChanged: (v) =>
                              setState(() => _rememberEmail = v ?? false),
                        ),
                        const Text('이메일 저장'),
                        const Spacer(),
                        TextButton(
                          onPressed: _submitting
                              ? null
                              : _showResetPasswordNotice,
                          child: const Text('비밀번호 찾기'),
                        ),
                      ],
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _errorText!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _submitting ? null : _onSubmit,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('로그인'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _submitting ? null : _goToSignup,
                      child: const Text('계정이 없으신가요? 회원가입'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
