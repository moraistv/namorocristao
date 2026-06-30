import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image_picker/image_picker.dart';
import 'package:social_media_recorder/audio_encoder_type.dart';
import 'package:social_media_recorder/screen/social_media_recorder.dart';
import 'package:voice_message_package/voice_message_package.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/config/api_config.dart';
import 'package:mioamoreapp/services/chat_socket.dart';
import 'package:mioamoreapp/services/token_storage.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';
import 'package:mioamoreapp/views/app/ads/app_banner.dart';
import 'package:mioamoreapp/views/app/profile_detail_view.dart';

class ChatPage extends StatefulWidget {
  final String matchId;
  final String otherName;
  final String? otherPhoto;
  final String? otherUserId;
  const ChatPage({
    super.key,
    required this.matchId,
    required this.otherName,
    this.otherPhoto,
    this.otherUserId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _socket = ChatSocket();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scroll = ScrollController();
  final Map<String, VoiceController> _voiceControllers = {};
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _otherTyping = false;
  bool _hasText = false;
  bool _recording = false;
  bool _otherOnline = false;
  String? _otherLastActive;
  Timer? _presenceTimer;
  bool _typingSent = false;
  String? _accessStatus; // null/PENDING/APPROVED/DENIED (acesso às fotos do outro)
  String get _myId => TokenStorage.userId ?? "";

  // Sugestões de "quebra-gelo" (rotacionam pra não ficar mesmice).
  final List<String> _allSuggestions = [
    "Oi, tudo bem? 😊",
    "Como está sendo seu dia?",
    "Qual a sua igreja?",
    "O que você curte fazer no fim de semana?",
    "Qual seu versículo preferido? ✝️",
    "Você gosta de louvor? 🎶",
    "Bora tomar um café? ☕",
    "Como você conheceu a Deus?",
    "O que te trouxe aqui no app?",
    "Prazer em te conhecer! 💛",
    "Qual seu plano de fé pra esse ano?",
    "Curte um culto ou mais um louvor em casa?",
  ];
  int _sugOffset = 0;
  Timer? _sugTimer;
  Timer? _pollTimer;
  Timer? _localTypingTimer;
  bool _localTyping = false;

  @override
  void initState() {
    super.initState();
    _allSuggestions.shuffle();
    _init();
    // Rotaciona as 3 sugestões exibidas a cada 6s.
    _sugTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      setState(() => _sugOffset = (_sugOffset + 3) % _allSuggestions.length);
    });
  }

  Future<void> _init() async {
    try {
      final hist = await AppApi.getHistory(widget.matchId);
      _messages = hist.cast<Map<String, dynamic>>();
    } catch (_) {}
    setState(() => _loading = false);
    _scrollToBottom();
    // Marca como lido de forma confiável (REST) ao abrir — cobre mensagens
    // acumuladas do bot/broadcast mesmo se o socket ainda não conectou.
    AppApi.markRead(widget.matchId);
    _refreshAccess();
    _refreshPresence();
    _presenceTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _refreshPresence());
    // Fallback confiável de tempo real: busca novas mensagens via REST a cada 2,5s
    // (garante ver a resposta do bot/pessoa mesmo se o socket não conectar).
    _pollTimer =
        Timer.periodic(const Duration(milliseconds: 2500), (_) => _poll());

    _socket.connect(
      onMessage: (msg) {
        if (msg["matchId"] == widget.matchId) {
          _addMessage(msg);
          if (msg["senderId"] != _myId) {
            _clearLocalTyping();
            _socket.markRead(widget.matchId);
            AppApi.markRead(widget.matchId); // confiável (REST), inclusive p/ bot
          }
        }
      },
      onRead: (matchId, by) {
        if (matchId == widget.matchId && by != _myId) {
          setState(() {
            for (final msg in _messages) {
              if (msg["senderId"] == _myId && msg["readAt"] == null) {
                msg["readAt"] = DateTime.now().toIso8601String();
              }
            }
          });
        }
      },
      onTyping: (matchId, userId, isTyping) {
        if (matchId == widget.matchId && userId != _myId) {
          setState(() => _otherTyping = isTyping);
        }
      },
    );
    // Pequeno atraso pra garantir conexão antes do join.
    Future.delayed(const Duration(milliseconds: 400), () {
      _socket.joinMatch(widget.matchId);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() => _hasText = false);
    _typingSent = false;
    _socket.setTyping(widget.matchId, false);
    try {
      final msg = await AppApi.sendMessage(widget.matchId, text);
      _addMessage(msg);
      _startLocalTyping(); // mostra "digitando..." enquanto a resposta vem
    } catch (_) {
      EasyLoading.showError("Falha ao enviar");
    }
  }

