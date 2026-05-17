import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/extensions/context_extensions.dart';
import 'package:ora/features/auth/auth_provider.dart';
import 'package:ora/features/menu/menu_provider.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';

/// Screen shown after a new customer's first login if their profile
/// does not yet have a full_name set. Prompts them to enter their name.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState
    extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(profileProvider.notifier).updateProfile(
        fullName: _nameC.text.trim(),
      );
      // Sync cart from guest session if any
      await ref.read(cartProvider.notifier).syncGuestCart();
      if (!mounted) return;
      context.go('/');
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
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ora logo
                      const Text(
                        'Ora',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -3,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Welcome icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: OraTheme.primaryOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.waving_hand_rounded,
                          color: OraTheme.primaryOrange,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Welcome to Ora!',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'What should we call you?',
                        style: TextStyle(
                          color: OraTheme.textMuted,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 36),

                      OraInput(
                        controller: _nameC,
                        label: 'Your Name',
                        prefixIcon: Icons.person_outline,
                        keyboardType: TextInputType.name,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          if (v.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      OraButton(
                        label: 'Continue',
                        onPressed: _save,
                        isLoading: _loading,
                        icon: Icons.arrow_forward,
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
