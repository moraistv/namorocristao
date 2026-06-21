import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/device_model.dart';

class DeviceTokenProvider {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _deviceTokenCollection = FirebaseConstants.deviceTokensCollection;

  Future<String?> _getDeviceToken() async {
    String? deviceToken = await _firebaseMessaging.getToken();
    return deviceToken;
  }

  Future<void> saveDeviceToken(String currentUserId) async {
    final token = await _getDeviceToken();
    if (token != null) {
      final DeviceTokenModel deviceToken = DeviceTokenModel(
        deviceToken: token,
        userId: currentUserId,
      );
      await FirebaseFirestore.instance
          .collection(_deviceTokenCollection)
          .doc(deviceToken.deviceToken)
          .set(deviceToken.toMap());
    }
  }

  Future<void> deleteDeviceToken() async {
    final token = await _getDeviceToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection(_deviceTokenCollection)
          .doc(token)
          .delete();
    }
  }
}
