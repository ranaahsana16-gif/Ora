import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/data/models/models.dart';

final _supabase = Supabase.instance.client;

// ─── Auth State Provider ───
final authStateProvider = StreamProvider<AuthState>((ref) {
  return _supabase.auth.onAuthStateChange;
});

// ─── Current User Provider ───
final currentUserProvider = Provider<User?>((ref) {
  return _supabase.auth.currentUser;
});

// ─── Profile Provider ───
final profileProvider = AsyncNotifierProvider<ProfileNotifier, Profile?>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final data = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();
    return Profile.fromJson(data);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return Profile.fromJson(data);
    });
  }

  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    if (updates.isEmpty) return;

    await _supabase.from('profiles').update(updates).eq('id', user.id);
    await refresh();
  }
}

// ─── Friendly error message helper ───
String _friendlyAuthMessage(AuthException e) {
  final msg = e.message.toLowerCase();
  final code = e.code?.toLowerCase() ?? '';

  // Email not confirmed
  if (msg.contains('email not confirmed') ||
      code.contains('email_not_confirmed') ||
      msg.contains('not confirmed')) {
    return 'Your email is not verified. Please check your inbox and verify your email before logging in.';
  }

  // Invalid credentials (wrong email or password)
  if (msg.contains('invalid login credentials') ||
      msg.contains('invalid credentials') ||
      code.contains('invalid_credentials')) {
    return 'Incorrect email or password. Please try again.';
  }

  // User not found
  if (msg.contains('user not found') || code.contains('user_not_found')) {
    return 'No account found with this email. Please sign up first.';
  }

  // Too many requests
  if (msg.contains('rate limit') ||
      msg.contains('too many requests') ||
      code.contains('over_request_rate_limit')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }

  // Signup disabled
  if (msg.contains('signups not allowed') ||
      code.contains('signup_disabled')) {
    return 'Signups are currently disabled. Please contact support.';
  }

  // User already registered
  if (msg.contains('already registered') ||
      msg.contains('already exists') ||
      code.contains('user_already_exists')) {
    return 'An account with this email already exists. Please log in instead.';
  }

  // Weak password
  if (msg.contains('password') && msg.contains('weak') ||
      code.contains('weak_password')) {
    return 'Password is too weak. Please use a stronger password.';
  }

  // Generic fallback — strip the technical prefix
  return e.message;
}

// ─── Auth Actions ───
class AuthService {
  /// Signs up and returns `true` if email confirmation is required.
  static Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
        emailRedirectTo: const bool.hasEnvironment('dart.library.js_util') 
            ? Uri.base.origin 
            : null,
      );

      // If no session was returned, email confirmation is required
      if (response.session == null) {
        return true; // email confirmation needed
      }
      return false; // auto-confirmed, signed in
    } on AuthException catch (e) {
      throw Exception(_friendlyAuthMessage(e));
    }
  }

  static Future<void> resendVerificationEmail(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: const bool.hasEnvironment('dart.library.js_util') 
            ? Uri.base.origin 
            : null,
      );
    } on AuthException catch (e) {
      throw Exception(_friendlyAuthMessage(e));
    }
  }

  static Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    try {
      // Resolve identifier (Name, Phone, or Email) to Email using RPC
      final response = await _supabase.rpc('get_email_by_identifier', params: {
        'p_identifier': identifier.trim(),
      });

      final String resolvedEmail = (response as String?) ?? identifier.trim();

      await _supabase.auth.signInWithPassword(
        email: resolvedEmail,
        password: password,
      );
    } on AuthException catch (e) {
      throw Exception(_friendlyAuthMessage(e));
    } catch (e) {
      throw Exception('Login failed: Check your credentials and try again.');
    }
  }

  static Future<void> updateUser({
    String? email,
    String? password,
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final attributes = UserAttributes(
        email: email,
        password: password,
        data: {
          'full_name': ?fullName,
          'avatar_url': ?avatarUrl,
        },
      );
      await _supabase.auth.updateUser(attributes);

      // Update profiles table too
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final updates = <String, dynamic>{};
        if (fullName != null) updates['full_name'] = fullName;
        if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
        if (updates.isNotEmpty) {
          await _supabase.from('profiles').update(updates).eq('id', user.id);
        }
      }
    } on AuthException catch (e) {
      throw Exception(_friendlyAuthMessage(e));
    }
  }

  static Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
