import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/features/auth/auth_provider.dart';
import 'package:ora/features/menu/menu_provider.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.signIn(
        identifier: _emailC.text.trim(),
        password: _passwordC.text,
      );
      await ref.read(cartProvider.notifier).syncGuestCart();

      if (!mounted) return;

      // Load profile and route accordingly
      await ref.read(profileProvider.notifier).refresh();
      final profile = ref.read(profileProvider).valueOrNull;

      if (!mounted) return;

      // Check for a redirect destination (e.g. from checkout flow)
      final redirectTo = GoRouterState.of(context).uri.queryParameters['redirect'];

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

  @override
  Widget build(BuildContext context) {
    // Check if there's a previous route the user can go back to
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: OraTheme.surfaceWhite,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: OraTheme.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: OraTheme.primaryOrange.withValues(alpha: 0.3),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'O',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Welcome Back',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 40),

                          OraInput(
                            controller: _emailC,
                            label: 'Email, Name, or Phone',
                            prefixIcon: Icons.person_outline,
                            keyboardType: TextInputType.text,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Identifier is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          OraInput(
                            controller: _passwordC,
                            label: 'Password',
                            obscureText: !_showPassword,
                            prefixIcon: Icons.lock_outline,
                            suffix: GestureDetector(
                              onTap: () =>
                                  setState(() => _showPassword = !_showPassword),
                              child: Icon(
                                _showPassword ? Icons.visibility_off : Icons.visibility,
                                size: 20,
                                color: OraTheme.textMuted,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Password is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),

                          OraButton(
                            label: 'Sign In',
                            onPressed: _login,
                            isLoading: _loading,
                            icon: Icons.arrow_forward,
                          ),
                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: TextStyle(color: OraTheme.textMuted),
                              ),
                              GestureDetector(
                                onTap: () {
                                  final redirectTo = GoRouterState.of(context).uri.queryParameters['redirect'];
                                  var path = '/signup';
                                  if (redirectTo != null) {
                                    path += '?redirect=${Uri.encodeComponent(redirectTo)}';
                                  }
                                  context.go(path);
                                },
                                child: const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: OraTheme.primaryOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Back / Browse button
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        canPop ? Icons.arrow_back_rounded : Icons.home_outlined,
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
