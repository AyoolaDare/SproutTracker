import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'app/app_router.dart';
import 'app/app_theme.dart';
import 'core/api/api_client.dart';
import 'core/auth/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final uri = Uri.base;
  final isTokenLink = (uri.path == '/reset-password' || uri.path == '/verify-email') &&
      (uri.queryParameters['token'] ?? '').isNotEmpty;
  if (isTokenLink) {
    await const TokenStore().clear();
  }

  // Fire-and-forget: wake Render backend while the user sees the login screen.
  // Render free tier sleeps after 15 min of inactivity; this brings cold-start
  // latency from ~45 s to <1 s by the time the user finishes logging in.
  // ignore: unawaited_futures
  _warmUpBackend();

  runApp(const ProviderScope(child: SproutTrackApp()));
}

Future<void> _warmUpBackend() async {
  try {
    await Dio().get<void>(
      '$apiBaseUrl/api/health',
      options: Options(
        sendTimeout:    const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
  } catch (_) {
    // Intentionally silent — best-effort warm-up only.
  }
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
