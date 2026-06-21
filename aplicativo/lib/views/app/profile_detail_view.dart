import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';

/// Exibe o perfil completo de uma pessoa (fotos + infos).
/// Se [withActions] for true, mostra os botões X / super / curtir no rodapé.
class ProfileDetailView extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool withActions;
  final VoidCallback? onNope;
  final VoidCallback? onSuper;
  final VoidCallback? onLike;

  const ProfileDetailView({
    super.key,
    required this.user,
    this.withActions = false,
    this.onNope,
    this.onSuper,
    this.onLike,
  });

  @override
  State<ProfileDetailView> createState() => _ProfileDetailViewState();
}

class _ProfileDetailViewState extends State<ProfileDetailView> {
  final _pc = PageController();
  int _photo = 0;

  List<String> get _photos {
    final media = (widget.user["mediaFiles"] as List?)?.cast<String>() ?? [];
    if (media.isNotEmpty) return media;
    final pic = widget.user["profilePicture"];
    return pic != null ? [pic.toString()] : [];
  }

  void _act(VoidCallback? cb) {
    Navigator.pop(context);
    cb?.call();
  }

  void _goPhoto(int delta) {
    final n = _photos.length;
    if (n <= 1) return;
    final next = (_photo + delta).clamp(0, n - 1);
    if (next == _photo) return;
    _pc.animateToPage(next,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final photos = _photos;
    final interests = (u["interests"] as List?)?.cast<String>() ?? [];
    final match = u["matchPercent"];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: 480,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pc,
                      itemCount: photos.isEmpty ? 1 : photos.length,
                      onPageChanged: (i) => setState(() => _photo = i),
                      itemBuilder: (_, i) => photos.isEmpty
                          ? Container(color: AppTheme.navy)
                          : CachedNetworkImage(imageUrl: photos[i], fit: BoxFit.cover),
                    ),
                    // Zonas de toque nas laterais (centro livre para swipe).
                    if (photos.length > 1)
                      Positioned.fill(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () => _goPhoto(-1),
                              ),
                            ),
                            const Expanded(flex: 2, child: SizedBox()),
                            Expanded(
                              flex: 1,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () => _goPhoto(1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (photos.length > 1)
                      Positioned(
                        top: 50,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: List.generate(
                            photos.length,
                            (i) => Expanded(
                              child: Container(
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: i == _photo ? Colors.white : Colors.white38,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
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
                            colors: [Colors.transparent, Color(0xE6111D40)],
                          ),
                        ),
                      ),
                    ),
                    if (match is num && widget.withActions)
                      Positioned(
                        top: 50,
                        right: 16,
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.navy.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.gold, width: 1.5),
                          ),
                          child: Text("$match% match",
                              style: TextStyle(
                                  color: AppTheme.gold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                      ),
                    Positioned(
                      left: 22,
                      right: 22,
                      bottom: 28,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text("${u["name"]}, ${u["age"]}",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold)),
                              ),
                              if (u["isVerified"] == true) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.verified, color: AppTheme.gold, size: 24),
                              ],
                            ],
                          ),
                          if (u["city"] != null || u["distanceKm"] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Row(children: [
                                const Icon(Icons.location_on,
                                    color: Colors.white70, size: 16),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    [
                                      if (u["city"] != null) u["city"].toString(),
                                      if (u["distanceKm"] != null)
                                        "${u["distanceKm"]} km",
                                    ].join(" · "),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 15),
                                  ),
                                ),
                                if (onlineLabel(u["isOnline"], u["lastActiveAt"]) !=
                                    null) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                        color: Color(0xFF2ECC71),
                                        shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    onlineLabel(
                                        u["isOnline"], u["lastActiveAt"])!,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                  ),
                                ],
                              ]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -22),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                  ),
                  padding: EdgeInsets.fromLTRB(
                      20, 22, 20, widget.withActions ? 120 : 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (match is num && widget.withActions) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppTheme.gold.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.favorite, color: AppTheme.gold, size: 18),
                              const SizedBox(width: 8),
                              Text("$match% de compatibilidade",
                                  style: const TextStyle(
                                      color: AppTheme.navy,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (u["denomination"] != null)
                            _pill(Icons.book, u["denomination"].toString()),
                          if (u["churchFrequency"] != null)
                            _pill(Icons.church, u["churchFrequency"].toString()),
                          if (u["intention"] != null)
                            _pill(Icons.favorite, u["intention"].toString()),
                        ],
                      ),
                      if (u["about"] != null &&
                          u["about"].toString().isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const Text("Sobre",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: AppTheme.navy)),
                        const SizedBox(height: 8),
                        Text(u["about"].toString(),
                            style: const TextStyle(
                                color: Color(0xFF444B5E),
                                fontSize: 15,
                                height: 1.4)),
                      ],
                      if (interests.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const Text("Interesses",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: AppTheme.navy)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 9,
                          runSpacing: 9,
                          children: interests
                              .map((it) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 13, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: AppTheme.gold.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(interestIcon(it),
                                            size: 15, color: AppTheme.navy),
                                        const SizedBox(width: 6),
                                        Text(it,
                                            style: const TextStyle(
                                                color: AppTheme.navy,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13)),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Voltar
          Positioned(
            top: 44,
            left: 12,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.35),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),
          // Botões de ação
          if (widget.withActions)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _actionBtn(Icons.close, Colors.white, AppTheme.navy,
                      () => _act(widget.onNope)),
                  const SizedBox(width: 22),
                  _actionBtn(Icons.star, AppTheme.navy, Colors.white,
                      () => _act(widget.onSuper)),
                  const SizedBox(width: 22),
                  _actionBtn(Icons.favorite, AppTheme.gold, Colors.white,
                      () => _act(widget.onLike)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFEDEFF4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: AppTheme.gold),
          const SizedBox(width: 7),
          Text(text,
              style: const TextStyle(
                  color: AppTheme.navy, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );

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
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Icon(icon, color: fg, size: 28),
      ),
    );
  }
}
