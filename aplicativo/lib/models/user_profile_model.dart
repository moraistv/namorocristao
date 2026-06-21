import 'dart:convert';
import 'package:mioamoreapp/models/user_account_settings_model.dart';

class UserProfileModel {
  String id;
  String userId;
  String fullName;
  String? email;
  String? profilePicture;
  String? phoneNumber;
  String gender;
  String? about;

// NEW Variables
  String? myPurpose;
  String? instagramUsername;
  String? snapchatUsername;
  String? twitterUsername;
  String? facebookUsername;
  String? tiktokUsername;

  DateTime birthDay;
  List<String> mediaFiles;
  List<String> interests;
  UserAccountSettingsModel userAccountSettingsModel;
  bool isVerified;
  bool isOnline;
  UserProfileModel({
    required this.id,
    required this.userId,
    required this.fullName,
    this.email,
    this.profilePicture,
    this.phoneNumber,
    required this.gender,
    this.about,
    this.myPurpose,
    this.instagramUsername,
    this.snapchatUsername,
    this.twitterUsername,
    this.facebookUsername,
    this.tiktokUsername,
    required this.birthDay,
    required this.mediaFiles,
    required this.interests,
    required this.userAccountSettingsModel,
    required this.isVerified,
    this.isOnline = false,
  });

  UserProfileModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? email,
    String? profilePicture,
    String? phoneNumber,
    String? gender,
    String? about,
    String? myPurpose,
    String? instagramUsername,
    String? snapchatUsername,
    String? twitterUsername,
    String? facebookUsername,
    String? tiktokUsername,
    DateTime? birthDay,
    List<String>? mediaFiles,
    List<String>? interests,
    UserAccountSettingsModel? userAccountSettingsModel,
    bool? isVerified,
    bool? isOnline,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      profilePicture: profilePicture ?? this.profilePicture,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gender: gender ?? this.gender,
      about: about ?? this.about,
      myPurpose: myPurpose ?? this.myPurpose,
      instagramUsername: instagramUsername ?? this.instagramUsername,
      snapchatUsername: snapchatUsername ?? this.snapchatUsername,
      twitterUsername: twitterUsername ?? this.twitterUsername,
      facebookUsername: facebookUsername ?? this.facebookUsername,
      tiktokUsername: tiktokUsername ?? this.tiktokUsername,
      birthDay: birthDay ?? this.birthDay,
      mediaFiles: mediaFiles ?? this.mediaFiles,
      interests: interests ?? this.interests,
      userAccountSettingsModel:
          userAccountSettingsModel ?? this.userAccountSettingsModel,
      isVerified: isVerified ?? this.isVerified,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{};

    result.addAll({'id': id});
    result.addAll({'userId': userId});
    result.addAll({'fullName': fullName});
    if (email != null) {
      result.addAll({'email': email});
    }
    if (profilePicture != null) {
      result.addAll({'profilePicture': profilePicture});
    }
    if (phoneNumber != null) {
      result.addAll({'phoneNumber': phoneNumber});
    }
    result.addAll({'gender': gender});
    if (about != null) {
      result.addAll({'about': about});
    }
    if (myPurpose != null) {
      result.addAll({'myPurpose': myPurpose});
    }
    if (instagramUsername != null) {
      result.addAll({'instagramUsername': instagramUsername});
    }
    if (snapchatUsername != null) {
      result.addAll({'snapchatUsername': snapchatUsername});
    }
    if (twitterUsername != null) {
      result.addAll({'twitterUsername': twitterUsername});
    }
    if (facebookUsername != null) {
      result.addAll({'facebookUsername': facebookUsername});
    }
    if (tiktokUsername != null) {
      result.addAll({'tiktokUsername': tiktokUsername});
    }

    result.addAll({'birthDay': birthDay.millisecondsSinceEpoch});
    result.addAll({'mediaFiles': mediaFiles});
    result.addAll({'interests': interests});
    result
        .addAll({'userAccountSettingsModel': userAccountSettingsModel.toMap()});
    result.addAll({'isVerified': isVerified});
    result.addAll({'isOnline': isOnline});

    return result;
  }

  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'],
      profilePicture: map['profilePicture'],
      phoneNumber: map['phoneNumber'],
      gender: map['gender'] ?? '',
      about: map['about'],
      myPurpose: map['myPurpose'],
      instagramUsername: map['instagramUsername'],
      snapchatUsername: map['snapchatUsername'],
      twitterUsername: map['twitterUsername'],
      facebookUsername: map['facebookUsername'],
      tiktokUsername: map['tiktokUsername'],
      birthDay: DateTime.fromMillisecondsSinceEpoch(map['birthDay']),
      mediaFiles: List<String>.from(map['mediaFiles']),
      interests: List<String>.from(map['interests']),
      userAccountSettingsModel:
          UserAccountSettingsModel.fromMap(map['userAccountSettingsModel']),
      isVerified: map['isVerified'] ?? false,
      isOnline: map['isOnline'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory UserProfileModel.fromJson(String source) =>
      UserProfileModel.fromMap(json.decode(source));
}
