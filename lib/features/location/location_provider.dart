import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderLocation {
  final String type; // 'delivery' or 'pickup'

  // Delivery details
  final String? cityId;
  final String? cityName;
  final String? areaId;
  final String? areaName;
  final double? deliveryFee;
  final String? estimatedDeliveryTime;

  // Pickup details
  final String? outletId;
  final String? outletName;

  const OrderLocation({
    required this.type,
    this.cityId,
    this.cityName,
    this.areaId,
    this.areaName,
    this.deliveryFee,
    this.estimatedDeliveryTime,
    this.outletId,
    this.outletName,
  });

  bool get isComplete {
    if (type == 'delivery') {
      return cityId != null && areaId != null;
    } else {
      return outletId != null;
    }
  }

  String get displayTitle {
    if (type == 'delivery') {
      return cityName != null ? 'Delivery to $cityName' : 'Delivery to';
    }
    return 'Pick-Up from';
  }

  String? get formattedDeliveryTime {
    if (estimatedDeliveryTime == null) return null;
    if (estimatedDeliveryTime!.toLowerCase().contains('min')) {
      return estimatedDeliveryTime;
    }
    return '$estimatedDeliveryTime min';
  }

  String get displaySubtitle {
    if (type == 'delivery' && areaName != null) {
      return '$areaName${cityName != null ? ", $cityName" : ""}';
    } else if (type == 'pickup' && outletName != null) {
      return outletName!;
    }
    return 'Select Location';
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'cityId': cityId,
    'cityName': cityName,
    'areaId': areaId,
    'areaName': areaName,
    'deliveryFee': deliveryFee,
    'estimatedDeliveryTime': estimatedDeliveryTime,
    'outletId': outletId,
    'outletName': outletName,
  };

  factory OrderLocation.fromJson(Map<String, dynamic> json) {
    return OrderLocation(
      type: json['type'] as String,
      cityId: json['cityId'] as String?,
      cityName: json['cityName'] as String?,
      areaId: json['areaId'] as String?,
      areaName: json['areaName'] as String?,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble(),
      estimatedDeliveryTime: json['estimatedDeliveryTime'] as String?,
      outletId: json['outletId'] as String?,
      outletName: json['outletName'] as String?,
    );
  }
}

class LocationNotifier extends StateNotifier<OrderLocation?> {
  LocationNotifier() : super(null) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('order_location');
    if (data != null) {
      try {
        state = OrderLocation.fromJson(jsonDecode(data));
      } catch (e) {
        state = null;
      }
    }
  }

  Future<void> setLocation(OrderLocation location) async {
    state = location;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('order_location', jsonEncode(location.toJson()));
  }

  Future<void> clearLocation() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('order_location');
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, OrderLocation?>((ref) {
      return LocationNotifier();
    });
