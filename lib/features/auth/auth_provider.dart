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

  if (msg.contains('invalid login credentials') ||
      msg.contains('invalid credentials') ||
      code.contains('invalid_credentials')) {
    return 'Incorrect email or password. Please try again.';
  }

  if (msg.contains('user not found') || code.contains('user_not_found')) {
    return 'No account found with this email. Please contact support.';
  }

  if (msg.contains('rate limit') ||
      msg.contains('too many requests') ||
      code.contains('over_request_rate_limit')) {
    return 'Too many attempts. Please wait a moment and try again.';
  }

  if (msg.contains('signups not allowed') || code.contains('signup_disabled')) {
    return 'Signups are currently disabled. Please contact support.';
  }

  if (msg.contains('already registered') ||
      msg.contains('already exists') ||
      code.contains('user_already_exists')) {
    return 'An account with this email already exists. Please log in instead.';
  }

  if (msg.contains('password') && msg.contains('weak') ||
      code.contains('weak_password')) {
    return 'Password is too weak. Please use a stronger password.';
  }

  return e.message;
}

// ─── Auth Actions ───
class AuthService {
  // ── WhatsApp OTP ──────────────────────────────────────────────────────────

  /// Requests an OTP to be sent via WhatsApp.
  /// Inserts into otp_requests table via RPC; the Node.js server picks it up
  /// and sends the code to the customer's WhatsApp.
  static Future<void> sendWhatsAppOtp(String phone) async {
    try {
      await _supabase.rpc('request_whatsapp_otp', params: {'p_phone': phone});
    } catch (e) {
      throw Exception('Failed to send verification code. Please try again.');
    }
  }

  /// Verifies an OTP code for a given phone number.
  /// Returns true if valid, false if expired/wrong.
  static Future<bool> verifyWhatsAppOtp(String phone, String code) async {
    try {
      final result = await _supabase.rpc(
        'verify_otp',
        params: {'p_phone': phone, 'p_code': code},
      );
      return result as bool? ?? false;
    } catch (e) {
      throw Exception('Verification failed. Please try again.');
    }
  }

  /// Signs in or creates a customer account using Supabase phone OTP.
  /// Call this AFTER verifyWhatsAppOtp returns true.
  static Future<void> signInWithPhone(String phone) async {
    try {
      final res = await _supabase.functions.invoke(
        'sign-in-with-phone',
        body: {'phone': phone},
      );
      final data = res.data as Map<String, dynamic>;
      final token = data['token'].toString();
      final email = data['email'] as String;
      
      await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
    } on AuthException catch (e) {
      throw Exception(_friendlyAuthMessage(e));
    } on FunctionException catch (e) {
      throw Exception('Server Error: ${e.details ?? e.reasonPhrase}');
    } catch (e) {
      throw Exception('Sign-in failed: $e');
    }
  }

  /// Completes sign-in by verifying the OTP from Supabase's phone auth.
  /// This is the token that Supabase's own phone OTP sends (if SMS enabled),
  /// OR we use our own WhatsApp-verified code and a custom edge function.
  static Future<void> verifyPhoneOtp(String phone, String token) async {
    try {
      await _supabase.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
    } on AuthException catch (e) {
      throw Exception(_friendlyAuthMessage(e));
    } catch (e) {
      throw Exception('Invalid or expired code. Please try again.');
    }
  }

  // ── Email / Password (for workers: riders and admins) ────────────────────

  static Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_email_by_identifier',
        params: {'p_identifier': identifier.trim()},
      );

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
        data: {'full_name': ?fullName, 'avatar_url': ?avatarUrl},
      );
      await _supabase.auth.updateUser(attributes);

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

  static Future<void> signOutAndClear(WidgetRef ref) async {
    await _supabase.auth.signOut();
    ref.invalidate(profileProvider);
    
    // Attempt to invalidate other providers if they are loaded.
    // Instead of importing all of them and causing circular dependencies,
    // we can just call them locally in the UI, or import them here.
  }
}
