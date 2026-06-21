import 'dart:convert';

class AccountDeleteRequestModel {
  String userId;
  DateTime requestDate;
  DateTime deleteDate;
  AccountDeleteRequestModel({
    required this.userId,
    required this.requestDate,
    required this.deleteDate,
  });

  AccountDeleteRequestModel copyWith({
    String? userId,
    DateTime? requestDate,
    DateTime? deleteDate,
  }) {
    return AccountDeleteRequestModel(
      userId: userId ?? this.userId,
      requestDate: requestDate ?? this.requestDate,
      deleteDate: deleteDate ?? this.deleteDate,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'userId': userId});
    result.addAll({'requestDate': requestDate.millisecondsSinceEpoch});
    result.addAll({'deleteDate': deleteDate.millisecondsSinceEpoch});

    return result;
  }

  factory AccountDeleteRequestModel.fromMap(Map<String, dynamic> map) {
    return AccountDeleteRequestModel(
      userId: map['userId'] ?? '',
      requestDate: DateTime.fromMillisecondsSinceEpoch(map['requestDate']),
      deleteDate: DateTime.fromMillisecondsSinceEpoch(map['deleteDate']),
    );
  }

  String toJson() => json.encode(toMap());

  factory AccountDeleteRequestModel.fromJson(String source) =>
      AccountDeleteRequestModel.fromMap(json.decode(source));

  @override
  String toString() =>
      'AccountDeleteRequestModel(userId: $userId, requestDate: $requestDate, deleteDate: $deleteDate)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AccountDeleteRequestModel &&
        other.userId == userId &&
        other.requestDate == requestDate &&
        other.deleteDate == deleteDate;
  }

  @override
  int get hashCode =>
      userId.hashCode ^ requestDate.hashCode ^ deleteDate.hashCode;
}
