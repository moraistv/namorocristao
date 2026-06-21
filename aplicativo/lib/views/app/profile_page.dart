import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/realtime_bus.dart';
import 'package:mioamoreapp/services/token_storage.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';
import 'package:mioamoreapp/views/app/edit_profile_page.dart';
import 'package:mioamoreapp/views/app/photo_manager_page.dart';
import 'package:mioamoreapp/views/app/premium_page.dart';
import 'package:mioamoreapp/views/app/store_page.dart';
import 'package:mioamoreapp/views/app/settings_page.dart';
import 'package:mioamoreapp/views/auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _isPremium = false;
  int _superLikes = 0;
  int _boosts = 0;
  String? _verseRef;
  String? _verseText;

  @override
  void initState() {
    super.initState();
    _load();
    _loadStats();
    _loadVerse();
    RealtimeBus.account.addListener(_onAccountChanged);
  }

  void _onAccountChanged() {
    if (!mounted) return;
    _load();
    _loadStats();
  }

  @override
  void dispose() {
    RealtimeBus.account.removeListener(_onAccountChanged);
    super.dispose();
  }

  Future<void> _loadVerse() async {
    try {
      final v = await AppApi.getDailyVerse();
      if (!mounted || v == null) return;
      setState(() {
        _verseRef = v["reference"]?.toString();
        _verseText = v["text"]?.toString();
      });
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final s = await AppApi.getStats();
      if (!mounted) return;
      setState(() {
        _isPremium = s["isPremium"] == true;
        _superLikes = (s["superLikesLeft"] as num?)?.toInt() ?? 0;
        _boosts = (s["boostsRemaining"] as num?)?.toInt() ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final p = await AppApi.getMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPremium() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const PremiumPage()));
    _loadStats();
  }

  Future<void> _openStore() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const StorePage()));
    _loadStats();
  }

  Future<void> _openSettings() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SettingsPage()));
    _load();
    _loadStats();
  }

  Future<void> _editProfile() async {
    final p = _profile;
    if (p == null) return;
    final saved = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => EditProfilePage(profile: p)));
    if (saved == true) _load();
  }

  Future<void> _logout() async {
    await AppApi.setOnline(false);
    await TokenStorage.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
  }

  Future<void> _managePhotos() async {
    final p = _profile;
    if (p == null) return;
    final current = (p["mediaFiles"] as List?)?.cast<String>() ?? [];
    final currentLocked = (p["lockedPhotos"] as List?)?.cast<String>() ?? [];
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              PhotoManagerPage(initial: current, initialLocked: currentLocked)),
    );
    if (result == null) return;
    final photos = (result["photos"] as List).cast<String>();
    final locked = (result["locked"] as List).cast<String>();
    EasyLoading.show(status: "Salvando...");
    try {
      await AppApi.upsertProfile({
        "fullName": p["fullName"],
        "gender": p["gender"],
        "birthday": p["birthday"],
        "city": p["city"],
        "addressText": p["addressText"],
        "denomination": p["denomination"],
        "churchFrequency": p["churchFrequency"],
        "intention": p["intention"],
        "interests": (p["interests"] as List?)?.cast<String>() ?? [],
        "about": p["about"],
        "mediaFiles": photos,
        "lockedPhotos": locked,
        "profilePicture": photos.isNotEmpty ? photos.first : null,
      });
      EasyLoading.dismiss();
      _load();
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showError("Falha ao salvar fotos");
    }
  }

  int? _age(String? birthday) {
    if (birthday == null) return null;
    final b = DateTime.tryParse(birthday);
    if (b == null) return null;
    final now = DateTime.now();
    int a = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) a--;
    return a;
  }

  int _completion(Map<String, dynamic>? p, List<String> photos) {
    if (p == null) return 0;
    int done = 0;
    const total = 7;
    if ((p["fullName"]?.toString() ?? "").isNotEmpty) done++;
    if ((p["about"]?.toString() ?? "").isNotEmpty) done++;
    if ((p["city"]?.toString() ?? "").isNotEmpty) done++;
    if (p["denomination"] != null) done++;
    if (p["intention"] != null) done++;
    if ((p["interests"] as List?)?.isNotEmpty ?? false) done++;
    if (photos.length >= 2) done++;
    return ((done / total) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final p = _profile;
    final photos = (p?["mediaFiles"] as List?)?.cast<String>() ?? [];
    final interests = (p?["interests"] as List?)?.cast<String>() ?? [];
    final age = _age(p?["birthday"]?.toString());
    final pct = _completion(p, photos);
    final photo = photos.isNotEmpty
        ? photos.first
        : p?["profilePicture"]?.toString();
    final subtitle = (p?["intention"] ?? p?["city"])?.toString();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          // Topo: configurações (esq) + editar (dir)
          Row(
            children: [
              _topBtn(Icons.settings, _openSettings),
              const Spacer(),
              Row(children: [
                Icon(Icons.favorite, color: AppTheme.gold, size: 22),
                const SizedBox(width: 6),
                const Text("Meu Perfil",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy)),
              ]),
              const Spacer(),
              _topBtn(Icons.edit, _editProfile),
            ],
          ),
          const SizedBox(height: 14),
          // Avatar com anel de progresso + % completo
          Center(child: _avatarRing(photo, pct)),
          const SizedBox(height: 22),
          // Nome, idade + badge VIP
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    p == null
                        ? "Sem perfil"
                        : "${(p["fullName"] ?? "").toString().split(" ").first}${age != null ? ", $age" : ""}",
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy),
                  ),
                ),
                if (p?["isVerified"] == true) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified, color: AppTheme.gold, size: 22),
                ],
                if (_isPremium) ...[
                  const SizedBox(width: 8),
                  _vipBadge(),
                ],
              ],
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8A91A3), fontSize: 14)),
            ),
          const SizedBox(height: 22),
          // Cards rápidos
          _quickCards(),
          const SizedBox(height: 18),
          if (_verseText != null) ...[
            _verseCard(),
            const SizedBox(height: 18),
          ],
          if (!_isPremium) _getPlusBanner(),
          if (!_isPremium) const SizedBox(height: 18),
          // Detalhes do perfil
          _details(p, interests),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _managePhotos,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text("Gerenciar fotos"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.navy,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text("Sair da conta"),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.navy,
                  side: const BorderSide(color: Color(0xFFE0E3EB)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
              color: Color(0xFFF0F2F7), shape: BoxShape.circle),
          child: Icon(icon, color: AppTheme.navy, size: 22),
        ),
      );

  Widget _vipBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [Color(0xFFE9C75A), Color(0xFFD4AF37)]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.workspace_premium, color: AppTheme.navy, size: 13),
          SizedBox(width: 3),
          Text("VIP",
              style: TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 11)),
        ]),
      );

  Widget _avatarRing(String? photo, int pct) {
    return SizedBox(
      width: 156,
      height: 156,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 146,
            height: 146,
            child: CircularProgressIndicator(
              value: pct / 100,
              strokeWidth: 5,
              backgroundColor: const Color(0xFFE8EAF0),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFD4AF37)),
            ),
          ),
          CircleAvatar(
            radius: 62,
            backgroundColor: const Color(0xFFE8EAF0),
            backgroundImage:
                photo != null ? CachedNetworkImageProvider(photo) : null,
            child: photo == null
                ? const Icon(Icons.person, color: Colors.white, size: 50)
                : null,
          ),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFE9C75A), Color(0xFFD4AF37)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Text("$pct% Completo",
                  style: const TextStyle(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickCards() {
    final cards = <Widget>[
      _quickCard(Icons.star_rounded, const Color(0xFF3FA9F5),
          "$_superLikes Super Likes", _openStore),
      if (!_isPremium)
        _quickCard(Icons.workspace_premium, AppTheme.gold, "Assinar Plus",
            _openPremium),
      _quickCard(Icons.rocket_launch_rounded, const Color(0xFFEB5C7A),
          "$_boosts Boosts", _openStore),
    ];
    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _quickCard(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDEFF4)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD7DCE6)),
              ),
              child: const Icon(Icons.add, color: Color(0xFF9AA1B2), size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verseCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.gold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold.withOpacity(0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text("✝️", style: TextStyle(fontSize: 14)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_verseText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.navy,
                        height: 1.25,
                        fontStyle: FontStyle.italic)),
                Text(_verseRef ?? "",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.gold.withOpacity(0.95))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getPlusBanner() {
    return GestureDetector(
      onTap: _openPremium,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [AppTheme.navy, Color(0xFF1E2C5A)]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            const Text("Seja VIP",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 6),
            const Text(
              "Curtidas ilimitadas, veja quem te curtiu e muito mais!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFE9C75A), Color(0xFFD4AF37)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text("Assinar agora",
                  style: TextStyle(
                      color: AppTheme.navy,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(Map<String, dynamic>? p, List<String> interests) {
    final about = p?["about"]?.toString() ?? "";
    final hasInfo = p?["denomination"] != null ||
        p?["churchFrequency"] != null ||
        p?["intention"] != null ||
        p?["city"] != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasInfo) ...[
          _sectionTitle("Informações"),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEDEFF4)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (p?["denomination"] != null)
                  _pill(Icons.book, p!["denomination"].toString()),
                if (p?["churchFrequency"] != null)
                  _pill(Icons.church, p!["churchFrequency"].toString()),
                if (p?["intention"] != null)
                  _pill(Icons.favorite, p!["intention"].toString()),
                if (p?["city"] != null)
                  _pill(Icons.location_on, p!["city"].toString()),
              ],
            ),
          ),
        ],
        if (about.isNotEmpty) ...[
          const SizedBox(height: 22),
          _sectionTitle("Sobre mim"),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEDEFF4)),
            ),
            child: Text(about,
                style: const TextStyle(
                    color: Color(0xFF444B5E), fontSize: 15, height: 1.4)),
          ),
        ],
        if (interests.isNotEmpty) ...[
          const SizedBox(height: 22),
          _sectionTitle("Interesses"),
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
                          Icon(interestIcon(it), size: 15, color: AppTheme.navy),
                          const SizedBox(width: 6),
                          Text(
                            it,
                            style: const TextStyle(
                                color: AppTheme.navy,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.navy));

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
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ]),
      );
}
