import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/token_storage.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';
import 'package:mioamoreapp/views/app/premium_page.dart';
import 'package:mioamoreapp/views/auth/login_page.dart';

/// Configurações da conta: VIP, notificações, privacidade, sair e excluir conta.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isPremium = false;
  bool _notifications = true;
  bool _incognito = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await AppApi.getStats();
      final p = await AppApi.getMyProfile();
      if (!mounted) return;
      setState(() {
        _isPremium = s["isPremium"] == true;
        _incognito = p?["incognito"] == true;
      });
    } catch (_) {}
  }

  Future<void> _toggleIncognito(bool v) async {
    setState(() => _incognito = v);
    try {
      await AppApi.setIncognito(v);
    } on AppApiException catch (e) {
      if (!mounted) return;
      setState(() => _incognito = !v); // reverte
      if (e.statusCode == 403) {
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const PremiumPage(
                  highlight: "Modo incógnito é um recurso VIP")),
        );
        _load();
      } else {
        EasyLoading.showError(e.message);
      }
    }
  }

  Future<void> _logout() async {
    await AppApi.setOnline(false);
    await TokenStorage.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (r) => false,
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await _confirm("Sair da conta", "Deseja realmente sair?");
    if (ok) _logout();
  }

  Future<void> _deleteAccount() async {
    final ok = await _confirm(
      "Excluir conta",
      "Sua conta e seus dados serão removidos. Esta ação não pode ser desfeita. Continuar?",
      danger: true,
    );
    if (!ok) return;
    EasyLoading.show(status: "Processando...");
    try {
      await AppApi.requestAccountDeletion();
      EasyLoading.dismiss();
      _logout();
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showError("Falha ao solicitar exclusão");
    }
  }

  Future<bool> _confirm(String title, String body, {bool danger = false}) async {
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
                child: Text(danger ? "Excluir" : "Confirmar",
                    style: TextStyle(
                        color: danger ? Colors.red : AppTheme.navy,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.navy,
        elevation: 0,
        title: const Text("Configurações",
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumPage()),
              );
              _load();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppTheme.navy, Color(0xFF1E2C5A)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium, color: AppTheme.gold, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isPremium ? "Você é VIP 👑" : "Seja VIP",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white54),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _section("Conta"),
          _tile(Icons.email_outlined, "E-mail",
              subtitle: TokenStorage.email ?? "—"),
          _switchTile(Icons.notifications_outlined, "Notificações", _notifications,
              (v) => setState(() => _notifications = v)),
          const SizedBox(height: 20),
          _section("Privacidade & Segurança"),
          _switchTile(Icons.visibility_off_outlined, "Modo incógnito", _incognito,
              _toggleIncognito),
          _tile(Icons.lock_outline, "Política de privacidade", onTap: () {}),
          _tile(Icons.description_outlined, "Termos de uso", onTap: () {}),
          _tile(Icons.shield_outlined, "Dicas de segurança", onTap: () {}),
          const SizedBox(height: 20),
          _section("Sessão"),
          _tile(Icons.logout, "Sair da conta", onTap: _confirmLogout),
          _tile(Icons.delete_outline, "Excluir minha conta",
              danger: true, onTap: _deleteAccount),
          const SizedBox(height: 30),
          const Center(
            child: Text("Namoro Cristão • v1.0.0",
                style: TextStyle(color: Color(0xFF9AA1B2), fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.navy,
                fontSize: 15)),
      );

  Widget _tile(IconData icon, String title,
      {String? subtitle, VoidCallback? onTap, bool danger = false}) {
    final color = danger ? Colors.red : AppTheme.navy;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF4)),
      ),
      child: ListTile(
        leading: Icon(icon, color: danger ? Colors.red : AppTheme.gold),
        title: Text(title,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: onTap != null
            ? const Icon(Icons.chevron_right, color: Color(0xFF9AA1B2))
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _switchTile(
      IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF4)),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: AppTheme.gold),
        title: Text(title,
            style: const TextStyle(
                color: AppTheme.navy, fontWeight: FontWeight.w600)),
        value: value,
        activeColor: AppTheme.gold,
        onChanged: onChanged,
      ),
    );
  }
}
