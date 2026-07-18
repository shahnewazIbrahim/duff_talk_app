import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageSourceSheet extends StatelessWidget {
  const ImageSourceSheet({super.key});

  static Future<ImageSource?> show(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (_) => const ImageSourceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add a hand sign photo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take Photo'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose from Gallery'),
            ),
          ],
        ),
      ),
    );
  }
}
