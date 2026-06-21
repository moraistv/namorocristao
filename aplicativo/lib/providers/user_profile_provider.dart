import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';

final userProfileFutureProvider =
    FutureProvider<UserProfileModel?>((ref) async {
  final userCollection = FirebaseFirestore.instance
      .collection(FirebaseConstants.userProfileCollection);

  return userCollection
      .where("userId", isEqualTo: ref.watch(currentUserStateProvider)!.uid)
      .get()
      .then((data) {
    if (data.docs.isEmpty) {
      return null;
    } else {
      return UserProfileModel.fromMap(data.docs.first.data());
    }
  });
});

final userProfileNotifier = Provider<UserProfileNotifier>((ref) {
  return UserProfileNotifier();
});

class UserProfileNotifier {
  final _userCollection = FirebaseFirestore.instance
      .collection(FirebaseConstants.userProfileCollection);

  Future<bool> createUserProfile(UserProfileModel userProfileModel) async {
    try {
      UserProfileModel? newUserProfile;

      if (userProfileModel.profilePicture != null) {
        if (Uri.parse(userProfileModel.profilePicture!).isAbsolute) {
          newUserProfile = userProfileModel;
        } else {
          final profileURL = await _uploadProfilePicture(
              userProfileModel.profilePicture!, userProfileModel.userId);
          newUserProfile =
              userProfileModel.copyWith(profilePicture: profileURL);
        }
      } else {
        newUserProfile = userProfileModel;
      }

      await _userCollection.doc(newUserProfile.id).set(newUserProfile.toMap());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateUserProfile(UserProfileModel userProfileModel) async {
    try {
      UserProfileModel newUserProfile = userProfileModel;

      if (userProfileModel.profilePicture != null) {
        if (Uri.parse(userProfileModel.profilePicture!).isAbsolute) {
          newUserProfile = userProfileModel;
        } else if (userProfileModel.profilePicture == "") {
          newUserProfile = userProfileModel.copyWith(profilePicture: "");
        } else {
          final profileURL = await _uploadProfilePicture(
              userProfileModel.profilePicture!, userProfileModel.userId);
          newUserProfile =
              userProfileModel.copyWith(profilePicture: profileURL);
        }
      }

      List<String> mediaURLs = [];
      for (var media in userProfileModel.mediaFiles) {
        if (Uri.parse(media).isAbsolute) {
          mediaURLs.add(media);
        } else if (media == "") {
          debugPrint("Media is empty");
        } else {
          final mediaURL =
              await _uploadUserMediaFiles(media, userProfileModel.userId);
          if (mediaURL != null) {
            mediaURLs.add(mediaURL);
          }
        }
      }

      final anotherNewUserProfile =
          newUserProfile.copyWith(mediaFiles: mediaURLs);

      await _userCollection
          .doc(anotherNewUserProfile.id)
          .update(anotherNewUserProfile.toMap());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> _uploadProfilePicture(String imagePath, String userId) async {
    final storageRef = FirebaseStorage.instance.ref();

    final imageRef = storageRef.child("user_profile_pictures/$userId");
    final uploadTask = imageRef.putFile(File(imagePath));

    String? imageUrl;
    await uploadTask.whenComplete(() async {
      imageUrl = await imageRef.getDownloadURL();
    });
    return imageUrl;
  }

  Future<String?> _uploadUserMediaFiles(String path, String userId) async {
    final storageRef = FirebaseStorage.instance.ref();

    final imageRef =
        storageRef.child("user_media_files/$userId/${path.split("/").last}");
    final uploadTask = imageRef.putFile(File(path));

    String? imageUrl;
    await uploadTask.whenComplete(() async {
      imageUrl = await imageRef.getDownloadURL();
    });
    return imageUrl;
  }

  //Update Online Status
  Future<void> updateOnlineStatus({
    required bool isOnline,
    required String userId,
  }) async {
    await _userCollection.doc(userId).update({"isOnline": isOnline});
  }
}

final isUserAddedProvider = FutureProvider<bool>((ref) async {
  final userCollection = FirebaseFirestore.instance
      .collection(FirebaseConstants.userProfileCollection);
  final userId = ref.watch(currentUserStateProvider)!.uid;
  bool isUserAdded = false;
  await userCollection.where("userId", isEqualTo: userId).get().then((event) {
    if (event.docs.isNotEmpty) {
      isUserAdded = true;
    }
  });
  return isUserAdded;
});

//Show Guided Tour
Future<void> setShowGuidedTour(bool value) async {
  final box = Hive.box(HiveConstants.hiveBox);
  await box.put(HiveConstants.guidedTour, value);
}
