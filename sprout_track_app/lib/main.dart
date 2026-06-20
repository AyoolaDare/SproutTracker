import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'app/app_router.dart';
import 'app/app_theme.dart';
import 'core/auth/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final uri = Uri.base;
  if (uri.path == '/reset-password' && (uri.queryParameters['token'] ?? '').isNotEmpty) {
    await const TokenStore().clear();
  }

  runApp(const ProviderScope(child: SproutTrackApp()));
}

class SproutTrackApp extends ConsumerWidget {
  const SproutTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Sprout Track',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) {
        return ResponsiveBreakpoints.builder(
          child: child!,
          breakpoints: const [
            Breakpoint(start: 0, end: 599, name: MOBILE),
            Breakpoint(start: 600, end: 1023, name: TABLET),
            Breakpoint(start: 1024, end: 1439, name: DESKTOP),
            Breakpoint(start: 1440, end: double.infinity, name: 'XL'),
          ],
        );
      },
    );
  }
}
