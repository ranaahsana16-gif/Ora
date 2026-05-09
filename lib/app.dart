import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ora/core/theme/app_theme.dart';
import 'package:ora/core/router/app_router.dart';

class OraApp extends ConsumerWidget {
  const OraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Ora',
      debugShowCheckedModeBanner: false,
      theme: OraTheme.lightTheme,
      routerConfig: router,
    );
  }
}