  // Busca novas mensagens via REST (fallback de tempo real). Incremental: só
  // pega o que chegou depois da última mensagem que já temos (payload mínimo).
  Future<void> _poll() async {
    try {
      final String? after =
          _messages.isNotEmpty ? _messages.last["createdAt"]?.toString() : null;
      final hist = await AppApi.getHistory(widget.matchId, after: after);
      final list = hist.cast<Map<String, dynamic>>();
      if (list.isEmpty) return;
      bool added = false;
      for (final m in list) {
        final id = m["id"]?.toString();
        if (id == null) continue;
        if (_messages.any((x) => x["id"]?.toString() == id)) continue;
        _messages.add(m);
        added = true;
        if (m["senderId"] != _myId) {
          _clearLocalTyping();
          AppApi.markRead(widget.matchId);
        }
      }
      if (added && mounted) {
        setState(() {});
        _scrollToBottom();
      }
    } catch (_) {}
  }

  // "Digitando..." otimista após eu enviar (a resposta — ex.: do bot — vem logo).
  void _startLocalTyping() {
    _localTypingTimer?.cancel();
    if (mounted) setState(() => _localTyping = true);
    _scrollToBottom();
    _localTypingTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _localTyping = false);
    });
  }

  void _clearLocalTyping() {
    _localTypingTimer?.cancel();
    if (_localTyping && mounted) setState(() => _localTyping = false);
  }

  Future<void> _sendPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 78,
      );
      if (file == null) return;
      EasyLoading.show(status: "Enviando foto...");
      final bytes = await file.readAsBytes();
      final ext = file.name.split(".").last.toLowerCase();
      final url = await AppApi.uploadPhoto(base64Encode(bytes),
          ext: ext == "png" ? "png" : "jpg");
      final msg = await AppApi.sendMessage(widget.matchId, url, type: "IMAGE");
      _addMessage(msg);
      EasyLoading.dismiss();
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showError("Falha ao enviar a foto");
    }
  }

  Future<void> _sendAudio(File soundFile, String time) async {
    try {
      EasyLoading.show(status: "Enviando áudio...");
      final bytes = await soundFile.readAsBytes();
      final url = await AppApi.uploadPhoto(base64Encode(bytes), ext: "m4a");
      final secs = _parseSeconds(time);
      // content = "url#segundos" para reconstruir a duração no player.
      final msg = await AppApi.sendMessage(widget.matchId, "$url#$secs",
          type: "AUDIO");
      _addMessage(msg);
      EasyLoading.dismiss();
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showError("Falha ao enviar o áudio");
    }
  }

  int _parseSeconds(String time) {
    // Aceita "ss", "m:ss" ou "h:mm:ss".
    final parts = time.trim().split(":").map((e) => int.tryParse(e) ?? 0).toList();
    if (parts.length == 1) return parts[0];
    if (parts.length == 2) return parts[0] * 60 + parts[1];
    if (parts.length == 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
    return 30;
  }

  Future<void> _openOtherProfile() async {
    if (widget.otherUserId == null) return;
    EasyLoading.show();
    try {
      final card = await AppApi.getUserCard(widget.otherUserId!);
      EasyLoading.dismiss();
      if (card == null || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProfileDetailView(user: card, withActions: false)),
      );
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showError("Não foi possível abrir o perfil");
    }
  }

  /// Adiciona a mensagem evitando duplicatas (socket + REST podem repetir).
  void _addMessage(Map<String, dynamic> msg) {
    final id = msg["id"]?.toString();
    if (id != null && _messages.any((m) => m["id"]?.toString() == id)) return;
    setState(() => _messages.add(msg));
    _scrollToBottom();
  }

  void _openGiftShop() async {
    EasyLoading.show(status: "Carregando...");
    List<dynamic> gifts = [];
    int credits = 0;
    try {
      final store = await AppApi.getStore();
      gifts = (store["gifts"] as List?) ?? [];
    } catch (_) {}
    try {
      final stats = await AppApi.getStats();
      final c = stats["credits"];
      if (c is int) credits = c;
    } catch (_) {}
    EasyLoading.dismiss();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.card_giftcard, color: AppTheme.gold, size: 24),
                  const SizedBox(width: 8),
                  const Text("Presentes",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navy)),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("🪙 ",
                            style: TextStyle(fontSize: 14)),
                        Text("$credits créditos",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.navy)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (gifts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Text("Nenhum presente disponível no momento.",
                      style: TextStyle(color: Color(0xFF7A849C))),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5),
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: gifts.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.78,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (_, i) {
                      final g = gifts[i] as Map<String, dynamic>;
                      final cost = (g["costCredits"] ?? 0) as int;
                      final canAfford = credits >= cost;
                      return InkWell(
                        onTap: () => _confirmSendGift(g, () {
                          // ao enviar, debita localmente e atualiza a folha
                          setSheet(() => credits -= cost);
                        }),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F8FB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: canAfford
                                    ? AppTheme.gold.withOpacity(0.4)
                                    : const Color(0xFFE6E9F0)),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _giftImage(g["imageUrl"]?.toString()),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                g["name"]?.toString() ?? "",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.navy),
                              ),
                              Text("🪙 $cost",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: canAfford
                                          ? AppTheme.gold
                                          : Colors.redAccent,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _giftImage(String? url) {
    url = _mediaUrl(url);
    if (url == null || url.isEmpty) {
      return Icon(Icons.card_giftcard, color: AppTheme.gold, size: 32);
    }
    if (url.toLowerCase().endsWith(".svg")) {
      return SvgPicture.network(
        url,
        fit: BoxFit.contain,
        placeholderBuilder: (_) =>
            Icon(Icons.card_giftcard, color: AppTheme.gold, size: 32),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      errorWidget: (_, __, ___) =>
          Icon(Icons.card_giftcard, color: AppTheme.gold, size: 32),
    );
  }

  /// Resolve URLs de mídia: `/uploads/...` (relativo ou com host errado tipo
  /// localhost) sempre apontam para o host real da API. URLs externas passam direto.
  String? _mediaUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final idx = raw.indexOf("/uploads/");
    if (idx >= 0) {
      final origin = ApiConfig.baseUrl.replaceAll("/api", "");
      return origin + raw.substring(idx);
    }
    return raw;
  }

  Future<void> _confirmSendGift(
      Map<String, dynamic> gift, VoidCallback onSent) async {
    final cost = (gift["costCredits"] ?? 0) as int;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Enviar ${gift["name"] ?? "presente"}?"),
        content: Text("Custa $cost crédito(s). Será enviado na conversa."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Enviar")),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await AppApi.sendGift(widget.matchId, gift["id"].toString());
      final msg = (res["message"] as Map).cast<String, dynamic>();
      _addMessage(msg);
      onSent();
      EasyLoading.showSuccess("Presente enviado!");
    } on AppApiException catch (e) {
      if (e.statusCode == 402) {
        EasyLoading.showError("Créditos insuficientes");
      } else {
        EasyLoading.showError(e.message);
      }
    } catch (_) {
      EasyLoading.showError("Falha ao enviar presente");
    }
  }

  Future<void> _refreshAccess() async {
    if (widget.otherUserId == null) return;
    try {
      final s = await AppApi.canSeePhotos(widget.otherUserId!);
      if (mounted) setState(() => _accessStatus = s);
    } catch (_) {}
  }

  Future<void> _refreshPresence() async {
    if (widget.otherUserId == null) return;
    try {
      final card = await AppApi.getUserCard(widget.otherUserId!);
      if (card != null && mounted) {
        setState(() {
          _otherOnline = card["isOnline"] == true;
          _otherLastActive = card["lastActiveAt"]?.toString();
        });
      }
    } catch (_) {}
  }

  // ── Bloquear ──
  Future<void> _confirmBlock() async {
    if (widget.otherUserId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("🤝", style: TextStyle(fontSize: 44)),
              const SizedBox(height: 12),
              Text("Bloquear ${widget.otherName}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navy)),
              const SizedBox(height: 8),
              Text(
                "Não se preocupe, não avisaremos ${widget.otherName}.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF7A849C)),
              ),
              const SizedBox(height: 18),
              _blockInfo(Icons.person_off, "Não poderá ver seu perfil nem te enviar mensagens."),
              _blockInfo(Icons.notifications_off, "A pessoa não será avisada do bloqueio."),
              _blockInfo(Icons.settings, "Você pode desbloquear quando quiser."),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.navy,
                        side: BorderSide(color: AppTheme.gold),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24))),
                    child: const Text("Cancelar"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24))),
                    child: const Text("Sim, bloquear"),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    EasyLoading.show(status: "Bloqueando...");
    try {
      await AppApi.blockUser(widget.otherUserId!);
      EasyLoading.dismiss();
      EasyLoading.showSuccess("Usuário bloqueado");
      if (mounted) Navigator.pop(context);
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showError("Falha ao bloquear");
    }
  }

  Widget _blockInfo(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppTheme.gold, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Color(0xFF444B5E), fontSize: 13)),
          ),
        ]),
      );

  // ── Denunciar ──
  Future<void> _openReport() async {
    if (widget.otherUserId == null) return;
    const reasons = [
      "Assédio",
      "Conteúdo inapropriado",
      "Violação dos termos",
      "Linguagem ofensiva",
      "Comportamento desrespeitoso",
      "Ameaças",
      "Perfil falso (catfishing)",
      "Avanços indesejados",
      "Conteúdo explícito não solicitado",
      "Questões de privacidade",
      "Golpe ou spam",
      "Outro",
    ];
    String? selected;
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.92,
          builder: (_, scroll) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE0E3EB),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Text("Denunciar ${widget.otherName}",
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navy)),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 6, 24, 4),
                child: Text("Por que você está denunciando? Não avisaremos.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF7A849C), fontSize: 13)),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  children: reasons
                      .map((r) => RadioListTile<String>(
                            value: r,
                            groupValue: selected,
                            activeColor: AppTheme.gold,
                            title: Text(r),
                            onChanged: (v) => setSheet(() => selected = v),
                          ))
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selected == null
                        ? null
                        : () => Navigator.pop(ctx, selected),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: AppTheme.navy,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: const Text("Enviar denúncia",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (reason == null) return;
    EasyLoading.show(status: "Enviando...");
    try {
      await AppApi.reportUser(widget.otherUserId!, reason);
      EasyLoading.dismiss();
      EasyLoading.showSuccess("Denúncia enviada. Obrigado!");
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showError("Falha ao denunciar");
    }
  }

  Future<void> _decide(String requestId, bool approve) async {
    try {
      await AppApi.decidePhotoAccess(requestId, approve);
      EasyLoading.showSuccess(approve ? "Liberado!" : "Negado");
    } catch (_) {
      EasyLoading.showError("Falha");
    }
  }

  Future<void> _viewLockedPhotos() async {
    if (widget.otherUserId == null) return;
    EasyLoading.show();
    try {
      final photos = await AppApi.getLockedPhotos(widget.otherUserId!);
      EasyLoading.dismiss();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: PageView(
            children: photos
                .map((p) => CachedNetworkImage(imageUrl: p, fit: BoxFit.contain))
                .toList(),
          ),
        ),
      );
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showError("Não foi possível abrir");
    }
  }

  @override
  void dispose() {
    _sugTimer?.cancel();
    _pollTimer?.cancel();
    _localTypingTimer?.cancel();
    _presenceTimer?.cancel();
    _socket.leaveMatch(widget.matchId);
    _socket.disconnect();
    _controller.dispose();
    _focusNode.dispose();
    _scroll.dispose();
    for (final c in _voiceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.navy,
        elevation: 0.5,
        titleSpacing: 0,
        title: Row(
          children: [
            GestureDetector(
              onTap: widget.otherPhoto != null
                  ? () => _openImage(widget.otherPhoto!)
                  : null,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE8EAF0),
                backgroundImage: widget.otherPhoto != null
                    ? CachedNetworkImageProvider(widget.otherPhoto!)
                    : null,
                child: widget.otherPhoto == null
                    ? const Icon(Icons.person, size: 18, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _openOtherProfile,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.otherName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        if (!_otherTyping && _otherOnline) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Color(0xFF2FB344),
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(
                            _otherTyping
                                ? "digitando..."
                                : presenceText(_otherOnline, _otherLastActive),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: _otherTyping
                                    ? AppTheme.gold
                                    : (_otherOnline
                                        ? const Color(0xFF2FB344)
                                        : const Color(0xFF9AA1B2))),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == "view") _viewLockedPhotos();
              if (v == "block") _confirmBlock();
              if (v == "report") _openReport();
            },
            itemBuilder: (_) => [
              if (widget.otherUserId != null && _accessStatus == "APPROVED")
                PopupMenuItem(
                    value: "view",
                    child: Row(children: [
                      Icon(Icons.lock_open, color: AppTheme.gold, size: 20),
                      const SizedBox(width: 12),
                      const Text("Ver fotos privadas"),
                    ])),
              const PopupMenuItem(
                  value: "block",
                  child: Row(children: [
                    Icon(Icons.block, color: AppTheme.navy, size: 20),
                    SizedBox(width: 12),
                    Text("Bloquear"),
                  ])),
              const PopupMenuItem(
                  value: "report",
                  child: Row(children: [
                    Icon(Icons.flag_outlined, color: AppTheme.navy, size: 20),
                    SizedBox(width: 12),
                    Text("Denunciar"),
                  ])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length +
                        ((_otherTyping || _localTyping) ? 1 : 0),
                    itemBuilder: (_, i) {
                      if ((_otherTyping || _localTyping) &&
                          i == _messages.length) {
                        return const TypingBubble();
                      }
                      return _bubble(_messages[i]);
                    },
                  ),
          ),
          const AppBannerAd(),
          _suggestionsBar(),
          _inputBar(),
        ],
      ),
    );
  }

  // Mostra quebra-gelos rotativos enquanto a conversa ainda não tem mensagens reais.
  bool get _showSuggestions =>
      !_recording &&
      !_hasText &&
      !_messages.any((m) => m["type"] != "SYSTEM");

  Widget _suggestionsBar() {
    if (!_showSuggestions) return const SizedBox.shrink();
    final shown = List.generate(
        3, (i) => _allSuggestions[(_sugOffset + i) % _allSuggestions.length]);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 13, color: AppTheme.gold),
                const SizedBox(width: 5),
                const Text("Sugestões para começar",
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF9AA1B2),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          SizedBox(
            height: 36,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: ListView.separated(
                key: ValueKey(_sugOffset),
                scrollDirection: Axis.horizontal,
                itemCount: shown.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _suggestionChip(shown[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionChip(String text) {
    return GestureDetector(
      onTap: () => _pickSuggestion(text),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppTheme.gold.withOpacity(0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.gold.withOpacity(0.45)),
        ),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  // Deixa a mensagem pronta no campo (usuário pode editar e enviar).
  void _pickSuggestion(String text) {
    _controller.text = text;
    _controller.selection =
        TextSelection.fromPosition(TextPosition(offset: text.length));
    setState(() => _hasText = true);
    _focusNode.requestFocus();
  }

  Widget _bubble(Map<String, dynamic> m) {
    final mine = m["senderId"] == _myId;
    if (m["type"] == "PHOTO_REQUEST") {
      return _photoRequestBubble(m, mine);
    }
    if (m["type"] == "AUDIO") {
      return _audioBubble(m, mine);
    }
    if (m["type"] == "GIFT") {
      return _giftBubble(m, mine);
    }
    if (m["type"] == "SYSTEM") {
      final content = m["content"].toString();
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.gold.withOpacity(0.18),
                AppTheme.gold.withOpacity(0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.gold.withOpacity(0.45)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFE9C75A), Color(0xFFD4AF37)]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.gold.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 12),
              const Text(
                "Vocês deram match!",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                content.contains("conversa")
                    ? "Que tal começar a conversa? 💛"
                    : content,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF6A7286),
                    fontSize: 13.5,
                    height: 1.3),
              ),
            ],
          ),
        ),
      );
    }
    final isImage = m["type"] == "IMAGE";
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: isImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.fromLTRB(14, 10, 14, 6),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          gradient: mine
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFE9C75A), Color(0xFFD4AF37)])
              : null,
          color: mine ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isImage)
              GestureDetector(
                onTap: () => _openImage(m["content"].toString()),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: m["content"].toString(),
                    width: 220,
                    height: 280,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                        width: 220,
                        height: 280,
                        color: const Color(0xFFE8EAF0),
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2))),
                    errorWidget: (_, __, ___) => Container(
                        width: 220,
                        height: 280,
                        color: const Color(0xFFE8EAF0),
                        child: const Icon(Icons.broken_image,
                            color: Colors.white)),
                  ),
                ),
              )
            else
              Text(
                m["content"].toString(),
                style: TextStyle(
                    color: mine ? AppTheme.navy : const Color(0xFF1A1A2E),
                    fontSize: 15),
              ),
            Padding(
              padding: EdgeInsets.only(top: isImage ? 4 : 3, left: isImage ? 6 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _msgTime(m["createdAt"]?.toString()),
                    style: TextStyle(
                        color: mine
                            ? AppTheme.navy.withOpacity(0.55)
                            : const Color(0xFFAAB1C0),
                        fontSize: 10.5),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      m["readAt"] != null ? Icons.done_all : Icons.done,
                      size: 15,
                      color: m["readAt"] != null
                          ? const Color(0xFFD4AF37)
                          : AppTheme.navy.withOpacity(0.45),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _giftBubble(Map<String, dynamic> m, bool mine) {
    Map<String, dynamic> gift = {};
    try {
      gift = jsonDecode(m["content"].toString()) as Map<String, dynamic>;
    } catch (_) {}
    final name = gift["name"]?.toString() ?? "Presente";
    final imageUrl = gift["imageUrl"]?.toString();
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 200),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF7E0), Color(0xFFFCEFC2)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.gold.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: _giftImage(imageUrl),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.card_giftcard, size: 14, color: AppTheme.gold),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    mine ? "Você enviou: $name" : "Enviou: $name",
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _msgTime(m["createdAt"]?.toString()),
              style: TextStyle(
                  color: AppTheme.navy.withOpacity(0.5), fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  void _openImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _audioBubble(Map<String, dynamic> m, bool mine) {
    final id = m["id"]?.toString() ?? UniqueKey().toString();
    final raw = m["content"].toString();
    final parts = raw.split("#");
    final url = parts.first;
    final secs = parts.length > 1 ? (int.tryParse(parts[1]) ?? 30) : 30;
    final ctrl = _voiceControllers[id] ??= VoiceController(
      audioSrc: url,
      maxDuration: Duration(seconds: secs.clamp(1, 600)),
      isFile: false,
      onComplete: () {},
      onPlaying: () {},
      onPause: () {},
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: VoiceMessageView(
          controller: ctrl,
          backgroundColor: mine ? AppTheme.gold : Colors.white,
          activeSliderColor: mine ? AppTheme.navy : AppTheme.gold,
          circlesColor: mine ? AppTheme.navy : AppTheme.gold,
          innerPadding: 10,
          cornerRadius: 18,
          counterTextStyle: TextStyle(
              fontSize: 11,
              color: mine ? AppTheme.navy : const Color(0xFF6A7286)),
        ),
      ),
    );
  }

  String _msgTime(String? iso) {
    if (iso == null) return "";
    final t = DateTime.tryParse(iso);
    if (t == null) return "";
    final l = t.toLocal();
    return "${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}";
  }

  Widget _photoRequestBubble(Map<String, dynamic> m, bool mine) {
    final requestId = m["content"].toString();
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: AppTheme.gold.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.gold.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Icon(Icons.photo_library, color: AppTheme.gold, size: 28),
            const SizedBox(height: 8),
            Text(
              mine
                  ? "Você pediu acesso às fotos privadas."
                  : "${widget.otherName} quer ver suas fotos privadas.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.navy, fontWeight: FontWeight.w600),
            ),
            if (!mine) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _decide(requestId, false),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.navy,
                          side: const BorderSide(color: Color(0xFFE0E3EB))),
                      child: const Text("Negar"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _decide(requestId, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: AppTheme.navy),
                      child: const Text("Aprovar"),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        color: Colors.white,
        child: Row(
          children: [
            // Pill com o campo de digitar (oculto enquanto grava áudio).
            if (!_recording)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border:
                        Border.all(color: const Color(0xFFE3E6EF), width: 1.4),
                  ),
                  padding: const EdgeInsets.only(left: 6, right: 8),
                  child: Row(
                    children: [
                      _pillIcon(Icons.emoji_emotions_outlined,
                          const Color(0xFF8A91A3), _openEmoji),
                      Expanded(
                        key: const ValueKey("chatTextField"),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onChanged: (v) {
                            final typing = v.trim().isNotEmpty;
                            if (typing != _typingSent) {
                              _typingSent = typing;
                              _socket.setTyping(widget.matchId, typing);
                            }
                            if (typing != _hasText) setState(() => _hasText = typing);
                          },
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: "Sua mensagem",
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Color(0xFF9AA1B2)),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      _pillIcon(
                          Icons.photo_camera_rounded, AppTheme.navy, _photoOptions),
                      _pillIcon(Icons.card_giftcard, AppTheme.gold, _openGiftShop),
                    ],
                  ),
                ),
              ),
            if (!_recording) const SizedBox(width: 8),
            // Texto → enviar; vazio → microfone (vira barra cheia ao gravar).
            if (_hasText)
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.gold,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 24),
                ),
              )
            else if (_recording)
              Expanded(child: _recorder())
            else
              SizedBox(width: 52, height: 52, child: _recorder()),
          ],
        ),
      ),
    );
  }

  Widget _pillIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _recorder() {
    return SocialMediaRecorder(
      key: const ValueKey("recorder"),
      sendRequestFunction: (soundFile, time) => _sendAudio(soundFile, time),
      startRecording: () {
        if (mounted) setState(() => _recording = true);
      },
      stopRecording: (_) {
        if (mounted) setState(() => _recording = false);
      },
      encode: AudioEncoderType.AAC,
      radius: BorderRadius.circular(18),
      fullRecordPackageHeight: 52,
      initRecordPackageWidth: 52,
      backGroundColor: AppTheme.gold,
      counterBackGroundColor: const Color(0xFFF0F2F7),
      recordIconBackGroundColor: AppTheme.gold,
      recordIconWhenLockBackGroundColor: AppTheme.gold,
      slideToCancelText: "Arraste p/ cancelar",
      slideToCancelTextStyle:
          const TextStyle(color: Color(0xFF6A7286), fontSize: 12),
      cancelText: "Cancelar",
      cancelTextStyle: const TextStyle(color: Colors.red, fontSize: 13),
      counterTextStyle: const TextStyle(color: AppTheme.navy, fontSize: 13),
      recordIcon: const Icon(Icons.mic, color: Colors.white, size: 24),
      recordIconWhenLockedRecord:
          const Icon(Icons.mic, color: Colors.white, size: 24),
      sendButtonIcon:
          const Icon(Icons.send_rounded, color: AppTheme.navy, size: 22),
      lockButton: const Icon(Icons.lock_outline, color: AppTheme.navy, size: 20),
    );
  }

  /// Bottom sheet rápido pra escolher Câmera ou Galeria.
  void _photoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_rounded, color: AppTheme.gold),
              title: const Text("Tirar foto"),
              onTap: () {
                Navigator.pop(context);
                _sendPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: AppTheme.gold),
              title: const Text("Escolher da galeria"),
              onTap: () {
                Navigator.pop(context);
                _sendPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Seletor rápido de emojis (insere no campo).
  void _openEmoji() {
    const emojis = [
      "😀","😁","😂","🥰","😍","😘","😊","😉","🙂","😎",
      "🤩","😇","🤗","😅","😋","😏","🥲","😴","🤔","🙄",
      "❤️","🧡","💛","💚","💙","💜","🤍","💖","💕","💘",
      "🙏","✝️","🕊️","🎶","☕","🌹","🌻","✨","🔥","👍",
      "👏","🙌","😢","😭","😡","🤝","💍","🎁","🥳","💯",
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            crossAxisCount: 8,
            shrinkWrap: true,
            children: emojis
                .map((e) => GestureDetector(
                      onTap: () {
                        _controller.text = _controller.text + e;
                        _controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: _controller.text.length),
                        );
                        if (!_hasText) setState(() => _hasText = true);
                        Navigator.pop(context);
                      },
                      child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 26))),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}


/// Bolha de "digitando..." com 3 bolinhas animadas (estilo WhatsApp).
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4),
          ],
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                // Cada bolinha "pula" com um pequeno atraso entre elas.
                final t = (_c.value - i * 0.2) % 1.0;
                final scale = t < 0.5 ? 0.6 + (t * 2) * 0.6 : 0.6 + (2 - t * 2) * 0.6;
                return Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
                  child: Transform.scale(
                    scale: scale.clamp(0.6, 1.2),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
