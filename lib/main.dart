import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image/image.dart' as imglib;
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

/* ---------------- App Shell ---------------- */
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sign Letters (A..Y) Demo',
      theme: ThemeData.dark(),
      home: const SignLivePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/* ---------------- Page ---------------- */
class SignLivePage extends StatefulWidget {
  const SignLivePage({super.key});
  @override
  State<SignLivePage> createState() => _SignLivePageState();
}

class _SignLivePageState extends State<SignLivePage> {
  CameraController? _cam;
  Interpreter? _interpreter;
  late FlutterTts _tts;

  List<String> _labels = [];
  bool _busy = false;
  bool _speakingEachLetter = true;

  String _currentLetter = '';
  String _composedText = '';

  // smoothing
  final int _smoothWin = 7;
  final List<int> _recentPreds = [];

  // ROI (center square)
  Rect? _roiRect;
  int _frameSkip = 2; // process every Nth frame
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _initAll();
  }

  Future<void> _initAll() async {
    try {
      // permissions
      await Permission.camera.request();

      // cameras
      final cams = await availableCameras();
      final cam = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cams.first);
      _cam = CameraController(cam, ResolutionPreset.medium, enableAudio: false);
      await _cam!.initialize();

      // TFLite & labels
      _interpreter = await Interpreter.fromAsset(
        'assets/models/sign_mnist_float32.tflite'.replaceFirst('assets/', ''),
        options: InterpreterOptions()..threads = 2,
      );

      final labelJson = await rootBundle.loadString('assets/models/labels_map.json');
      final map = json.decode(labelJson) as Map<String, dynamic>;
      final id2 = map['id_to_letter'] as Map<String, dynamic>;
      _labels = List.generate(id2.length, (i) => id2['$i'] as String);

      // TTS config
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);

      // start stream
      await _cam!.startImageStream(_onFrame);

      setState(() {});
    } catch (e) {
      debugPrint('Init error: $e');
    }
  }

  Future<void> _onFrame(CameraImage img) async {
    if (!mounted || _busy) return;
    _frameCount++;
    if (_frameCount % _frameSkip != 0) return;
    _busy = true;

    try {
      // Compute ROI rect (center square) in preview coordinates once
      _roiRect ??= _computeRoiRect(img.width, img.height);

      // 1) Y-plane -> grayscale Image of ROI
      final roi = _extractGrayscaleROI(img, _roiRect!);

      // 2) Resize to 28x28
      final resized = imglib.copyResize(roi, width: 28, height: 28, interpolation: imglib.Interpolation.nearest);

      // 3) Convert to float32 [0..1], NHWC= (1,28,28,1)
      final input = Float32List(1 * 28 * 28 * 1);
      for (int y = 0; y < 28; y++) {
        for (int x = 0; x < 28; x++) {
          // final p = resized.getPixel(x, y); // 0xAARRGGBB
          // final r = (p >> 16) & 0xFF;
          // final g = (p >> 8) & 0xFF;
          // final b = (p) & 0xFF;
          // // গ্রেস্কেল হলে তিনটাই সমান থাকবে; নিরাপদে avg নিলাম
          // final gray = (r + g + b) / 3.0;
          // final v = gray / 255.0;
          // input[(y * 28 + x)] = v; // channel=1, batch=1 -> flatten ok for float32 model

          final px = resized.getPixel(x, y); // Pixel object
          final r = px.r.toDouble();
          final g = px.g.toDouble();
          final b = px.b.toDouble();
          final gray = (r + g + b) / 3.0;
          final v = gray / 255.0;
          input[(y * 28 + x)] = v;
        }
      }

      // 4) Run inference
      final output = Float32List(_labels.length);
      _interpreter!.run(input, output);

      // 5) Argmax + smoothing
      final predIdx = _argMax(output);
      _recentPreds.add(predIdx);
      if (_recentPreds.length > _smoothWin) _recentPreds.removeAt(0);

      final stableIdx = _mode(_recentPreds);
      final letter = _labels[stableIdx];

      if (letter != _currentLetter) {
        _currentLetter = letter;
        if (_speakingEachLetter) {
          unawaited(_tts.speak(letter));
        }
      }
      setState(() {});

    } catch (e) {
      debugPrint('Frame error: $e');
    } finally {
      _busy = false;
    }
  }

  Rect _computeRoiRect(int w, int h) {
    final sz = math.min(w, h) * 0.7; // 70% center square
    final left = (w - sz) / 2;
    final top = (h - sz) / 2;
    return Rect.fromLTWH(left, top, sz, sz);
  }

  // Take Y plane as grayscale and crop ROI
  imglib.Image _extractGrayscaleROI(CameraImage img, Rect roi) {
    // YUV420 -> use plane[0] (Y) as luminance (grayscale)
    final yPlane = img.planes[0];
    final yBytes = yPlane.bytes;
    final width = img.width;
    final height = img.height;
    final rowStride = yPlane.bytesPerRow;

    final rx = roi.left.round().clamp(0, width - 1);
    final ry = roi.top.round().clamp(0, height - 1);
    final rw = roi.width.round().clamp(1, width - rx);
    final rh = roi.height.round().clamp(1, height - ry);

    final out = imglib.Image(width: rw, height: rh);

    for (int y = 0; y < rh; y++) {
      final srcRow = ry + y;
      final rowStart = srcRow * rowStride;
      for (int x = 0; x < rw; x++) {
        final srcCol = rx + x;
        final yVal = yBytes[rowStart + srcCol];
        final v = yVal; // 0..255
        final color = imglib.ColorRgb8(v, v, v);
        out.setPixel(x, y, color);
      }
    }
    return out;
  }

  int _argMax(Float32List a) {
    var mi = 0;
    var mv = -1e9;
    for (int i = 0; i < a.length; i++) {
      if (a[i] > mv) { mv = a[i]; mi = i; }
    }
    return mi;
  }

  int _mode(List<int> xs) {
    final m = <int, int>{};
    for (final v in xs) { m[v] = (m[v] ?? 0) + 1; }
    int bestK = xs.last, bestC = -1;
    m.forEach((k, c) { if (c > bestC) { bestC = c; bestK = k; } });
    return bestK;
  }

  @override
  void dispose() {
    _cam?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  /* ---------------- UI ---------------- */
  @override
  Widget build(BuildContext context) {
    final camReady = _cam?.value.isInitialized ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Letters Live (A..Y)'),
        actions: [
          Switch(
            value: _speakingEachLetter,
            onChanged: (v) => setState(() => _speakingEachLetter = v),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: camReady ? Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cam!),
          if (_roiRect != null) Positioned.fromRect(
            rect: Rect.fromLTWH(
              // CameraPreview is rotated on some devices; for simplicity we draw overlay as guide only
              // You can refine with proper transforms if needed.
              20, 100, MediaQuery.of(context).size.width - 40, MediaQuery.of(context).size.width - 40,
            ),
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.greenAccent, width: 3),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text("Current: $_currentLetter", style: const TextStyle(fontSize: 24)),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_composedText, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: ElevatedButton(
                          onPressed: () {
                            setState(() => _composedText += _currentLetter);
                            if (!_speakingEachLetter) {
                              unawaited(_tts.speak(_currentLetter));
                            }
                          },
                          child: const Text("Add Letter"),
                        )),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.space_bar),
                          onPressed: () => setState(() => _composedText += " "),
                          tooltip: "Space",
                        ),
                        IconButton(
                          icon: const Icon(Icons.backspace),
                          onPressed: () {
                            if (_composedText.isNotEmpty) {
                              setState(() => _composedText = _composedText.substring(0, _composedText.length - 1));
                            }
                          },
                          tooltip: "Backspace",
                        ),
                        IconButton(
                          icon: const Icon(Icons.volume_up),
                          onPressed: () => _tts.speak(_composedText.isEmpty ? _currentLetter : _composedText),
                          tooltip: "Speak",
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _composedText = ""),
                          tooltip: "Clear",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ) : const Center(child: CircularProgressIndicator()),
    );
  }
}
