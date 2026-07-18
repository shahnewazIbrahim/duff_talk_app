import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

enum ImagePickFailure { denied, permanentlyDenied, unavailable }

class ImagePickException implements Exception {
  const ImagePickException(this.failure, this.message);

  final ImagePickFailure failure;
  final String message;

  @override
  String toString() => message;
}

class ImagePickerService {
  ImagePickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<XFile?> takePhoto() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        throw const ImagePickException(
          ImagePickFailure.permanentlyDenied,
          'Camera access is disabled. Enable it in Settings to take a photo.',
        );
      }
      if (!status.isGranted) {
        throw const ImagePickException(
          ImagePickFailure.denied,
          'Camera permission was denied.',
        );
      }
    }
    return _pick(ImageSource.camera);
  }

  Future<XFile?> chooseFromGallery() => _pick(ImageSource.gallery);

  Future<XFile?> _pick(ImageSource source) async {
    try {
      return await _picker.pickImage(
        source: source,
        imageQuality: 95,
        requestFullMetadata: true,
      );
    } catch (error) {
      throw ImagePickException(
        ImagePickFailure.unavailable,
        'Could not open the image source: $error',
      );
    }
  }
}
