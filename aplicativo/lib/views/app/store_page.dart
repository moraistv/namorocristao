import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/analytics_service.dart';
import 'package:mioamoreapp/services/ads_service.dart';
import 'package:mioamoreapp/services/realtime_bus.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';

/// Loja de produtos (créditos, super likes, boosts, VIP) lida de /config/store.
/// A compra real passa pela Google Play; aqui chamamos /me/purchase para conceder.
class StorePage extends StatefulWidget {
  const StorePage({super.key});
  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  bool _loading = true;
  List<Map<String, dynamic>> _products = [];
  int _credits = 0;

  static const _kindLabel = {
    "PREMIUM": "Planos VIP",
    "CREDITS": "Créditos",
    "SUPERLIKES": "Super Likes",
    "BOOSTS": "Boosts",
  };

  @override
  void initState() {
    super.initState();
    _load();
    RealtimeBus.store.addListener(_load);
    RealtimeBus.account.addListener(_load);
  }

  @override
  void dispose() {
    RealtimeBus.store.removeListener(_load);
    RealtimeBus.account.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final store = await AppApi.getStore();
      final stats = await AppApi.getStats();
      if (!mounted) return;
      setState(() {
        _products = ((store["products"] as List?) ?? []).cast<Map<String, dynamic>>();
        _credits = (stats["credits"] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _price(int cents) => "R\$ ${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')}";

  Future<void> _buy(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p["title"]?.toString() ?? "Comprar"),
        content: Text(
            "Confirmar compra por ${_price((p["priceCents"] ?? 0) as int)}?\n\n(A cobrança real será feita pela Google Play.)"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: AppTheme.navy),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Comprar"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    EasyLoading.show(status: "Processando...");
    try {
      await AppApi.purchase(p["id"].toString());
      AnalyticsService.purchase(p["id"].toString(), p["kind"]?.toString() ?? "");
      // Se comprou VIP, esconde anúncios; e atualiza todas as telas na hora.
      if ((p["kind"]?.toString() ?? "") == "PREMIUM") {
        AdsService.setPremium(true);
      }
      RealtimeBus.accountChanged();
      EasyLoading.dismiss();
      EasyLoading.showSuccess("Compra concluída! 🎉");
      _load();
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError("Falha na compra");
    }
  }

  @override
  Widget build(BuildContext context) {
    final kinds = ["PREMIUM", "CREDITS", "SUPERLIKES", "BOOSTS"];
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.navy,
        elevation: 0.5,
        title: const Text("Loja"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: AppTheme.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text("🪙 $_credits",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppTheme.navy)),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Text("Nenhum produto disponível no momento.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF7A849C))),
                ))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final k in kinds)
                      if (_products.any((p) => p["kind"] == k)) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                          child: Text(_kindLabel[k] ?? k,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.navy)),
                        ),
                        ..._products
                            .where((p) => p["kind"] == k)
                            .map(_productTile),
                      ],
                  ],
                ),
    );
  }

  Widget _productTile(Map<String, dynamic> p) {
    final kind = p["kind"]?.toString();
    final amount = (p["amount"] ?? 0) as int;
    final days = (p["durationDays"] ?? 0) as int;
    final sub = kind == "PREMIUM" ? "$days dias de VIP" : "$amount unidades";
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p["title"]?.toString() ?? "",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.navy)),
                const SizedBox(height: 2),
                Text(p["description"]?.toString().isNotEmpty == true
                    ? p["description"].toString()
                    : sub,
                    style: const TextStyle(
                        color: Color(0xFF7A849C), fontSize: 13)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _buy(p),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: AppTheme.navy,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20))),
            child: Text(_price((p["priceCents"] ?? 0) as int),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
