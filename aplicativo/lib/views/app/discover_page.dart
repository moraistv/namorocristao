import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/analytics_service.dart';
import 'package:mioamoreapp/services/realtime_bus.dart';
import 'package:mioamoreapp/services/token_storage.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';
import 'package:mioamoreapp/views/app/match_celebration.dart';
import 'package:mioamoreapp/views/app/filters_page.dart';
import 'package:mioamoreapp/views/app/premium_page.dart';
import 'package:mioamoreapp/views/app/profile_detail_view.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final _controller = CardSwiperController();
  bool _loading = true;
  String? _error;
  bool _needsProfile = false;
  List<Map<String, dynamic>> _cards = [];
  DiscoverFilters _filters = DiscoverFilters();
  int _superLikesLeft = 0;
  bool _isPremium = false;
  int _boosts = 0;
  String? _pendingSuperNote;

  @override
  void initState() {
    super.initState();
    _load();
    _loadStats();
    RealtimeBus.account.addListener(_onAccountChanged);
  }

  void _onAccountChanged() {
    if (!mounted) return;
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final s = await AppApi.getStats();
      if (!mounted) return;
      setState(() {
        _superLikesLeft = (s["superLikesLeft"] as num?)?.toInt() ?? 0;
        _isPremium = s["isPremium"] == true;
        _boosts = (s["boostsRemaining"] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    RealtimeBus.account.removeListener(_onAccountChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await AppApi.getDiscovery(_filters.toQuery());
      if (res["needsProfile"] == true) {
        setState(() {
          _needsProfile = true;
          _loading = false;
        });
        return;
      }
      setState(() {
        _cards = (res["candidates"] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } on AppApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _swipe(Map<String, dynamic> user, String type) async {
    final note = type == "SUPERLIKE" ? _pendingSuperNote : null;
    _pendingSuperNote = null;
    try {
      final res = await AppApi.swipe(user["id"].toString(), type, note: note);
      AnalyticsService.swipe(type);
      if (type == "SUPERLIKE") _loadStats();
      if (res["matched"] == true && mounted) {
        AnalyticsService.match();
        final w = res["withUser"] as Map?;
        // Deixa a animação do card terminar antes de abrir a tela de match
        // (evita o "travamento"/flicker de abrir o diálogo durante o swipe).
        await Future.delayed(const Duration(milliseconds: 420));
        if (!mounted) return;
        showMatchCelebration(
          context,
          matchId: res["matchId"].toString(),
          otherName: (w?["name"] ?? user["name"]).toString(),
          otherPhoto: (w?["photo"] ?? user["profilePicture"])?.toString(),
          otherUserId: (w?["userId"] ?? user["id"])?.toString(),
          myPhoto: TokenStorage.myPhoto,
        );
      }
    } on AppApiException catch (e) {
      // Limite de super like atingido → oferece o VIP.
      if (e.statusCode == 403 && mounted) {
        _openPremium("Seus Super Likes acabaram por hoje");
        _loadStats();
      }
    } catch (_) {}
  }

  void _openPremium(String highlight) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PremiumPage(highlight: highlight)),
    ).then((_) => _loadStats());
  }

  /// Tenta dar super like: se não houver saldo e não for premium, abre o VIP.
  Future<void> _trySuperLike() async {
    if (!_isPremium && _superLikesLeft <= 0) {
      _openPremium("Tenha mais Super Likes com o VIP");
      return;
    }
    final note = await _askSuperNote();
    if (note == null) return; // cancelou
    _pendingSuperNote = note.isEmpty ? null : note;
    _controller.swipe(CardSwiperDirection.top);
  }

  /// Diálogo do Super Like com recado opcional. Retorna o texto, "" (sem recado) ou null (cancelar).
  Future<String?> _askSuperNote() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          Icon(Icons.star_rounded, color: AppTheme.gold),
          const SizedBox(width: 8),
          const Text("Super Like"),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Mande um recado junto com seu Super Like (opcional). Quem recebe vê sua mensagem!",
              style: TextStyle(fontSize: 13, color: Color(0xFF7A849C)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLength: 200,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: "Ex.: Adorei seu perfil! 🙏",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancelar")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ""),
              child: const Text("Sem recado")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold, foregroundColor: AppTheme.navy),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text("Enviar"),
          ),
        ],
      ),
    );
  }

  /// Rewind: desfaz o último swipe (VIP, configurável).
  Future<void> _rewind() async {
    try {
      await AppApi.undoSwipe();
      EasyLoading.showSuccess("Swipe desfeito");
      _load();
    } on AppApiException catch (e) {
      if (e.statusCode == 403) {
        _openPremium("O Rewind é VIP — desfaça quem você passou!");
      } else {
        EasyLoading.showInfo(e.message);
      }
    }
  }

  /// Boost/Turbo: destaque na descoberta.
  Future<void> _boost() async {
    if (_boosts <= 0) {
      _openPremium("Compre Boosts para se destacar no topo! 🚀");
      return;
    }
    try {
      final res = await AppApi.activateBoost();
      AnalyticsService.boost();
      _loadStats();
      final min = res["minutes"] ?? 30;
      EasyLoading.showSuccess("Você está em destaque por $min min! 🚀");
    } on AppApiException catch (e) {
      if (e.statusCode == 403) {
        _openPremium("Compre Boosts para se destacar! 🚀");
      } else {
        EasyLoading.showInfo(e.message);
      }
    }
  }

  bool _onSwipe(int prev, int? current, CardSwiperDirection dir) {
    final user = _cards[prev];
    if (dir == CardSwiperDirection.right) {
      _swipe(user, "LIKE");
    } else if (dir == CardSwiperDirection.left) {
      _swipe(user, "DISLIKE");
    } else if (dir == CardSwiperDirection.top) {
      _swipe(user, "SUPERLIKE");
    }
    return true;
  }

  void _openProfile(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileDetailView(
          user: user,
          withActions: true,
          onLike: () => _controller.swipe(CardSwiperDirection.right),
          onNope: () => _controller.swipe(CardSwiperDirection.left),
          onSuper: () => _controller.swipe(CardSwiperDirection.top),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          AppTabHeader(
            title: "Descobrir",
            icon: Icons.local_fire_department_rounded,
            actions: [
              IconButton(
                onPressed: () => _openPremium(
                    "Aproveite o máximo da sua jornada no amor 🙏"),
                icon: Icon(Icons.workspace_premium,
                    color: _isPremium ? AppTheme.gold : AppTheme.navy),
                tooltip: "VIP",
              ),
              IconButton(
                onPressed: () async {
                  final result = await Navigator.push<DiscoverFilters>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FiltersPage(filters: _filters)),
                  );
                  if (result != null) {
                    setState(() => _filters = result);
                    _load();
                  }
                },
                icon: const Icon(Icons.tune, color: AppTheme.navy),
              ),
              IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, color: AppTheme.navy)),
            ],
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_needsProfile) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(30),
        child: Text("Complete seu perfil para ver pessoas.",
            textAlign: TextAlign.center),
      ));
    }
    if (_error != null) return Center(child: Text(_error!));
    if (_cards.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(30),
        child: Text("Ninguém por aqui agora.\nVolte mais tarde! 🙏",
            textAlign: TextAlign.center),
      ));
    }

    return Column(
      children: [
        Expanded(
          child: CardSwiper(
            controller: _controller,
            cardsCount: _cards.length,
            numberOfCardsDisplayed: 1,
            isLoop: false,
            scale: 1.0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            allowedSwipeDirection:
                const AllowedSwipeDirection.only(left: true, right: true, up: true),
            onSwipe: _onSwipe,
            onEnd: _load,
            cardBuilder: (context, index, px, py) => _DiscoverCard(
              user: _cards[index],
              percentX: px,
              percentY: py,
              onOpenProfile: () => _openProfile(_cards[index]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _smallBtn(Icons.replay, const Color(0xFFF5A623), _rewind),
              const SizedBox(width: 16),
              _actionBtn(Icons.close, Colors.white, AppTheme.navy,
                  () => _controller.swipe(CardSwiperDirection.left)),
              const SizedBox(width: 16),
              _superLikeBtn(),
              const SizedBox(width: 16),
              _actionBtn(Icons.favorite, AppTheme.gold, Colors.white,
                  () => _controller.swipe(CardSwiperDirection.right)),
              const SizedBox(width: 16),
              _smallBtn(Icons.bolt, const Color(0xFF7B61FF), _boost),
            ],
          ),
        ),
      ],
    );
  }

  Widget _smallBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _superLikeBtn() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _actionBtn(Icons.star, AppTheme.navy, Colors.white, _trySuperLike),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.gold,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              _isPremium ? "∞" : "$_superLikesLeft",
              style: const TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Icon(icon, color: fg, size: 28),
      ),
    );
  }
}

