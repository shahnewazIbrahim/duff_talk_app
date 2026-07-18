import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/prediction_result.dart';

const String modelAsset = 'assets/models/sign_mnist_float32.tflite';
const String labelsAsset = 'assets/models/labels_map.json';

// The supplied Sign-MNIST model was trained with grayscale pixel values / 255.
// Change only this value if a replacement model was trained on 0..255 values.
const bool normalizePixelsToUnitRange = true;

@immutable
class _PreprocessRequest {
  const _PreprocessRequest(this.bytes, this.width, this.height, this.channels);

  final Uint8List bytes;
  final int width;
  final int height;
  final int channels;
}

class SignClassifierException implements Exception {
  const SignClassifierException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SignClassifierService {
  Interpreter? _interpreter;
  List<String> _labels = const [];
  late int _inputWidth;
  late int _inputHeight;
  late int _inputChannels;
  bool _running = false;

  bool get isReady => _interpreter != null;

  Future<void> initialize() async {
    if (isReady) return;
    try {
      final interpreter = await Interpreter.fromAsset(
        modelAsset,
        options: InterpreterOptions()..threads = 2,
      );
      final input = interpreter.getInputTensor(0);
      final output = interpreter.getOutputTensor(0);
      _labels = parseLabels(await rootBundle.loadString(labelsAsset));

      debugPrint('TFLite input: shape=${input.shape}, type=${input.type}');
      debugPrint('TFLite output: shape=${output.shape}, type=${output.type}');
      debugPrint('TFLite classes: ${output.shape.last}');

      if (input.type != TensorType.float32 ||
          output.type != TensorType.float32) {
        throw SignClassifierException(
          'Unsupported model tensor type. Expected float32 input and output; '
          'found ${input.type} and ${output.type}.',
        );
      }
      if (input.shape.length != 4 || input.shape.first != 1) {
        throw SignClassifierException(
          'Unsupported input shape: ${input.shape}.',
        );
      }
      _inputHeight = input.shape[1];
      _inputWidth = input.shape[2];
      _inputChannels = input.shape[3];
      final supportedShape =
          (_inputWidth == 28 && _inputHeight == 28 && _inputChannels == 1) ||
          (_inputWidth == 64 && _inputHeight == 64 && _inputChannels == 3);
      if (!supportedShape) {
        throw SignClassifierException(
          'Unsupported input shape: ${input.shape}.',
        );
      }
      final outputCount = output.shape.last;
      if (output.shape.length != 2 ||
          output.shape.first != 1 ||
          outputCount != _labels.length) {
        throw SignClassifierException(
          'Model has $outputCount outputs but the label file has '
          '${_labels.length} labels.',
        );
      }
      _interpreter = interpreter;
    } catch (error, stackTrace) {
      debugPrint('Classifier initialization failed: $error\n$stackTrace');
      _interpreter?.close();
      _interpreter = null;
      if (error is SignClassifierException) rethrow;
      throw SignClassifierException(
        'Could not load the recognition model: $error',
      );
    }
  }

  Future<List<PredictionResult>> classify(Uint8List imageBytes) async {
    if (_running) {
      throw const SignClassifierException('A detection is already running.');
    }
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw const SignClassifierException(
        'The recognition model is not ready.',
      );
    }
    _running = true;
    try {
      final input = await compute(
        _preprocessImage,
        _PreprocessRequest(
          imageBytes,
          _inputWidth,
          _inputHeight,
          _inputChannels,
        ),
      );
      final output = <List<double>>[List<double>.filled(_labels.length, 0)];
      final shapedInput = shapeInputForModel(
        input,
        height: _inputHeight,
        width: _inputWidth,
        channels: _inputChannels,
      );
      interpreter.run(shapedInput, output);
      return PredictionResult.sorted(_labels, output.first).take(3).toList();
    } catch (error, stackTrace) {
      debugPrint('Inference failed: $error\n$stackTrace');
      if (error is SignClassifierException) rethrow;
      throw SignClassifierException('Could not analyze this image: $error');
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}

List<List<List<List<double>>>> shapeInputForModel(
  Float32List values, {
  required int height,
  required int width,
  required int channels,
}) {
  final expectedLength = height * width * channels;
  if (values.length != expectedLength) {
    throw ArgumentError(
      'Input contains ${values.length} values; expected $expectedLength.',
    );
  }
  var offset = 0;
  return [
    List.generate(
      height,
      (_) => List.generate(
        width,
        (_) => List.generate(channels, (_) => values[offset++]),
        growable: false,
      ),
      growable: false,
    ),
  ];
}

List<String> parseLabels(String source) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        decoded['id_to_letter'] is! Map<String, dynamic>) {
      throw const FormatException('Missing id_to_letter map.');
    }
    final map = decoded['id_to_letter'] as Map<String, dynamic>;
    final entries = map.entries.map((entry) {
      final index = int.tryParse(entry.key);
      if (index == null || entry.value is! String) {
        throw const FormatException('Labels must map numeric keys to strings.');
      }
      return MapEntry(index, entry.value as String);
    }).toList()..sort((a, b) => a.key.compareTo(b.key));
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].key != i) {
        throw FormatException('Missing label index $i.');
      }
    }
    return entries.map((entry) => entry.value).toList(growable: false);
  } on FormatException {
    rethrow;
  } catch (error) {
    throw FormatException('Invalid label JSON: $error');
  }
}

Float32List _preprocessImage(_PreprocessRequest request) {
  var decoded = img.decodeImage(request.bytes);
  if (decoded == null) {
    throw const SignClassifierException(
      'The selected image could not be decoded.',
    );
  }
  decoded = img.bakeOrientation(decoded);
  // Preserve the complete frame and its aspect ratio. Padding makes it square
  // before resizing to the model tensor instead of cropping any image content.
  final side = decoded.width > decoded.height ? decoded.width : decoded.height;
  final square = img.Image(width: side, height: side, numChannels: 3);
  img.compositeImage(
    square,
    decoded,
    dstX: (side - decoded.width) ~/ 2,
    dstY: (side - decoded.height) ~/ 2,
  );
  final resized = img.copyResize(
    square,
    width: request.width,
    height: request.height,
    interpolation: img.Interpolation.linear,
  );
  final values = Float32List(request.width * request.height * request.channels);
  var offset = 0;
  for (var y = 0; y < request.height; y++) {
    for (var x = 0; x < request.width; x++) {
      final pixel = resized.getPixel(x, y);
      if (request.channels == 1) {
        final gray = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
            .toDouble();
        values[offset++] = normalizePixelsToUnitRange ? gray / 255 : gray;
      } else {
        for (final channel in [pixel.r, pixel.g, pixel.b]) {
          final value = channel.toDouble();
          values[offset++] = normalizePixelsToUnitRange ? value / 255 : value;
        }
      }
    }
  }
  return values;
}
