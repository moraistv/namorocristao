import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:mioamoreapp/services/analytics_service.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/services/realtime_bus.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';

/// Confirma e ativa um Boost (destaque na descoberta). Retorna true se ativou.
Future<bool> activateBoostFlow(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text("Ativar Boost"),
      content: const Text(
        "Seu perfil aparece com mais destaque na descoberta por um tempo. "
        "Isso usa 1 Boost.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text("Agora não"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            foregroundColor: AppTheme.navy,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text("Ativar"),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  EasyLoading.show(status: "Ativando...");
  try {
    final response = await AppApi.activateBoost();
    final minutes = (response["minutes"] as num?)?.toInt();
    AnalyticsService.boost();
    RealtimeBus.accountChanged();
    EasyLoading.dismiss();
    EasyLoading.showSuccess(
      minutes != null ? "Boost ativo por $minutes min" : "Boost ativado",
    );
    return true;
  } on AppApiException catch (error) {
    EasyLoading.dismiss();
    EasyLoading.showError(error.message);
  } catch (_) {
    EasyLoading.dismiss();
    EasyLoading.showError("Não foi possível ativar o Boost.");
  }
  return false;
}
