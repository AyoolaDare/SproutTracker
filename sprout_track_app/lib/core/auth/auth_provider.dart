import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'token_store.dart';

// ── Auth status ────────────────────────────────────────────────────────────────

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.error,
    this.isDemo = false,
  });

  final AuthStatus status;
  final String?    error;
  final bool       isDemo;

  bool get isLoading         => status == AuthStatus.loading;
  bool get isAuthenticated   => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
}

// ── Provider ───────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final tokenStore = ref.watch(tokenStoreProvider);
  final apiClient  = ref.watch(apiClientProvider);
  return AuthNotifier(tokenStore, apiClient);
});

// ── Notifier ───────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._tokenStore, this._apiClient)
      : super(const AuthState(status: AuthStatus.loading)) {
    // Register the forced-logout callback before any async work
    _apiClient.onUnauthenticated = _handleForcedLogout;
    _initialize();
  }

  final TokenStore _tokenStore;
  final ApiClient  _apiClient;

  // ── Startup token check ────────────────────────────────────────────────────

  Future<void> _initialize() async {
    try {
      final token = await _tokenStore.readAccessToken();

      if (token == null || token.isEmpty) {
        if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      // Demo sessions persist across refreshes without hitting the server
      if (token == 'demo') {
        if (mounted) {
          state = const AuthState(status: AuthStatus.authenticated, isDemo: true);
        }
        return;
      }

      // Validate token against backend
      await _apiClient.get('/api/auth/me');
      if (mounted) state = const AuthState(status: AuthStatus.authenticated);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _tryRefresh();
      } else {
        // Network unavailable — allow offline use with cached token
        final token = await _tokenStore.readAccessToken();
        if (mounted) {
          state = AuthState(
            status: AuthStatus.authenticated,
            isDemo: token == 'demo',
          );
        }
      }
    } catch (_) {
      if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _tryRefresh() async {
    try {
      final refresh = await _tokenStore.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        await _tokenStore.clear();
        if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      final res = await _apiClient.post(
        '/api/auth/refresh',
        data: {'refresh_token': refresh},
      );
      final data = res.data as Map<String, dynamic>;
      await _tokenStore.saveTokens(
        accessToken:  data['access_token']  as String,
        refreshToken: data['refresh_token'] as String? ?? '',
      );
      if (mounted) state = const AuthState(status: AuthStatus.authenticated);
    } catch (_) {
      await _tokenStore.clear();
      if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final res = await _apiClient.post(
        '/api/auth/login',
        data: {
          'email':    email.trim().toLowerCase(),
          'password': password,
        },
      );
      final data = res.data as Map<String, dynamic>;
      await _tokenStore.saveTokens(
        accessToken:  data['access_token']  as String,
        refreshToken: data['refresh_token'] as String? ?? '',
      );
      if (mounted) state = const AuthState(status: AuthStatus.authenticated);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      var message = (code == 401 || code == 400)
          ? 'Invalid email or password.'
          : code == 429
              ? 'Too many attempts. Please wait and try again.'
              : 'Sign in failed. Check your connection and try again.';
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data as Map<String, dynamic>)['detail']
          : null;
      if (code == 403 && detail is Map<String, dynamic>) {
        if (detail['code'] == 'PASSWORD_SETUP_REQUIRED') {
          message = 'This migrated account needs a new password. Use your setup link to activate it.';
        }
      }
      if (mounted) {
        state = AuthState(status: AuthStatus.unauthenticated, error: message);
      }
    } catch (_) {
      if (mounted) {
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          error: 'Something went wrong. Please try again.',
        );
      }
    }
  }

  // ── Demo login ─────────────────────────────────────────────────────────────

  Future<void> loginDemo() async {
    // Store the demo marker so it persists across page refreshes
    await _tokenStore.saveTokens(accessToken: 'demo', refreshToken: '');
    if (mounted) {
      state = const AuthState(status: AuthStatus.authenticated, isDemo: true);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      if (!state.isDemo) {
        await _apiClient.post('/api/auth/logout');
      }
    } catch (_) { /* best-effort server-side session invalidation */ }
    await _tokenStore.clear();
    if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // ── Forced logout on 401 ───────────────────────────────────────────────────

  void _handleForcedLogout() {
    _tokenStore.clear();
    if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// ── GoRouter ChangeNotifier bridge ────────────────────────────────────────────

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
