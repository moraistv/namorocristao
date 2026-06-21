import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/account_delete_request_model.dart';

class AccountDeleteProvider {
  static Future<AccountDeleteRequestModel?> getAccountDeleteRequest(
      String userId) async {
    final collection = FirebaseFirestore.instance
        .collection(FirebaseConstants.accountDeleteRequestCollection);

    final doc = await collection.doc(userId).get();
    if (doc.exists) {
      return AccountDeleteRequestModel.fromMap(doc.data()!);
    } else {
      return null;
    }
  }

  static Future<bool> requestAccountDelete(
      AccountDeleteRequestModel model) async {
    final collection = FirebaseFirestore.instance
        .collection(FirebaseConstants.accountDeleteRequestCollection);

    try {
      await collection.doc(model.userId).set(model.toMap());
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> cancelAccountDeleteRequest(String userId) async {
    final collection = FirebaseFirestore.instance
        .collection(FirebaseConstants.accountDeleteRequestCollection);

    try {
      await collection.doc(userId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }
}
