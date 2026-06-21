import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/block_user_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';

final blockUsersCollection = FirebaseFirestore.instance
    .collection(FirebaseConstants.blockedUsersCollection);

Future<List<BlockUserModel>> getBlockUsers(String currentUserId) async {
  final blockUsers = await blockUsersCollection
      .where("blockedByUserId", isEqualTo: currentUserId)
      .get();
  final blockUsersList = blockUsers.docs.map((doc) {
    return BlockUserModel.fromMap(doc.data());
  }).toList();

  return blockUsersList;
}

Future<List<BlockUserModel>> getUsersWhoBlockedMe(String currentUserId) async {
  final blockUsers = await blockUsersCollection
      .where("blockedUserId", isEqualTo: currentUserId)
      .get();
  final blockUsersList = blockUsers.docs.map((doc) {
    return BlockUserModel.fromMap(doc.data());
  }).toList();

  return blockUsersList;
}

final blockedUsersFutureProvider =
    FutureProvider<List<BlockUserModel>>((ref) async {
  return await getBlockUsers(ref.watch(currentUserStateProvider)!.uid);
});

Future<bool> blockUser(String userId, String currentUserId) async {
  final id = userId + currentUserId;
  try {
    await blockUsersCollection.doc(id).set(
          BlockUserModel(
            id: id,
            blockedByUserId: currentUserId,
            blockedUserId: userId,
            createdAt: DateTime.now(),
          ).toMap(),
        );
    return true;
  } catch (e) {
    return false;
  }
}

Future<bool> unblockUser(String blockId) async {
  try {
    await blockUsersCollection.doc(blockId).delete();
    return true;
  } catch (e) {
    return false;
  }
}
