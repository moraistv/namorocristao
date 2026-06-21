import 'package:flutter/foundation.dart';

/// Barramento global de eventos em tempo real.
///
/// As telas escutam estes notificadores e se recarregam sozinhas quando algo
/// muda no servidor (VIP, créditos, selo de verificação, etc.), sem o usuário
/// precisar fechar/reabrir o app.
class RealtimeBus {
  RealtimeBus._();

  /// Incrementa quando a CONTA do usuário muda (VIP, créditos, verificação,
  /// banimento/suspensão...). Telas de Perfil, Curtidas e Descobrir escutam.
  static final ValueNotifier<int> account = ValueNotifier<int>(0);
  static void accountChanged() => account.value++;

  /// Incrementa quando a LOJA muda (planos, pacotes, presentes, valor do crédito).
  static final ValueNotifier<int> store = ValueNotifier<int>(0);
  static void storeChanged() => store.value++;
}
