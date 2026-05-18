import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/data/models/models.dart';
import 'package:ora/features/notifications/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final isMobile = MediaQuery.sizeOf(context).width <= 600;

    return Scaffold(
      backgroundColor: OraTheme.surfaceWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: isMobile
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: OraTheme.primaryOrange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () => markAllNotificationsRead(),
              child: Text(
                'Mark all read',
                style: TextStyle(
                  color: OraTheme.primaryOrange,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: notificationsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(
          child: Text(
            'Could not load notifications.\n$e',
            textAlign: TextAlign.center,
            style: TextStyle(color: OraTheme.textMuted),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return _EmptyNotifications();
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: notifications.length,
            separatorBuilder: (_, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _NotificationTile(
                notification: notifications[index],
                onTap: () async {
                  final n = notifications[index];
                  if (!n.isRead) {
                    await markNotificationRead(n.id);
                  }
                  if (n.orderId != null && context.mounted) {
                    context.go('/orders/${n.orderId}');
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyNotifications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: OraTheme.primaryOrange.withValues(alpha: 0.1),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 44,
                color: OraTheme.primaryOrange.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'All caught up!',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no notifications yet.\nWe\'ll let you know when your order status changes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: OraTheme.textMuted,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Notification Tile ────────────────────────────────────────────────────────

class _NotificationTile extends StatefulWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _hovered = false;

  IconData _iconForTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('accepted')) return Icons.check_circle_outline_rounded;
    if (t.contains('prepar')) return Icons.restaurant_rounded;
    if (t.contains('pickup')) return Icons.shopping_bag_rounded;
    if (t.contains('way')) return Icons.delivery_dining_rounded;
    if (t.contains('delivered') || t.contains('picked up')) {
      return Icons.check_circle_rounded;
    }
    if (t.contains('cancel')) return Icons.cancel_rounded;
    return Icons.notifications_rounded;
  }

  Color _colorForTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('cancel')) return OraTheme.error;
    if (t.contains('delivered') || t.contains('picked up')) {
      return OraTheme.success;
    }
    return OraTheme.primaryOrange;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final color = _colorForTitle(n.title);
    final icon = _iconForTitle(n.title);
    final isUnread = !n.isRead;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.black.withValues(alpha: 0.03)
                : isUnread
                ? color.withValues(alpha: 0.04)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread
                  ? color.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: isUnread
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icon bubble ──
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),

              // ── Content ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 14,
                              color: OraTheme.textPrimary,
                            ),
                          ),
                        ),
                        // Unread dot
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: OraTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: OraTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _timeAgo(n.createdAt.toLocal()),
                          style: TextStyle(
                            fontSize: 11,
                            color: OraTheme.textMuted,
                          ),
                        ),
                        if (n.orderId != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            '· Order #${n.orderId!.substring(0, 8)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: OraTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // ── Chevron ──
              if (n.orderId != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: OraTheme.textMuted,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
