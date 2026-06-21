import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/banned_user_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';

final isMeBannedProvider = FutureProvider<BannedUserModel?>((ref) async {
  final currentUserRef = ref.watch(currentUserStateProvider);

  if (currentUserRef == null) {
    return null;
  } else {
    final bannedUserCollection = FirebaseFirestore.instance
        .collection(FirebaseConstants.bannedUsersCollection);

    try {
      final bannedUserDoc =
          await bannedUserCollection.doc(currentUserRef.uid).get();

      if (bannedUserDoc.exists) {
        final bannedUser = BannedUserModel.fromMap(bannedUserDoc.data()!);
        return bannedUser;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }
});
