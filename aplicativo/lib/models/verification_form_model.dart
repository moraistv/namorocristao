import 'dart:convert';

class VerificationFormModel {
  String id;
  String userId;
  String photoIdFrontViewUrl;
  String photoIdBackViewUrl;
  String selfieUrl;
  DateTime createdAt;
  DateTime updatedAt;
  bool isPending;
  bool isApproved;
  String? statusMessage;
  VerificationFormModel({
    required this.id,
    required this.userId,
    required this.photoIdFrontViewUrl,
    required this.photoIdBackViewUrl,
    required this.selfieUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.isPending,
    required this.isApproved,
    this.statusMessage,
  });

  VerificationFormModel copyWith({
    String? id,
    String? userId,
    String? photoIdFrontViewUrl,
    String? photoIdBackViewUrl,
    String? selfieUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPending,
    bool? isApproved,
    String? statusMessage,
  }) {
    return VerificationFormModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      photoIdFrontViewUrl: photoIdFrontViewUrl ?? this.photoIdFrontViewUrl,
      photoIdBackViewUrl: photoIdBackViewUrl ?? this.photoIdBackViewUrl,
      selfieUrl: selfieUrl ?? this.selfieUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPending: isPending ?? this.isPending,
      isApproved: isApproved ?? this.isApproved,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'id': id});
    result.addAll({'userId': userId});
    result.addAll({'photoIdFrontViewUrl': photoIdFrontViewUrl});
    result.addAll({'photoIdBackViewUrl': photoIdBackViewUrl});
    result.addAll({'selfieUrl': selfieUrl});
    result.addAll({'createdAt': createdAt.millisecondsSinceEpoch});
    result.addAll({'updatedAt': updatedAt.millisecondsSinceEpoch});
    result.addAll({'isPending': isPending});
    result.addAll({'isApproved': isApproved});
    if (statusMessage != null) {
      result.addAll({'statusMessage': statusMessage});
    }

    return result;
  }

  factory VerificationFormModel.fromMap(Map<String, dynamic> map) {
    return VerificationFormModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      photoIdFrontViewUrl: map['photoIdFrontViewUrl'] ?? '',
      photoIdBackViewUrl: map['photoIdBackViewUrl'] ?? '',
      selfieUrl: map['selfieUrl'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      isPending: map['isPending'] ?? false,
      isApproved: map['isApproved'] ?? false,
      statusMessage: map['statusMessage'],
    );
  }

  String toJson() => json.encode(toMap());

  factory VerificationFormModel.fromJson(String source) =>
      VerificationFormModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'GetVerifiedModel(id: $id, userId: $userId, photoIdFrontViewUrl: $photoIdFrontViewUrl, photoIdBackViewUrl: $photoIdBackViewUrl, selfieUrl: $selfieUrl, createdAt: $createdAt, updatedAt: $updatedAt, isPending: $isPending, isApproved: $isApproved, statusMessage: $statusMessage)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is VerificationFormModel &&
        other.id == id &&
        other.userId == userId &&
        other.photoIdFrontViewUrl == photoIdFrontViewUrl &&
        other.photoIdBackViewUrl == photoIdBackViewUrl &&
        other.selfieUrl == selfieUrl &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.isPending == isPending &&
        other.isApproved == isApproved &&
        other.statusMessage == statusMessage;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        photoIdFrontViewUrl.hashCode ^
        photoIdBackViewUrl.hashCode ^
        selfieUrl.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        isPending.hashCode ^
        isApproved.hashCode ^
        statusMessage.hashCode;
  }
}
