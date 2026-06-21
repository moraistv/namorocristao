import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/notification_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';

final notificationsStreamProvider =
    StreamProvider<List<NotificationModel>>((ref) {
  const notificationCollection = FirebaseConstants.notificationsCollection;

  final currentUserId = ref.watch(currentUserStateProvider)!.uid;

  return FirebaseFirestore.instance
      .collection(notificationCollection)
      .where("receiverId", isEqualTo: currentUserId)
      .orderBy("createdAt", descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => NotificationModel.fromMap(doc.data()))
        .toList();
  });
});

const _notificationCollection = FirebaseConstants.notificationsCollection;

Future<bool> addNotification(NotificationModel notificationModel) async {
  try {
    await FirebaseFirestore.instance
        .collection(_notificationCollection)
        .doc(notificationModel.id)
        .set(notificationModel.toMap());

    return true;
  } catch (e) {
    return false;
  }
}

//Update notification
Future<bool> updateNotification(NotificationModel notificationModel) async {
  try {
    await FirebaseFirestore.instance
        .collection(_notificationCollection)
        .doc(notificationModel.id)
        .update(notificationModel.toMap());

    return true;
  } catch (e) {
    return false;
  }
}

// Mark All As Read Notification
Future<bool> markAllAsRead(String currentUserId) async {
  try {
    await FirebaseFirestore.instance
        .collection(_notificationCollection)
        .where("receiverId", isEqualTo: currentUserId)
        .get()
        .then((snapshot) async {
      for (var doc in snapshot.docs) {
        final notificationModel = NotificationModel.fromMap(doc.data());
        if (notificationModel.isRead == false) {
          notificationModel.isRead = true;
          await updateNotification(notificationModel);
        }
      }
    });

    return true;
  } catch (e) {
    return false;
  }
}

Future<bool> deleteNotification(String notificationId) async {
  try {
    await FirebaseFirestore.instance
        .collection(_notificationCollection)
        .doc(notificationId)
        .delete();

    return true;
  } catch (e) {
    return false;
  }
}
