import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/models/report_model.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';

final _reportsCollection =
    FirebaseFirestore.instance.collection(FirebaseConstants.reportsCollection);

Future<bool> reportUser(ReportModel reportModel) async {
  try {
    List<File> images = [];
    for (var image in reportModel.images) {
      images.add(File(image));
    }

    await _uploadReportImages(
            files: images, userId: reportModel.reportingUserId)
        .then((value) {
      final newReportModel = reportModel.copyWith(images: value);
      _reportsCollection.doc(newReportModel.id).set(newReportModel.toMap());
    });

    return true;
  } catch (e) {
    return false;
  }
}

Future<List<String>> _uploadReportImages(
    {required List<File> files, required String userId}) async {
  try {
    final List<String> urls = [];

    for (var element in files) {
      final currentTime = DateTime.now();
      final ref = FirebaseStorage.instance
          .ref()
          .child(FirebaseConstants.reportsCollection)
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

final getMyReportsProvider = FutureProvider<List<ReportModel>>((ref) async {
  final userId = ref.watch(currentUserStateProvider)!.uid;
  final reports = await _reportsCollection
      .where('reportedByUserId', isEqualTo: userId)
      .get();
  final List<ReportModel> reportModels = [];
  for (var element in reports.docs) {
    reportModels.add(ReportModel.fromMap(element.data()));
  }
  return reportModels;
});
