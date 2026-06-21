import 'dart:convert';

class DeviceTokenModel {
  String userId;
  String deviceToken;
  DeviceTokenModel({
    required this.userId,
    required this.deviceToken,
  });

  DeviceTokenModel copyWith({
    String? userId,
    String? deviceToken,
  }) {
    return DeviceTokenModel(
      userId: userId ?? this.userId,
      deviceToken: deviceToken ?? this.deviceToken,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'deviceToken': deviceToken,
    };
  }

  factory DeviceTokenModel.fromMap(Map<String, dynamic> map) {
    return DeviceTokenModel(
      userId: map['userId'],
      deviceToken: map['deviceToken'],
    );
  }

  String toJson() => json.encode(toMap());

  factory DeviceTokenModel.fromJson(String source) =>
      DeviceTokenModel.fromMap(json.decode(source));

  @override
  String toString() => 'DeviceMode(userId: $userId, deviceToken: $deviceToken)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DeviceTokenModel &&
        other.userId == userId &&
        other.deviceToken == deviceToken;
  }

  @override
  int get hashCode => userId.hashCode ^ deviceToken.hashCode;
}
