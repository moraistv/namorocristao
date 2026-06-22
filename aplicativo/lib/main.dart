import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/helpers/config_loading.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/providers/auth_providers.dart';
import 'package:mioamoreapp/services/token_storage.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/analytics_service.dart';
import 'package:mioamoreapp/views/app/main_shell.dart';
import 'package:mioamoreapp/views/app/onboarding_page.dart';
import 'package:mioamoreapp/views/auth/login_page.dart';
import 'package:mioamoreapp/views/others/error_page.dart';
import 'package:mioamoreapp/views/others/loading_page.dart';
import 'package:mioamoreapp/views/tabs/bottom_nav_bar_page.dart';
import 'package:mioamoreapp/views/tabs/home/notification_page.dart';
import 'package:mioamoreapp/views/tabs/messages/components/chat_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isAdmobAvailable) {
    MobileAds.instance.initialize();
  }

  // Firebase (Analytics + Push/FCM). NÃO usamos Firebase Auth — o login é na
  // nossa API (VPS). Só inicializamos o core + messaging.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundNotification);
  } catch (_) {}

  await Hive.initFlutter();
  await Hive.openBox(HiveConstants.hiveBox);

  // Google Analytics (Firebase) — pronto; só ativa se o Firebase estiver configurado.
  await AnalyticsService.init();

  configLoading(
    isDarkMode: false,
    foregroundColor: AppConstants.primaryColor,
    backgroundColor: Colors.white,
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      builder: EasyLoading.init(),
      locale: const Locale("pt", "BR"),
      supportedLocales: const [Locale("pt", "BR"), Locale("en", "US")],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        primarySwatch: _primarySwatch,
        textTheme: GoogleFonts.notoSansTextTheme(
          Theme.of(context).textTheme,
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: AppConstants.primaryColor,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navega só após o primeiro frame (evita travar o Navigator durante o build).
    WidgetsBinding.instance.addPostFrameCallback((_) => _decideRoute());
  }

  Future<void> _decideRoute() async {
    Widget next;
    if (kBackendReady) {
      next = const LandingWidget();
    } else if (TokenStorage.isLoggedIn) {
      // Já logado na nossa API: decide entre app principal e onboarding.
      try {
        final profile = await AppApi.getMyProfile();
        next = profile != null ? const MainShell() : const OnboardingPage();
      } catch (_) {
        next = const LoginPage();
      }
    } else {
      next = const LoginPage();
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Splash do Flutter invisível: só fundo navy (igual à nativa). A navegação
    // acontece logo após o 1º frame, então não há coração/textos piscando.
    return const Scaffold(backgroundColor: Color(0xFF111D40));
  }
}

class LandingWidget extends ConsumerStatefulWidget {
  const LandingWidget({super.key});

  @override
  ConsumerState<LandingWidget> createState() => _LandingWidgetState();
}

class _LandingWidgetState extends ConsumerState<LandingWidget> {
  @override
  void initState() {
    _setupInteractedMessage();
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      showNotification(message);
    });
    FirebaseMessaging.onMessage.listen((message) {
      showNotification(message);
    });

    super.initState();
  }

  Future<void> _setupInteractedMessage() async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    if (message.data['type'] == 'message') {
      final otherUserId = message.data["userId"]!;
      final matchId = message.data["matchId"]!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ChatPage(matchId: matchId, otherUserId: otherUserId),
        ),
      );
    } else if (message.data['type'] == 'notification') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NotificationPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (data) {
        if (data != null) {
          return BottomNavBarPage(userId: data.uid);
        } else {
          return const LoginPage();
        }
      },
      error: (_, e) {
        return const ErrorPage();
      },
      loading: () => const LoadingPage(),
    );
  }
}

final _primarySwatch = MaterialColor(AppConstants.primaryColor.value, _swatch);
final _swatch = {
  50: AppConstants.primaryColor.withOpacity(0.1),
  100: AppConstants.primaryColor.withOpacity(0.2),
  200: AppConstants.primaryColor.withOpacity(0.3),
  300: AppConstants.primaryColor.withOpacity(0.4),
  400: AppConstants.primaryColor.withOpacity(0.5),
  500: AppConstants.primaryColor.withOpacity(0.6),
  600: AppConstants.primaryColor.withOpacity(0.7),
  700: AppConstants.primaryColor.withOpacity(0.8),
  800: AppConstants.primaryColor.withOpacity(0.9),
  900: AppConstants.primaryColor.withOpacity(1),
};

Future<void> _handleBackgroundNotification(RemoteMessage message) async {
  await Firebase.initializeApp();
  showNotification(message);
}

void showNotification(RemoteMessage message) {
  debugPrint("Notification type: ${message.data["type"]}");
  debugPrint("Other User Id ${message.data["userId"]}");
  debugPrint("MatchId ${message.data["matchId"]}");
}
