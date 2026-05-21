import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/supabase_service.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  bool _submitting = false;
  bool _resending = false;
  String? _errorText;
  String? _infoText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onVerify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorText = null;
      _infoText = null;
    });

    try {
      await SupabaseService.verifySignupOtp(
        email: widget.email,
        token: _codeController.text.trim(),
      );
      if (!mounted) return;
      // 검증 성공 = 세션 발급. AuthGate 가 자동으로 메인으로 전환.
      // 가입 흐름에서 진입했으므로 인증 스택 전체를 비운다.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = '인증 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _onResend() async {
    setState(() {
      _resending = true;
      _errorText = null;
      _infoText = null;
    });

    try {
      await SupabaseService.resendSignupOtp(email: widget.email);
      if (!mounted) return;
      setState(() => _infoText = '인증 코드를 다시 보냈습니다.');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = '코드 재발송 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이메일 인증')),
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
                    Text(
                      '${widget.email} 으로\n6자리 인증 코드를 보냈습니다.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        labelText: '인증 코드 6자리',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, letterSpacing: 6),
                      validator: (v) {
                        if (v == null || v.trim().length != 6) {
                          return '6자리 숫자를 입력하세요';
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
                    if (_infoText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _infoText!,
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _onVerify,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('인증 완료'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _resending ? null : _onResend,
                      child: Text(_resending ? '발송 중...' : '코드 다시 받기'),
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
