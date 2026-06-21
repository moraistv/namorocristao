import 'dart:convert';

class ChatItemModel {
  String id;
  String? userId;
  String matchId;
  String? message;
  String? image;
  String? video;
  String? audio;
  String? file;
  DateTime createdAt;
  bool isRead;
  ChatItemModel({
    required this.id,
    this.userId,
    required this.matchId,
    this.message,
    this.image,
    this.video,
    this.audio,
    this.file,
    required this.createdAt,
    required this.isRead,
  });

  ChatItemModel copyWith({
    String? id,
    String? userId,
    String? matchId,
    String? message,
    String? image,
    String? video,
    String? audio,
    String? file,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return ChatItemModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      matchId: matchId ?? this.matchId,
      message: message ?? this.message,
      image: image ?? this.image,
      video: video ?? this.video,
      audio: audio ?? this.audio,
      file: file ?? this.file,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'id': id});
    if (userId != null) {
      result.addAll({'userId': userId});
    }
    result.addAll({'matchId': matchId});
    if (message != null) {
      result.addAll({'message': message});
    }
    if (image != null) {
      result.addAll({'image': image});
    }
    if (video != null) {
      result.addAll({'video': video});
    }
    if (audio != null) {
      result.addAll({'audio': audio});
    }
    if (file != null) {
      result.addAll({'file': file});
    }
    result.addAll({'createdAt': createdAt.millisecondsSinceEpoch});
    result.addAll({'isRead': isRead});

    return result;
  }

  factory ChatItemModel.fromMap(Map<String, dynamic> map) {
    return ChatItemModel(
      id: map['id'] ?? '',
      userId: map['userId'],
      matchId: map['matchId'] ?? '',
      message: map['message'],
      image: map['image'],
      video: map['video'],
      audio: map['audio'],
      file: map['file'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      isRead: map['isRead'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory ChatItemModel.fromJson(String source) =>
      ChatItemModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'ChatItemModel(id: $id, userId: $userId, matchId: $matchId, message: $message, image: $image, video: $video, audio: $audio, file: $file, createdAt: $createdAt, isRead: $isRead)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatItemModel &&
        other.id == id &&
        other.userId == userId &&
        other.matchId == matchId &&
        other.message == message &&
        other.image == image &&
        other.video == video &&
        other.audio == audio &&
        other.file == file &&
        other.createdAt == createdAt &&
        other.isRead == isRead;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        matchId.hashCode ^
        message.hashCode ^
        image.hashCode ^
        video.hashCode ^
        audio.hashCode ^
        file.hashCode ^
        createdAt.hashCode ^
        isRead.hashCode;
  }
}
