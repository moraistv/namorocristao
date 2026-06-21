import 'dart:convert';
import 'package:collection/collection.dart';

class ChatQuizModel {
  String id;
  String conversationId;
  String question;
  List<String> options;
  String correctAnswer;
  String createdByUserId;
  DateTime createdAt;
  ChatQuizModel({
    required this.id,
    required this.conversationId,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.createdByUserId,
    required this.createdAt,
  });

  ChatQuizModel copyWith({
    String? id,
    String? conversationId,
    String? question,
    List<String>? options,
    String? correctAnswer,
    String? createdByUserId,
    DateTime? createdAt,
  }) {
    return ChatQuizModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      question: question ?? this.question,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'id': id});
    result.addAll({'conversationId': conversationId});
    result.addAll({'question': question});
    result.addAll({'options': options});
    result.addAll({'correctAnswer': correctAnswer});
    result.addAll({'createdByUserId': createdByUserId});
    result.addAll({'createdAt': createdAt.millisecondsSinceEpoch});

    return result;
  }

  factory ChatQuizModel.fromMap(Map<String, dynamic> map) {
    return ChatQuizModel(
      id: map['id'] ?? '',
      conversationId: map['conversationId'] ?? '',
      question: map['question'] ?? '',
      options: List<String>.from(map['options']),
      correctAnswer: map['correctAnswer'] ?? '',
      createdByUserId: map['createdByUserId'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  String toJson() => json.encode(toMap());

  factory ChatQuizModel.fromJson(String source) =>
      ChatQuizModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'ChatQuizModel(id: $id, conversationId: $conversationId, question: $question, options: $options, correctAnswer: $correctAnswer, createdByUserId: $createdByUserId, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other is ChatQuizModel &&
        other.id == id &&
        other.conversationId == conversationId &&
        other.question == question &&
        listEquals(other.options, options) &&
        other.correctAnswer == correctAnswer &&
        other.createdByUserId == createdByUserId &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        conversationId.hashCode ^
        question.hashCode ^
        options.hashCode ^
        correctAnswer.hashCode ^
        createdByUserId.hashCode ^
        createdAt.hashCode;
  }
}
