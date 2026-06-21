import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/user_account_settings_model.dart';
import 'package:mioamoreapp/models/user_profile_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/providers/block_user_provider.dart';
import 'package:mioamoreapp/providers/subscriptions/is_subscribed_provider.dart';
import 'package:mioamoreapp/providers/user_profile_provider.dart';

final filteredOtherUsersProvider =
    FutureProvider<List<UserProfileModel>>((ref) async {
  List<UserProfileModel> usersList = [];

  final otherUsers = ref.watch(otherUsersProvider);

  otherUsers.whenData((value) {
    usersList.addAll(value);
  });

  final myProfileProvider = ref.watch(userProfileFutureProvider);
  final isPremiumUserRef = ref.watch(isPremiumUserProvider);

  List<UserProfileModel> filteredUserList = [];

  myProfileProvider.whenData((value) {
    if (value != null) {
      final UserAccountSettingsModel mySettings =
          value.userAccountSettingsModel;

      for (var user in usersList) {
        bool willBeShown = false;
        bool isBoth = false;

        final userAge = DateTime.now().difference(user.birthDay).inDays ~/ 365;
        final userLocation = user.userAccountSettingsModel.location;
        final userGender = user.gender;

        double distanceBetweenMeAndUser = Geolocator.distanceBetween(
                mySettings.location.latitude,
                mySettings.location.longitude,
                userLocation.latitude,
                userLocation.longitude) /
            1;

        if (mySettings.interestedIn == null) {
          isBoth = true;
        }

        bool isWorldWide = mySettings.distanceInKm == null;

        bool isDistanceOk = isWorldWide ||
            (mySettings.distanceInKm! >= (distanceBetweenMeAndUser / 1000));

        if (userAge >= mySettings.minimumAge &&
            userAge <= mySettings.maximumAge &&
            isDistanceOk) {
          if (isBoth) {
            willBeShown = true;
          } else {
            if (mySettings.interestedIn == userGender) {
              willBeShown = true;
            } else {
              willBeShown = false;
            }
          }
        }

        if (willBeShown) {
          filteredUserList.add(user);
        }
      }
    }
  });

  bool isPremiumUser = false;
  isPremiumUserRef.whenData((value) {
    isPremiumUser = value;
  });

  if (!isPremiumUser) {
    filteredUserList.removeWhere((element) {
      return element.userAccountSettingsModel.showOnlyToPremiumUsers ?? false;
    });
  }

  return filteredUserList;
});

final closestUsersProvider = Provider<List<ClosestUser>>((ref) {
  List<UserProfileModel> usersList = [];

  final otherUsers = ref.watch(otherUsersProvider);

  otherUsers.whenData((value) {
    usersList.addAll(value);
  });

  final myProfileProvider = ref.watch(userProfileFutureProvider);

  List<ClosestUser> closestUsers = [];

  myProfileProvider.whenData((value) {
    if (value != null) {
      final UserAccountSettingsModel mySettings =
          value.userAccountSettingsModel;

      for (var user in usersList) {
        final userLocation = user.userAccountSettingsModel.location;

        double distanceBetweenMeAndUser = Geolocator.distanceBetween(
                mySettings.location.latitude,
                mySettings.location.longitude,
                userLocation.latitude,
                userLocation.longitude) /
            1;

        closestUsers
            .add(ClosestUser(user: user, distance: distanceBetweenMeAndUser));
      }
    }
  });

  return closestUsers;
});

class ClosestUser {
  UserProfileModel user;
  double distance;
  ClosestUser({
    required this.user,
    required this.distance,
  });
}

final otherUsersProvider = FutureProvider<List<UserProfileModel>>((ref) async {
  final allOtherUsers =
      await getAllOtherUsers(ref.watch(currentUserStateProvider)!.uid);

  final List<String> blockedUsersIds = [];
  final usersIblocked =
      await getBlockUsers(ref.watch(currentUserStateProvider)!.uid);
  for (var user in usersIblocked) {
    blockedUsersIds.add(user.blockedUserId);
  }
  final usersWhoBlockedMe =
      await getUsersWhoBlockedMe(ref.watch(currentUserStateProvider)!.uid);
  for (var user in usersWhoBlockedMe) {
    blockedUsersIds.add(user.blockedByUserId);
  }

  final filteredUsers = allOtherUsers.where((user) {
    return !blockedUsersIds.contains(user.userId);
  }).toList();

  return filteredUsers;
});

final otherUsersWithoutBlockedProvider =
    FutureProvider<List<UserProfileModel>>((ref) async {
  return await getAllOtherUsers(ref.watch(currentUserStateProvider)!.uid);
});

Future<List<UserProfileModel>> getAllOtherUsers(String currentUserId) async {
  final userCollection = FirebaseFirestore.instance
      .collection(FirebaseConstants.userProfileCollection);

  final otherUsers =
      await userCollection.where("userId", isNotEqualTo: currentUserId).get();

  final allOtherUsers = otherUsers.docs.map((doc) {
    return UserProfileModel.fromMap(doc.data());
  }).toList();

  if (!AppConfig.userProfileShowWithoutImages) {
    debugPrint("Removing users without profile picture");
    allOtherUsers.removeWhere((element) {
      bool isNotProfilePicture =
          element.profilePicture == null || element.profilePicture!.isEmpty;
      bool isOtherPicturesEmpty = element.mediaFiles.isEmpty;

      debugPrint("isNotProfilePicture: $isNotProfilePicture");
      debugPrint("isOtherOicturesEmpty: $isOtherPicturesEmpty");

      return isNotProfilePicture || isOtherPicturesEmpty;
    });
  }

  debugPrint("allOtherUsers: ${allOtherUsers.length}");

  return allOtherUsers;
}
