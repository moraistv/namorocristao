// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class BlockUserModel {
  String id;
  String blockedByUserId;
  String blockedUserId;
  DateTime createdAt;
  BlockUserModel({
    required this.id,
    required this.blockedByUserId,
    required this.blockedUserId,
    required this.createdAt,
  });

  BlockUserModel copyWith({
    String? id,
    String? blockedByUserId,
    String? blockedUserId,
    DateTime? createdAt,
  }) {
    return BlockUserModel(
      id: id ?? this.id,
      blockedByUserId: blockedByUserId ?? this.blockedByUserId,
      blockedUserId: blockedUserId ?? this.blockedUserId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'blockedByUserId': blockedByUserId,
      'blockedUserId': blockedUserId,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory BlockUserModel.fromMap(Map<String, dynamic> map) {
    return BlockUserModel(
      id: map['id'] as String,
      blockedByUserId: map['blockedByUserId'] as String,
      blockedUserId: map['blockedUserId'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  String toJson() => json.encode(toMap());

  factory BlockUserModel.fromJson(String source) =>
      BlockUserModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'BlockUserModel(id: $id, blockedByUserId: $blockedByUserId, blockedUserId: $blockedUserId, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is BlockUserModel &&
        other.id == id &&
        other.blockedByUserId == blockedByUserId &&
        other.blockedUserId == blockedUserId &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        blockedByUserId.hashCode ^
        blockedUserId.hashCode ^
        createdAt.hashCode;
  }
}
