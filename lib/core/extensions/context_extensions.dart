import 'package:flutter/material.dart';

extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  bool get isMobile => screenSize.width < 600;
  bool get isTablet => screenSize.width >= 600 && screenSize.width < 1200;
  bool get isDesktop => screenSize.width >= 1200;

  void showOraSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).clearSnackBars();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }
}
