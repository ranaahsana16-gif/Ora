import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/features/auth/auth_provider.dart';
import 'package:ora/shared/widgets/ora_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final isMobile = MediaQuery.sizeOf(context).width <= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go('/'),
              )
            : null,
        automaticallyImplyLeading: false,
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Not logged in'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Avatar
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: profile.avatarUrl == null ? OraTheme.primaryGradient : null,
                        image: profile.avatarUrl != null
                            ? DecorationImage(
                                image: NetworkImage(profile.avatarUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: OraTheme.primaryOrange.withValues(
                              alpha: 0.25,
                            ),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: profile.avatarUrl == null
                          ? Center(
                              child: Text(
                                (profile.fullName ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      profile.fullName ?? 'User',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.phone ?? '',
                      style: TextStyle(color: OraTheme.textMuted),
                    ),
                    const SizedBox(height: 32),

                    _ProfileTile(
                      icon: Icons.person_outline_rounded,
                      label: 'Edit Profile',
                      onTap: () => context.push('/profile/edit'),
                    ),
                    _ProfileTile(
                      icon: Icons.receipt_long_outlined,
                      label: 'My Orders',
                      onTap: () => context.go('/orders'),
                    ),
                    _ProfileTile(
                      icon: Icons.favorite_border_rounded,
                      label: 'My Wishlist',
                      onTap: () => context.go('/wishlist'),
                    ),
                    _ProfileTile(
                      icon: Icons.location_on_outlined,
                      label: 'Saved Addresses',
                      onTap: () => context.go('/profile/addresses'),
                    ),
                    if (profile.isAdmin)
                      _ProfileTile(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Admin Panel',
                        onTap: () => context.go('/admin'),
                      ),
                    if (profile.isRider)
                      _ProfileTile(
                        icon: Icons.delivery_dining,
                        label: 'Rider Dashboard',
                        onTap: () => context.go('/rider'),
                      ),
                    _ProfileTile(
                      icon: Icons.info_outline,
                      label: 'About Ora',
                      onTap: () {},
                    ),
                    const SizedBox(height: 24),

                    OraButton(
                      label: 'Sign Out',
                      icon: Icons.logout,
                      onPressed: () async {
                        await AuthService.signOut();
                        if (context.mounted) context.go('/login');
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _ProfileTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<_ProfileTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _hovered
                  ? Colors.black.withValues(alpha: 0.03)
                  : OraTheme.cardLight,
              border: Border.all(
                color: Colors.black.withValues(alpha: _hovered ? 0.08 : 0.04),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: OraTheme.primaryOrange.withValues(alpha: 0.1),
                  ),
                  child: Icon(
                    widget.icon,
                    color: OraTheme.primaryOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right_rounded,
                  color: OraTheme.textMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
