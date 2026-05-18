import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/features/auth/auth_provider.dart';
import 'package:ora/features/menu/menu_provider.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';
import 'package:ora/features/orders/orders_screen.dart';
import 'package:ora/features/profile/address_provider.dart';
import 'package:ora/features/wishlist/wishlist_provider.dart';

/// Bottom sheet for riders and admins to log in with email + password.
/// Opened by tapping the small "Worker?" link on the main login screen.
class WorkerLoginSheet extends ConsumerStatefulWidget {
  const WorkerLoginSheet({super.key});

  @override
  ConsumerState<WorkerLoginSheet> createState() => _WorkerLoginSheetState();
}

class _WorkerLoginSheetState extends ConsumerState<WorkerLoginSheet> {
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

      await ref.read(profileProvider.notifier).refresh();
      final profile = ref.read(profileProvider).valueOrNull;

      if (!mounted) return;

      Navigator.of(context).pop(); // close sheet

      if (profile?.isAdmin ?? false) {
        context.go('/admin');
      } else if (profile?.isRider ?? false) {
        context.go('/rider');
      } else {
        context.showOraSnackBar(
          'Access denied. This login is for workers only.',
          isError: true,
        );
        await AuthService.signOut();
        ref.invalidate(profileProvider);
        ref.invalidate(cartProvider);
        ref.invalidate(ordersProvider);
        ref.invalidate(addressProvider);
        ref.invalidate(wishlistProvider);
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        28,
        20,
        28,
        28 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: OraTheme.primaryOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color: OraTheme.primaryOrange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Worker Login',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: OraTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'For riders and administrators only',
                      style: TextStyle(fontSize: 12, color: OraTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Email field
            OraInput(
              controller: _emailC,
              label: 'Email',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Password field
            OraInput(
              controller: _passwordC,
              label: 'Password',
              obscureText: !_showPassword,
              prefixIcon: Icons.lock_outline,
              suffix: GestureDetector(
                onTap: () => setState(() => _showPassword = !_showPassword),
                child: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: OraTheme.textMuted,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Sign in button
            OraButton(
              label: 'Sign In as Worker',
              onPressed: _login,
              isLoading: _loading,
              icon: Icons.arrow_forward,
            ),
          ],
        ),
      ),
    );
  }
}
