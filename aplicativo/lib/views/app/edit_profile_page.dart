import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> profile;
  const EditProfilePage({super.key, required this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final _name = TextEditingController(text: widget.profile["fullName"]?.toString() ?? "");
  late final _city = TextEditingController(text: widget.profile["city"]?.toString() ?? "");
  late final _about = TextEditingController(text: widget.profile["about"]?.toString() ?? "");
  late String? _denomination = widget.profile["denomination"]?.toString();
  late String? _frequency = widget.profile["churchFrequency"]?.toString();
  late String? _intention = widget.profile["intention"]?.toString();
  late final Set<String> _interests = {
    ...((widget.profile["interests"] as List?)?.cast<String>() ?? [])
  };

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      EasyLoading.showError("Informe seu nome");
      return;
    }
    final p = widget.profile;
    EasyLoading.show(status: "Salvando...");
    try {
      await AppApi.upsertProfile({
        "fullName": _name.text.trim(),
        "gender": p["gender"],
        "birthday": p["birthday"],
        "city": _city.text.trim().isEmpty ? null : _city.text.trim(),
        "addressText": p["addressText"],
        "denomination": _denomination,
        "churchFrequency": _frequency,
        "intention": _intention,
        "interests": _interests.toList(),
        "about": _about.text.trim().isEmpty ? null : _about.text.trim(),
        "mediaFiles": (p["mediaFiles"] as List?)?.cast<String>() ?? [],
        "lockedPhotos": (p["lockedPhotos"] as List?)?.cast<String>() ?? [],
        "profilePicture": p["profilePicture"],
      });
      EasyLoading.dismiss();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showError("Falha ao salvar");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.navy,
        elevation: 0.5,
        title: const Text("Editar perfil"),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text("Salvar",
                style: TextStyle(
                    color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _label("Nome"),
          TextField(controller: _name, decoration: _dec("Seu nome")),
          _label("Cidade"),
          TextField(controller: _city, decoration: _dec("Sua cidade")),
          _label("Sobre"),
          TextField(
              controller: _about, maxLines: 4, decoration: _dec("Fale sobre você...")),
          _label("Denominação"),
          _chips(kDenominations, _denomination, (v) => setState(() => _denomination = v)),
          _label("Frequência à igreja"),
          _chips(kChurchFrequency, _frequency, (v) => setState(() => _frequency = v)),
          _label("Intenção"),
          _chips(kIntentions, _intention, (v) => setState(() => _intention = v)),
          _label("Interesses (até 5)"),
          _multi(kInterests, _interests),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: AppTheme.navy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: const Text("Salvar alterações",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec(String h) => InputDecoration(
        hintText: h,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E3EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E3EB))),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppTheme.navy, fontSize: 15)),
      );

  Widget _chips(List<String> opts, String? sel, void Function(String) onTap) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: opts
            .map((o) => AppChoiceChip(
                  label: o,
                  selected: sel == o,
                  onTap: () => onTap(o),
                ))
            .toList(),
      );

  Widget _multi(List<String> opts, Set<String> set) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: opts.map((o) {
          final s = set.contains(o);
          return AppChoiceChip(
            label: o,
            selected: s,
            onTap: () => setState(() {
              if (s) {
                set.remove(o);
              } else if (set.length < 5) {
                set.add(o);
              }
            }),
          );
        }).toList(),
      );
}
