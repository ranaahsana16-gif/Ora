import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/features/auth/auth_provider.dart';
import 'package:ora/features/menu/menu_provider.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _phoneC = TextEditingController();
  final _passwordC = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _nameC.dispose();
    _emailC.dispose();
    _phoneC.dispose();
    _passwordC.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    try {
      final redirectTo = GoRouterState.of(context).uri.queryParameters['redirect'];
      final needsVerification = await AuthService.signUp(
        email: _emailC.text.trim(),
        password: _passwordC.text,
        fullName: _nameC.text.trim(),
        phone: _phoneC.text.trim(),
      );

      if (mounted) {
        if (needsVerification) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Check Your Email'),
              content: const Text(
                'Account created successfully! We have sent a verification link to your email inbox. '
                'Please verify your email address to continue.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    var path = '/login';
                    if (redirectTo != null) {
                      path += '?redirect=${Uri.encodeComponent(redirectTo)}';
                    }
                    context.go(path);
                  },
                  child: const Text('Go to Login'),
                ),
              ],
            ),
          );
        } else {
          context.showOraSnackBar('Account created! Signing you in...');
          await ref.read(cartProvider.notifier).syncGuestCart();
          if (!mounted) return;
          if (redirectTo != null && redirectTo.isNotEmpty) {
            context.go(Uri.decodeComponent(redirectTo));
          } else {
            context.go('/');
          }
        }
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
    return Scaffold(
      body: Container(
        color: OraTheme.surfaceWhite,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Container(
                        width: 70,
                        height: 70,
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
                      const SizedBox(height: 24),
                      Text(
                        'Create Account',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 36),

                      OraInput(
                        controller: _nameC,
                        label: 'Full Name',
                        prefixIcon: Icons.person_outline,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 16),

                      OraInput(
                        controller: _emailC,
                        label: 'Email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      OraInput(
                        controller: _phoneC,
                        label: 'Phone (Optional)',
                        hint: 'e.g. 03XX XXXXXXX',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

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
                          if (v == null || v.length < 6) {
                            return 'Min 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      OraButton(
                        label: 'Create Account',
                        onPressed: _signup,
                        isLoading: _loading,
                        icon: Icons.person_add_outlined,
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: TextStyle(color: OraTheme.textMuted),
                          ),
                          GestureDetector(
                            onTap: () {
                              final redirectTo = GoRouterState.of(context).uri.queryParameters['redirect'];
                              var path = '/login';
                              if (redirectTo != null) {
                                path += '?redirect=${Uri.encodeComponent(redirectTo)}';
                              }
                              context.go(path);
                            },
                            child: const Text(
                              'Sign In',
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
    );
  }
}
