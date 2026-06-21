import 'dart:convert';

import 'package:collection/collection.dart';

class Prediction {
  String? description;
  List<MatchedSubstring>? matchedSubstrings;
  String? placeId;
  String? reference;
  StructuredFormatting? structuredFormatting;
  List<Term>? terms;
  List<String>? types;

  Prediction({
    this.description,
    required this.matchedSubstrings,
    required this.placeId,
    this.reference,
    this.structuredFormatting,
    this.terms,
    this.types,
  });

  Prediction copyWith({
    String? description,
    List<MatchedSubstring>? matchedSubstrings,
    String? placeId,
    String? reference,
    StructuredFormatting? structuredFormatting,
    List<Term>? terms,
    List<String>? types,
  }) {
    return Prediction(
      description: description ?? this.description,
      matchedSubstrings: matchedSubstrings ?? this.matchedSubstrings,
      placeId: placeId ?? this.placeId,
      reference: reference ?? this.reference,
      structuredFormatting: structuredFormatting ?? this.structuredFormatting,
      terms: terms ?? this.terms,
      types: types ?? this.types,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'matched_substrings': matchedSubstrings?.map((x) => x.toMap()).toList(),
      'place_id': placeId,
      'reference': reference,
      'structured_formatting': structuredFormatting?.toMap(),
      'terms': terms?.map((x) => x.toMap()).toList(),
      'types': types,
    };
  }

  factory Prediction.fromMap(Map<String, dynamic> map) {
    return Prediction(
      description: map['description'],
      matchedSubstrings: map['matched_substrings'] != null
          ? List<MatchedSubstring>.from(map['matched_substrings']
              ?.map((x) => MatchedSubstring.fromMap(x)))
          : null,
      placeId: map['place_id'],
      reference: map['reference'],
      structuredFormatting: map['structured_formatting'] != null
          ? StructuredFormatting.fromMap(map['structured_formatting'])
          : null,
      terms: map['terms'] != null
          ? List<Term>.from(map['terms']?.map((x) => Term.fromMap(x)))
          : null,
      types: map['types'] != null ? List<String>.from(map['types']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Prediction.fromJson(String source) =>
      Prediction.fromMap(json.decode(source));

  @override
  String toString() {
    return 'Prediction(description: $description, matchedSubstrings: $matchedSubstrings, placeId: $placeId, reference: $reference, structuredFormatting: $structuredFormatting, terms: $terms, types: $types)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other is Prediction &&
        other.description == description &&
        listEquals(other.matchedSubstrings, matchedSubstrings) &&
        other.placeId == placeId &&
        other.reference == reference &&
        other.structuredFormatting == structuredFormatting &&
        listEquals(other.terms, terms) &&
        listEquals(other.types, types);
  }

  @override
  int get hashCode {
    return description.hashCode ^
        matchedSubstrings.hashCode ^
        placeId.hashCode ^
        reference.hashCode ^
        structuredFormatting.hashCode ^
        terms.hashCode ^
        types.hashCode;
  }
}

class MatchedSubstring {
  int? length;
  int? offset;
  MatchedSubstring({
    this.length,
    this.offset,
  });

  MatchedSubstring copyWith({
    int? length,
    int? offset,
  }) {
    return MatchedSubstring(
      length: length ?? this.length,
      offset: offset ?? this.offset,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'length': length,
      'offset': offset,
    };
  }

  factory MatchedSubstring.fromMap(Map<String, dynamic> map) {
    return MatchedSubstring(
      length: map['length'],
      offset: map['offset'],
    );
  }

  String toJson() => json.encode(toMap());

  factory MatchedSubstring.fromJson(String source) =>
      MatchedSubstring.fromMap(json.decode(source));

  @override
  String toString() => 'MatchedSubstring(length: $length, offset: $offset)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MatchedSubstring &&
        other.length == length &&
        other.offset == offset;
  }

  @override
  int get hashCode => length.hashCode ^ offset.hashCode;
}

class StructuredFormatting {
  String? mainText;
  List<MatchedSubstring>? mainTextMatchedSubstrings;
  String? secondaryText;
  List<MatchedSubstring>? secondaryTextMatchedSubstrings;
  StructuredFormatting({
    this.mainText,
    this.mainTextMatchedSubstrings,
    this.secondaryText,
    this.secondaryTextMatchedSubstrings,
  });

  StructuredFormatting copyWith({
    String? mainText,
    List<MatchedSubstring>? mainTextMatchedSubstrings,
    String? secondaryText,
    List<MatchedSubstring>? secondaryTextMatchedSubstrings,
  }) {
    return StructuredFormatting(
      mainText: mainText ?? this.mainText,
      mainTextMatchedSubstrings:
          mainTextMatchedSubstrings ?? this.mainTextMatchedSubstrings,
      secondaryText: secondaryText ?? this.secondaryText,
      secondaryTextMatchedSubstrings:
          secondaryTextMatchedSubstrings ?? this.secondaryTextMatchedSubstrings,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mainText': mainText,
      'mainTextMatchedSubstrings':
          mainTextMatchedSubstrings?.map((x) => x.toMap()).toList(),
      'secondaryText': secondaryText,
      'secondaryTextMatchedSubstrings':
          secondaryTextMatchedSubstrings?.map((x) => x.toMap()).toList(),
    };
  }

  factory StructuredFormatting.fromMap(Map<String, dynamic> map) {
    return StructuredFormatting(
      mainText: map['main_text'],
      mainTextMatchedSubstrings: map['main_text_matched_substrings'] != null
          ? List<MatchedSubstring>.from(map['main_text_matched_substrings']
              ?.map((x) => MatchedSubstring.fromMap(x)))
          : null,
      secondaryText: map['secondary_text'],
      secondaryTextMatchedSubstrings:
          map['secondary_text_matched_substrings'] != null
              ? List<MatchedSubstring>.from(
                  map['secondary_text_matched_substrings']
                      ?.map((x) => MatchedSubstring.fromMap(x)))
              : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory StructuredFormatting.fromJson(String source) =>
      StructuredFormatting.fromMap(json.decode(source));

  @override
  String toString() {
    return 'StructuredFormatting(mainText: $mainText, mainTextMatchedSubstrings: $mainTextMatchedSubstrings, secondaryText: $secondaryText, secondaryTextMatchedSubstrings: $secondaryTextMatchedSubstrings)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other is StructuredFormatting &&
        other.mainText == mainText &&
        listEquals(
            other.mainTextMatchedSubstrings, mainTextMatchedSubstrings) &&
        other.secondaryText == secondaryText &&
        listEquals(other.secondaryTextMatchedSubstrings,
            secondaryTextMatchedSubstrings);
  }

  @override
  int get hashCode {
    return mainText.hashCode ^
        mainTextMatchedSubstrings.hashCode ^
        secondaryText.hashCode ^
        secondaryTextMatchedSubstrings.hashCode;
  }
}

class Term {
  int? offset;
  String? value;
  Term({
    this.offset,
    this.value,
  });

  Term copyWith({
    int? offset,
    String? value,
  }) {
    return Term(
      offset: offset ?? this.offset,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'offset': offset,
      'value': value,
    };
  }

  factory Term.fromMap(Map<String, dynamic> map) {
    return Term(
      offset: map['offset'],
      value: map['value'],
    );
  }

  String toJson() => json.encode(toMap());

  factory Term.fromJson(String source) => Term.fromMap(json.decode(source));

  @override
  String toString() => 'Term(offset: $offset, value: $value)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Term && other.offset == offset && other.value == value;
  }

  @override
  int get hashCode => offset.hashCode ^ value.hashCode;
}
