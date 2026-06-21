import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mioamoreapp/views/custom/custom_button.dart';

class SelfiePage extends StatefulWidget {
  final File? selfie;

  const SelfiePage({
    super.key,
    this.selfie,
  });

  @override
  State<SelfiePage> createState() => _SelfiePageState();
}

class _SelfiePageState extends State<SelfiePage> {
  File? _selfie;

  final ImagePicker _picker = ImagePicker();

  void _onTapPicker() async {
    await _picker.pickImage(source: ImageSource.camera).then((value) {
      if (value != null) {
        setState(() {
          _selfie = File(value.path);
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _selfie = widget.selfie;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selfie'),
        leading: BackButton(
          onPressed: () {
            if (_selfie != null) {
              Navigator.pop(context, _selfie!);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text('Please take clear a selfie of your self',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _onTapPicker,
                child: Container(
                  height: MediaQuery.of(context).size.height / 2,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black.withOpacity(0.38)),
                  ),
                  child: _selfie == null
                      ? const Center(
                          child: Text('Take a selfie'),
                        )
                      : Image.file(
                          _selfie!,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
              const Expanded(child: SizedBox(height: 32)),
              _selfie != null
                  ? CustomButton(
                      text: "Save",
                      onPressed: () {
                        Navigator.pop(context, _selfie!);
                      },
                    )
                  : const SizedBox(),
            ],
          ),
        ),
      ),
    );
  }
}
