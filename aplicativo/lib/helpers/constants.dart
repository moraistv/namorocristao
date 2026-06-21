import 'package:flutter/material.dart';
import 'package:mioamoreapp/config/config.dart';

class AppConstants {
  AppConstants._();

  static Color primaryColor = AppConfig.primaryColor;
  static const double defaultNumericValue = 16.0;

  static const String logo = 'assets/images/logo.png';

  static LinearGradient defaultGradient = LinearGradient(
    colors: [
      AppConstants.primaryColor.withOpacity(0.8),
      AppConstants.primaryColor,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  //TODO: Update this when releasing the app for the LIVE mode
  static const bool isTestMode = false;
}

class FirebaseConstants {
  FirebaseConstants._();

  static const String userProfileCollection = "userProfile";
  static const String userInteractionCollection = "userInteraction";
  static const String matchCollection = "matches";
  static const String chatCollection = "chat";
  static const String verificationFormsCollection = "verificationForms";
  static const String feedsCollection = "feeds";
  static const String deviceTokensCollection = "deviceTokens";
  static const String notificationsCollection = "notifications";
  static const String blockedUsersCollection = "blockedUsers";
  static const String reportsCollection = "reports";
  static const String bannedUsersCollection = "bannedUsers";
  static const String accountDeleteRequestCollection = "accountDeleteRequest";
  static const String appSettingsCollection = "appSettings";
}

class HiveConstants {
  HiveConstants._();

  static const String hiveBox = "hiveBox";

  static const String chatWallpaper = "chatWallpaper";
  static const String showCompleteDialog = "showCompleteDialog";
  static const String guidedTour = "guidedTour";
}

///Json
const String countryCodeJson = "assets/json/country_code.json";

/// Lottie Json
const String lottieNoItemFound = "assets/json/lottie/no_item_found.json";

///Images
const String appleLogo = "assets/logos/apple.png";
const String facebookLogo = "assets/logos/facebook.png";
const String googleLogo = "assets/logos/google.png";
const String twitterLogo = "assets/logos/twitter.png";

/// Icons
const String facebookIcon = "assets/icons/facebook.png";
const String instagramIcon = "assets/icons/instagram.png";
const String snapchatIcon = "assets/icons/snapchat.png";
const String twitterIcon = "assets/icons/twitterx.png";
const String tiktokIcon = "assets/icons/tiktok.png";

const String defaultImage =
    "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=687&q=80";
const String profilePicture =
    "https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=687&q=80";

final emailVerificationRedExp = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
