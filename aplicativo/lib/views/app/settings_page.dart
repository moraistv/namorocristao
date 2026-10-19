import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mioamoreapp/config/config.dart';
import 'package:mioamoreapp/helpers/url_launcher_helper.dart';
import 'package:mioamoreapp/providers/version_provider.dart';
import 'package:mioamoreapp/services/ads_service.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/push_device_service.dart';
import 'package:mioamoreapp/services/realtime_bus.dart';
import 'package:mioamoreapp/services/token_storage.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';
import 'package:mioamoreapp/views/app/rewards_page.dart';
import 'package:mioamoreapp/views/app/vip_offer.dart';
import 'package:mioamoreapp/views/auth/login_page.dart';

/// Configurações da conta: recompensas, notificações, privacidade, sair e excluir conta.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isPremium = false;
  bool _notifications = TokenStorage.notificationsEnabled;
  bool _incognito = false;
  bool _changingNotifications = false;
  bool _loggingOut = false;

  String? get _devicePlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return "android";
      case TargetPlatform.iOS:
        return "ios";
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    // VIP ganho ou vencido com a tela aberta (ex.: incógnito desligado no fim).
    RealtimeBus.account.addListener(_onAccountChanged);
  }

  void _onAccountChanged() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    RealtimeBus.account.removeListener(_onAccountChanged);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final stats = await AppApi.getStats();
      final profile = await AppApi.getMyProfile();
      if (!mounted) return;
      // Estado real: sem VIP, o servidor desliga o incógnito restrito ao VIP.
      final incognitoActive = stats["incognitoActive"];
      setState(() {
        _isPremium = stats["isPremium"] == true;
        _incognito = incognitoActive is bool
            ? incognitoActive
            : profile?["incognito"] == true;
        _notifications = TokenStorage.notificationsEnabled;
      });
    } catch (_) {}
  }

  Future<void> _toggleNotifications(bool enabled) async {
    if (_changingNotifications) return;
    setState(() => _changingNotifications = true);
    var notifiedShell = false;

    void notifyShell() {
      if (notifiedShell) return;
      RealtimeBus.notificationsChanged();
      notifiedShell = true;
    }

    try {
      if (!enabled) {
        final result = await PushDeviceService.disableNotifications();
        notifyShell();
        if (!mounted) return;
        setState(() => _notifications = false);
        if (result.remoteRemovalPending) {
          EasyLoading.showInfo(
            "Notificações desativadas neste aparelho. A limpeza no servidor será tentada novamente.",
          );
        } else if (!result.localTokenInvalidated) {
          EasyLoading.showInfo(
            "Notificações desativadas no app, mas o token do aparelho não pôde ser invalidado agora.",
          );
        } else {
          EasyLoading.showSuccess("Notificações desativadas.");
        }
        return;
      }

      final platform = _devicePlatform;
      if (platform == null) {
        await PushDeviceService.disableNotifications();
        notifyShell();
        if (mounted) {
          setState(() => _notifications = false);
          EasyLoading.showInfo(
            "Notificações não estão disponíveis nesta plataforma.",
          );
        }
        return;
      }

      final settings = await FirebaseMessaging.instance.requestPermission();
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) {
        await PushDeviceService.disableNotifications();
        notifyShell();
        if (mounted) {
          setState(() => _notifications = false);
          EasyLoading.showInfo(
            "Permita notificações nas configurações do aparelho para ativá-las.",
          );
        }
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        throw AppApiException(
          "Não foi possível obter o token de notificações.",
          0,
          AppApiErrorType.unexpected,
        );
      }

      await TokenStorage.setNotificationsEnabled(true);
      final result = await PushDeviceService.registerToken(
        token,
        platform: platform,
      );
      if (!result.registered) {
        throw AppApiException(
          "Não foi possível confirmar a ativação das notificações.",
          0,
          AppApiErrorType.unexpected,
        );
      }

      notifyShell();
      if (!mounted) return;
      setState(() => _notifications = true);
      if (result.cleanupPending) {
        EasyLoading.showInfo(
          "Notificações ativadas. Uma limpeza anterior será tentada novamente.",
        );
      }
    } catch (error) {
      try {
        await PushDeviceService.disableNotifications();
      } catch (cleanupError) {
        debugPrint(
          "Não foi possível concluir a limpeza local de push: $cleanupError",
        );
      }
      notifyShell();
      if (mounted) {
        setState(() => _notifications = false);
        EasyLoading.showError(
          error is AppApiException
              ? error.message
              : "Não foi possível alterar as notificações.",
        );
      }
    } finally {
      if (mounted) setState(() => _changingNotifications = false);
    }
  }

  Future<void> _toggleIncognito(bool value) async {
    setState(() => _incognito = value);
    try {
      await AppApi.setIncognito(value);
    } on AppApiException catch (error) {
      if (!mounted) return;
      setState(() => _incognito = !value);
      if (error.code == "PREMIUM_ONLY" && value) {
        final vip = await offerVipByAd(
          context,
          reason: "O modo incógnito é um recurso VIP.",
        );
        if (vip && mounted) {
          setState(() => _isPremium = true);
          await _toggleIncognito(true);
        }
      } else {
        EasyLoading.showError(error.message);
      }
    }
  }

  Future<void> _setOfflineForLogout() async {
    try {
      await AppApi.setOnline(false).timeout(const Duration(seconds: 2));
    } catch (error) {
      debugPrint("Não foi possível encerrar a presença no logout: $error");
    }
  }

  Future<void> _cleanupPushForLogout() async {
    try {
      await PushDeviceService.cleanupForLogout();
    } catch (error) {
      debugPrint("A limpeza remota de push ficou pendente: $error");
    }
  }

  Future<void> _logout({
    required int expectedGeneration,
    required String? expectedAccessToken,
    required String? expectedRefreshToken,
  }) async {
    if (_loggingOut ||
        TokenStorage.sessionGeneration != expectedGeneration ||
        TokenStorage.accessToken != expectedAccessToken ||
        TokenStorage.refreshToken != expectedRefreshToken) {
      return;
    }
    _loggingOut = true;
    await Future.wait<void>([
      _setOfflineForLogout(),
      _cleanupPushForLogout(),
    ]);
    final cleared = await TokenStorage.clearIfCurrent(
      expectedGeneration: expectedGeneration,
      expectedAccessToken: expectedAccessToken,
      expectedRefreshToken: expectedRefreshToken,
    );
    if (!mounted) return;
    if (!cleared && TokenStorage.isLoggedIn) return;
    if (TokenStorage.sessionGeneration != expectedGeneration + 1) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _confirmLogout() async {
    final expectedGeneration = TokenStorage.sessionGeneration;
    final expectedAccessToken = TokenStorage.accessToken;
    final expectedRefreshToken = TokenStorage.refreshToken;
    final confirmed = await _confirm("Sair da conta", "Deseja realmente sair?");
    if (confirmed) {
      await _logout(
        expectedGeneration: expectedGeneration,
        expectedAccessToken: expectedAccessToken,
        expectedRefreshToken: expectedRefreshToken,
      );
    }
  }

  Future<void> _deleteAccount() async {
    final expectedGeneration = TokenStorage.sessionGeneration;
    final expectedAccessToken = TokenStorage.accessToken;
    final expectedRefreshToken = TokenStorage.refreshToken;
    final confirmed = await _confirm(
      "Excluir conta",
      "Sua conta e seus dados serão removidos. Esta ação não pode ser desfeita. Continuar?",
      danger: true,
    );
    if (!confirmed ||
        TokenStorage.sessionGeneration != expectedGeneration ||
        TokenStorage.accessToken != expectedAccessToken ||
        TokenStorage.refreshToken != expectedRefreshToken) {
      return;
    }
    EasyLoading.show(status: "Processando...");
    try {
      await AppApi.requestAccountDeletion();
      EasyLoading.dismiss();
      await _logout(
        expectedGeneration: expectedGeneration,
        expectedAccessToken: expectedAccessToken,
        expectedRefreshToken: expectedRefreshToken,
      );
    } on AppApiException catch (error) {
      EasyLoading.dismiss();
      EasyLoading.showError(error.message);
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showError("Falha ao solicitar exclusão");
    }
  }

  Future<bool> _confirm(String title, String body,
      {bool danger = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  danger ? "Excluir" : "Confirmar",
                  style: TextStyle(
                    color: danger ? Colors.red : AppTheme.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Uri? _configuredUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != "https" || uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(versionProvider).when(
          data: (value) => value,
          loading: () => "carregando versão...",
          error: (_, __) => "versão indisponível",
        );
    final privacyUrl = _configuredUrl(privacyPolicyUrl);
    final termsUrl = _configuredUrl(termsAndConditionsUrl);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.navy,
        elevation: 0,
        title: const Text(
          "Configurações",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isPremium || AdsService.rewardedAvailable) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isPremium
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RewardsPage(),
                          ),
                        );
                        if (mounted) _load();
                      },
                child: Ink(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.navy, Color(0xFF1E2C5A)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isPremium
                            ? Icons.workspace_premium
                            : Icons.play_circle_fill_rounded,
                        color: AppTheme.gold,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isPremium
                              ? "Você é VIP 👑"
                              : "Ganhe recompensas assistindo anúncios",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (!_isPremium)
                        const Icon(Icons.chevron_right, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          _section("Conta"),
          _tile(
            Icons.email_outlined,
            "E-mail",
            subtitle: TokenStorage.email ?? "—",
          ),
          _switchTile(
            Icons.notifications_outlined,
            "Notificações",
            _notifications,
            _changingNotifications ? null : _toggleNotifications,
          ),
          const SizedBox(height: 20),
          _section("Privacidade & Segurança"),
          _switchTile(
            Icons.visibility_off_outlined,
            "Modo incógnito",
            _incognito,
            _toggleIncognito,
          ),
          _tile(
            Icons.lock_outline,
            "Política de privacidade",
            subtitle: privacyUrl == null
                ? "Link ainda não configurado"
                : "Abrir no navegador",
            onTap: privacyUrl == null
                ? null
                : () => UrlLauncherHelper.launchURL(privacyUrl),
          ),
          _tile(
            Icons.description_outlined,
            "Termos de uso",
            subtitle: termsUrl == null
                ? "Link ainda não configurado"
                : "Abrir no navegador",
            onTap: termsUrl == null
                ? null
                : () => UrlLauncherHelper.launchURL(termsUrl),
          ),
          _tile(
            Icons.shield_outlined,
            "Dicas de segurança",
            subtitle: "Conteúdo ainda não configurado",
          ),
          const SizedBox(height: 20),
          _section("Sessão"),
          _tile(Icons.logout, "Sair da conta", onTap: _confirmLogout),
          _tile(
            Icons.delete_outline,
            "Excluir minha conta",
            danger: true,
            onTap: _deleteAccount,
          ),
          const SizedBox(height: 30),
          Center(
            child: Text(
              "Namoro Cristão • $version",
              style: const TextStyle(
                color: Color(0xFF9AA1B2),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.navy,
            fontSize: 15,
          ),
        ),
      );

  Widget _tile(
    IconData icon,
    String title, {
    String? subtitle,
    VoidCallback? onTap,
    bool danger = false,
  }) {
    final enabled = onTap != null || subtitle == null;
    final color = danger
        ? Colors.red
        : enabled
            ? AppTheme.navy
            : const Color(0xFF7A849C);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF4)),
      ),
      child: ListTile(
        enabled: enabled,
        leading: Icon(
          icon,
          color: danger
              ? Colors.red
              : enabled
                  ? AppTheme.gold
                  : const Color(0xFFB4BAC8),
        ),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: onTap != null
            ? const Icon(Icons.chevron_right, color: Color(0xFF9AA1B2))
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _switchTile(
    IconData icon,
    String title,
    bool value,
    ValueChanged<bool>? onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF4)),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: AppTheme.gold),
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.navy,
            fontWeight: FontWeight.w600,
          ),
        ),
        value: value,
        activeColor: AppTheme.gold,
        onChanged: onChanged,
      ),
    );
  }
}
