import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/helpers/config_loading.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/services/analytics_service.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/push_device_service.dart';
import 'package:mioamoreapp/services/token_storage.dart';
import 'package:mioamoreapp/views/app/main_shell.dart';
import 'package:mioamoreapp/views/app/onboarding_page.dart';
import 'package:mioamoreapp/views/auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  if (isAdmobAvailable) {
    try {
      await MobileAds.instance.initialize();
    } catch (error) {
      debugPrint("Não foi possível inicializar anúncios: $error");
    }
  }

  // Firebase Core permanece para Analytics e Push/FCM. A autenticação e os
  // dados do aplicativo usam exclusivamente a API REST.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundNotification);
  } catch (_) {}

  await Hive.initFlutter();
  await Hive.openBox(HiveConstants.hiveBox);

  await AnalyticsService.init();

  configLoading(
    isDarkMode: false,
    foregroundColor: AppConstants.primaryColor,
    backgroundColor: Colors.white,
  );

  // Outras telas ainda consomem providers Riverpod.
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<SessionEvent>? _sessionSubscription;
  bool _redirectingExpiredSession = false;

  @override
  void initState() {
    super.initState();
    _sessionSubscription = TokenStorage.sessionEvents.listen((event) {
      if (event.type == SessionEventType.sessionExpired) {
        _redirectExpiredSession(event);
      }
    });
  }

  void _redirectExpiredSession(SessionEvent event) {
    if (_redirectingExpiredSession) return;
    _redirectingExpiredSession = true;
    final expiredGeneration = TokenStorage.sessionGeneration;
    unawaited(_finishExpiredSessionRedirect(event, expiredGeneration));
  }

  Future<void> _finishExpiredSessionRedirect(
    SessionEvent event,
    int expiredGeneration,
  ) async {
    final cleanup = await PushDeviceService.cleanupForSessionTermination();
    if (cleanup.localError != null) {
      debugPrint(
        "Não foi possível invalidar completamente o token push local: "
        "${cleanup.localError}",
      );
    }
    if (!mounted) return;
    if (TokenStorage.isLoggedIn &&
        TokenStorage.sessionGeneration != expiredGeneration) {
      _redirectingExpiredSession = false;
      return;
    }

    final message =
        event.message ?? "Sua sessão expirou. Entre novamente para continuar.";
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigatorKey.currentState;
      if (!mounted ||
          navigator == null ||
          (TokenStorage.isLoggedIn &&
              TokenStorage.sessionGeneration != expiredGeneration)) {
        _redirectingExpiredSession = false;
        return;
      }

      EasyLoading.dismiss();
      _messengerKey.currentState?.clearSnackBars();
      unawaited(
        navigator.pushAndRemoveUntil<void>(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(message)),
        );
        _redirectingExpiredSession = false;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_sessionSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
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
  bool _deciding = false;
  bool _navigating = false;
  bool _unavailableRetryable = true;
  String? _unavailableMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_decideRoute());
    });
  }

  Future<void> _decideRoute() async {
    if (_deciding || _navigating) return;
    _deciding = true;
    var retryForNewSession = false;
    int? requestedGeneration;
    if (_unavailableMessage != null && mounted) {
      setState(() => _unavailableMessage = null);
    }

    try {
      if (!TokenStorage.isLoggedIn) {
        _replaceWith(const LoginPage());
        return;
      }

      requestedGeneration = TokenStorage.sessionGeneration;
      final profile = await AppApi.getMyProfile();
      if (!mounted) return;
      if (requestedGeneration != TokenStorage.sessionGeneration) {
        retryForNewSession = TokenStorage.isLoggedIn;
        return;
      }
      _replaceWith(
        profile != null ? const MainShell() : const OnboardingPage(),
      );
    } on AppApiException catch (error) {
      if (!mounted) return;
      if (requestedGeneration != null &&
          requestedGeneration != TokenStorage.sessionGeneration) {
        retryForNewSession = TokenStorage.isLoggedIn;
        return;
      }
      // Erros terminais limpam a sessão e emitem um evento global. O Splash
      // não compete com o coordenador por uma segunda navegação.
      if (!TokenStorage.isLoggedIn) return;
      setState(() {
        _unavailableRetryable = error.retryable;
        _unavailableMessage = error.retryable
            ? "Não foi possível acessar o serviço agora. Verifique sua conexão e tente novamente. Sua sessão foi preservada."
            : "Sua conta não pôde ser carregada agora. Você pode sair e entrar com outra conta.";
      });
    } catch (_) {
      if (!mounted) return;
      if (requestedGeneration != null &&
          requestedGeneration != TokenStorage.sessionGeneration) {
        retryForNewSession = TokenStorage.isLoggedIn;
        return;
      }
      if (!TokenStorage.isLoggedIn) return;
      setState(() {
        _unavailableRetryable = true;
        _unavailableMessage =
            "Não foi possível acessar o serviço agora. Verifique sua conexão e tente novamente. Sua sessão foi preservada.";
      });
    } finally {
      _deciding = false;
      if (retryForNewSession && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_decideRoute());
        });
      }
    }
  }

  Future<void> _leaveUnavailableSession() async {
    if (_deciding || _navigating || !TokenStorage.isLoggedIn) return;
    final expectedGeneration = TokenStorage.sessionGeneration;
    final expectedAccessToken = TokenStorage.accessToken;
    final expectedRefreshToken = TokenStorage.refreshToken;
    setState(() => _deciding = true);
    try {
      await PushDeviceService.cleanupForLogout();
      final cleared = await TokenStorage.clearIfCurrent(
        expectedGeneration: expectedGeneration,
        expectedAccessToken: expectedAccessToken,
        expectedRefreshToken: expectedRefreshToken,
      );
      if (!mounted) return;
      if (!cleared && TokenStorage.isLoggedIn) return;
      if (TokenStorage.sessionGeneration != expectedGeneration + 1) return;
      _replaceWith(const LoginPage());
    } finally {
      if (mounted && !_navigating) setState(() => _deciding = false);
    }
  }

  void _replaceWith(Widget next) {
    if (!mounted || _navigating) return;
    _navigating = true;
    unawaited(
      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute(builder: (_) => next),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = _unavailableMessage;
    final retryable = _unavailableRetryable;
    return Scaffold(
      backgroundColor: const Color(0xFF111D40),
      body: SafeArea(
        child: Center(
          child: message == null
              ? const CircularProgressIndicator(color: Colors.white)
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        retryable
                            ? Icons.cloud_off_outlined
                            : Icons.person_off_outlined,
                        color: Colors.white,
                        size: 56,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        retryable
                            ? "Serviço indisponível"
                            : "Conta indisponível",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (retryable)
                        ElevatedButton.icon(
                          onPressed: _deciding ? null : _decideRoute,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Tentar novamente"),
                        )
                      else if (TokenStorage.isLoggedIn)
                        ElevatedButton.icon(
                          onPressed:
                              _deciding ? null : _leaveUnavailableSession,
                          icon: const Icon(Icons.logout),
                          label: const Text("Sair/trocar conta"),
                        ),
                    ],
                  ),
                ),
        ),
      ),
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

@pragma('vm:entry-point')
Future<void> _handleBackgroundNotification(RemoteMessage message) async {
  await Firebase.initializeApp();
  showNotification(message);
}

void showNotification(RemoteMessage message) {
  debugPrint("Notification type: ${message.data["type"]}");
  debugPrint("Other User Id ${message.data["userId"]}");
  debugPrint("MatchId ${message.data["matchId"]}");
}
