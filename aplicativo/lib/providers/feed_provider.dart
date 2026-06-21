import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/feed_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/providers/match_provider.dart';
import 'package:mioamoreapp/providers/other_users_provider.dart';

final getFeedsProvider = FutureProvider<List<FeedModel>>((ref) async {
  final feedsCollection =
      FirebaseFirestore.instance.collection(FirebaseConstants.feedsCollection);
  final currentUserId = ref.watch(currentUserStateProvider)!.uid;
  final machingProvider = ref.watch(matchStreamProvider);
  final otherUsersRef = ref.watch(otherUsersProvider);

  final List<String> feedsUserIds = [currentUserId];

  machingProvider.whenData((matches) {
    matches.removeWhere((element) => element.isMatched == false);
    otherUsersRef.whenData((otherUsers) {
      final List<String> matchUserIds = [];
      for (var match in matches) {
        matchUserIds
            .add(match.userIds.firstWhere((userId) => userId != currentUserId));
      }

      for (var matchUserId in matchUserIds) {
        for (var otherUser in otherUsers) {
          if (matchUserId == otherUser.id) {
            feedsUserIds.add(otherUser.id);
          }
        }
      }
    });
  });

  final snapshot =
      await feedsCollection.where('userId', whereIn: feedsUserIds).get();

  final List<FeedModel> feeds = [];
  for (final doc in snapshot.docs) {
    feeds.add(FeedModel.fromMap(doc.data()));
  }

  feeds.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return feeds;
});

final _feedsCollection =
    FirebaseFirestore.instance.collection(FirebaseConstants.feedsCollection);

Future<bool> addFeed(FeedModel feedModel) async {
  try {
    await _feedsCollection.doc(feedModel.id).set(feedModel.toMap());

    return true;
  } catch (e) {
    return false;
  }
}

Future<bool> updateFeed(FeedModel feedModel) async {
  try {
    await _feedsCollection.doc(feedModel.id).update(feedModel.toMap());
    return true;
  } catch (e) {
    return false;
  }
}

Future<bool> deleteFeed(String id) async {
  try {
    await _feedsCollection.doc(id).delete();
    return true;
  } catch (e) {
    return false;
  }
}

Future<List<String>> uploadFeedImages(
    {required List<File> files, required String userId}) async {
  try {
    final List<String> urls = [];

    for (var element in files) {
      final currentTime = DateTime.now();
      final ref = FirebaseStorage.instance
          .ref()
          .child(FirebaseConstants.feedsCollection)
          .child(userId)
          .child(currentTime.millisecondsSinceEpoch.toString() +
              userId +
              element.path.split('/').last);

      final uploadTask = ref.putFile(element);
      String? url;
      await uploadTask.whenComplete(() async {
        url = await ref.getDownloadURL();
      });

      if (url != null) {
        urls.add(url!);
      }
    }

    return urls;
  } catch (e) {
    return [];
  }
}
