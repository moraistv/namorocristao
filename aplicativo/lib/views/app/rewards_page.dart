import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:mioamoreapp/services/ads_service.dart';
import 'package:mioamoreapp/services/analytics_service.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/realtime_bus.dart';
import 'package:mioamoreapp/services/rewarded_ad_service.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';
import 'package:mioamoreapp/views/app/boost_flow.dart';

class _KindMeta {
  final IconData icon;
  final Color color;
  final String singular;
  final String plural;
  const _KindMeta(this.icon, this.color, this.singular, this.plural);

  String label(int amount) => amount == 1 ? singular : plural;
}

const _kinds = <String, _KindMeta>{
  "SUPERLIKES": _KindMeta(
      Icons.star_rounded, Color(0xFF3FA9F5), "Super Like", "Super Likes"),
  "BOOSTS": _KindMeta(Icons.bolt_rounded, Color(0xFF8B5CF6), "Boost", "Boosts"),
  "CREDITS": _KindMeta(
      Icons.monetization_on_rounded, Color(0xFFE0A91B), "crédito", "créditos"),
  "VIP": _KindMeta(Icons.workspace_premium, Color(0xFFD4AF37), "hora de VIP",
      "horas de VIP"),
};

const _fallbackKind =
    _KindMeta(Icons.card_giftcard, Color(0xFF7A849C), "item", "itens");

_KindMeta _metaOf(String? kind) => _kinds[kind] ?? _fallbackKind;

/// Recompensas por anúncio premiado: substitui a antiga loja paga.
/// As ofertas, limites e esperas vêm do painel (`/me/rewards`).
class RewardsPage extends StatefulWidget {
  /// Frase opcional no topo (ex.: "Seus Super Likes acabaram").
  final String? highlight;

