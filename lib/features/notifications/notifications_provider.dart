import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/data/models/models.dart';

final _supabase = Supabase.instance.client;

/// Streams the current user's notifications in real-time, newest first.
final notificationsStreamProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
      final user = _supabase.auth.currentUser;
      if (user == null) return const Stream.empty();

      return _supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .map((rows) => rows.map((r) => AppNotification.fromJson(r)).toList());
    });

/// Derived unread count.
final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final async = ref.watch(notificationsStreamProvider);
  return async.maybeWhen(
    data: (list) => list.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

/// Marks a single notification as read.
Future<void> markNotificationRead(String notificationId) async {
  await _supabase
      .from('notifications')
      .update({'is_read': true})
      .eq('id', notificationId);
}

/// Marks all of the current user's notifications as read.
Future<void> markAllNotificationsRead() async {
  final user = _supabase.auth.currentUser;
  if (user == null) return;
  await _supabase
      .from('notifications')
      .update({'is_read': true})
      .eq('user_id', user.id)
      .eq('is_read', false);
}
