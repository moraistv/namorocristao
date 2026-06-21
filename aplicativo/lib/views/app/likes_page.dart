import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/realtime_bus.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';
import 'package:mioamoreapp/views/app/chat_page.dart';
import 'package:mioamoreapp/views/app/premium_page.dart';
import 'package:mioamoreapp/views/app/profile_detail_view.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
    _loadTopPicks();
    RealtimeBus.account.addListener(_onAccountChanged);
  }

  void _onAccountChanged() {
    if (!mounted) return;
    _load();
  }

  @override
  void dispose() {
    RealtimeBus.account.removeListener(_onAccountChanged);
    super.dispose();
  }

  Future<void> _loadTopPicks() async {
    setState(() => _loadingPicks = true);
    try {
      final picks = await AppApi.getTopPicks();
      if (!mounted) return;
      setState(() {
        _topPicks = picks;
        _loadingPicks = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPicks = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await AppApi.getLikes();
      setState(() {
        _premium = r["isPremium"] == true;
        _matches = (r["matches"] as List?) ?? [];
        _likedYou = (r["likedYou"] as List?) ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _subscribeDialog() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const PremiumPage(highlight: "Veja quem já te curtiu e dê match!"),
      ),
    );
    if (ok == true) _load();
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
    final photo = photos.isNotEmpty
        ? photos.first
        : u["profilePicture"]?.toString();
    final name = u["name"]?.toString() ?? "";
    final age = u["age"];
    final match = u["matchPercent"];
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
              CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover)
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

  Future<void> _pickSwipe(dynamic u, String type) async {
    try {
      final res = await AppApi.swipe(u["id"].toString(), type);
      if (res["matched"] == true && mounted) {
        EasyLoading.showSuccess("É um match! 💛");
      }
      _loadTopPicks();
    } on AppApiException catch (e) {
      if (e.statusCode == 403 && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const PremiumPage(
                  highlight: "Tenha mais Super Likes com o VIP")),
        );
      }
    } catch (_) {}
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(t,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy)),
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
    final name = fullName.split(" ").first; // só o 1º nome (não empurra a cidade)
    final age = u["age"];
    final city = u["city"]?.toString();
    final dist = u["distanceKm"];
    final superLike = u["superLike"] == true;
    final matchId = u["matchId"]?.toString();

    return GestureDetector(
      onTap: () {
        if (locked) {
          _subscribeDialog();
        } else if (matchId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatPage(
                  matchId: matchId, otherName: name, otherPhoto: photo,
                  otherUserId: u["userId"]?.toString()),
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
              CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover)
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
                            dist != null
                                ? "$dist km"
                                : (city ?? ""),
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
