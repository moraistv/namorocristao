import 'package:flutter/material.dart';
import 'package:mioamoreapp/helpers/get_color_from.hex.dart';

class AppConfig {
  AppConfig._();

  // ? This is the main configuration file for the app. You can change the app name, app primary color, chat background, user interaction buttons colors, etc. from here. All the main configuration settings are here. Please read the comments carefully before changing anything. Every comment is important. If you have any questions, please contact us. We are always happy to help you.

  ///
  /// App Primary Constants
  ///

//!!App Name. Change this to your app name
  static const String appName = "Namoro Cristão";

//!! App Primary Color. Change this to your app primary color
  static HexColor primaryColor = HexColor("#D4AF37");

  ///
  /// Chat Constants
  ///

  //!! Default Chat Background. Change the image in assets/images/chat_bg.png. Keep the image file name and format same as the name below. No need to change anything here.
  static const String defaultChatBg = "assets/images/chat_bg.png";

  //!! Chat Text Field and Other user message text color
  static const Color chatTextFieldAndOtherText =
      Color.fromARGB(255, 244, 238, 238);

  //!! My message text color
  static const Color chatMyTextColor = Color.fromARGB(255, 255, 193, 202);

  //!! Solid Colors for Chat Background. You can add more colors here or remove colors from here.
  static const List<Color> wallpaperSolidColors = [
    Colors.deepPurple,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.indigo,
    Colors.cyan,
    Colors.teal,
    Colors.lime,
    Colors.lightGreen,
    Colors.lightBlue,
    Colors.lightBlueAccent,
    Colors.deepOrange,
    Colors.deepOrangeAccent,
    Colors.brown,
    Colors.grey,
    Colors.white,
  ];

  ///
  /// User Interaction Buttons Settings
  ///

  //!! Dislike Button Color
  static const Color dislikeButtonColor = Color.fromARGB(255, 195, 16, 4);

  //!! Super Like Button Color
  static const Color superLikeButtonColor = Color.fromARGB(255, 3, 160, 204);

  //!! Like Button Color
  static const Color likeButtonColor = Color.fromARGB(255, 3, 223, 10);

  //!! Show Interaction Button Text
  static const bool showInteractionButtonText = true;

  //!! Like Button Text
  static const String likeButtonText = "Like";

  //!! Super Like Button Text
  static const String superLikeButtonText = "Super Like";

  //!! Dislike Button Text
  static const String dislikeButtonText = "Dislike";

  ///
  /// Gender Settings
  ///

  //!! Change this to False if you don't want transgender
  static const bool allowTransGender = true;

  //!! Male gender text
  static const String maleText = "male";

  //!! Female Gender text
  static const String femaleText = "female";

  //!! Other Gender text
  static const String transText = "other";

  ///
  /// Base settings for a new user
  ///

  //!! Initial Distance in KM to filter users
  static const double initialDistanceInKM = 500;

  //!! Initial Maximum Distance in KM to filter users
  static const double initialMaximumDistanceInKM = 1000;

  //!! Maximum default age to filter users
  static const int maximumUserAge = 99;

  ///
  /// Other Settings
  ///

  //!! Can a user change name?
  static const bool canChangeName = true;

  //!! Can user see other user profile if they don't have images?
  static const bool userProfileShowWithoutImages = true;

  //!! Minimum age required to use the app
  static const int minimumAgeRequired = 18;

  //!! Maximum number of media a user can upload
  static const int maxNumOfMedia = 6;

  //!! Maximum number of interests a user can select
  static const int maxNumOfInterests = 5;

  // !! Interests List for user to select! You can add more or remove some!
  static const List<String> interests = [
    "pets",
    "exercise",
    "dancing",
    "cooking",
    "politics",
    "sports",
    "photography",
    "art",
    "learning",
    "music",
    "movies",
    "books",
    "gaming",
    "food",
    "fashion",
    "technology",
    "science",
    "health",
    "business",
  ];
}

///
/// Authentication Modes
///

//!! Backend pronto? Durante a migração para a VPS, deixamos FALSE: o app sobe sem
//!! Firebase e vai direto para a tela de Login (preview/rebrand). Quando a API da VPS
//!! estiver no ar, mudar para TRUE e religar auth/dados + FCM.
const bool kBackendReady = false;

