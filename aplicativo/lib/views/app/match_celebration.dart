import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';
import 'package:mioamoreapp/views/app/chat_page.dart';

/// Mostra a tela "É um Match!" como overlay sobre tudo.
Future<void> showMatchCelebration(
  BuildContext context, {
  required String matchId,
  required String otherName,
  String? otherPhoto,
  String? otherUserId,
  String? myPhoto,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (_, __, ___) => _MatchCelebration(
      matchId: matchId,
      otherName: otherName,
      otherPhoto: otherPhoto,
      otherUserId: otherUserId,
      myPhoto: myPhoto,
    ),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: child,
    ),
  );
}

class _MatchCelebration extends StatefulWidget {
  final String matchId;
  final String otherName;
  final String? otherPhoto;
  final String? otherUserId;
  final String? myPhoto;
  const _MatchCelebration({
    required this.matchId,
    required this.otherName,
    this.otherPhoto,
    this.otherUserId,
    this.myPhoto,
  });

  @override
  State<_MatchCelebration> createState() => _MatchCelebrationState();
}

class _MatchCelebrationState extends State<_MatchCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Stack(
          children: [
            // Corações flutuantes
            ..._hearts(),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppTheme.navy),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
                      child: const Text(
                        "É um Match!",
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navy),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Você e ${widget.otherName} se curtiram",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, color: Color(0xFF7A849C)),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _avatar(widget.myPhoto),
                        Transform.translate(
                          offset: const Offset(-12, 0),
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppTheme.gold,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.favorite,
                                color: Colors.white, size: 26),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(-24, 0),
                          child: _avatar(widget.otherPhoto),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                matchId: widget.matchId,
                                otherName: widget.otherName,
                                otherPhoto: widget.otherPhoto,
                                otherUserId: widget.otherUserId,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: AppTheme.navy,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30))),
                        child: const Text("Conversar",
                            style:
                                TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Pular",
                          style: TextStyle(color: Color(0xFF7A849C), fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String? url) => Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.gold, width: 3),
          color: const Color(0xFFE8EAF0),
        ),
        clipBehavior: Clip.antiAlias,
        child: url != null
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : const Icon(Icons.person, color: Colors.white, size: 40),
      );

  List<Widget> _hearts() {
    final rnd = Random(7);
    return List.generate(7, (i) {
      final left = rnd.nextDouble();
      final size = 16.0 + rnd.nextDouble() * 18;
      final delay = rnd.nextDouble() * 0.5;
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = (_c.value - delay).clamp(0.0, 1.0);
          final w = MediaQuery.of(context).size.width;
          return Positioned(
            left: left * (w - 40) + 10,
            top: 120 + (1 - t) * 60,
            child: Opacity(
              opacity: (t * 1.4).clamp(0.0, 1.0) * 0.8,
              child: Icon(Icons.favorite,
                  color: i.isEven ? AppTheme.gold : const Color(0xFFE0B94A),
                  size: size),
            ),
          );
        },
      );
    });
  }
}
