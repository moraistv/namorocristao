import 'dart:convert';
import 'package:collection/collection.dart';

class MatchModel {
  String id;
  List<String> userIds;
  bool isMatched;
  MatchModel({
    required this.id,
    required this.userIds,
    required this.isMatched,
  });

  MatchModel copyWith({
    String? id,
    List<String>? userIds,
    bool? isMatched,
  }) {
    return MatchModel(
      id: id ?? this.id,
      userIds: userIds ?? this.userIds,
      isMatched: isMatched ?? this.isMatched,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'userIds': userIds,
      'isMatched': isMatched,
    };
  }

  factory MatchModel.fromMap(Map<String, dynamic> map) {
    return MatchModel(
      id: map['id'] as String,
      userIds: List<String>.from((map['userIds'])),
      isMatched: map['isMatched'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory MatchModel.fromJson(String source) =>
      MatchModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'MatchModel(id: $id, userIds: $userIds, isMatched: $isMatched)';

  @override
  bool operator ==(covariant MatchModel other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other.id == id &&
        listEquals(other.userIds, userIds) &&
        other.isMatched == isMatched;
  }

  @override
  int get hashCode => id.hashCode ^ userIds.hashCode ^ isMatched.hashCode;
}
