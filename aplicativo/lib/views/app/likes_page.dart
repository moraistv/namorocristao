import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:mioamoreapp/services/ads_service.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/public_url.dart';
import 'package:mioamoreapp/services/realtime_bus.dart';
import 'package:mioamoreapp/services/token_storage.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';
import 'package:mioamoreapp/views/app/chat_page.dart';
import 'package:mioamoreapp/views/app/match_celebration.dart';
import 'package:mioamoreapp/views/app/profile_detail_view.dart';
import 'package:mioamoreapp/views/app/rewards_page.dart';

class LikesPage extends StatefulWidget {
  const LikesPage({super.key});
  @override
  State<LikesPage> createState() => _LikesPageState();
}

class _LikesPageState extends State<LikesPage> {
  bool _loading = true;
  bool _premium = false;
  List<dynamic> _matches = [];
  List<dynamic> _likedYou = [];
  List<dynamic> _topPicks = [];
  bool _loadingPicks = true;
  bool _pickSwipeInFlight = false;
  int _loadGeneration = 0;
  int _picksLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadTopPicks());
    RealtimeBus.account.addListener(_onAccountChanged);
  }

  void _onAccountChanged() {
    if (!mounted) return;
    unawaited(_load());
  }

  @override
  void dispose() {
    RealtimeBus.account.removeListener(_onAccountChanged);
    super.dispose();
  }

  Future<void> _loadTopPicks() async {
    final generation = ++_picksLoadGeneration;
    if (!mounted) return;
    setState(() => _loadingPicks = true);
    try {
      final picks = await AppApi.getTopPicks();
      if (!mounted || generation != _picksLoadGeneration) return;
      setState(() {
        _topPicks = picks;
        _loadingPicks = false;
      });
    } catch (_) {
      if (!mounted || generation != _picksLoadGeneration) return;
      setState(() => _loadingPicks = false);
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final response = await AppApi.getLikes();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _premium = response["isPremium"] == true;
        _matches = (response["matches"] as List?) ?? [];
        _likedYou = (response["likedYou"] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _loading = false);
    }
  }

  /// Ver quem curtiu é exclusivo VIP (concedido pela equipe); não há compra.
  Future<void> _showVipOnlyInfo() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          Icon(Icons.workspace_premium, color: AppTheme.gold),
          const SizedBox(width: 8),
          const Text("Recurso VIP"),
        ]),
        content: const Text(
          "Ver quem já te curtiu é um recurso exclusivo para usuários VIP.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Entendi"),
          ),
        ],
      ),
    );
  }

  /// Leva às recompensas por anúncio quando os Super Likes acabam.
  Future<void> _openRewardsForSuperLikes() async {
    if (!AdsService.rewardedAvailable) {
      EasyLoading.showInfo("Seus Super Likes de hoje acabaram. Volte amanhã!");
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RewardsPage(
          highlight:
              "Seus Super Likes acabaram. Assista a um anúncio e ganhe mais.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          children: [
            AppTabHeader(
              title: "Curtidas",
              icon: Icons.favorite_rounded,
              actions: [
                if (_premium)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: AppTheme.gold.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.workspace_premium,
                            color: AppTheme.gold, size: 16),
                        const SizedBox(width: 4),
                        const Text("VIP",
                            style: TextStyle(
                                color: AppTheme.navy,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ]),
                    ),
                  ),
              ],
            ),
            TabBar(
              labelColor: AppTheme.navy,
              unselectedLabelColor: const Color(0xFF9AA1B2),
              indicatorColor: AppTheme.gold,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: "Curtidas (${_likedYou.length})"),
                const Tab(text: "Top Picks"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _likesTab(),
                  _topPicksTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _likesTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator())),
          if (!_loading) ...[
            _sectionTitle("Quem te curtiu (${_likedYou.length})"),
            if (_likedYou.isEmpty)
              _emptyText("Ninguém te curtiu ainda. Continue descobrindo!")
            else
              _grid(_likedYou, locked: !_premium),
            const SizedBox(height: 24),
            _sectionTitle("Seus matches (${_matches.length})"),
            if (_matches.isEmpty)
              _emptyText("Sem matches ainda.")
            else
              _grid(_matches, locked: false),
          ],
        ],
      ),
    );
  }

  Widget _topPicksTab() {
    return RefreshIndicator(
      onRefresh: _loadTopPicks,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.gold, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  "Selecionamos perfis mais compatíveis com você",
                  style: TextStyle(color: Color(0xFF7A849C), fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingPicks)
            const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator())),
          if (!_loadingPicks && _topPicks.isEmpty)
            _emptyText("Sem sugestões agora. Volte mais tarde! 🙏"),
          if (!_loadingPicks && _topPicks.isNotEmpty) _picksGrid(),
        ],
      ),
    );
  }

  Widget _picksGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.72,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: _topPicks.map(_pickCard).toList(),
    );
  }

  Widget _pickCard(dynamic u) {
    final photos = (u["mediaFiles"] as List?)?.cast<String>() ?? [];
    final photo =
        photos.isNotEmpty ? photos.first : u["profilePicture"]?.toString();
    final name = u["name"]?.toString() ?? "";
    final age = u["age"];
    final match = u["matchPercent"];
    final isVirtual = u["isVirtual"] == true || u["isBot"] == true;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileDetailView(
              user: Map<String, dynamic>.from(u as Map),
              withActions: true,
              onLike: () => _pickSwipe(u, "LIKE"),
              onNope: () => _pickSwipe(u, "DISLIKE"),
              onSuper: () => _pickSwipe(u, "SUPERLIKE"),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null)
              CachedNetworkImage(
                imageUrl: PublicUrl.media(photo),
                fit: BoxFit.cover,
              )
            else
              Container(color: AppTheme.navy),
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
            if (isVirtual)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Perfil virtual • IA",
                    style: TextStyle(
                      color: AppTheme.navy,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (match is num)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppTheme.gold,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text("$match%",
                      style: const TextStyle(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                "$name${age != null ? ", $age" : ""}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSwipe(dynamic user, String type) async {
    if (_pickSwipeInFlight) return;
    String? note;
    if (type == "SUPERLIKE") {
      try {
        final stats = await AppApi.getStats();
        final premium = stats["isPremium"] == true;
        final remaining = (stats["superLikesLeft"] as num?)?.toInt() ?? 0;
        if (!premium && remaining <= 0) {
          if (mounted) await _openRewardsForSuperLikes();
          return;
        }
      } on AppApiException catch (error) {
        EasyLoading.showError(error.message);
        return;
      }

      note = await _askPickSuperNote();
      if (note == null || !mounted) return;
    }

    _pickSwipeInFlight = true;
    EasyLoading.show(status: "Registrando sua escolha...");
    try {
      final response = await AppApi.swipe(
        user["id"].toString(),
        type,
        note: note,
      );
      EasyLoading.dismiss();
      if (!mounted) return;

      if (response["matched"] == true) {
        final withUser = response["withUser"] as Map?;
        await showMatchCelebration(
          context,
          matchId: response["matchId"].toString(),
          otherName: (withUser?["name"] ?? user["name"]).toString(),
          otherPhoto:
              (withUser?["photo"] ?? user["profilePicture"])?.toString(),
          otherUserId: (withUser?["userId"] ?? user["id"])?.toString(),
          myPhoto: TokenStorage.myPhoto,
          otherIsVirtual: withUser?["isVirtual"] == true ||
              withUser?["isBot"] == true ||
              user["isVirtual"] == true ||
              user["isBot"] == true,
        );
      }
      if (mounted) await _loadTopPicks();
    } on AppApiException catch (error) {
      EasyLoading.dismiss();
      if (mounted) EasyLoading.showError(error.message);
      if (error.statusCode == 403 && mounted && type == "SUPERLIKE") {
        await _openRewardsForSuperLikes();
      }
    } catch (_) {
      EasyLoading.dismiss();
      if (mounted) {
        EasyLoading.showError(
          "Não foi possível registrar sua escolha. Tente novamente.",
        );
      }
    } finally {
      _pickSwipeInFlight = false;
    }
  }

  Future<String?> _askPickSuperNote() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Super Like"),
          content: TextField(
            controller: controller,
            maxLength: 200,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: "Recado opcional",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, ""),
              child: const Text("Sem recado"),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text("Enviar"),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(t,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.navy)),
      );

  Widget _emptyText(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(t, style: const TextStyle(color: Color(0xFF9AA1B2))),
      );

  Widget _grid(List<dynamic> items, {required bool locked}) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.64,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: items.map((it) => _card(it, locked)).toList(),
    );
  }

  Widget _card(dynamic u, bool locked) {
    final photo = u["profilePicture"]?.toString();
    final fullName = u["name"]?.toString() ?? "";
    final name =
        fullName.split(" ").first; // só o 1º nome (não empurra a cidade)
    final age = u["age"];
    final city = u["city"]?.toString();
    final dist = u["distanceKm"];
    final superLike = u["superLike"] == true;
    final matchId = u["matchId"]?.toString();
    final isVirtual = u["isVirtual"] == true || u["isBot"] == true;

    return GestureDetector(
      onTap: () {
        if (locked) {
          unawaited(_showVipOnlyInfo());
        } else if (matchId != null) {
          unawaited(
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  matchId: matchId,
                  otherName: name,
                  otherPhoto: photo,
                  otherUserId: u["userId"]?.toString(),
                  otherIsVirtual: isVirtual,
                ),
              ),
            ),
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (photo != null)
              CachedNetworkImage(
                imageUrl: PublicUrl.media(photo),
                fit: BoxFit.cover,
              )
            else
              Container(color: AppTheme.navy),
            if (locked)
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(color: Colors.black.withOpacity(0.15)),
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
            if (superLike)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: AppTheme.navy.withOpacity(0.8),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.star, color: Colors.white, size: 14),
                ),
              ),
            if (locked)
              const Center(
                child: Icon(Icons.lock, color: Colors.white, size: 30),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!locked && isVirtual)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 3),
                      child: Text(
                        "Perfil virtual • IA",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    locked ? "•••• ••" : "$name${age != null ? ", $age" : ""}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  if (!locked && (city != null || dist != null))
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.white70, size: 11),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            dist != null ? "$dist km" : (city ?? ""),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 10.5),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
