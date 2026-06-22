import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/ads_service.dart';
import 'package:mioamoreapp/services/interstitial_manager.dart';
import 'package:mioamoreapp/views/app/ads/app_banner.dart';
import 'package:mioamoreapp/services/chat_socket.dart';
import 'package:mioamoreapp/services/location_service.dart';
import 'package:mioamoreapp/services/realtime_bus.dart';
import 'package:mioamoreapp/services/token_storage.dart';
import 'package:mioamoreapp/helpers/url_launcher_helper.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';
import 'package:mioamoreapp/views/app/discover_page.dart';
import 'package:mioamoreapp/views/app/enable_location_page.dart';
import 'package:mioamoreapp/views/app/likes_page.dart';
import 'package:mioamoreapp/views/app/matches_page.dart';
import 'package:mioamoreapp/views/app/match_celebration.dart';
import 'package:mioamoreapp/views/app/premium_page.dart';
import 'package:mioamoreapp/views/app/profile_page.dart';
import 'package:mioamoreapp/views/auth/login_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _socket = ChatSocket();
  final ValueNotifier<int> _tick = ValueNotifier(0);
  final ValueNotifier<Set<String>> _typingMatches = ValueNotifier(<String>{});
  final Map<String, Timer> _typingTimers = {};
  int _unreadConvos = 0;
  int _newLikes = 0;

  late final List<Widget> _pages = [
    const DiscoverPage(),
    const LikesPage(),
    MatchesPage(
      refreshTick: _tick,
      typingMatches: _typingMatches,
      onUnread: (n) {
        if (mounted) setState(() => _unreadConvos = n);
      },
      onOpenLikes: () {
        if (mounted) setState(() => _index = 1);
      },
      onLikesCount: (n) {
        if (mounted) setState(() => _newLikes = n);
      },
    ),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    // Salva minha foto (pra tela de match) + marca presença online.
    try {
      final p = await AppApi.getMyProfile();
      if (p != null) await TokenStorage.setMyPhoto(p["profilePicture"]?.toString());
      AppApi.setOnline(true);
    } catch (_) {}

    // Carrega config de anúncios (AdMob) e pré-carrega o intersticial.
    AdsService.load().then((_) => InterstitialManager.preload());

    // Push/FCM: pede permissão, registra o token e trata toques nas notificações.
    _setupPush();

    // Pede localização: se ainda não tem permissão, mostra a nossa tela;
    // caso já tenha, só atualiza em silêncio.
    final hasLoc = await LocationService.hasPermission();
    if (!hasLoc && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EnableLocationPage()),
        );
      });
    } else {
      LocationService.refresh(ask: false);
    }

    // Socket global: mensagens/matches em tempo real.
    _socket.connect(
      onMessage: (_) {
        // Chegou mensagem → atualiza a lista de conversas e o badge na hora.
        _tick.value++;
      },
      onRead: (_, __) {
        _tick.value++;
      },
      onTyping: (matchId, userId, isTyping) {
        if (!mounted || matchId.isEmpty) return;
        final s = Set<String>.from(_typingMatches.value);
        _typingTimers[matchId]?.cancel();
        if (isTyping) {
          s.add(matchId);
          // Expira sozinho caso o evento de parada se perca.
          _typingTimers[matchId] =
              Timer(const Duration(seconds: 6), () {
            final cur = Set<String>.from(_typingMatches.value);
            if (cur.remove(matchId)) _typingMatches.value = cur;
          });
        } else {
          s.remove(matchId);
        }
        _typingMatches.value = s;
      },
      onMatch: (data) {
        _tick.value++;
        if (!mounted) return;
        showMatchCelebration(
          context,
          matchId: data["matchId"]?.toString() ?? "",
          otherName: data["name"]?.toString() ?? "Alguém",
          otherPhoto: data["photo"]?.toString(),
          otherUserId: data["withUserId"]?.toString(),
          myPhoto: TokenStorage.myPhoto,
        );
      },
      onNotification: (data) {
        if (!mounted) return;
        final type = data["type"]?.toString() ?? "";
        // Match já é tratado pela tela de celebração (match:new) — evita duplicar.
        if (type == "match") return;
        final title = data["title"]?.toString() ?? "Notificação";
        final body = data["body"]?.toString() ?? "";
        // Destino ao tocar: curtidas abrem a aba Curtidas (não-premium vê borrado
        // e é convidado a assinar lá dentro).
        final bool goesToLikes = type == "like" || type == "superlike";
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.navy,
            behavior: SnackBarBehavior.floating,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                if (body.isNotEmpty)
                  Text(body, style: const TextStyle(color: Colors.white70)),
              ],
            ),
            duration: const Duration(seconds: 4),
            action: goesToLikes
                ? SnackBarAction(
                    label: "Ver",
                    textColor: AppTheme.gold,
                    onPressed: () {
                      messenger.hideCurrentSnackBar();
                      if (mounted) setState(() => _index = 1);
                    },
                  )
                : null,
          ),
        );
      },
      onConfigAds: () {
        // Admin mudou os anúncios no painel → recarrega a config e reflete na hora.
        AdsService.reload();
      },
      onConfigStore: () {
        // Admin mudou planos/presentes/valor do crédito → atualiza a loja na hora.
        RealtimeBus.storeChanged();
      },
      onConfigMe: (data) {
        // Admin mudou minha conta (VIP, créditos, selo, ban...) → reflete na hora.
        if (data.containsKey("isPremium")) {
          AdsService.setPremium(data["isPremium"] == true);
        }
        // Banido ou suspenso → desconecta imediatamente.
        if (data["banned"] == true ||
            data["suspended"] == true ||
            data["deleted"] == true) {
          _forceLogout(
            data["banned"] == true
                ? "Sua conta foi banida."
                : data["deleted"] == true
                    ? "Sua conta foi excluída."
                    : "Sua conta foi suspensa temporariamente.",
          );
          return;
        }
        RealtimeBus.accountChanged(); // recarrega Perfil/Curtidas/Descobrir
        _tick.value++; // e a lista de conversas
      },
    );
  }

  Future<void> _setupPush() async {
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      final token = await fm.getToken();
      if (token != null) await AppApi.registerDevice(token);
      fm.onTokenRefresh.listen((t) => AppApi.registerDevice(t));

      // App em background e aberto ao tocar na notificação.
      FirebaseMessaging.onMessageOpenedApp.listen(_handlePushTap);
      // App fechado (terminado) e aberto por uma notificação.
      final initial = await fm.getInitialMessage();
      if (initial != null) _handlePushTap(initial);
    } catch (_) {}
  }

  /// Ao tocar numa push: reporta o clique (estatística), depois navega.
  /// - data.url        → abre link externo (navegador)
  /// - data.route      → tela interna (discover/likes/chat/profile/plans)
  /// - senão, fallback por type (like/superlike → Curtidas; resto → Chat)
  void _handlePushTap(RemoteMessage m) {
    if (!mounted) return;
    final data = m.data;

    // Estatística de clique (campanhas do painel).
    final broadcastId = data["broadcastId"]?.toString() ?? "";
    if (broadcastId.isNotEmpty) {
      AppApi.reportNotificationClick(broadcastId);
    }

    // Link externo.
    final url = data["url"]?.toString() ?? "";
    if (url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null) UrlLauncherHelper.launchURL(uri);
      return;
    }

    // Tela interna definida pelo painel.
    final route = data["route"]?.toString() ?? "";
    if (route.isNotEmpty) {
      switch (route) {
        case "discover":
          setState(() => _index = 0);
          return;
        case "likes":
          setState(() => _index = 1);
          return;
        case "chat":
          setState(() => _index = 2);
          return;
        case "profile":
          setState(() => _index = 3);
          return;
        case "plans":
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const PremiumPage()));
          return;
      }
    }

    // Fallback pelo tipo da notificação.
    final type = data["type"]?.toString() ?? "";
    if (type == "like" || type == "superlike") {
      setState(() => _index = 1);
    } else {
      setState(() => _index = 2);
    }
  }

  Future<void> _forceLogout(String message) async {
    try {
      await AppApi.setOnline(false);
    } catch (_) {}
    await TokenStorage.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.navy,
        content: Text(message, style: const TextStyle(color: Colors.white)),
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (r) => false,
    );
  }

  @override
  void dispose() {
    _socket.disconnect();
    _tick.dispose();
    for (final t in _typingTimers.values) {
      t.cancel();
    }
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 2),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.local_fire_department_rounded, "Descobrir"),
                _navItem(1, Icons.favorite_rounded, "Curtidas", badge: _newLikes),
                _navItem(2, Icons.chat_bubble_rounded, "Chat",
                    badge: _unreadConvos),
                _navItem(3, Icons.person_rounded, "Perfil"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label, {int badge = 0}) {
    final active = _index == i;
    return GestureDetector(
      onTap: () => setState(() => _index = i),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.gold.withOpacity(0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon,
                    color: active ? AppTheme.gold : const Color(0xFF9AA1B2),
                    size: 24),
                if (badge > 0)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.gold,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        badge > 9 ? "9+" : "$badge",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppTheme.navy,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: active ? AppTheme.navy : const Color(0xFF9AA1B2))),
          ],
        ),
      ),
    );
  }
}
