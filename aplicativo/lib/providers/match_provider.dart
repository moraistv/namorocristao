import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/helpers/encrypt_helper.dart';
import 'package:mioamoreapp/models/chat_item_model.dart';
import 'package:mioamoreapp/models/match_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/providers/interaction_provider.dart';

final matchStreamProvider = StreamProvider<List<MatchModel>>((ref) {
  final matchCollection =
      FirebaseFirestore.instance.collection(FirebaseConstants.matchCollection);

  return matchCollection
      .where("userIds", arrayContains: ref.watch(currentUserStateProvider)!.uid)
      .snapshots()
      .map((event) {
    return event.docs.map((doc) {
      return MatchModel.fromMap(doc.data());
    }).toList();
  });
});

final _matchCollection =
    FirebaseFirestore.instance.collection(FirebaseConstants.matchCollection);

Future<bool> createConversation(MatchModel match) async {
  try {
    await _matchCollection.doc(match.id).set(match.toMap());

    final chatCollection = FirebaseFirestore.instance
        .collection(FirebaseConstants.matchCollection)
        .doc(match.id)
        .collection(FirebaseConstants.chatCollection);
    final currentTime = DateTime.now();
    final ChatItemModel chatItemModel = ChatItemModel(
      id: currentTime.millisecondsSinceEpoch.toString(),
      message: encryptText("Say Hi!"),
      matchId: match.id,
      createdAt: currentTime,
      isRead: true,
    );
    await chatCollection
        .doc(currentTime.millisecondsSinceEpoch.toString())
        .set(chatItemModel.toMap());

    return true;
  } catch (e) {
    return false;
  }
}

Future<bool> unMatchUser(String matchId, String userId1, String userId2) async {
  final interactionId1 = userId1 + userId2;
  final interactionId2 = userId2 + userId1;
  try {
    await _matchCollection.doc(matchId).delete();
    await deleteInteraction(interactionId1);
    await deleteInteraction(interactionId2);

    return true;
  } catch (e) {
    return false;
  }
}
