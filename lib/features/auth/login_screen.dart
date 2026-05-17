import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/features/auth/auth_provider.dart';
import 'package:ora/features/auth/worker_login_sheet.dart';
import 'package:ora/features/menu/menu_provider.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';

import 'package:ora/data/models/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  // ─── State ───────────────────────────────────────────────────────────────
  final _phoneC = TextEditingController();
  final _otpC = TextEditingController();
  final _phoneFocus = FocusNode();
  final _otpFocus = FocusNode();

  bool _loading = false;
  bool _otpSent = false;
  String _phone = ''; // normalized phone stored after step 1

  // Resend cooldown
  int _resendCountdown = 0;
  Timer? _resendTimer;

  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut),
    );
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _phoneC.dispose();
    _otpC.dispose();
    _phoneFocus.dispose();
    _otpFocus.dispose();
    _resendTimer?.cancel();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Converts local Pakistani numbers to international format.
  /// 03XX XXXXXXX → +923XXXXXXXXX
  String _normalizePhone(String input) {
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length == 11) {
      digits = '92${digits.substring(1)}';
    }
    if (!digits.startsWith('+')) {
      return '+$digits';
    }
    return digits;
  }

  bool _isPhoneValid(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10;
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) t.cancel();
      });
    });
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    final raw = _phoneC.text.trim();
    if (!_isPhoneValid(raw)) {
      context.showOraSnackBar('Enter a valid phone number', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      // Fetch shop operational hours first
      final settingsData = await Supabase.instance.client
          .from('app_settings')
          .select()
          .single();
      final settings = AppSettings.fromJson(settingsData);
      if (!settings.isCurrentlyOpen) {
        throw Exception('The store is currently closed. We will be back soon!');
      }

      _phone = _normalizePhone(raw);
      await AuthService.sendWhatsAppOtp(_phone);

      if (!mounted) return;
      setState(() => _otpSent = true);
      _startResendTimer();

      // Animate new view in
      _slideCtrl.reset();
      _slideCtrl.forward();

      // Auto-focus OTP field
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) _otpFocus.requestFocus();
      });
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpC.text.trim();
    if (code.length != 6) {
      context.showOraSnackBar('Enter the 6-digit code', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final valid = await AuthService.verifyWhatsAppOtp(_phone, code);
      if (!valid) {
        if (mounted) {
          context.showOraSnackBar(
            'Incorrect or expired code. Please try again.',
            isError: true,
          );
        }
        return;
      }

      // Code is correct — sign in via Supabase phone OTP
      await AuthService.signInWithPhone(_phone);

      if (!mounted) return;

      // Sync guest cart
      await ref.read(cartProvider.notifier).syncGuestCart();
      if (!mounted) return;

      // Load profile and decide where to navigate
      await ref.read(profileProvider.notifier).refresh();
      final profile = ref.read(profileProvider).valueOrNull;
      if (!mounted) return;

      final redirectTo =
          GoRouterState.of(context).uri.queryParameters['redirect'];

      // First-time user with no name set
      if (profile != null &&
          (profile.fullName == null || profile.fullName!.trim().isEmpty)) {
        context.go('/complete-profile');
        return;
      }

      if (profile?.isAdmin ?? false) {
        context.go('/admin');
      } else if (profile?.isRider ?? false) {
        context.go('/rider');
      } else if (redirectTo != null && redirectTo.isNotEmpty) {
        context.go(Uri.decodeComponent(redirectTo));
      } else {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0) return;
    setState(() => _loading = true);
    try {
      // Fetch shop operational hours first
      final settingsData = await Supabase.instance.client
          .from('app_settings')
          .select()
          .single();
      final settings = AppSettings.fromJson(settingsData);
      if (!settings.isCurrentlyOpen) {
        throw Exception('The store is currently closed. We will be back soon!');
      }

      await AuthService.sendWhatsAppOtp(_phone);
      if (!mounted) return;
      _startResendTimer();
      _otpC.clear();
      context.showOraSnackBar('A new code has been sent to your WhatsApp ✅');
    } catch (e) {
      if (mounted) {
        context.showOraSnackBar(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goBack() {
    _otpC.clear();
    _slideCtrl.reset();
    _slideCtrl.forward();
    setState(() {
      _otpSent = false;
      _resendCountdown = 0;
      _resendTimer?.cancel();
    });
  }

  void _openWorkerLogin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WorkerLoginSheet(),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(color: OraTheme.surfaceWhite),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Logo ──────────────────────────────────────
                          const Text(
                            'Ora',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -3,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Step indicator / title ────────────────────
                          if (!_otpSent) ...[
                            Text(
                              'Welcome',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your WhatsApp number to receive\na verification code',
                              style: TextStyle(
                                color: OraTheme.textMuted,
                                fontSize: 14,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ] else ...[
                            // Back button row
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: _goBack,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.arrow_back_rounded,
                                        size: 18,
                                        color: OraTheme.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Change number',
                                        style: TextStyle(
                                          color: OraTheme.textMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Check WhatsApp',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: TextStyle(
                                  color: OraTheme.textMuted,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                                children: [
                                  const TextSpan(
                                      text: 'We sent a 6-digit code to\n'),
                                  TextSpan(
                                    text: _phone,
                                    style: const TextStyle(
                                      color: OraTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const TextSpan(text: ' via WhatsApp'),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 40),

                          // ── Step 1: Phone input ───────────────────────
                          if (!_otpSent) ...[
                            _PhoneInput(
                              controller: _phoneC,
                              focusNode: _phoneFocus,
                              onSubmit: _sendOtp,
                            ),
                            const SizedBox(height: 28),
                            OraButton(
                              label: 'Send Verification Code',
                              onPressed: _sendOtp,
                              isLoading: _loading,
                              icon: Icons.send_rounded,
                            ),
                          ]

                          // ── Step 2: OTP input ─────────────────────────
                          else ...[
                            _OtpInput(
                              controller: _otpC,
                              focusNode: _otpFocus,
                              onSubmit: _verifyOtp,
                            ),
                            const SizedBox(height: 28),
                            OraButton(
                              label: 'Verify Code',
                              onPressed: _verifyOtp,
                              isLoading: _loading,
                              icon: Icons.verified_outlined,
                            ),
                            const SizedBox(height: 20),

                            // Resend link
                            GestureDetector(
                              onTap: _resendCountdown > 0 ? null : _resendOtp,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Didn't receive it? ",
                                    style: TextStyle(
                                      color: OraTheme.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    _resendCountdown > 0
                                        ? 'Resend in ${_resendCountdown}s'
                                        : 'Resend',
                                    style: TextStyle(
                                      color: _resendCountdown > 0
                                          ? OraTheme.textMuted
                                          : OraTheme.primaryOrange,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 48),

                          // ── Worker link (always visible) ──────────────
                          GestureDetector(
                            onTap: _openWorkerLogin,
                            child: Text(
                              'Worker?',
                              style: TextStyle(
                                color: OraTheme.textMuted.withValues(alpha: 0.6),
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                                decorationColor:
                                    OraTheme.textMuted.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Back / Browse button (top-left) ───────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (canPop) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/');
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        canPop
                            ? Icons.arrow_back_rounded
                            : Icons.home_outlined,
                        size: 20,
                        color: OraTheme.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        canPop ? 'Back' : 'Browse Menu',
                        style: TextStyle(
                          color: OraTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Phone Input Widget ──────────────────────────────────────────────────────

class _PhoneInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  const _PhoneInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return OraInput(
      controller: controller,
      focusNode: focusNode,
      label: 'WhatsApp Number',
      hint: 'e.g. 03XX XXXXXXX',
      prefixIcon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => onSubmit(),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+\-\(\)]')),
        LengthLimitingTextInputFormatter(16),
      ],
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Phone number is required';
        final digits = v.replaceAll(RegExp(r'\D'), '');
        if (digits.length < 10) return 'Enter a valid phone number';
        return null;
      },
    );
  }
}

// ─── OTP Input Widget ────────────────────────────────────────────────────────

class _OtpInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  const _OtpInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return OraInput(
      controller: controller,
      focusNode: focusNode,
      label: 'Verification Code',
      hint: '6-digit code',
      prefixIcon: Icons.lock_outline,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => onSubmit(),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      validator: (v) {
        if (v == null || v.length != 6) return 'Enter the 6-digit code';
        return null;
      },
    );
  }
}