class _DiscoverCard extends StatefulWidget {
  final Map<String, dynamic> user;
  final int percentX;
  final int percentY;
  final VoidCallback onOpenProfile;
  const _DiscoverCard({
    required this.user,
    required this.percentX,
    required this.percentY,
    required this.onOpenProfile,
  });
  @override
  State<_DiscoverCard> createState() => _DiscoverCardState();
}

class _DiscoverCardState extends State<_DiscoverCard> {
  int _photo = 0;

  List<String> get _photos {
    final media = (widget.user["mediaFiles"] as List?)?.cast<String>() ?? [];
    if (media.isNotEmpty) return media;
    final pic = widget.user["profilePicture"];
    return pic != null ? [pic.toString()] : [];
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final photos = _photos;
    final match = u["matchPercent"];
    final px = widget.percentX;
    final py = widget.percentY;

    // Feedback de arraste
    Color? overlayColor;
    String? overlayLabel;
    IconData? overlayIcon;
    double overlayStrength = 0;
    if (py < -8 && py.abs() > px.abs()) {
      overlayColor = AppTheme.navy; // super like
      overlayLabel = "SUPER";
      overlayIcon = Icons.star;
      overlayStrength = (py.abs() / 100).clamp(0, 1).toDouble();
    } else if (px > 8) {
      overlayColor = const Color(0xFF2E9E5B); // curtir (verde/dourado)
      overlayLabel = "CURTIR";
      overlayIcon = Icons.favorite;
      overlayStrength = (px / 100).clamp(0, 1).toDouble();
    } else if (px < -8) {
      overlayColor = const Color(0xFF1B2440); // descartar (escuro/azul)
      overlayLabel = "NÃO";
      overlayIcon = Icons.close;
      overlayStrength = (px.abs() / 100).clamp(0, 1).toDouble();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isNotEmpty)
            CachedNetworkImage(
              imageUrl: photos[_photo % photos.length],
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: const Color(0xFFE8EAF0)),
              errorWidget: (_, __, ___) => Container(color: const Color(0xFFE8EAF0)),
            )
          else
            Container(color: const Color(0xFFE8EAF0)),

