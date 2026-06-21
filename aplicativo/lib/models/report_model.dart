import 'dart:convert';
import 'package:collection/collection.dart';

class ReportModel {
  String id;
  String reportingUserId;
  String reportedByUserId;
  String reason;
  DateTime createdAt;
  List<String> images;
  ReportModel({
    required this.id,
    required this.reportingUserId,
    required this.reportedByUserId,
    required this.reason,
    required this.createdAt,
    required this.images,
  });

  ReportModel copyWith({
    String? id,
    String? reportingUserId,
    String? reportedByUserId,
    String? reason,
    DateTime? createdAt,
    List<String>? images,
  }) {
    return ReportModel(
      id: id ?? this.id,
      reportingUserId: reportingUserId ?? this.reportingUserId,
      reportedByUserId: reportedByUserId ?? this.reportedByUserId,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      images: images ?? this.images,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'reportingUserId': reportingUserId,
      'reportedByUserId': reportedByUserId,
      'reason': reason,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'images': images,
    };
  }

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
        id: map['id'] as String,
        reportingUserId: map['reportingUserId'] as String,
        reportedByUserId: map['reportedByUserId'] as String,
        reason: map['reason'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        images: List<String>.from((map['images'] as List<String>)));
  }

  String toJson() => json.encode(toMap());

  factory ReportModel.fromJson(String source) =>
      ReportModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'ReportModel(id: $id, reportingUserId: $reportingUserId, reportedByUserId: $reportedByUserId, reason: $reason, createdAt: $createdAt, images: $images)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other is ReportModel &&
        other.id == id &&
        other.reportingUserId == reportingUserId &&
        other.reportedByUserId == reportedByUserId &&
        other.reason == reason &&
        other.createdAt == createdAt &&
        listEquals(other.images, images);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        reportingUserId.hashCode ^
        reportedByUserId.hashCode ^
        reason.hashCode ^
        createdAt.hashCode ^
        images.hashCode;
  }
}
