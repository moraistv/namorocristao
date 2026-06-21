import 'dart:convert';

class NotificationModel {
  String id;
  String? userId;
  String receiverId;
  String? matchId;
  String title;
  String body;
  String? image;
  bool isRead;
  DateTime createdAt;
  bool isMatchingNotification;
  bool isInteractionNotification;
  NotificationModel({
    required this.id,
    this.userId,
    required this.receiverId,
    this.matchId,
    required this.title,
    required this.body,
    this.image,
    required this.isRead,
    required this.createdAt,
    required this.isMatchingNotification,
    required this.isInteractionNotification,
  });

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? receiverId,
    String? matchId,
    String? title,
    String? body,
    String? image,
    bool? isRead,
    DateTime? createdAt,
    bool? isMatchingNotification,
    bool? isInteractionNotification,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      receiverId: receiverId ?? this.receiverId,
      matchId: matchId ?? this.matchId,
      title: title ?? this.title,
      body: body ?? this.body,
      image: image ?? this.image,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      isMatchingNotification:
          isMatchingNotification ?? this.isMatchingNotification,
      isInteractionNotification:
          isInteractionNotification ?? this.isInteractionNotification,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'id': id});
    if (userId != null) {
      result.addAll({'userId': userId});
    }
    result.addAll({'receiverId': receiverId});
    if (matchId != null) {
      result.addAll({'matchId': matchId});
    }
    result.addAll({'title': title});
    result.addAll({'body': body});
    if (image != null) {
      result.addAll({'image': image});
    }
    result.addAll({'isRead': isRead});
    result.addAll({'createdAt': createdAt.millisecondsSinceEpoch});
    result.addAll({'isMatchingNotification': isMatchingNotification});
    result.addAll({'isInteractionNotification': isInteractionNotification});

    return result;
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? '',
      userId: map['userId'],
      receiverId: map['receiverId'] ?? '',
      matchId: map['matchId'],
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      image: map['image'],
      isRead: map['isRead'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      isMatchingNotification: map['isMatchingNotification'] ?? false,
      isInteractionNotification: map['isInteractionNotification'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory NotificationModel.fromJson(String source) =>
      NotificationModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'NotificationModel(id: $id, userId: $userId, receiverId: $receiverId, matchId: $matchId, title: $title, body: $body, image: $image, isRead: $isRead, createdAt: $createdAt, isMatchingNotification: $isMatchingNotification, isInteractionNotification: $isInteractionNotification)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NotificationModel &&
        other.id == id &&
        other.userId == userId &&
        other.receiverId == receiverId &&
        other.matchId == matchId &&
        other.title == title &&
        other.body == body &&
        other.image == image &&
        other.isRead == isRead &&
        other.createdAt == createdAt &&
        other.isMatchingNotification == isMatchingNotification &&
        other.isInteractionNotification == isInteractionNotification;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        receiverId.hashCode ^
        matchId.hashCode ^
        title.hashCode ^
        body.hashCode ^
        image.hashCode ^
        isRead.hashCode ^
        createdAt.hashCode ^
        isMatchingNotification.hashCode ^
        isInteractionNotification.hashCode;
  }
}
