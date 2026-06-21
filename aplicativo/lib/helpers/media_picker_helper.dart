import 'package:image_picker/image_picker.dart';

Future<String?> pickMedia({bool isVideo = false, bool isCamera = false}) async {
  final ImagePicker picker = ImagePicker();
  final XFile? pickedFile = isVideo
      ? await picker.pickVideo(source: ImageSource.gallery)
      : await picker.pickImage(
          source: isCamera ? ImageSource.camera : ImageSource.gallery);

  return pickedFile?.path;
}
