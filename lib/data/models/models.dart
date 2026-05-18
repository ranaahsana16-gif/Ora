import 'package:flutter/material.dart';

class Profile {
  final String id;
  final String role;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.role,
    this.fullName,
    this.phone,
    this.avatarUrl,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  bool get isRider => role == 'rider';
  bool get isCustomer => role == 'customer';

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      role: json['role'] as String? ?? 'customer',
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'full_name': fullName,
    'phone': phone,
    'avatar_url': avatarUrl,
  };
}

class Category {
  final String id;
  final String name;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;

  const Category({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.sortOrder,
    required this.isActive,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'image_url': imageUrl,
    'sort_order': sortOrder,
    'is_active': isActive,
  };
}

class Product {
  final String id;
  final String categoryId;
  final String? categoryId2;
  final String name;
  final String? description;
  final double price;
  final double? discountedPrice;
  final String? imageUrl;
  final bool isAvailable;
  final bool isNew;
  final int sortOrder;
  final List<ProductOptionGroup>? optionGroups;

  const Product({
    required this.id,
    required this.categoryId,
    this.categoryId2,
    required this.name,
    this.description,
    required this.price,
    this.discountedPrice,
    this.imageUrl,
    required this.isAvailable,
    this.isNew = false,
    required this.sortOrder,
    this.optionGroups,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      categoryId2: json['category_id_2'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      discountedPrice: json['discounted_price'] != null
          ? (json['discounted_price'] as num).toDouble()
          : null,
      imageUrl: json['image_url'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      isNew: json['is_new'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      optionGroups: json['product_option_groups'] != null
          ? (json['product_option_groups'] as List)
                .map(
                  (e) => ProductOptionGroup.fromJson(e as Map<String, dynamic>),
                )
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'category_id': categoryId,
    'category_id_2': categoryId2,
    'name': name,
    'description': description,
    'price': price,
    'discounted_price': discountedPrice,
    'image_url': imageUrl,
    'is_available': isAvailable,
    'is_new': isNew,
    'sort_order': sortOrder,
  };
}

class ProductOptionGroup {
  final String id;
  final String productId;
  final String name;
  final bool isMandatory;
  final bool allowMultiple;
  final int sortOrder;
  final List<ProductOption>? options;

  const ProductOptionGroup({
    required this.id,
    required this.productId,
    required this.name,
    required this.isMandatory,
    required this.allowMultiple,
    required this.sortOrder,
    this.options,
  });

  factory ProductOptionGroup.fromJson(Map<String, dynamic> json) {
    return ProductOptionGroup(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      name: json['name'] as String,
      isMandatory: json['is_mandatory'] as bool? ?? false,
      allowMultiple: json['allow_multiple'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      options: json['product_options'] != null
          ? (json['product_options'] as List)
                .map((e) => ProductOption.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'name': name,
    'is_mandatory': isMandatory,
    'allow_multiple': allowMultiple,
    'sort_order': sortOrder,
  };
}

class ProductOption {
  final String id;
  final String? productId; // Kept for backwards compatibility
  final String? groupId;
  final String name;
  final double price;
  final bool isDefault;
  final int sortOrder;

  const ProductOption({
    required this.id,
    this.productId,
    this.groupId,
    required this.name,
    required this.price,
    required this.isDefault,
    required this.sortOrder,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    return ProductOption(
      id: json['id'] as String,
      productId: json['product_id'] as String?,
      groupId: json['group_id'] as String?,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      isDefault: json['is_default'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'group_id': groupId,
    'name': name,
    'price': price,
    'is_default': isDefault,
    'sort_order': sortOrder,
  };
}

class CartItem {
  final String id;
  final String cartId;
  final String productId;
  final int quantity;
  final List<Map<String, dynamic>> selectedOptions;
  final double unitPrice;
  final double totalPrice;
  final Product? product;

  const CartItem({
    required this.id,
    required this.cartId,
    required this.productId,
    required this.quantity,
    required this.selectedOptions,
    required this.unitPrice,
    required this.totalPrice,
    this.product,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      cartId: json['cart_id'] as String,
      productId: json['product_id'] as String,
      quantity: json['quantity'] as int,
      selectedOptions:
          (json['selected_options'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
      product: json['products'] != null
          ? Product.fromJson(json['products'] as Map<String, dynamic>)
          : null,
    );
  }
}

class AppOrder {
  final String id;
  final String userId;
  final String status;
  final String deliveryType;
  final Map<String, dynamic>? address;
  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double total;
  final String? couponCode;
  final String? riderId;
  final String paymentStatus;
  final String? notes;
  final DateTime createdAt;
  final List<OrderItem>? items;
  final Profile? rider;

  const AppOrder({
    required this.id,
    required this.userId,
    required this.status,
    required this.deliveryType,
    this.address,
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    required this.total,
    this.couponCode,
    this.riderId,
    required this.paymentStatus,
    this.notes,
    required this.createdAt,
    this.items,
    this.rider,
  });

  factory AppOrder.fromJson(Map<String, dynamic> json) {
    return AppOrder(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String,
      deliveryType: json['delivery_type'] as String? ?? 'delivery',
      address: json['address'] as Map<String, dynamic>?,
      subtotal: (json['subtotal'] as num).toDouble(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num).toDouble(),
      couponCode: json['coupon_code'] as String?,
      riderId: json['rider_id'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      items: json['order_items'] != null
          ? (json['order_items'] as List)
                .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
                .toList()
          : null,
      rider: json['rider'] != null
          ? Profile.fromJson(json['rider'] as Map<String, dynamic>)
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'preparing':
        return 'Preparing';
      case 'on_the_way':
        return 'On the Way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  int get statusIndex {
    const steps = [
      'pending',
      'accepted',
      'preparing',
      'on_the_way',
      'delivered',
    ];
    return steps.indexOf(status);
  }
}

class OrderItem {
  final String id;
  final String orderId;
  final String? productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final List<Map<String, dynamic>> selectedOptions;

  const OrderItem({
    required this.id,
    required this.orderId,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.selectedOptions,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String,
      quantity: json['quantity'] as int,
      unitPrice: (json['unit_price'] as num).toDouble(),
      totalPrice: (json['total_price'] as num).toDouble(),
      selectedOptions:
          (json['selected_options'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
    );
  }
}

class UserAddress {
  final String id;
  final String userId;
  final String label;
  final String fullName;
  final String phone;
  final String city;
  final String area;
  final String house;
  final String street;
  final String? block;
  final bool isDefault;

  const UserAddress({
    required this.id,
    required this.userId,
    required this.label,
    required this.fullName,
    required this.phone,
    required this.city,
    required this.area,
    required this.house,
    required this.street,
    this.block,
    required this.isDefault,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      label: json['label'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String,
      city: json['city'] as String,
      area: json['area'] as String,
      house: json['house'] as String,
      street: json['street'] as String,
      block: json['block'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'label': label,
    'full_name': fullName,
    'phone': phone,
    'city': city,
    'area': area,
    'house': house,
    'street': street,
    'block': block,
    'is_default': isDefault,
  };
}

class Coupon {
  final String id;
  final String code;
  final String discountType;
  final double discountValue;
  final double minOrder;
  final int? maxUses;
  final int usedCount;
  final bool isActive;
  final DateTime? expiresAt;

  const Coupon({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.minOrder,
    this.maxUses,
    required this.usedCount,
    required this.isActive,
    this.expiresAt,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['id'] as String,
      code: json['code'] as String,
      discountType: json['discount_type'] as String,
      discountValue: (json['discount_value'] as num).toDouble(),
      minOrder: (json['min_order'] as num?)?.toDouble() ?? 0,
      maxUses: json['max_uses'] as int?,
      usedCount: json['used_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'discount_type': discountType,
    'discount_value': discountValue,
    'min_order': minOrder,
    'max_uses': maxUses,
    'is_active': isActive,
    'expires_at': expiresAt?.toIso8601String(),
  };
}

class AppBanner {
  final String id;
  final String imageUrl;
  final String? title;
  final String groupName;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;

  const AppBanner({
    required this.id,
    required this.imageUrl,
    this.title,
    this.groupName = 'main_hero_banner',
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
  });

  factory AppBanner.fromJson(Map<String, dynamic> json) {
    return AppBanner(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String,
      title: json['title'] as String?,
      groupName: json['group_name'] as String? ?? 'main_hero_banner',
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'image_url': imageUrl,
    'title': title,
    'group_name': groupName,
    'is_active': isActive,
    'sort_order': sortOrder,
  };
}

class AppSettings {
  final int id;
  final double taxPercentage;
  final double discountPercentage;
  final double deliveryFee;
  final String? openingTime;
  final String? closingTime;
  final bool isShopOpen;
  final bool isAutoTiming;
  final String? storeName;
  final String? shortDescription;
  final String? operatingDays;
  final String? socialMediaUrl; // Kept for backward compatibility if needed
  final String? phone;
  final String? email;
  final String? facebookUrl;
  final String? instagramUrl;
  final String? tiktokUrl;
  final String? youtubeUrl;

  const AppSettings({
    required this.id,
    required this.taxPercentage,
    required this.discountPercentage,
    required this.deliveryFee,
    this.openingTime,
    this.closingTime,
    this.isShopOpen = true,
    this.isAutoTiming = false,
    this.storeName,
    this.shortDescription,
    this.operatingDays,
    this.socialMediaUrl,
    this.phone,
    this.email,
    this.facebookUrl,
    this.instagramUrl,
    this.tiktokUrl,
    this.youtubeUrl,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      id: json['id'] as int,
      taxPercentage: (json['tax_percentage'] as num).toDouble(),
      discountPercentage: (json['discount_percentage'] as num).toDouble(),
      deliveryFee: (json['delivery_fee'] as num).toDouble(),
      openingTime: json['opening_time'] as String?,
      closingTime: json['closing_time'] as String?,
      isShopOpen: json['is_shop_open'] as bool? ?? true,
      isAutoTiming: json['is_auto_timing'] as bool? ?? false,
      storeName: json['store_name'] as String?,
      shortDescription: json['short_description'] as String?,
      operatingDays: json['operating_days'] as String?,
      socialMediaUrl: json['social_media_url'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      facebookUrl: json['facebook_url'] as String?,
      instagramUrl: json['instagram_url'] as String?,
      tiktokUrl: json['tiktok_url'] as String?,
      youtubeUrl: json['youtube_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tax_percentage': taxPercentage,
    'discount_percentage': discountPercentage,
    'delivery_fee': deliveryFee,
    if (openingTime != null) 'opening_time': openingTime,
    if (closingTime != null) 'closing_time': closingTime,
    'is_shop_open': isShopOpen,
    'is_auto_timing': isAutoTiming,
    'store_name': storeName,
    'short_description': shortDescription,
    'operating_days': operatingDays,
    'social_media_url': socialMediaUrl,
  };

  bool get isCurrentlyOpen {
    if (isAutoTiming) {
      if (openingTime != null && closingTime != null) {
        final now = TimeOfDay.now();

        // Parse "HH:mm:ss" into TimeOfDay
        final openParts = openingTime!.split(':');
        final closeParts = closingTime!.split(':');

        if (openParts.length >= 2 && closeParts.length >= 2) {
          final openTime = TimeOfDay(
            hour: int.parse(openParts[0]),
            minute: int.parse(openParts[1]),
          );
          final closeTime = TimeOfDay(
            hour: int.parse(closeParts[0]),
            minute: int.parse(closeParts[1]),
          );

          final nowMinutes = now.hour * 60 + now.minute;
          final openMinutes = openTime.hour * 60 + openTime.minute;
          final closeMinutes = closeTime.hour * 60 + closeTime.minute;

          if (openMinutes < closeMinutes) {
            // Standard day (e.g. 09:00 to 22:00)
            return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
          } else {
            // Crosses midnight (e.g. 20:00 to 02:00)
            return nowMinutes >= openMinutes || nowMinutes <= closeMinutes;
          }
        }
      }

      // If no specific times are set under auto mode, default to open
      return true;
    } else {
      return isShopOpen;
    }
  }
}

class Area {
  final String id;
  final String cityId;
  final String name;
  final double deliveryFee;
  final String? estimatedDeliveryTime;
  final bool isActive;

  const Area({
    required this.id,
    required this.cityId,
    required this.name,
    required this.deliveryFee,
    this.estimatedDeliveryTime,
    required this.isActive,
  });

  factory Area.fromJson(Map<String, dynamic> json) {
    return Area(
      id: json['id'] as String,
      cityId: json['city_id'] as String,
      name: json['name'] as String,
      deliveryFee: (json['delivery_fee'] as num? ?? 0).toDouble(),
      estimatedDeliveryTime: json['estimated_delivery_time'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'city_id': cityId,
    'name': name,
    'delivery_fee': deliveryFee,
    'estimated_delivery_time': estimatedDeliveryTime,
    'is_active': isActive,
  };
}

class AppNotification {
  final String id;
  final String userId;
  final String? orderId;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    this.orderId,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      orderId: json['order_id'] as String?,
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'order_id': orderId,
    'title': title,
    'body': body,
    'is_read': isRead,
    'created_at': createdAt.toIso8601String(),
  };
}
