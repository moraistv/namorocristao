import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/ads_service.dart';
import 'package:mioamoreapp/services/realtime_bus.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';

/// Tela de assinatura VIP (paywall) com planos, benefícios e cores do app.
class PremiumPage extends StatefulWidget {
  /// Frase opcional no topo (ex.: "Veja quem te curtiu").
  final String? highlight;
  const PremiumPage({super.key, this.highlight});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  bool _loading = true;
  bool _isPremium = false;
  String? _premiumUntil;
  List<Map<String, dynamic>> _plans = [];
  String _selected = "quarterly";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await AppApi.getStats();
      setState(() {
        _isPremium = s["isPremium"] == true;
        _premiumUntil = s["premiumUntil"]?.toString();
        _plans = ((s["plans"] as List?) ?? []).cast<Map<String, dynamic>>();
        if (_plans.isNotEmpty &&
            !_plans.any((p) => p["id"] == _selected)) {
          _selected = _plans.first["id"].toString();
        }
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _subscribe() async {
    EasyLoading.show(status: "Ativando VIP...");
    try {
      await AppApi.subscribePlan(_selected);
      // VIP não vê anúncios — esconde imediatamente (reflete na hora).
      AdsService.setPremium(true);
      RealtimeBus.accountChanged();
      EasyLoading.dismiss();
      EasyLoading.showSuccess("Bem-vindo ao VIP! 👑");
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showError("Falha ao ativar");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: Column(
                children: [
                  _header(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      children: [
                        if (_isPremium) _activeCard() else ..._paywall(),
                      ],
                    ),
                  ),
                  if (!_isPremium) _bottomBar(),
                ],
              ),
            ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFF1D27A), Color(0xFFD4AF37)]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppTheme.gold.withOpacity(0.5),
                    blurRadius: 24,
                    spreadRadius: 2)
              ],
            ),
            child: const Icon(Icons.workspace_premium,
                color: AppTheme.navy, size: 42),
          ),
          const SizedBox(height: 14),
          const Text("Namoro Cristão VIP",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            widget.highlight ?? "Aproveite o máximo da sua jornada no amor 🙏",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<Widget> _paywall() {
    const benefits = [
      ["favorite", "Veja quem te curtiu", "Dê match na hora com quem já gostou de você"],
      ["star", "Mais Super Likes", "Destaque-se com até 5 Super Likes por dia"],
      ["all_inclusive", "Curtidas ilimitadas", "Curta quantos perfis quiser, sem limites"],
      ["visibility_off", "Modo invisível", "Navegue com discrição quando quiser"],
      ["bolt", "Boost de perfil", "Apareça para mais pessoas na sua região"],
      ["lock_open", "Fotos privadas", "Peça e libere fotos com mais facilidade"],
    ];
    return [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: benefits
              .map((b) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: AppTheme.gold.withOpacity(0.18),
                              shape: BoxShape.circle),
                          child: Icon(_icon(b[0]), color: AppTheme.gold, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b[1],
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(b[2],
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
      const SizedBox(height: 22),
      const Text("Escolha seu plano",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 12),
      ..._plans.map(_planCard),
    ];
  }

  Widget _planCard(Map<String, dynamic> plan) {
    final id = plan["id"].toString();
    final selected = id == _selected;
    final popular = id == "quarterly";
    return GestureDetector(
      onTap: () => setState(() => _selected = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.gold.withOpacity(0.16) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? AppTheme.gold : Colors.white12,
              width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppTheme.gold : Colors.white38),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(plan["label"]?.toString() ?? "",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      if (popular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: AppTheme.gold,
                              borderRadius: BorderRadius.circular(10)),
                          child: const Text("MAIS POPULAR",
                              style: TextStyle(
                                  color: AppTheme.navy,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(plan["monthly"]?.toString() ?? "",
                      style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
                ],
              ),
            ),
            Text(plan["price"]?.toString() ?? "",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _activeCard() {
    String validade = "";
    if (_premiumUntil != null) {
      final d = DateTime.tryParse(_premiumUntil!);
      if (d != null) {
        validade = "Válido até ${d.day.toString().padLeft(2, '0')}/"
            "${d.month.toString().padLeft(2, '0')}/${d.year}";
      }
    }
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.gold.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Icon(Icons.verified, color: AppTheme.gold, size: 48),
          const SizedBox(height: 12),
          const Text("Você é VIP! 👑",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            validade.isEmpty ? "Aproveite todos os benefícios." : validade,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(color: AppTheme.navy),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _subscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.navy,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("Assinar agora",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          ),
          const SizedBox(height: 8),
          const Text("Cancele quando quiser. Renovação automática.",
              style: TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  IconData _icon(String name) {
    switch (name) {
      case "favorite":
        return Icons.favorite;
      case "star":
        return Icons.star;
      case "all_inclusive":
        return Icons.all_inclusive;
      case "visibility_off":
        return Icons.visibility_off;
      case "bolt":
        return Icons.bolt;
      case "lock_open":
        return Icons.lock_open;
      default:
        return Icons.check;
    }
  }
}
