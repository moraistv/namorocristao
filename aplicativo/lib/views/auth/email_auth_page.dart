import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:mioamoreapp/helpers/constants.dart';
import 'package:mioamoreapp/services/analytics_service.dart';
import 'package:mioamoreapp/services/auth_api.dart';
import 'package:mioamoreapp/services/token_storage.dart';
import 'package:mioamoreapp/views/app/main_shell.dart';
import 'package:mioamoreapp/views/app/onboarding_page.dart';
import 'package:mioamoreapp/views/custom/custom_button.dart';

const _navy = Color(0xFF111D40);

/// Navega para o app após login: tela principal se já tem perfil, senão onboarding.
void goAfterAuth(BuildContext context, bool hasProfile) {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) => hasProfile ? const MainShell() : const OnboardingPage(),
    ),
    (route) => false,
  );
}

class EmailAuthPage extends StatefulWidget {
  final bool startInRegister;
  const EmailAuthPage({super.key, this.startInRegister = false});

  @override
  State<EmailAuthPage> createState() => _EmailAuthPageState();
}

class _EmailAuthPageState extends State<EmailAuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegister = false;

  @override
  void initState() {
    super.initState();
    _isRegister = widget.startInRegister;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();
  String get _password => _passwordController.text;

  bool _validEmail() => _email.contains("@") && _email.contains(".");

  Future<void> _submit() async {
    if (!_validEmail()) {
      EasyLoading.showError("Informe um e-mail válido");
      return;
    }
    if (_password.length < 6) {
      EasyLoading.showError("A senha deve ter ao menos 6 caracteres");
      return;
    }
    EasyLoading.show(status: "Entrando...");
    try {
      final result = _isRegister
          ? await AuthApi.register(_email, _password)
          : await AuthApi.login(_email, _password);
      AnalyticsService.log(_isRegister ? "sign_up" : "login", {"method": "email"});
      EasyLoading.dismiss();
      if (!mounted) return;
      goAfterAuth(context, result.hasProfile);
    } on AuthApiException catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError(e.message);
    }
  }

  Future<void> _requestCode() async {
    if (!_validEmail()) {
      EasyLoading.showError("Informe um e-mail válido");
      return;
    }
    EasyLoading.show(status: "Enviando código...");
    try {
      await AuthApi.requestCode(_email);
      EasyLoading.dismiss();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OtpCodePage(email: _email)),
      );
    } on AuthApiException catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _navy,
        elevation: 0,
        title: Text(_isRegister ? "Criar conta" : "Entrar com e-mail"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultNumericValue * 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppConstants.defaultNumericValue),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: "E-mail",
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppConstants.defaultNumericValue),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Senha",
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppConstants.defaultNumericValue * 1.5),
            CustomButton(
              onPressed: _submit,
              text: _isRegister ? "Criar conta" : "Entrar",
            ),
            const SizedBox(height: AppConstants.defaultNumericValue),
            TextButton(
              onPressed: () => setState(() => _isRegister = !_isRegister),
              child: Text(
                _isRegister
                    ? "Já tenho conta — Entrar"
                    : "Não tem conta? Criar conta",
                style: TextStyle(color: AppConstants.primaryColor),
              ),
            ),
            const Divider(height: AppConstants.defaultNumericValue * 2),
            OutlinedButton.icon(
              onPressed: _requestCode,
              style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                side: BorderSide(color: AppConstants.primaryColor),
                padding: const EdgeInsets.all(AppConstants.defaultNumericValue),
              ),
              icon: const Icon(Icons.password),
              label: const Text("Entrar com código no e-mail"),
            ),
          ],
        ),
      ),
    );
  }
}

class OtpCodePage extends StatefulWidget {
  final String email;
  const OtpCodePage({super.key, required this.email});

  @override
  State<OtpCodePage> createState() => _OtpCodePageState();
}

class _OtpCodePageState extends State<OtpCodePage> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      EasyLoading.showError("O código tem 6 dígitos");
      return;
    }
    EasyLoading.show(status: "Validando...");
    try {
      final result = await AuthApi.loginWithCode(widget.email, code);
      EasyLoading.dismiss();
      if (!mounted) return;
      goAfterAuth(context, result.hasProfile);
    } on AuthApiException catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _navy,
        elevation: 0,
        title: const Text("Código de acesso"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultNumericValue * 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppConstants.defaultNumericValue),
            Text(
              "Enviamos um código de 6 dígitos para:\n${widget.email}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: _navy, fontSize: 15),
            ),
            const SizedBox(height: AppConstants.defaultNumericValue * 1.5),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                counterText: "",
                hintText: "______",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppConstants.defaultNumericValue),
            CustomButton(onPressed: _confirm, text: "Confirmar"),
          ],
        ),
      ),
    );
  }
}

class LoggedInPage extends StatelessWidget {
  const LoggedInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final email = TokenStorage.email ?? "(sem e-mail)";
    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.defaultNumericValue * 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppConstants.primaryColor,
                size: 96,
              ),
              const SizedBox(height: AppConstants.defaultNumericValue),
              const Text(
                "Login realizado!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue / 2),
              Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue),
              const Text(
                "Conectado à nossa API (VPS).\nO restante do app será migrado em seguida.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: AppConstants.defaultNumericValue * 2),
              CustomButton(
                isWhite: true,
                borderColor: AppConstants.primaryColor,
                onPressed: () async {
                  await TokenStorage.clear();
                  if (context.mounted) {
                    Navigator.of(context)
                        .popUntil((route) => route.isFirst);
                  }
                },
                text: "Sair",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
