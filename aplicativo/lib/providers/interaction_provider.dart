import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/user_interaction_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';

final interactionFutureProvider =
    FutureProvider<List<UserInteractionModel>>((ref) async {
  final interactionCollection = FirebaseFirestore.instance
      .collection(FirebaseConstants.userInteractionCollection);

  return await interactionCollection
      .where("userId", isEqualTo: ref.watch(currentUserStateProvider)!.uid)
      .get()
      .then((snapshot) {
    final List<UserInteractionModel> interactionList = [];
    for (var doc in snapshot.docs) {
      interactionList.add(UserInteractionModel.fromMap(doc.data()));
    }
    return interactionList;
  });
});

final _interactionCollection = FirebaseFirestore.instance
    .collection(FirebaseConstants.userInteractionCollection);

Future<bool> createInteraction(UserInteractionModel interaction) async {
  try {
    await _interactionCollection.doc(interaction.id).set(interaction.toMap());
    return true;
  } catch (e) {
    return false;
  }
}

Future<bool> deleteInteraction(String interactionId) async {
  try {
    await _interactionCollection.doc(interactionId).delete();
    return true;
  } catch (e) {
    return false;
  }
}

Future<UserInteractionModel?> getExistingInteraction(
    String otherUserId, String currentUserId) async {
  final interactionCollection = FirebaseFirestore.instance
      .collection(FirebaseConstants.userInteractionCollection);

  return await interactionCollection
      .where("id", isEqualTo: otherUserId + currentUserId)
      .get()
      .then((snapshot) {
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return UserInteractionModel.fromMap(snapshot.docs.first.data());
  });
}
