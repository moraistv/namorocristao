import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/ads_service.dart';
import 'package:mioamoreapp/services/interstitial_manager.dart';
import 'package:mioamoreapp/services/token_storage.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';
import 'package:mioamoreapp/views/app/chat_page.dart';

class MatchesPage extends StatefulWidget {
  /// Dispara recarga quando muda (ex.: chegou mensagem/match via socket).
  final Listenable? refreshTick;

  /// Conjunto de matchIds em que o outro usuário está digitando (tempo real).
  final ValueNotifier<Set<String>>? typingMatches;

  /// Reporta a quantidade de CONVERSAS com mensagens não lidas.
  final void Function(int unreadConversations)? onUnread;

  /// Abre a aba Curtidas (mantém o menu inferior).
  final VoidCallback? onOpenLikes;

  /// Reporta a quantidade de pessoas que te curtiram (badge no menu).
  final void Function(int likes)? onLikesCount;

  const MatchesPage(
      {super.key,
      this.refreshTick,
      this.typingMatches,
      this.onUnread,
      this.onOpenLikes,
      this.onLikesCount});
  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _matches = [];

  @override
  void initState() {
    super.initState();
    _load();
    widget.refreshTick?.addListener(_onTick);
    widget.typingMatches?.addListener(_onTyping);
  }

  @override
  void dispose() {
    widget.refreshTick?.removeListener(_onTick);
    widget.typingMatches?.removeListener(_onTyping);
    super.dispose();
  }

