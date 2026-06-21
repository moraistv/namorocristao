import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mioamoreapp/services/app_api.dart';
import 'package:mioamoreapp/views/app/app_theme.dart';

/// Gerencia as fotos do perfil (adicionar/remover/trancar). Retorna {photos, locked}.
class PhotoManagerPage extends StatefulWidget {
  final List<String> initial;
  final List<String> initialLocked;
  const PhotoManagerPage({super.key, required this.initial, this.initialLocked = const []});

  @override
  State<PhotoManagerPage> createState() => _PhotoManagerPageState();
}

class _PhotoManagerPageState extends State<PhotoManagerPage> {
  late final List<String> _photos = [...widget.initial];
  late final Set<String> _locked = {...widget.initialLocked};

  Future<void> _add() async {
    if (_photos.length >= 6) {
      EasyLoading.showError("Máximo de 6 fotos");
      return;
    }
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 75,
      );
      if (file == null) return;
      EasyLoading.show(status: "Enviando...");
      final bytes = await file.readAsBytes();
      final ext = file.name.split(".").last.toLowerCase();
      final url = await AppApi.uploadPhoto(base64Encode(bytes),
          ext: ext == "png" ? "png" : "jpg");
      setState(() => _photos.add(url));
      EasyLoading.dismiss();
    } catch (_) {
      EasyLoading.dismiss();
      EasyLoading.showError("Falha ao enviar a foto");
    }
  }

  void _save() {
    if (_photos.isEmpty) {
      EasyLoading.showError("Mantenha ao menos 1 foto");
      return;
    }
    Navigator.pop(context, {
      "photos": _photos,
      "locked": _locked.where((u) => _photos.contains(u)).toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.navy,
        elevation: 0.5,
        title: const Text("Minhas fotos"),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text("Salvar",
                style: TextStyle(
                    color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Até 6 fotos. A 1ª é a principal. Toque no cadeado para deixar uma foto privada.",
                style: TextStyle(color: Color(0xFF7A849C))),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  ..._photos.asMap().entries.map((e) => _tile(e.key, e.value)),
                  if (_photos.length < 6) _addTile(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(int i, String url) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(fit: StackFit.expand, children: [
          CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
          if (_locked.contains(url))
            Container(color: Colors.black.withOpacity(0.35)),
          // Cadeado (trancar/destrancar)
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              onTap: () => setState(() {
                if (_locked.contains(url)) {
                  _locked.remove(url);
                } else {
                  _locked.add(url);
                }
              }),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: _locked.contains(url)
                        ? AppTheme.gold
                        : Colors.black54,
                    shape: BoxShape.circle),
                child: Icon(
                    _locked.contains(url) ? Icons.lock : Icons.lock_open,
                    color: _locked.contains(url) ? AppTheme.navy : Colors.white,
                    size: 15),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => setState(() {
                _photos.removeAt(i);
              }),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
          if (i == 0)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: AppTheme.gold,
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: const Text("Principal",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      );

  Widget _addTile() => GestureDetector(
        onTap: _add,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.gold, width: 1.5),
          ),
          child: Center(
            child: Icon(Icons.add_a_photo_outlined, color: AppTheme.gold, size: 28),
          ),
        ),
      );
}
