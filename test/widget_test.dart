import 'dart:convert';
import 'dart:typed_data';

import 'package:duff_talk/models/prediction_result.dart';
import 'package:duff_talk/screens/home_screen.dart';
import 'package:duff_talk/widgets/prediction_result_card.dart';
import 'package:duff_talk/widgets/selected_image_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen shows its empty state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.text('No image selected'), findsOneWidget);
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Choose from Gallery'), findsOneWidget);
  });

  testWidgets('selected image state displays the image guide', (tester) async {
    final pixel = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SelectedImageCard(bytes: Uint8List.fromList(pixel)),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(find.bySemanticsLabel('Selected hand sign image'), findsOneWidget);
  });

  testWidgets('prediction result displays result and top predictions', (
    tester,
  ) async {
    const predictions = [
      PredictionResult(label: 'a', confidence: 0.91),
      PredictionResult(label: 'b', confidence: 0.06),
      PredictionResult(label: 'c', confidence: 0.03),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PredictionResultCard(
              predictions: predictions,
              onSpeak: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Detected letter'), findsOneWidget);
    expect(find.text('91.0% confidence'), findsOneWidget);
    expect(find.text('Top predictions'), findsOneWidget);
    expect(find.text('Speak'), findsOneWidget);
  });
}
