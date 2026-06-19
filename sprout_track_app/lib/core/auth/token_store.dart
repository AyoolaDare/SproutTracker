import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return const TokenStore();
});

class TokenStore {
  const TokenStore();

  static const _storage = FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'sprout_track_secure',
      publicKey: 'sprout_track_tokens',
    ),
  );

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<String?> readAccessToken() {
    return _storage.read(key: 'access_token');
  }

  Future<String?> readRefreshToken() {
    return _storage.read(key: 'refresh_token');
  }

  Future<void> clear() {
    return _storage.deleteAll();
  }
}
