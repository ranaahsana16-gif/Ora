import 'package:flutter/material.dart';
import 'package:ora/data/models/models.dart';
import 'package:ora/features/menu/product_popup_web.dart';
import 'package:ora/features/menu/product_popup_mobile.dart';

class ProductPopup extends StatelessWidget {
  final Product product;
  final ScrollController? scrollController;

  const ProductPopup({super.key, required this.product, this.scrollController});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth <= 600;

    if (isMobile) {
      return ProductPopupMobile(
        product: product,
        scrollController: scrollController,
      );
    } else {
      return ProductPopupWeb(product: product);
    }
  }
}
