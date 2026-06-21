import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/services/ads_service.dart';

/// Banner do AdMob (usa o ID do painel ou o ID de teste do Google).
/// Reage em tempo real a `AdsService.revision`: quando o admin muda a config
/// remota ou o usuário vira VIP, o banner some/aparece sem reabrir o app.
class AppBannerAd extends StatefulWidget {
  const AppBannerAd({super.key});

  @override
  State<AppBannerAd> createState() => _AppBannerAdState();
}

class _AppBannerAdState extends State<AppBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    AdsService.revision.addListener(_onRevision);
    _init();
  }

  Future<void> _init() async {
    if (!isAdmobAvailable) return;
    await AdsService.load();
    _createAd();
  }

  void _createAd() {
    if (!mounted || !AdsService.shouldShowAds || _ad != null) return;
    final ad = BannerAd(
      adUnitId: AdsService.bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
    ad.load();
    _ad = ad;
  }

  /// Config remota / status VIP mudou: descarta o atual e recria (ou esconde).
  void _onRevision() {
    if (!mounted) return;
    _ad?.dispose();
    _ad = null;
    setState(() => _loaded = false);
    _createAd();
  }

  @override
  void dispose() {
    AdsService.revision.removeListener(_onRevision);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      width: double.infinity,
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}

/// Banner inline para uso DENTRO da lista de mensagens do chat.
/// Fica totalmente invisível (SizedBox.shrink) enquanto o anúncio não carrega,
/// para não deixar espaço vazio no meio da conversa. Também reage em tempo real.
class ChatInlineAd extends StatefulWidget {
  const ChatInlineAd({super.key});

  @override
  State<ChatInlineAd> createState() => _ChatInlineAdState();
}

class _ChatInlineAdState extends State<ChatInlineAd> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    AdsService.revision.addListener(_onRevision);
    _init();
  }

  Future<void> _init() async {
    if (!isAdmobAvailable) return;
    await AdsService.load();
    _createAd();
  }

  void _createAd() {
    if (!mounted || !AdsService.shouldShowAds || _ad != null) return;
    final ad = BannerAd(
      adUnitId: AdsService.bannerId,
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
    ad.load();
    _ad = ad;
  }

  void _onRevision() {
    if (!mounted) return;
    _ad?.dispose();
    _ad = null;
    setState(() => _loaded = false);
    _createAd();
  }

  @override
  void dispose() {
    AdsService.revision.removeListener(_onRevision);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text("Publicidade",
                style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9AA1B2),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
          ),
          SizedBox(
            width: _ad!.size.width.toDouble(),
            height: _ad!.size.height.toDouble(),
            child: AdWidget(ad: _ad!),
          ),
        ],
      ),
    );
  }
}
