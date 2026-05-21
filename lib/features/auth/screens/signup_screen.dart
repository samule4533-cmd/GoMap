import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_service.dart';
import 'otp_verify_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
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
      await SupabaseService.signUpWithEmail(
        email: email,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OtpVerifyScreen(email: email)),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = '회원가입 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
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
                        labelText: '비밀번호 (6자 이상)',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) {
                        if (v == null || v.isEmpty) return '비밀번호를 입력하세요';
                        if (v.length < 6) return '6자 이상이어야 합니다';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordConfirmController,
                      decoration: const InputDecoration(
                        labelText: '비밀번호 확인',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (v) {
                        if (v != _passwordController.text) {
                          return '비밀번호가 일치하지 않습니다';
                        }
                        return null;
                      },
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorText!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _onSubmit,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('인증 코드 받기'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '입력하신 이메일로 6자리 인증 코드가 발송됩니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
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