          // Zonas de toque: laterais trocam foto, centro abre o perfil
          Positioned.fill(
            child: Row(children: [
              Expanded(
                flex: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: photos.length > 1
                      ? () => setState(() => _photo--)
                      : widget.onOpenProfile,
                ),
              ),
              Expanded(
                flex: 3,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: widget.onOpenProfile,
                ),
              ),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: photos.length > 1
                      ? () => setState(() => _photo++)
                      : widget.onOpenProfile,
                ),
              ),
            ]),
          ),

          if (photos.length > 1)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: List.generate(
                  photos.length,
                  (i) => Expanded(
                    child: Container(
                      height: 3.5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i == _photo % photos.length
                            ? Colors.white
                            : Colors.white38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Badge de distância em "vidro" (glassmorphism) no topo.
          if (u["distanceKm"] != null)
            Positioned(
              top: photos.length > 1 ? 28 : 16,
              left: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.4), width: 1.5),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.near_me, color: Colors.white, size: 15),
                      const SizedBox(width: 6),
                      Text("${u["distanceKm"]} Km",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ]),
                  ),
                ),
              ),
            ),

          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC0B1228)],
                ),
              ),
            ),
          ),

          // Overlay de feedback (cor + blur + label)
          if (overlayColor != null && overlayStrength > 0.02)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 8 * overlayStrength,
                    sigmaY: 8 * overlayStrength,
                  ),
                  child: Container(
                    color: overlayColor.withOpacity(0.45 * overlayStrength),
                    child: Center(
                      child: Opacity(
                        opacity: overlayStrength.clamp(0, 1),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(overlayIcon, color: Colors.white, size: 64),
                            const SizedBox(height: 8),
                            Text(overlayLabel!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (match is num)
            const SizedBox.shrink(),

          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onOpenProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(children: [
                  Flexible(
                    child: Text("${u["name"]}, ${u["age"]}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (u["isVerified"] == true) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.verified, color: AppTheme.gold, size: 22),
                  ],
                  if (match is num) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.gold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("$match%",
                          style: const TextStyle(
                              color: AppTheme.navy,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ],
                ]),
                if (_infoLine(u) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      const Icon(Icons.location_on,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _infoLine(u)!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ),
                      if (onlineLabel(u["isOnline"], u["lastActiveAt"]) != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Color(0xFF2ECC71), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(onlineLabel(u["isOnline"], u["lastActiveAt"])!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12.5)),
                      ],
                    ]),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (u["denomination"] != null)
                      _tag(Icons.book, u["denomination"].toString()),
                    if (u["intention"] != null)
                      _tag(Icons.favorite, u["intention"].toString()),
                  ],
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }

  String? _infoLine(Map<String, dynamic> u) {
    final city = u["city"]?.toString();
    final dist = u["distanceKm"];
    final parts = <String>[];
    if (city != null && city.isNotEmpty) parts.add(city);
    if (dist != null) parts.add("$dist km");
    return parts.isEmpty ? null : parts.join(" · ");
  }

  Widget _tag(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white38, width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}
