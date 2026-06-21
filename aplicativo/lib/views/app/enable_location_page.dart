import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mioamoreapp/services/location_service.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';
import 'package:mioamoreapp/views/company/privacy_policy.dart';
import 'package:mioamoreapp/views/company/terms_and_conditions.dart';

/// Tela de pedido de localização (padrão Namoro Cristão: navy + dourado).
/// Mostrada após o primeiro login/cadastro quando a permissão ainda não foi dada.
class EnableLocationPage extends StatefulWidget {
  const EnableLocationPage({super.key});

  @override
  State<EnableLocationPage> createState() => _EnableLocationPageState();
}

class _EnableLocationPageState extends State<EnableLocationPage> {
  bool _busy = false;

  Future<void> _allow() async {
    setState(() => _busy = true);
    try {
      // 1) Serviço de localização do aparelho ligado?
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        EasyLoading.showInfo("Ative a localização do aparelho e tente de novo");
        await Geolocator.openLocationSettings();
        return;
      }
      // 2) Permissão do app.
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        EasyLoading.showInfo("Permissão bloqueada. Abrindo as configurações...");
        await Geolocator.openAppSettings();
        return;
      }
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        EasyLoading.show(status: "Obtendo localização...");
        await LocationService.refresh(ask: false);
        EasyLoading.dismiss();
        if (!mounted) return;
        EasyLoading.showSuccess("Localização ativada!");
        Navigator.of(context).maybePop();
      } else {
        EasyLoading.showError("Permissão de localização negada");
      }
    } catch (_) {
      EasyLoading.showError("Não foi possível ativar a localização");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, color: AppTheme.navy),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Ativar Localização",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navy),
              ),
              const SizedBox(height: 14),
              const Text(
                "Ative sua localização para encontrar pessoas perto de você no Namoro Cristão.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16, color: Color(0xFF7A849C), height: 1.4),
              ),
              const Spacer(),
              _mapIllustration(),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _allow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.navy,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text(
                    "Permitir Localização",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text("Agora não",
                    style: TextStyle(
                        color: Color(0xFF9AA1B2),
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              _termsText(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _termsText(BuildContext context) {
    const base = TextStyle(color: Color(0xFF9AA1B2), fontSize: 12, height: 1.4);
    final link = TextStyle(
        color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.w600, height: 1.4);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: "Ao continuar, você concorda com nossos ", style: base),
            TextSpan(
              text: "Termos de Serviço",
              style: link,
              recognizer: TapGestureRecognizer()
                ..onTap = () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TermsAndConditions(),
                        fullscreenDialog: true)),
            ),
            TextSpan(text: " e ", style: base),
            TextSpan(
              text: "Política de Privacidade",
              style: link,
              recognizer: TapGestureRecognizer()
                ..onTap = () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicy(),
                        fullscreenDialog: true)),
            ),
            TextSpan(text: ".", style: base),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _mapIllustration() {
    return SizedBox(
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base circular suave
          Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                AppTheme.gold.withOpacity(0.16),
                AppTheme.gold.withOpacity(0.04),
              ]),
            ),
          ),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppTheme.gold.withOpacity(0.25), width: 1.5),
            ),
          ),
          const Icon(Icons.public_rounded, size: 110, color: AppTheme.navy),
          // Pino principal
          const Positioned(
            top: 40,
            child: _Pin(size: 54),
          ),
          // Pinos secundários
          Positioned(
            left: 40,
            top: 120,
            child: _Pin(size: 30, color: AppTheme.gold.withOpacity(0.8)),
          ),
          Positioned(
            right: 46,
            top: 100,
            child: _Pin(size: 26, color: AppTheme.gold.withOpacity(0.7)),
          ),
          Positioned(
            right: 70,
            bottom: 46,
            child: _Pin(size: 22, color: AppTheme.gold.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final double size;
  final Color? color;
  const _Pin({required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Icon(Icons.location_on, size: size, color: color ?? AppTheme.gold),
    );
  }
}