  void _onTick() => _load();
  void _onTyping() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (mounted && !_loading) setState(() => _loading = true);
    try {
      final list = await AppApi.getMatches();
      int liked = 0;
      try {
        final likes = await AppApi.getLikes();
        liked = ((likes["likedYou"] as List?) ?? []).length;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _matches = list;
        _loading = false;
        _error = null;
      });
      // Conta CONVERSAS não lidas (não o total de mensagens).
      final unreadConvos =
          list.where((m) => ((m["unreadCount"] ?? 0) as int) > 0).length;
      widget.onUnread?.call(unreadConvos);
      widget.onLikesCount?.call(liked);
    } on AppApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  /// Prévia da última mensagem com ícone SVG para mídia (sem emoji do sistema).
  Widget _previewWidget(dynamic last, bool unread, {bool mine = false}) {
    final color = unread ? AppTheme.navy : const Color(0xFF8A91A3);
    final weight = unread ? FontWeight.w600 : FontWeight.normal;
    if (last == null) {
      return const SizedBox.shrink();
    }
    final type = last["type"]?.toString() ?? "TEXT";
    final prefix = mine ? "Você: " : "";
    String label;
    String? svg;
    switch (type) {
      case "IMAGE":
        label = "${prefix}Foto";
        svg = "assets/icons/ic_photo.svg";
        break;
      case "AUDIO":
        label = "${prefix}Mensagem de voz";
        svg = "assets/icons/ic_mic.svg";
        break;
      case "PHOTO_REQUEST":
        label = "${prefix}Pedido de fotos privadas";
        svg = "assets/icons/ic_photo.svg";
        break;
      case "GIFT":
        label = "${prefix}Presente";
        svg = "assets/icons/ic_gift.svg";
        break;
      default:
        label = "$prefix${last["content"]?.toString() ?? ""}";
    }
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontWeight: weight, fontSize: 14),
    );
    if (svg == null) return text;
    return Row(
      children: [
        SvgPicture.asset(svg,
            width: 14,
            height: 14,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
        const SizedBox(width: 5),
        Flexible(child: text),
      ],
    );
  }

  String _timeAgo(String? iso) {
    if (iso == null) return "";
    final t = DateTime.tryParse(iso);
    if (t == null) return "";
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return "agora";
    if (d.inMinutes < 60) return "${d.inMinutes}m";
    if (d.inHours < 24) return "${d.inHours}h";
    return "${d.inDays}d";
  }

  @override
  Widget build(BuildContext context) {
    final newMatches = _matches.where((m) => m["lastMessage"] == null).toList();
    final convos = _matches.where((m) => m["lastMessage"] != null).toList();

    return SafeArea(
      child: Column(
        children: [
          const AppTabHeader(title: "Chat", icon: Icons.chat_bubble_rounded),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  if (_loading)
              const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator())),
            if (_error != null) Center(child: Text(_error!)),
            if (!_loading) ...[
              if (newMatches.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text("Matches recentes",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 92,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: newMatches.map(_newMatchAvatar).toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (newMatches.isEmpty) const SizedBox(height: 14),
              const Text("Conversas",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy)),
              const SizedBox(height: 6),
              if (convos.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: Center(
                      child: Text("Sem conversas ainda. Diga olá nos novos matches! 👋",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF9AA1B2)))),
                ),
              for (int i = 0; i < convos.length; i++) ...[
                _convoTile(convos[i]),
                if (i < convos.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 70),
                    child: Divider(
                        height: 1, thickness: 1, color: Color(0xFFD9DEE7)),
                  ),
              ],
            ],
          ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _newMatchAvatar(dynamic m) {
    final other = m["otherUser"] ?? {};
    final name = (other["name"] ?? "").toString().split(" ").first;
    return GestureDetector(
      onTap: () => _openChat(m),
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          children: [
            Stack(children: [
              CircleAvatar(
                radius: 31,
                backgroundColor: const Color(0xFFE8EAF0),
                backgroundImage: other["profilePicture"] != null
                    ? CachedNetworkImageProvider(other["profilePicture"])
                    : null,
                child: other["profilePicture"] == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              if (other["isOnline"] == true)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
            ]),
            const SizedBox(height: 5),
            SizedBox(
              width: 64,
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _convoTile(dynamic m) {
    final other = m["otherUser"] ?? {};
    final last = m["lastMessage"];
    final unread = (m["unreadCount"] ?? 0) as int;
    final online = other["isOnline"] == true;
    final myId = TokenStorage.userId;
    final lastMine = last != null && last["senderId"]?.toString() == myId;
    final lastRead = last != null && last["readAt"] != null;
    final matchId = m["matchId"]?.toString() ?? "";
    final isTyping = widget.typingMatches?.value.contains(matchId) ?? false;
    return InkWell(
      onTap: () => _openChat(m),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Stack(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFE8EAF0),
                backgroundImage: other["profilePicture"] != null
                    ? CachedNetworkImageProvider(other["profilePicture"])
                    : null,
                child: other["profilePicture"] == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              if (online)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(other["name"]?.toString() ?? "Usuário",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.navy)),
                  const SizedBox(height: 3),
                  isTyping
                      ? const Text("digitando...",
                          style: TextStyle(
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              fontStyle: FontStyle.italic))
                      : _previewWidget(last, unread > 0, mine: lastMine),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_timeAgo(last?["createdAt"]?.toString()),
                    style: const TextStyle(color: Color(0xFF9AA1B2), fontSize: 12)),
                const SizedBox(height: 6),
                if (!lastMine && unread > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: Color(0xFFD4AF37), shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                    child: Text("$unread",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppTheme.navy,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  )
                else if (lastMine)
                  // ✓ enviada (não lida) / ✓✓ lida — em dourado.
                  Icon(lastRead ? Icons.done_all : Icons.done,
                      color: lastRead ? AppTheme.gold : const Color(0xFFCBD2E0),
                      size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(dynamic m) async {
    final other = m["otherUser"] ?? {};
    // Anúncio intersticial ao abrir conversa (se ligado no painel).
    if (AdsService.interstitialOnOpenChat) {
      InterstitialManager.maybeShow();
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          matchId: m["matchId"].toString(),
          otherName: other["name"]?.toString() ?? "Usuário",
          otherPhoto: other["profilePicture"]?.toString(),
          otherUserId: other["id"]?.toString(),
        ),
      ),
    );
    _load();
  }
}
