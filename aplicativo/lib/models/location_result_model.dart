import 'dart:convert';

import 'package:collection/collection.dart';

LocationResultModel locationResultModelFromJson(String str) =>
    LocationResultModel.fromJson(json.decode(str));

String locationResultModelToJson(LocationResultModel data) =>
    json.encode(data.toJson());

class LocationResultModel {
  PlusCode? plusCode;
  List<Result> results;
  String status;
  LocationResultModel({
    this.plusCode,
    required this.results,
    required this.status,
  });

  LocationResultModel copyWith({
    PlusCode? plusCode,
    List<Result>? results,
    String? status,
  }) {
    return LocationResultModel(
      plusCode: plusCode ?? this.plusCode,
      results: results ?? this.results,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    if (plusCode != null) {
      result.addAll({'plusCode': plusCode!.toMap()});
    }
    result.addAll({'results': results.map((x) => x.toMap()).toList()});
    result.addAll({'status': status});

    return result;
  }

  factory LocationResultModel.fromMap(Map<String, dynamic> map) {
    return LocationResultModel(
      plusCode:
          map['plusCode'] != null ? PlusCode.fromMap(map['plusCode']) : null,
      results: List<Result>.from(map['results']?.map((x) => Result.fromMap(x))),
      status: map['status'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory LocationResultModel.fromJson(String source) =>
      LocationResultModel.fromMap(json.decode(source));

  @override
  String toString() =>
      'LocationResultModel(plusCode: $plusCode, results: $results, status: $status)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other is LocationResultModel &&
        other.plusCode == plusCode &&
        listEquals(other.results, results) &&
        other.status == status;
  }

  @override
  int get hashCode => plusCode.hashCode ^ results.hashCode ^ status.hashCode;
}

class PlusCode {
  String? compoundCode;
  String? globalCode;
  PlusCode({
    this.compoundCode,
    this.globalCode,
  });

  PlusCode copyWith({
    String? compoundCode,
    String? globalCode,
  }) {
    return PlusCode(
      compoundCode: compoundCode ?? this.compoundCode,
      globalCode: globalCode ?? this.globalCode,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    if (compoundCode != null) {
      result.addAll({'compoundCode': compoundCode});
    }
    if (globalCode != null) {
      result.addAll({'globalCode': globalCode});
    }

    return result;
  }

  factory PlusCode.fromMap(Map<String, dynamic> map) {
    return PlusCode(
      compoundCode: map['compoundCode'],
      globalCode: map['globalCode'],
    );
  }

  String toJson() => json.encode(toMap());

  factory PlusCode.fromJson(String source) =>
      PlusCode.fromMap(json.decode(source));

  @override
  String toString() =>
      'PlusCode(compoundCode: $compoundCode, globalCode: $globalCode)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PlusCode &&
        other.compoundCode == compoundCode &&
        other.globalCode == globalCode;
  }

  @override
  int get hashCode => compoundCode.hashCode ^ globalCode.hashCode;
}

class Result {
  List<AddressComponent>? addressComponents;
  String? formattedAddress;
  Geometry? geometry;
  String? placeId;
  PlusCode? plusCode;
  List<String>? types;
  Result({
    this.addressComponents,
    this.formattedAddress,
    this.geometry,
    this.placeId,
    this.plusCode,
    this.types,
  });

  Result copyWith({
    List<AddressComponent>? addressComponents,
    String? formattedAddress,
    Geometry? geometry,
    String? placeId,
    PlusCode? plusCode,
    List<String>? types,
  }) {
    return Result(
      addressComponents: addressComponents ?? this.addressComponents,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      geometry: geometry ?? this.geometry,
      placeId: placeId ?? this.placeId,
      plusCode: plusCode ?? this.plusCode,
      types: types ?? this.types,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    if (addressComponents != null) {
      result.addAll({
        'address_components': addressComponents!.map((x) => x.toMap()).toList()
      });
    }
    if (formattedAddress != null) {
      result.addAll({'formatted_address': formattedAddress});
    }
    if (geometry != null) {
      result.addAll({'geometry': geometry!.toMap()});
    }
    if (placeId != null) {
      result.addAll({'place_id': placeId});
    }
    if (plusCode != null) {
      result.addAll({'plus_code': plusCode!.toMap()});
    }
    if (types != null) {
      result.addAll({'types': types});
    }

    return result;
  }

  factory Result.fromMap(Map<String, dynamic> map) {
    return Result(
      addressComponents: map['address_components'] != null
          ? List<AddressComponent>.from(map['address_components']
              ?.map((x) => AddressComponent.fromMap(x)))
          : null,
      formattedAddress: map['formatted_address'],
      geometry:
          map['geometry'] != null ? Geometry.fromMap(map['geometry']) : null,
      placeId: map['place_id'],
      plusCode:
          map['plus_code'] != null ? PlusCode.fromMap(map['plus_code']) : null,
      types: List<String>.from(map['types']),
    );
  }

  String toJson() => json.encode(toMap());

  factory Result.fromJson(String source) => Result.fromMap(json.decode(source));

  @override
  String toString() {
    return 'Result(addressComponents: $addressComponents, formattedAddress: $formattedAddress, geometry: $geometry, placeId: $placeId, plusCode: $plusCode, types: $types)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other is Result &&
        listEquals(other.addressComponents, addressComponents) &&
        other.formattedAddress == formattedAddress &&
        other.geometry == geometry &&
        other.placeId == placeId &&
        other.plusCode == plusCode &&
        listEquals(other.types, types);
  }

  @override
  int get hashCode {
    return addressComponents.hashCode ^
        formattedAddress.hashCode ^
        geometry.hashCode ^
        placeId.hashCode ^
        plusCode.hashCode ^
        types.hashCode;
  }
}

class AddressComponent {
  String longName;
  String shortName;
  List<String> types;
  AddressComponent({
    required this.longName,
    required this.shortName,
    required this.types,
  });

  AddressComponent copyWith({
    String? longName,
    String? shortName,
    List<String>? types,
  }) {
    return AddressComponent(
      longName: longName ?? this.longName,
      shortName: shortName ?? this.shortName,
      types: types ?? this.types,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'long_name': longName});
    result.addAll({'short_name': shortName});
    result.addAll({'types': types});

    return result;
  }

  factory AddressComponent.fromMap(Map<String, dynamic> map) {
    return AddressComponent(
      longName: map['long_name'] ?? '',
      shortName: map['short_name'] ?? '',
      types: List<String>.from(map['types']),
    );
  }

  String toJson() => json.encode(toMap());

  factory AddressComponent.fromJson(String source) =>
      AddressComponent.fromMap(json.decode(source));

  @override
  String toString() =>
      'AddressComponent(longName: $longName, shortName: $shortName, types: $types)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other is AddressComponent &&
        other.longName == longName &&
        other.shortName == shortName &&
        listEquals(other.types, types);
  }

  @override
  int get hashCode => longName.hashCode ^ shortName.hashCode ^ types.hashCode;
}

class Geometry {
  Location? location;
  String? locationType;
  Viewport? viewport;
  Viewport? bounds;
  Geometry({
    required this.location,
    required this.locationType,
    required this.viewport,
    required this.bounds,
  });

  Geometry copyWith({
    Location? location,
    String? locationType,
    Viewport? viewport,
    Viewport? bounds,
  }) {
    return Geometry(
      location: location ?? this.location,
      locationType: locationType ?? this.locationType,
      viewport: viewport ?? this.viewport,
      bounds: bounds ?? this.bounds,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    if (location != null) {
      result.addAll({'location': location!.toMap()});
    }
    if (locationType != null) {
      result.addAll({'locationType': locationType});
    }
    if (viewport != null) {
      result.addAll({'viewport': viewport!.toMap()});
    }
    if (bounds != null) {
      result.addAll({'bounds': bounds!.toMap()});
    }

    return result;
  }

  factory Geometry.fromMap(Map<String, dynamic> map) {
    return Geometry(
      location:
          map['location'] != null ? Location.fromMap(map['location']) : null,
      locationType: map['locationType'],
      viewport:
          map['viewport'] != null ? Viewport.fromMap(map['viewport']) : null,
      bounds: map['bounds'] != null ? Viewport.fromMap(map['bounds']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Geometry.fromJson(String source) =>
      Geometry.fromMap(json.decode(source));

  @override
  String toString() {
    return 'Geometry(location: $location, locationType: $locationType, viewport: $viewport, bounds: $bounds)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Geometry &&
        other.location == location &&
        other.locationType == locationType &&
        other.viewport == viewport &&
        other.bounds == bounds;
  }

  @override
  int get hashCode {
    return location.hashCode ^
        locationType.hashCode ^
        viewport.hashCode ^
        bounds.hashCode;
  }
}

class Viewport {
  Location northeast;
  Location southwest;
  Viewport({
    required this.northeast,
    required this.southwest,
  });

  Viewport copyWith({
    Location? northeast,
    Location? southwest,
  }) {
    return Viewport(
      northeast: northeast ?? this.northeast,
      southwest: southwest ?? this.southwest,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'northeast': northeast.toMap()});
    result.addAll({'southwest': southwest.toMap()});

    return result;
  }

  factory Viewport.fromMap(Map<String, dynamic> map) {
    return Viewport(
      northeast: Location.fromMap(map['northeast']),
      southwest: Location.fromMap(map['southwest']),
    );
  }

  String toJson() => json.encode(toMap());

  factory Viewport.fromJson(String source) =>
      Viewport.fromMap(json.decode(source));

  @override
  String toString() => 'Viewport(northeast: $northeast, southwest: $southwest)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Viewport &&
        other.northeast == northeast &&
        other.southwest == southwest;
  }

  @override
  int get hashCode => northeast.hashCode ^ southwest.hashCode;
}

class Location {
  double lat;
  double lng;

  Location({
    required this.lat,
    required this.lng,
  });

  Location copyWith({
    double? lat,
    double? lng,
  }) {
    return Location(
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'lat': lat});
    result.addAll({'lng': lng});

    return result;
  }

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      lat: map['lat']?.toDouble() ?? 0.0,
      lng: map['lng']?.toDouble() ?? 0.0,
    );
  }

  String toJson() => json.encode(toMap());

  factory Location.fromJson(String source) =>
      Location.fromMap(json.decode(source));

  @override
  String toString() => 'Location(lat: $lat, lng: $lng)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Location && other.lat == lat && other.lng == lng;
  }

  @override
  int get hashCode => lat.hashCode ^ lng.hashCode;
}