  /// Tipo de recompensa em destaque (ex.: "VIP"): aparece primeiro e marcado.
  final String? focusKind;
  const RewardsPage({super.key, this.highlight, this.focusKind});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  bool _loading = true;
  String? _loadError;
  bool _enabled = false;
  List<Map<String, dynamic>> _rewards = [];
  Map<String, dynamic>? _dailyCap;
  int _superLikes = 0;
  int _boosts = 0;
  int _credits = 0;
  bool _isVip = false;
  DateTime? _vipUntil;
  String? _busyId;
  int _loadGeneration = 0;
  Timer? _ticker;
  final Map<String, int> _cooldowns = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    RealtimeBus.store.addListener(_onRemoteChange);
    RealtimeBus.account.addListener(_onRemoteChange);
    AdsService.revision.addListener(_onRemoteChange);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    RealtimeBus.store.removeListener(_onRemoteChange);
    RealtimeBus.account.removeListener(_onRemoteChange);
    AdsService.revision.removeListener(_onRemoteChange);
    super.dispose();
  }

  void _onRemoteChange() {
    if (!mounted) return;
    unawaited(_load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_loadGeneration;
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      await AdsService.load();
      final results = await Future.wait<Map<String, dynamic>>([
        AppApi.getRewards(),
        AppApi.getStats(),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      final overview = results[0];
      final stats = results[1];
      // O evento do servidor pode se perder ao fechar o anúncio (o socket
      // reconecta): os anúncios seguem o que o servidor diz agora.
      AdsService.setPremium(
        AdsService.adFreeFrom(stats),
        until: DateTime.tryParse(stats["premiumUntil"]?.toString() ?? ""),
      );
      final rewards = ((overview["rewards"] as List?) ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      setState(() {
        _enabled = overview["enabled"] == true && AdsService.rewardedAvailable;
        _rewards = rewards;
        _dailyCap = overview["dailyCap"] is Map
            ? Map<String, dynamic>.from(overview["dailyCap"] as Map)
            : null;
        _superLikes = (stats["superLikesLeft"] as num?)?.toInt() ?? 0;
        _boosts = (stats["boostsRemaining"] as num?)?.toInt() ?? 0;
        _credits = (stats["credits"] as num?)?.toInt() ?? 0;
        _isVip = stats["isPremium"] == true;
        _vipUntil = DateTime.tryParse(stats["premiumUntil"]?.toString() ?? "")
            ?.toLocal();
        _cooldowns
          ..clear()
          ..addEntries([
            for (final reward in rewards)
              if (((reward["cooldownLeftSecs"] as num?)?.toInt() ?? 0) > 0)
                MapEntry(
                  reward["id"].toString(),
                  (reward["cooldownLeftSecs"] as num).toInt(),
                ),
          ]);
        _loading = false;
        _loadError = null;
      });
      _syncTicker();
      if (_enabled) unawaited(RewardedAdService.preload());
    } on AppApiException catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        if (_rewards.isEmpty) _loadError = error.message;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        if (_rewards.isEmpty) {
          _loadError = "Não foi possível carregar as recompensas.";
        }
      });
    }
  }

  /// Mantém um relógio de 1s só enquanto houver espera em andamento.
  void _syncTicker() {
    if (_cooldowns.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _cooldowns.updateAll((_, secs) => secs - 1);
        _cooldowns.removeWhere((_, secs) => secs <= 0);
      });
      if (_cooldowns.isEmpty) _syncTicker();
    });
  }

  Future<void> _activateBoost() async {
    final activated = await activateBoostFlow(context);
    if (activated && mounted) unawaited(_load(silent: true));
  }

  Future<void> _watch(Map<String, dynamic> reward) async {
    if (_busyId != null) return;
    final rewardId = reward["id"].toString();
    setState(() => _busyId = rewardId);
    try {
      EasyLoading.show(status: "Carregando anúncio...");
      final ready = await RewardedAdService.ensureReady();
      if (!ready) {
        EasyLoading.dismiss();
        EasyLoading.showInfo(
          "Nenhum anúncio disponível agora. Tente novamente em instantes.",
        );
        return;
      }

      final start = await AppApi.startReward(rewardId);
      final claimId = start["claimId"]?.toString();
      final ssv = start["ssv"];
      final userId = ssv is Map ? ssv["userId"]?.toString() : null;
      if (claimId == null ||
          claimId.isEmpty ||
          userId == null ||
          userId.isEmpty) {
        throw AppApiException(
          "Resposta inesperada do servidor.",
          0,
          AppApiErrorType.invalidResponse,
        );
      }

      EasyLoading.dismiss();
      final outcome =
          await RewardedAdService.show(userId: userId, claimId: claimId);
      switch (outcome) {
        case RewardedAdOutcome.earned:
          await _confirm(claimId, reward);
        case RewardedAdOutcome.dismissed:
          EasyLoading.showInfo(
            "Assista ao anúncio até o fim para ganhar a recompensa.",
          );
        case RewardedAdOutcome.unavailable:
          EasyLoading.showInfo(
            "Nenhum anúncio disponível agora. Tente novamente em instantes.",
          );
        case RewardedAdOutcome.failed:
          EasyLoading.showError(
            "Não foi possível exibir o anúncio. Tente novamente.",
          );
      }
    } on AppApiException catch (error) {
      EasyLoading.dismiss();
      EasyLoading.showError(error.message);
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showError("Não foi possível concluir. Tente novamente.");
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
        unawaited(_load(silent: true));
      }
    }
  }

  /// Confirma o resgate no servidor. Com SSV obrigatório a recompensa vem do
  /// Google e pode levar alguns segundos, então consulta algumas vezes.
  Future<void> _confirm(String claimId, Map<String, dynamic> reward) async {
    EasyLoading.show(status: "Confirmando recompensa...");
    // Teto de ~20s no total: com rede lenta a tela não fica presa esperando.
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(deadline)) {
      Map<String, dynamic> result;
      try {
        result = await AppApi.completeReward(claimId)
            .timeout(const Duration(seconds: 8));
      } on TimeoutException {
        continue;
      } on AppApiException catch (error) {
        if (!error.retryable) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        continue;
      }

      final status = result["status"]?.toString();
      if (status == "GRANTED") {
        final kind =
            result["kind"]?.toString() ?? reward["kind"]?.toString() ?? "";
        final amount = (result["amount"] as num?)?.toInt() ?? 1;
        AnalyticsService.rewardEarned(kind);
        RealtimeBus.accountChanged();
        EasyLoading.dismiss();
        EasyLoading.showSuccess(
          "Você ganhou +$amount ${_metaOf(kind).label(amount)}",
        );
        return;
      }
      if (status == "EXPIRED") {
        EasyLoading.dismiss();
        EasyLoading.showError(
          "O tempo para confirmar a recompensa acabou. Tente de novo.",
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }
    EasyLoading.dismiss();
    EasyLoading.showInfo(
      "Estamos confirmando seu anúncio. A recompensa chega em instantes.",
    );
  }

  String _wait(int secs) => secs >= 60
      ? "${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}"
      : "${secs}s";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.navy,
        elevation: 0.5,
        title: const Text("Recompensas"),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading && _rewards.isEmpty && _loadError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                style: AppTheme.primaryButton,
                onPressed: () => unawaited(_load()),
                child: const Text("Tentar novamente"),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.highlight != null && widget.highlight!.isNotEmpty)
            _highlightBanner(widget.highlight!),
          if (_isVip) _vipStatus(),
          _balances(),
          const SizedBox(height: 16),
          if (!_enabled)
            _notice(
              "As recompensas estão indisponíveis no momento. Volte mais tarde.",
            )
          else if (_rewards.isEmpty)
            _notice("Nenhuma recompensa disponível agora.")
          else ...[
            if (widget.focusKind != null &&
                !_rewards.any((r) => r["kind"] == widget.focusKind)) ...[
              _notice(
                widget.focusKind == "VIP"
                    ? "O VIP por anúncio não está disponível agora."
                    : "Esta recompensa não está disponível agora.",
              ),
              const SizedBox(height: 16),
            ],
            const SectionTitle("Assista e ganhe"),
            const SizedBox(height: 4),
            _capLine(),
            const SizedBox(height: 8),
            for (final reward in _orderedRewards()) _rewardCard(reward),
            const SizedBox(height: 4),
            const Text(
              "Os anúncios ajudam a manter o app gratuito. Os limites renovam todo dia.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  /// Ofertas do tipo em destaque primeiro; o resto mantém a ordem do painel.
  List<Map<String, dynamic>> _orderedRewards() {
    final focus = widget.focusKind;
    if (focus == null) return _rewards;
    return [
      ..._rewards.where((r) => r["kind"] == focus),
      ..._rewards.where((r) => r["kind"] != focus),
    ];
  }

  String _two(int value) => value.toString().padLeft(2, "0");

  Widget _vipStatus() {
    final until = _vipUntil;
    final text = until == null
        ? "Você é VIP."
        : "Você é VIP até ${_two(until.day)}/${_two(until.month)} às ${_two(until.hour)}:${_two(until.minute)}.";
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.gold.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        border: Border.all(color: AppTheme.gold.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium, color: AppTheme.gold, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.navy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlightBanner(String text) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.gold.withOpacity(0.14),
          borderRadius: BorderRadius.circular(AppTheme.rMd),
          border: Border.all(color: AppTheme.gold.withOpacity(0.4)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.navy,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _notice(String text) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.rMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );

  Widget _capLine() {
    final cap = _dailyCap;
    final limit = (cap?["limit"] as num?)?.toInt() ?? 0;
    if (cap == null || limit <= 0) return const SizedBox.shrink();
    final used = (cap["used"] as num?)?.toInt() ?? 0;
    return Text(
      "Hoje você ganhou $used de $limit recompensas.",
      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
    );
  }

  Widget _balances() {
    return Row(
      children: [
        Expanded(
          child: _balanceCard(
            _kinds["SUPERLIKES"]!,
            _superLikes,
            "Super Likes",
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _balanceCard(
            _kinds["BOOSTS"]!,
            _boosts,
            "Boosts",
            hint: _boosts > 0 ? "Toque para ativar" : null,
            onTap: _boosts > 0 ? () => unawaited(_activateBoost()) : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _balanceCard(_kinds["CREDITS"]!, _credits, "Créditos"),
        ),
      ],
    );
  }

  Widget _balanceCard(
    _KindMeta meta,
    int value,
    String label, {
    String? hint,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: meta.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(meta.icon, color: meta.color, size: 20),
          ),
          const SizedBox(height: 7),
          Text(
            "$value",
            style: const TextStyle(
              color: AppTheme.navy,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          if (hint != null)
            Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: meta.color,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }

  Widget _rewardCard(Map<String, dynamic> reward) {
    final id = reward["id"].toString();
    final meta = _metaOf(reward["kind"]?.toString());
    final amount = (reward["amount"] as num?)?.toInt() ?? 1;
    final dailyLimit = (reward["dailyLimit"] as num?)?.toInt() ?? 0;
    final used = (reward["usedToday"] as num?)?.toInt() ?? 0;
    final blockedBy = reward["blockedBy"]?.toString();
    final cooldownLeft = _cooldowns[id] ?? 0;
    final busy = _busyId == id;
    final locked = blockedBy == "LIMIT" ||
        blockedBy == "DAILY_CAP" ||
        blockedBy == "ALREADY_VIP";

    String buttonLabel;
    if (busy) {
      buttonLabel = "Aguarde...";
    } else if (blockedBy == "ALREADY_VIP") {
      // VIP sem validade: não há horas a somar.
      buttonLabel = "Você já é VIP";
    } else if (blockedBy == "LIMIT") {
      buttonLabel = "Volte amanhã";
    } else if (blockedBy == "DAILY_CAP") {
      buttonLabel = "Limite do dia atingido";
    } else if (cooldownLeft > 0) {
      buttonLabel = "Próximo anúncio em ${_wait(cooldownLeft)}";
    } else {
      buttonLabel = "Assistir anúncio";
    }
    final canTap = !locked && cooldownLeft == 0 && _busyId == null;
    final description = reward["description"]?.toString() ?? "";
    final focused =
        widget.focusKind != null && reward["kind"] == widget.focusKind;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        border: focused
            ? Border.all(color: AppTheme.gold, width: 2)
            : Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: meta.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(meta.icon, color: meta.color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward["title"]?.toString() ?? "",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "+$amount ${meta.label(amount)} por anúncio",
                      style: TextStyle(
                        color: meta.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      dailyLimit > 0
                          ? "Hoje: $used de $dailyLimit"
                          : "Sem limite diário",
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: AppTheme.primaryButton.copyWith(
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              onPressed: canTap ? () => unawaited(_watch(reward)) : null,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_circle_fill_rounded, size: 20),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
