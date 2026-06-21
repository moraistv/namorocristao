import 'dart:convert';

class AdModel {
  String id;
  String? onCLickUrl;
  String imageUrl;
  String title;
  String description;
  String createdBy;
  DateTime createdAt;
  DateTime expiresAt;
  AdModel({
    required this.id,
    this.onCLickUrl,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.expiresAt,
  });

  AdModel copyWith({
    String? id,
    String? onCLickUrl,
    String? imageUrl,
    String? title,
    String? description,
    String? createdBy,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return AdModel(
      id: id ?? this.id,
      onCLickUrl: onCLickUrl ?? this.onCLickUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'id': id});
    if (onCLickUrl != null) {
      result.addAll({'onCLickUrl': onCLickUrl});
    }
    result.addAll({'imageUrl': imageUrl});
    result.addAll({'title': title});
    result.addAll({'description': description});
    result.addAll({'createdBy': createdBy});
    result.addAll({'createdAt': createdAt.millisecondsSinceEpoch});
    result.addAll({'expiresAt': expiresAt.millisecondsSinceEpoch});

    return result;
  }

  factory AdModel.fromMap(Map<String, dynamic> map) {
    return AdModel(
      id: map['id'] ?? '',
      onCLickUrl: map['onCLickUrl'],
      imageUrl: map['imageUrl'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expiresAt']),
    );
  }

  String toJson() => json.encode(toMap());

  factory AdModel.fromJson(String source) =>
      AdModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'AdModel(id: $id, onCLickUrl: $onCLickUrl, imageUrl: $imageUrl, title: $title, description: $description, createdBy: $createdBy, createdAt: $createdAt, expiresAt: $expiresAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AdModel &&
        other.id == id &&
        other.onCLickUrl == onCLickUrl &&
        other.imageUrl == imageUrl &&
        other.title == title &&
        other.description == description &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        onCLickUrl.hashCode ^
        imageUrl.hashCode ^
        title.hashCode ^
        description.hashCode ^
        createdBy.hashCode ^
        createdAt.hashCode ^
        expiresAt.hashCode;
  }
}
