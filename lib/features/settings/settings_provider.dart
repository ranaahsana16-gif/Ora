import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ora/data/models/models.dart';

final _supabase = Supabase.instance.client;

final settingsProvider = StreamProvider<AppSettings>((ref) {
  return _supabase
      .from('app_settings')
      .stream(primaryKey: ['id'])
      .eq('id', 1)
      .map((data) {
        if (data.isEmpty) {
          return const AppSettings(
            id: 1,
            taxPercentage: 0,
            discountPercentage: 0,
            deliveryFee: 0,
          );
        }
        return AppSettings.fromJson(data.first);
      });
});
