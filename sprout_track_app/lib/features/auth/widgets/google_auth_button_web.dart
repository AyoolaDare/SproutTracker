import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:google_sign_in_web/web_only.dart';

import '../../../core/auth/auth_provider.dart';

class GoogleAuthButton extends ConsumerStatefulWidget {
  const GoogleAuthButton({
    super.key,
    required this.label,
    this.businessName,
    this.businessType = 'RETAIL',
  });

  final String label;
  final String? businessName;
  final String businessType;

  @override
  ConsumerState<GoogleAuthButton> createState() => _GoogleAuthButtonState();
}

class _GoogleAuthButtonState extends ConsumerState<GoogleAuthButton> {
  final GoogleSignInPlatform _platform = GoogleSignInPlatform.instance;
  StreamSubscription<GoogleSignInUserData?>? _subscription;
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeGoogle();
  }

  Future<void> _initializeGoogle() async {
    if (googleClientId.isEmpty) {
      ref
          .read(authProvider.notifier)
          .setGoogleSignInError('Google sign-in is not configured yet.');
      return;
    }

    await _platform.initWithParams(
      const SignInInitParameters(
        clientId: googleClientId,
        scopes: ['email', 'profile'],
      ),
    );

    _subscription ??= _platform.userDataEvents?.listen((userData) {
      final idToken = userData?.idToken;
      if (idToken == null || idToken.isEmpty) {
        ref.read(authProvider.notifier).setGoogleSignInError(
              'Google did not return an ID token. Use the Google button again.',
            );
        return;
      }
      ref.read(authProvider.notifier).loginWithGoogleIdToken(
            idToken,
            businessName: widget.businessName,
            businessType: widget.businessType,
          );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const OutlinedButton(
              onPressed: null,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          if (snapshot.hasError || googleClientId.isEmpty) {
            return OutlinedButton.icon(
              onPressed: null,
              icon: const Text(
                'G',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              label: Text(widget.label),
            );
          }
          return renderButton(
            configuration: GSIButtonConfiguration(
              size: GSIButtonSize.large,
              theme: GSIButtonTheme.outline,
              text: GSIButtonText.continueWith,
              shape: GSIButtonShape.pill,
              logoAlignment: GSIButtonLogoAlignment.left,
            ),
          );
        },
      ),
    );
  }
}
