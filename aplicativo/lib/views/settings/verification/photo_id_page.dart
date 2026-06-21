import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mioamoreapp/views/custom/custom_button.dart';

class PhotoIdPage extends StatefulWidget {
  final File? frontView;
  final File? backView;
  const PhotoIdPage({
    super.key,
    this.frontView,
    this.backView,
  });

  @override
  State<PhotoIdPage> createState() => _PhotoIdPageState();
}

class _PhotoIdPageState extends State<PhotoIdPage> {
  File? _photoIdFrontView;
  File? _photoIdBackView;

  final ImagePicker _picker = ImagePicker();

  void _onTapPicker(int index) async {
    await _picker.pickImage(source: ImageSource.gallery).then((value) {
      if (value != null) {
        setState(() {
          if (index == 0) {
            _photoIdFrontView = File(value.path);
          } else {
            _photoIdBackView = File(value.path);
          }
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _photoIdFrontView = widget.frontView;
    _photoIdBackView = widget.backView;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo ID'),
        leading: BackButton(
          onPressed: () {
            if (_photoIdBackView != null && _photoIdFrontView != null) {
              Navigator.pop(context, [_photoIdFrontView!, _photoIdBackView!]);
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
              Text('Please take photos of front and back of your of your ID',
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () {
                  _onTapPicker(0);
                },
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black.withOpacity(0.38)),
                  ),
                  child: _photoIdFrontView == null
                      ? const Center(
                          child: Text('Front View'),
                        )
                      : Image.file(
                          _photoIdFrontView!,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () {
                  _onTapPicker(1);
                },
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black.withOpacity(0.38)),
                  ),
                  child: _photoIdBackView == null
                      ? const Center(
                          child: Text('Back View'),
                        )
                      : Image.file(
                          _photoIdBackView!,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
              const Expanded(child: SizedBox(height: 32)),
              _photoIdBackView != null && _photoIdFrontView != null
                  ? CustomButton(
                      text: "Save",
                      onPressed: () {
                        Navigator.pop(
                            context, [_photoIdFrontView!, _photoIdBackView!]);
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
