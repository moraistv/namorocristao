import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/app_settings_model.dart';

final appSettingsProvider = FutureProvider<AppSettingsModel?>((ref) async {
  final collection = FirebaseFirestore.instance
      .collection(FirebaseConstants.appSettingsCollection);
  final snapshot = await collection.get();
  if (snapshot.docs.isEmpty) {
    return null;
  }
  final doc = snapshot.docs.first;
  return AppSettingsModel.fromMap(doc.data());
});
