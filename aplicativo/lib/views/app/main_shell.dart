import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mioamoreapp/helpers/url_launcher_helper.dart';
import 'package:mioamoreapp/services/ads_service.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/chat_socket.dart';
import 'package:mioamoreapp/services/interstitial_manager.dart';
import 'package:mioamoreapp/services/location_service.dart';
import 'package:mioamoreapp/services/push_device_service.dart';
import 'package:mioamoreapp/services/realtime_bus.dart';
import 'package:mioamoreapp/services/token_storage.dart';
import 'package:mioamoreapp/views/app/ads/app_banner.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';
import 'package:mioamoreapp/views/app/chat_page.dart';
import 'package:mioamoreapp/views/app/discover_page.dart';
import 'package:mioamoreapp/views/app/enable_location_page.dart';
import 'package:mioamoreapp/views/app/likes_page.dart';
import 'package:mioamoreapp/views/app/match_celebration.dart';
import 'package:mioamoreapp/views/app/matches_page.dart';
import 'package:mioamoreapp/views/app/profile_page.dart';
import 'package:mioamoreapp/views/app/rewards_page.dart';
import 'package:mioamoreapp/views/auth/login_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  final _socket = ChatSocket();
  final ValueNotifier<int> _tick = ValueNotifier(0);
  final ValueNotifier<Set<String>> _typingMatches = ValueNotifier(<String>{});
  final Map<String, Timer> _typingTimers = {};
  final Set<String> _reportedBroadcastClicks = <String>{};
  StreamSubscription<String>? _fcmTokenSubscription;
  StreamSubscription<RemoteMessage>? _fcmOpenedSubscription;
  StreamSubscription<RemoteMessage>? _fcmForegroundSubscription;
  Timer? _presenceHeartbeat;
  Future<void>? _pushSetupInFlight;
  int _unreadConvos = 0;
  int _newLikes = 0;
  bool _socketStarted = false;
  bool _isLoggingOut = false;
  bool _rerunPushSetup = false;
  bool _initialPushHandled = false;
  bool _isResumed = true;
  bool _presenceInFlight = false;
  bool? _pendingPresence;
  bool? _lastPresenceTarget;

  late final List<Widget> _pages = [
    const DiscoverPage(),
    const LikesPage(),
    MatchesPage(
      refreshTick: _tick,
      typingMatches: _typingMatches,
      onUnread: (count) {
        if (mounted) setState(() => _unreadConvos = count);
      },
      onOpenLikes: () {
        if (mounted) setState(() => _index = 1);
      },
      onLikesCount: (count) {
        if (mounted) setState(() => _newLikes = count);
      },
    ),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isResumed = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    RealtimeBus.notifications.addListener(_onNotificationPreferenceChanged);
    if (_isResumed) _resumePresence();
    unawaited(_setup());
  }

  void _onNotificationPreferenceChanged() {
    if (!mounted || _isLoggingOut) return;
    unawaited(_setupPush());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isLoggingOut || !TokenStorage.isLoggedIn) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _resumePresence();
        if (_socketStarted) _socket.reconnectWithLatestToken();
        if (TokenStorage.notificationsEnabled) {
          unawaited(_refreshPushRegistration());
        }
        break;
      case AppLifecycleState.inactive:
        // Transições breves (permissões/overlays do sistema) não mudam presença.
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _pausePresence();
        break;
    }
  }

  void _resumePresence() {
    if (_isLoggingOut || !TokenStorage.isLoggedIn) return;
    _isResumed = true;
    _requestPresence(true, force: true);
    _presenceHeartbeat ??= Timer.periodic(const Duration(seconds: 45), (_) {
      if (_isResumed && !_isLoggingOut && TokenStorage.isLoggedIn) {
        _requestPresence(true, force: true);
      }
    });
  }

  void _pausePresence() {
    if (!_isResumed && _presenceHeartbeat == null) return;
    _isResumed = false;
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = null;
    _requestPresence(false);
  }

  void _requestPresence(bool online, {bool force = false}) {
    if (!TokenStorage.isLoggedIn || (_isLoggingOut && online)) return;
    if (_presenceInFlight) {
      _pendingPresence = online;
      return;
    }
    if (!force && _lastPresenceTarget == online) return;

    _lastPresenceTarget = online;
    _presenceInFlight = true;
    unawaited(_sendPresence(online));
  }

  Future<void> _sendPresence(bool online) async {
    try {
      await AppApi.setOnline(online);
    } catch (error) {
      debugPrint("Não foi possível atualizar presença ($online): $error");
    } finally {
      _presenceInFlight = false;
      final pending = _pendingPresence;
      _pendingPresence = null;
      if (pending != null &&
          pending != _lastPresenceTarget &&
          TokenStorage.isLoggedIn) {
        _requestPresence(pending, force: true);
      }
    }
  }

  Future<void> _setup() async {
    try {
      final profile = await AppApi.getMyProfile();
      if (profile != null) {
        await TokenStorage.setMyPhoto(profile["profilePicture"]?.toString());
      }
    } catch (error) {
      debugPrint("Não foi possível carregar o perfil no shell: $error");
    }
    if (!mounted || _isLoggingOut) return;

    unawaited(
      AdsService.load().then((_) => InterstitialManager.preload()),
    );
    unawaited(_setupPush());
    _connectSocket();

    bool hasLocation;
    try {
      hasLocation = await LocationService.hasPermission();
    } catch (error) {
      debugPrint(
          "Não foi possível verificar a permissão de localização: $error");
      return;
    }
    if (!mounted || _isLoggingOut) return;
    if (!hasLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || _isLoggingOut) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EnableLocationPage()),
        );
      });
    } else {
      unawaited(LocationService.refresh(ask: false));
    }
  }

  void _connectSocket() {
    if (_socketStarted || _isLoggingOut) return;
    _socketStarted = true;
    _socket.connect(
      onMessage: (_) {
        _tick.value++;
      },
      onRead: (_, __) {
        _tick.value++;
      },
      onTyping: (matchId, userId, isTyping) {
        if (!mounted || matchId.isEmpty || userId == TokenStorage.userId) {
          return;
        }
        final typing = Set<String>.from(_typingMatches.value);
        _typingTimers.remove(matchId)?.cancel();
        if (isTyping) {
          typing.add(matchId);
          _typingTimers[matchId] = Timer(const Duration(seconds: 6), () {
            _typingTimers.remove(matchId);
            if (!mounted) return;
            final current = Set<String>.from(_typingMatches.value);
            if (current.remove(matchId)) _typingMatches.value = current;
          });
        } else {
          typing.remove(matchId);
        }
        _typingMatches.value = typing;
      },
      onMatch: (data) {
        _tick.value++;
        if (!mounted) return;
        unawaited(
          showMatchCelebration(
            context,
            matchId: data["matchId"]?.toString() ?? "",
            otherName: data["name"]?.toString() ?? "Alguém",
            otherPhoto: data["photo"]?.toString(),
            otherUserId: data["withUserId"]?.toString(),
            myPhoto: TokenStorage.myPhoto,
            otherIsVirtual: data["isVirtual"] == true || data["isBot"] == true,
          ),
        );
      },
      onNotification: _showNotificationSnack,
      onConfigAds: AdsService.reload,
      onConfigStore: RealtimeBus.storeChanged,
      onConfigMe: (data) {
        if (data.containsKey("isPremium")) {
          AdsService.setPremium(data["isPremium"] == true);
        }
        if (data["banned"] == true ||
            data["suspended"] == true ||
            data["deleted"] == true) {
          unawaited(
            _forceLogout(
              data["banned"] == true
                  ? "Sua conta foi banida."
                  : data["deleted"] == true
                      ? "Sua conta foi excluída."
                      : "Sua conta foi suspensa temporariamente.",
            ),
          );
          return;
        }
        RealtimeBus.accountChanged();
        _tick.value++;
      },
    );
  }

  String? get _devicePlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return "android";
      case TargetPlatform.iOS:
        return "ios";
      default:
        return null;
    }
  }

  Future<void> _setupPush() {
    final running = _pushSetupInFlight;
    if (running != null) {
      _rerunPushSetup = true;
      return running;
    }

    final future = _performPushSetup();
    _pushSetupInFlight = future;
    void complete() {
      if (!identical(_pushSetupInFlight, future)) return;
      _pushSetupInFlight = null;
      if (_rerunPushSetup && mounted && !_isLoggingOut) {
        _rerunPushSetup = false;
        unawaited(_setupPush());
      }
    }

    future.then<void>((_) => complete(), onError: (_, __) => complete());
    return future;
  }

  Future<void> _performPushSetup() async {
    await _cancelPushSubscriptions();

    if (!TokenStorage.notificationsEnabled) {
      final cleanup = await PushDeviceService.reconcileDisabledNotifications();
      if (cleanup.remoteRemovalPending) {
        debugPrint("A remoção remota do token FCM permanece pendente.");
      }
      return;
    }

    final platform = _devicePlatform;
    if (platform == null) {
      await PushDeviceService.disableNotifications();
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) {
        await PushDeviceService.disableNotifications();
        return;
      }
      if (!mounted || _isLoggingOut || !TokenStorage.notificationsEnabled) {
        return;
      }

      await _refreshPushRegistration();
      if (!mounted || _isLoggingOut || !TokenStorage.notificationsEnabled) {
        return;
      }

      _fcmTokenSubscription = messaging.onTokenRefresh.listen((token) {
        if (TokenStorage.notificationsEnabled && !_isLoggingOut) {
          unawaited(_registerPushToken(token));
        }
      });
      _fcmOpenedSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen(_handlePushTap);
      _fcmForegroundSubscription =
          FirebaseMessaging.onMessage.listen(_handleForegroundPush);

      if (!_initialPushHandled) {
        _initialPushHandled = true;
        final initial = await messaging.getInitialMessage();
        if (initial != null && mounted && !_isLoggingOut) {
          _handlePushTap(initial);
        }
      }
    } catch (error) {
      debugPrint("Não foi possível configurar notificações: $error");
    }
  }

  Future<void> _refreshPushRegistration() async {
    final platform = _devicePlatform;
    if (platform == null ||
        !TokenStorage.notificationsEnabled ||
        _isLoggingOut ||
        !TokenStorage.isLoggedIn) {
      return;
    }
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerPushToken(token);
      }
    } catch (error) {
      debugPrint("Não foi possível atualizar o token de push: $error");
    }
  }

  Future<void> _registerPushToken(String token) async {
    final platform = _devicePlatform;
    if (platform == null ||
        token.isEmpty ||
        !TokenStorage.notificationsEnabled ||
        _isLoggingOut ||
        !TokenStorage.isLoggedIn) {
      return;
    }

    try {
      final result = await PushDeviceService.registerToken(
        token,
        platform: platform,
      );
      if (result.cleanupPending) {
        debugPrint("Há uma remoção remota de token FCM pendente.");
      }
    } catch (error) {
      debugPrint("Não foi possível registrar o token FCM: $error");
    }
  }

  void _handleForegroundPush(RemoteMessage message) {
    if (!mounted || _isLoggingOut) return;
    final data = Map<String, dynamic>.from(message.data);
    if (data["type"]?.toString() == "match") {
      // O evento socket `match:new` já abre a celebração.
      return;
    }
    _showNotificationSnack(
      data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }

  void _showNotificationSnack(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    if (!mounted || _isLoggingOut || data["type"]?.toString() == "match") {
      return;
    }
    final resolvedTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : data["title"]?.toString().trim().isNotEmpty == true
            ? data["title"].toString().trim()
            : "Nova atividade";
    final resolvedBody = body?.trim().isNotEmpty == true
        ? body!.trim()
        : data["body"]?.toString().trim() ?? "";
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.navy,
        behavior: SnackBarBehavior.floating,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              resolvedTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (resolvedBody.isNotEmpty)
              Text(
                resolvedBody,
                style: const TextStyle(color: Colors.white70),
              ),
          ],
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: "Ver",
          textColor: AppTheme.gold,
          onPressed: () {
            messenger.hideCurrentSnackBar();
            unawaited(_handlePushData(data));
          },
        ),
      ),
    );
  }

  void _handlePushTap(RemoteMessage message) {
    unawaited(_handlePushData(Map<String, dynamic>.from(message.data)));
  }

  Future<void> _handlePushData(Map<String, dynamic> data) async {
    if (!mounted || _isLoggingOut) return;

    final broadcastId = data["broadcastId"]?.toString() ?? "";
    if (broadcastId.isNotEmpty) {
      unawaited(_reportBroadcastClickOnce(broadcastId));
    }

    final url = data["url"]?.toString() ?? "";
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.scheme == "https" && uri.host.isNotEmpty) {
        await UrlLauncherHelper.launchURL(uri);
        return;
      }
    }

    final matchId = data["matchId"]?.toString() ?? "";
    if (matchId.isNotEmpty) {
      await _openMatchFromPush(matchId);
      return;
    }

    final route = data["route"]?.toString() ?? "";
    switch (route) {
      case "discover":
        if (mounted) setState(() => _index = 0);
        return;
      case "likes":
        if (mounted) setState(() => _index = 1);
        return;
      case "chat":
        if (mounted) setState(() => _index = 2);
        return;
      case "profile":
        if (mounted) setState(() => _index = 3);
        return;
      // "plans" é o destino antigo (loja paga): hoje leva às recompensas.
      case "rewards":
      case "plans":
        if (mounted && AdsService.rewardedAvailable) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RewardsPage()),
          );
        } else if (mounted) {
          setState(() => _index = 3);
        }
        return;
    }

    final type = data["type"]?.toString() ?? "";
    if (mounted) {
      setState(() => _index = type == "like" || type == "superlike" ? 1 : 2);
    }
  }

  Future<void> _reportBroadcastClickOnce(String broadcastId) async {
    if (!_reportedBroadcastClicks.add(broadcastId)) return;
    try {
      await AppApi.reportNotificationClick(broadcastId);
    } catch (error) {
      debugPrint("Não foi possível registrar o clique da notificação: $error");
    }
  }

  Future<void> _openMatchFromPush(String matchId) async {
    Map<String, dynamic>? match;
    try {
      final matches = await AppApi.getMatches();
      for (final item in matches.whereType<Map>()) {
        final candidate = Map<String, dynamic>.from(item);
        final candidateId =
            candidate["matchId"]?.toString() ?? candidate["id"]?.toString();
        if (candidateId == matchId) {
          match = candidate;
          break;
        }
      }
    } catch (error) {
      debugPrint("Não foi possível localizar a conversa do push: $error");
    }

    if (!mounted || _isLoggingOut) return;
    setState(() => _index = 2);
    if (match == null) return;

    final otherRaw = match["otherUser"];
    final other = otherRaw is Map
        ? Map<String, dynamic>.from(otherRaw)
        : <String, dynamic>{};
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          matchId: matchId,
          otherName: other["name"]?.toString() ?? "Usuário",
          otherPhoto: other["profilePicture"]?.toString(),
          otherUserId: other["id"]?.toString() ?? other["userId"]?.toString(),
          otherIsVirtual: other["isVirtual"] == true || other["isBot"] == true,
        ),
      ),
    );
    if (mounted) _tick.value++;
  }

  Future<void> _cancelPushSubscriptions() async {
    await _fcmTokenSubscription?.cancel();
    await _fcmOpenedSubscription?.cancel();
    await _fcmForegroundSubscription?.cancel();
    _fcmTokenSubscription = null;
    _fcmOpenedSubscription = null;
    _fcmForegroundSubscription = null;
  }

  Future<void> _setOfflineForLogout() async {
    try {
      await AppApi.setOnline(false).timeout(const Duration(seconds: 2));
    } catch (error) {
      debugPrint("Não foi possível encerrar a presença: $error");
    }
  }

  Future<void> _forceLogout(
    String message, {
    bool cleanupRemote = true,
    bool clearSession = true,
  }) async {
    if (_isLoggingOut) return;
    final expectedGeneration = TokenStorage.sessionGeneration;
    final expectedAccessToken = TokenStorage.accessToken;
    final expectedRefreshToken = TokenStorage.refreshToken;
    _isLoggingOut = true;
    _isResumed = false;
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = null;
    _socket.disconnect();
    _socketStarted = false;

    if (cleanupRemote) {
      await Future.wait<void>([
        _setOfflineForLogout(),
        PushDeviceService.cleanupForLogout().then<void>((_) {}),
      ]);
    }
    await _cancelPushSubscriptions();
    var cleared = false;
    if (clearSession) {
      cleared = await TokenStorage.clearIfCurrent(
        expectedGeneration: expectedGeneration,
        expectedAccessToken: expectedAccessToken,
        expectedRefreshToken: expectedRefreshToken,
      );
    }

    if (!mounted) return;
    if (clearSession) {
      if (!cleared && TokenStorage.isLoggedIn) return;
      if (TokenStorage.sessionGeneration != expectedGeneration + 1) return;
    } else if (TokenStorage.sessionGeneration != expectedGeneration ||
        TokenStorage.accessToken != expectedAccessToken ||
        TokenStorage.refreshToken != expectedRefreshToken) {
      return;
    }

    if (!clearSession || cleared) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.navy,
          content: Text(message, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    RealtimeBus.notifications.removeListener(_onNotificationPreferenceChanged);
    _isResumed = false;
    _presenceHeartbeat?.cancel();
    _presenceHeartbeat = null;
    if (!_isLoggingOut && TokenStorage.isLoggedIn) {
      _requestPresence(false, force: true);
    }
    unawaited(_cancelPushSubscriptions());
    _socket.disconnect();
    _tick.dispose();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _typingMatches.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          Expanded(child: IndexedStack(index: _index, children: _pages)),
          const AppBannerAd(),
        ],
      ),
      bottomNavigationBar: Material(
        color: Colors.white,
        elevation: 12,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 2),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
            child: Row(
              children: [
                _navItem(0, Icons.local_fire_department_rounded, "Descobrir"),
                _navItem(
                  1,
                  Icons.favorite_rounded,
                  "Curtidas",
                  badge: _newLikes,
                ),
                _navItem(
                  2,
                  Icons.chat_bubble_rounded,
                  "Chat",
                  badge: _unreadConvos,
                ),
                _navItem(3, Icons.person_rounded, "Perfil"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label, {int badge = 0}) {
    final active = _index == index;
    final semanticsLabel =
        badge > 0 ? "$label, ${badge > 9 ? "mais de 9" : badge} novas" : label;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: semanticsLabel,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _index = index),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.gold.withOpacity(0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon,
                        color: active ? AppTheme.gold : const Color(0xFF9AA1B2),
                        size: 24,
                      ),
                      if (badge > 0)
                        Positioned(
                          right: -8,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.gold,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              badge > 9 ? "9+" : "$badge",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppTheme.navy,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: active ? AppTheme.navy : const Color(0xFF9AA1B2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