//!! Enable Google Authentication
const bool isGoogleAuthAvailable = true;

//!! Enable Facebook Authentication (adiado — ligar depois, se quisermos)
const bool isFacebookAuthAvailable = false;

//!! Enable Phone Authentication (REMOVIDO — não usaremos telefone/SMS)
const bool isPhoneAuthAvailable = false;

///
/// Company Pages Setup
///

// ? Must Have These Two

//!! Terms and Conditions Page. You should use your own page or use this one.
const String termsAndConditionsUrl = "";

//!! Privacy Policy Page. You should use your own page or use this one.
const String privacyPolicyUrl = "";

// ? These are optional

//!! If you have FAQ page, set this to true and set the url below
const bool isCompanyHasFAQ = true;

//! If you have About page, set this to true and set the url below
const bool isCompanyHasAbout = true;

//! If you have Contact page, set this to true and set the url below
const bool isCompanyHasContact = true;

//! FAQ Page URL
const String faqUrl = "";

//! Contact Page URL
const String contactUsUrl = "";

//! About Page URL
const String aboutUsUrl = "";

///
/// Location Settings
///

//!! Create this place api key from google cloud platform and paste here!
//!! Link: https://!console.cloud.google.com/apis/credentials
const String locationApiKey = "Location API Key";

///
/// Ads Settings
///

//! Enable Admob Ads or not. If you don't want ads, set this to false. If you want ads, set this to true and set the ad ids below.

// You must remove the configuration from the android manifest file if you don't want ads. Otherwise, the app will not compile.

// You must remove the configuration from the info.plist file if you don't want ads. Otherwise, the app will not compile.

const bool isAdmobAvailable = true;

class AndroidAdUnits {
  AndroidAdUnits._();

  //! Admob Android App Id (ID de TESTE do Google)
  static const String appId = "ca-app-pub-3940256099942544~3347511713";

  //! Admob Android Banner Ad Id (TESTE)
  static const String bannerId = "ca-app-pub-3940256099942544/6300978111";

  //! Admob Android Interstitial Ad Id (TESTE)
  static const String interstitialId = "ca-app-pub-3940256099942544/1033173712";

  //! Admob Android Rewarded Video Ad Id (TESTE)
  static const String rewardedVideoId = "ca-app-pub-3940256099942544/5224354917";
}

class IOSAdUnits {
  IOSAdUnits._();

  //! Admob iOS App Id
  static const String appId = "admob_ios_app_id";

  //! Admob iOS Banner Ad Id
  static const String bannerId = "admob_ios_banner_id";

  //! Admob iOS Interstitial Ad Id
  static const String interstitialId = "admob_ios_interstitial_id";

  //! Admob iOS Rewarded Video Ad Id
  static const String rewardedVideoId = "admob_ios_rewarded_video_id";
}

///
/// Subscription Settings
///!! You need to create a subscription plan in your app store and play store then create the api keys in revenue cat and paste them here.

class SubscriptionConstants {
  SubscriptionConstants._();

  // Revenue Cat Apple API Key
  static const String appleApiKey =
      ""; //!! Create this from revenue cat and paste here

  // Revenue Cat Google API Key
  static const String googleApiKey =
      ""; //!! Create this from revenue cat and paste here

  // Revenue Cat Entitlement Id
  static const String entitlementId =
      ""; //!! Create the entitlement id in revenue cat and paste here
}

// Free and Premium User Limitations
class FreemiumLimitation {
  FreemiumLimitation._();

  //!! Maximum number of likes a free user can send
  static const int maxDailyLikeLimitFree = 10; // Make it 0 for unlimited

  //!! Maximum number of super likes a free user can send
  static const int maxDailySuperLikeLimitFree = 1; // Make it 0 for unlimited

  //!! Maximum number of dislikes a free user can send
  static const int maxDailyDislikeLimitFree = 5; // Make it 0 for unlimited

  //!! Maximum number of likes a premium user can send
  static const int maxDailyLikeLimitPremium = 100; // Make it 0 for unlimited

  //!! Maximum number of super likes a premium user can send
  static const int maxDailySuperLikeLimitPremium =
      10; // Make it 0 for unlimited

  //!! Maximum number of dislikes a premium user can send
  static const int maxDailyDislikeLimitPremium = 50; // Make it 0 for unlimited
}
