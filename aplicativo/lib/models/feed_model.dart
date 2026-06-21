import 'dart:convert';
import 'package:collection/collection.dart';

class FeedModel {
  String id;
  String userId;
  DateTime createdAt;
  String? caption;
  List<String> images;
  List<String> likes;
  FeedModel({
    required this.id,
    required this.userId,
    required this.createdAt,
    this.caption,
    required this.images,
    required this.likes,
  });

  FeedModel copyWith({
    String? id,
    String? userId,
    DateTime? createdAt,
    String? caption,
    List<String>? images,
    List<String>? likes,
  }) {
    return FeedModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      caption: caption ?? this.caption,
      images: images ?? this.images,
      likes: likes ?? this.likes,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'id': id});
    result.addAll({'userId': userId});
    result.addAll({'createdAt': createdAt.millisecondsSinceEpoch});
    if (caption != null) {
      result.addAll({'caption': caption});
    }
    result.addAll({'images': images});
    result.addAll({'likes': likes});

    return result;
  }

  factory FeedModel.fromMap(Map<String, dynamic> map) {
    return FeedModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      caption: map['caption'],
      images: List<String>.from(map['images']),
      likes: List<String>.from(map['likes']),
    );
  }

  String toJson() => json.encode(toMap());

  factory FeedModel.fromJson(String source) =>
      FeedModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'FeedModel(id: $id, userId: $userId, createdAt: $createdAt, caption: $caption, images: $images, likes: $likes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other is FeedModel &&
        other.id == id &&
        other.userId == userId &&
        other.createdAt == createdAt &&
        other.caption == caption &&
        listEquals(other.images, images) &&
        listEquals(other.likes, likes);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        createdAt.hashCode ^
        caption.hashCode ^
        images.hashCode ^
        likes.hashCode;
  }
}
