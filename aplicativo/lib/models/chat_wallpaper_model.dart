import 'dart:convert';
import 'package:flutter/material.dart';

class ChatWallpaperModel {
  Color? solidColor;
  String? imagePath;

  ChatWallpaperModel({
    this.solidColor,
    this.imagePath,
  });

  ChatWallpaperModel copyWith({
    Color? solidColor,
    String? imagePath,
  }) {
    return ChatWallpaperModel(
      solidColor: solidColor ?? this.solidColor,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    if (solidColor != null) {
      result.addAll({'solidColor': solidColor!.value});
    }
    if (imagePath != null) {
      result.addAll({'imagePath': imagePath});
    }

    return result;
  }

  factory ChatWallpaperModel.fromMap(Map<String, dynamic> map) {
    return ChatWallpaperModel(
      solidColor: map['solidColor'] != null ? Color(map['solidColor']) : null,
      imagePath: map['imagePath'],
    );
  }

  String toJson() => json.encode(toMap());

  factory ChatWallpaperModel.fromJson(String source) =>
      ChatWallpaperModel.fromMap(json.decode(source));

  @override
  String toString() =>
      'ChatWallpaperModel(solidColor: $solidColor, imagePath: $imagePath)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatWallpaperModel &&
        other.solidColor == solidColor &&
        other.imagePath == imagePath;
  }

  @override
  int get hashCode => solidColor.hashCode ^ imagePath.hashCode;
}
