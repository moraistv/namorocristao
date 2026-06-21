import 'dart:convert';

class UserAccountSettingsModel {
  UserLocation location;
  double? distanceInKm;
  String? interestedIn;
  int minimumAge;
  int maximumAge;
  bool? showAge;
  bool? showLocation;
  bool? showOnlineStatus;
  bool? showOnlyToPremiumUsers;
  bool? allowAnonymousMessages;
  UserAccountSettingsModel({
    required this.location,
    this.distanceInKm,
    this.interestedIn,
    required this.minimumAge,
    required this.maximumAge,
    this.showAge,
    this.showLocation,
    this.showOnlineStatus,
    this.showOnlyToPremiumUsers,
    this.allowAnonymousMessages,
  });

  UserAccountSettingsModel copyWith({
    UserLocation? location,
    double? distanceInKm,
    String? interestedIn,
    int? minimumAge,
    int? maximumAge,
    bool? showAge,
    bool? showLocation,
    bool? showOnlineStatus,
    bool? showOnlyToPremiumUsers,
    bool? allowAnonymousMessages,
  }) {
    return UserAccountSettingsModel(
      location: location ?? this.location,
      distanceInKm: distanceInKm,
      interestedIn: interestedIn ?? this.interestedIn,
      minimumAge: minimumAge ?? this.minimumAge,
      maximumAge: maximumAge ?? this.maximumAge,
      showAge: showAge ?? this.showAge,
      showLocation: showLocation ?? this.showLocation,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      showOnlyToPremiumUsers:
          showOnlyToPremiumUsers ?? this.showOnlyToPremiumUsers,
      allowAnonymousMessages:
          allowAnonymousMessages ?? this.allowAnonymousMessages,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'location': location.toMap()});
    if (distanceInKm != null) {
      result.addAll({'distanceInKm': distanceInKm});
    }
    if (interestedIn != null) {
      result.addAll({'interestedIn': interestedIn});
    }
    result.addAll({'minimumAge': minimumAge});
    result.addAll({'maximumAge': maximumAge});
    if (showAge != null) {
      result.addAll({'showAge': showAge});
    }
    if (showLocation != null) {
      result.addAll({'showLocation': showLocation});
    }
    if (showOnlineStatus != null) {
      result.addAll({'showOnlineStatus': showOnlineStatus});
    }
    if (showOnlyToPremiumUsers != null) {
      result.addAll({'showOnlyToPremiumUsers': showOnlyToPremiumUsers});
    }
    if (allowAnonymousMessages != null) {
      result.addAll({'allowAnonymousMessages': allowAnonymousMessages});
    }

    return result;
  }

  factory UserAccountSettingsModel.fromMap(Map<String, dynamic> map) {
    return UserAccountSettingsModel(
      location: UserLocation.fromMap(map['location']),
      distanceInKm: map['distanceInKm']?.toDouble(),
      interestedIn: map['interestedIn'],
      minimumAge: map['minimumAge']?.toInt() ?? 0,
      maximumAge: map['maximumAge']?.toInt() ?? 0,
      showAge: map['showAge'],
      showLocation: map['showLocation'],
      showOnlineStatus: map['showOnlineStatus'],
      showOnlyToPremiumUsers: map['showOnlyToPremiumUsers'],
      allowAnonymousMessages: map['allowAnonymousMessages'],
    );
  }

  String toJson() => json.encode(toMap());

  factory UserAccountSettingsModel.fromJson(String source) =>
      UserAccountSettingsModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'UserAccountSettingsModel(location: $location, distanceInKm: $distanceInKm, interestedIn: $interestedIn, minimumAge: $minimumAge, maximumAge: $maximumAge, showAge: $showAge, showLocation: $showLocation, showOnlineStatus: $showOnlineStatus, showOnlyToPremiumUsers: $showOnlyToPremiumUsers, allowAnonymousMessages: $allowAnonymousMessages)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserAccountSettingsModel &&
        other.location == location &&
        other.distanceInKm == distanceInKm &&
        other.interestedIn == interestedIn &&
        other.minimumAge == minimumAge &&
        other.maximumAge == maximumAge &&
        other.showAge == showAge &&
        other.showLocation == showLocation &&
        other.showOnlineStatus == showOnlineStatus &&
        other.showOnlyToPremiumUsers == showOnlyToPremiumUsers &&
        other.allowAnonymousMessages == allowAnonymousMessages;
  }

  @override
  int get hashCode {
    return location.hashCode ^
        distanceInKm.hashCode ^
        interestedIn.hashCode ^
        minimumAge.hashCode ^
        maximumAge.hashCode ^
        showAge.hashCode ^
        showLocation.hashCode ^
        showOnlineStatus.hashCode ^
        showOnlyToPremiumUsers.hashCode ^
        allowAnonymousMessages.hashCode;
  }
}

class UserLocation {
  String addressText;
  double latitude;
  double longitude;
  UserLocation({
    required this.addressText,
    required this.latitude,
    required this.longitude,
  });

  UserLocation copyWith({
    String? addressText,
    double? latitude,
    double? longitude,
  }) {
    return UserLocation(
      addressText: addressText ?? this.addressText,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'addressText': addressText});
    result.addAll({'latitude': latitude});
    result.addAll({'longitude': longitude});

    return result;
  }

  factory UserLocation.fromMap(Map<String, dynamic> map) {
    return UserLocation(
      addressText: map['addressText'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
    );
  }

  String toJson() => json.encode(toMap());

  factory UserLocation.fromJson(String source) =>
      UserLocation.fromMap(json.decode(source));

  @override
  String toString() =>
      'UserLocation(addressText: $addressText, latitude: $latitude, longitude: $longitude)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserLocation &&
        other.addressText == addressText &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode =>
      addressText.hashCode ^ latitude.hashCode ^ longitude.hashCode;
}
