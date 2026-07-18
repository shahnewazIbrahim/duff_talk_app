import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/prediction_result.dart';
import '../services/image_picker_service.dart';
import '../services/sign_classifier_service.dart';
import '../services/text_to_speech_service.dart';
import '../widgets/image_source_sheet.dart';
import '../widgets/prediction_result_card.dart';
import '../widgets/selected_image_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _classifier = SignClassifierService();
  final _picker = ImagePickerService();
  final _tts = TextToSpeechService();

  Uint8List? _imageBytes;
  List<PredictionResult>? _predictions;
  String? _error;
  String? _initializationError;
  bool _modelLoading = true;
  bool _detecting = false;

  bool get _supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (!_supported) {
      if (mounted) {
        setState(() {
          _modelLoading = false;
          _error =
              'Offline recognition is currently supported on Android and iOS.';
        });
      }
      return;
    }
    try {
      await Future.wait([_classifier.initialize(), _tts.initialize()]);
    } catch (error, stackTrace) {
      debugPrint('App initialization failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _initializationError = error.toString());
      }
    } finally {
      if (mounted) setState(() => _modelLoading = false);
    }
  }

  Future<void> _showImageSources() async {
    final source = await ImageSourceSheet.show(context);
    if (source == null || !mounted) return;
    await _selectImage(source);
  }

  Future<void> _selectImage(ImageSource source) async {
    try {
      final file = source == ImageSource.camera
          ? await _picker.takePhoto()
          : await _picker.chooseFromGallery();
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _predictions = null;
        _error = null;
      });
    } on ImagePickException catch (error) {
      if (!mounted) return;
      final permanentlyDenied =
          error.failure == ImagePickFailure.permanentlyDenied;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          action: permanentlyDenied
              ? SnackBarAction(
                  label: 'Open Settings',
                  onPressed: openAppSettings,
                )
              : null,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Image selection failed: $error\n$stackTrace');
      if (mounted) {
        setState(() => _error = 'Could not read the selected image.');
      }
    }
  }

  Future<void> _detect() async {
    final bytes = _imageBytes;
    if (bytes == null || _detecting) return;
    setState(() {
      _detecting = true;
      _error = null;
      _predictions = null;
    });
    try {
      final predictions = await _classifier.classify(bytes);
      if (mounted) setState(() => _predictions = predictions);
    } catch (error, stackTrace) {
      debugPrint('Detection failed: $error\n$stackTrace');
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  void _reset() {
    setState(() {
      _imageBytes = null;
      _predictions = null;
      _error = null;
    });
  }

  @override
  void dispose() {
    _classifier.dispose();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _imageBytes;
    return Scaffold(
      appBar: AppBar(title: const Text('ASL Letter Recognizer')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Place one hand clearly inside the frame and use a plain background.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  if (image == null)
                    const _EmptyImageState()
                  else
                    SelectedImageCard(bytes: image),
                  const SizedBox(height: 16),
                  if (image == null) ...[
                    FilledButton.icon(
                      onPressed: _supported
                          ? () => _selectImage(ImageSource.camera)
                          : null,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Take Photo'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _supported
                          ? () => _selectImage(ImageSource.gallery)
                          : null,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose from Gallery'),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed:
                          _modelLoading || _detecting || !_classifier.isReady
                          ? null
                          : _detect,
                      icon: _detecting
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_detecting ? 'Detecting…' : 'Detect Sign'),
                    ),
                    TextButton.icon(
                      onPressed: _detecting ? null : _showImageSources,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Choose Another Photo'),
                    ),
                  ],
                  if (_modelLoading) ...[
                    const SizedBox(height: 20),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (_initializationError != null) ...[
                    const SizedBox(height: 16),
                    _ErrorCard(message: _initializationError!),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorCard(message: _error!),
                  ],
                  if (_predictions case final predictions?) ...[
                    const SizedBox(height: 20),
                    PredictionResultCard(
                      predictions: predictions,
                      onSpeak: () => _tts.speak(predictions.first),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset / Try Again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyImageState extends StatelessWidget {
  const _EmptyImageState();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Card.filled(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.back_hand_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No image selected',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('Take a photo or choose one from your gallery.'),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
