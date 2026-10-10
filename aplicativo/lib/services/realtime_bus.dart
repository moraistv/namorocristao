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

  /// Incrementa quando a preferência local de notificações muda. O shell usa
  /// este evento para instalar ou cancelar listeners FCM sem reiniciar o app.
  static final ValueNotifier<int> notifications = ValueNotifier<int>(0);
  static void notificationsChanged() => notifications.value++;

  /// Incrementa quando o catálogo muda no painel (recompensas por anúncio e presentes).
  static final ValueNotifier<int> store = ValueNotifier<int>(0);
  static void storeChanged() => store.value++;
}
