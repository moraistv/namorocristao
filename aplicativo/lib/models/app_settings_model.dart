import 'dart:convert';

class AppSettingsModel {
  bool isChattingEnabledBeforeMatch;
  AppSettingsModel({
    required this.isChattingEnabledBeforeMatch,
  });

  AppSettingsModel copyWith({
    bool? isChattingEnabledBeforeMatch,
  }) {
    return AppSettingsModel(
      isChattingEnabledBeforeMatch:
          isChattingEnabledBeforeMatch ?? this.isChattingEnabledBeforeMatch,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'isChattingEnabledBeforeMatch': isChattingEnabledBeforeMatch,
    };
  }

  factory AppSettingsModel.fromMap(Map<String, dynamic> map) {
    return AppSettingsModel(
      isChattingEnabledBeforeMatch: map['isChattingEnabledBeforeMatch'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory AppSettingsModel.fromJson(String source) =>
      AppSettingsModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() =>
      'AppSettingsModel(isChattingEnabledBeforeMatch: $isChattingEnabledBeforeMatch)';

  @override
  bool operator ==(covariant AppSettingsModel other) {
    if (identical(this, other)) return true;

    return other.isChattingEnabledBeforeMatch == isChattingEnabledBeforeMatch;
  }

  @override
  int get hashCode => isChattingEnabledBeforeMatch.hashCode;
}
