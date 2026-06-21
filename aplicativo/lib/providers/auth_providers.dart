import 'dart:developer';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mioamoreapp/providers/account_delete_request_provider.dart';
import 'package:mioamoreapp/providers/device_token_provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges().map((user) {
    ref.read(currentUserStateProvider.notifier).state = user;

    if (user != null) {
      AccountDeleteProvider.getAccountDeleteRequest(user.uid).then((value) {
        if (value != null) {
          AccountDeleteProvider.cancelAccountDeleteRequest(user.uid);
        }
      });
    }

    return user;
  });
});

final currentUserStateProvider = StateProvider<User?>((ref) {
  return null;
});

final authProvider = Provider<AuthProvider>((ref) {
  return AuthProvider();
});

class AuthProvider {
  final _deviceTokenProvider = DeviceTokenProvider();

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      final GoogleSignInAuthentication? googleAuth =
          await googleUser?.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      log('Google Credential: $credential');

      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);

      await _deviceTokenProvider.saveDeviceToken(userCred.user!.uid);
      return userCred.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        EasyLoading.showError(
            'An account already exists with the same email address but different sign-in credentials. Sign in using a provider associated with this email address.');
      }
    } catch (e) {
      EasyLoading.showError('Something went wrong.');
    }
    return null;
  }

  Future<User?> signInWithPhoneNumber(
      String smsCode, String verificationId) async {
    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      await _deviceTokenProvider.saveDeviceToken(userCred.user!.uid);
      return userCred.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        EasyLoading.showError('Invalid code.');
      }
    } catch (e) {
      EasyLoading.showError('Something went wrong.');
    }
    return null;
  }

  Future<void> signOut() async {
    Purchases.logOut();
    await _deviceTokenProvider.deleteDeviceToken();
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }
}
