import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/data/models/models.dart';

final _supabase = Supabase.instance.client;

final addressProvider =
    AsyncNotifierProvider<AddressNotifier, List<UserAddress>>(() {
      return AddressNotifier();
    });

class AddressNotifier extends AsyncNotifier<List<UserAddress>> {
  @override
  Future<List<UserAddress>> build() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('user_addresses')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (response as List).map((e) => UserAddress.fromJson(e)).toList();
  }

  Future<void> addAddress(UserAddress address) async {
    state = const AsyncValue.loading();
    try {
      if (address.isDefault) {
        await _supabase
            .from('user_addresses')
            .update({'is_default': false})
            .eq('user_id', address.userId);
      }

      await _supabase.from('user_addresses').insert(address.toJson());
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateAddress(UserAddress address) async {
    state = const AsyncValue.loading();
    try {
      if (address.isDefault) {
        await _supabase
            .from('user_addresses')
            .update({'is_default': false})
            .eq('user_id', address.userId);
      }

      await _supabase
          .from('user_addresses')
          .update(address.toJson())
          .eq('id', address.id);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteAddress(String id) async {
    state = const AsyncValue.loading();
    try {
      await _supabase.from('user_addresses').delete().eq('id', id);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setDefault(String id) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      await _supabase
          .from('user_addresses')
          .update({'is_default': false})
          .eq('user_id', user.id);

      await _supabase
          .from('user_addresses')
          .update({'is_default': true})
          .eq('id', id);
      ref.invalidateSelf();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
