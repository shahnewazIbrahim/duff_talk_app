import 'package:duff_talk/models/prediction_result.dart';
import 'package:duff_talk/services/sign_classifier_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

void main() {
  group('labels', () {
    test('are parsed in numeric order', () {
      const json = '{"id_to_letter":{"2":"C","0":"A","1":"B"}}';
      expect(parseLabels(json), ['A', 'B', 'C']);
    });

    test('reject missing numeric indexes', () {
      const json = '{"id_to_letter":{"0":"A","2":"C"}}';
      expect(() => parseLabels(json), throwsFormatException);
    });
  });

  test('predictions sort by descending confidence', () {
    final results = PredictionResult.sorted(['A', 'B', 'C'], [0.1, 0.7, 0.2]);
    expect(results.map((item) => item.label), ['B', 'C', 'A']);
  });

  test('model input is shaped as NHWC', () {
    final input = shapeInputForModel(
      Float32List.fromList([1, 2, 3, 4]),
      height: 2,
      width: 2,
      channels: 1,
    );
    expect(input.length, 1);
    expect(input.first.length, 2);
    expect(input.first.first.length, 2);
    expect(input.first.first.first, [1]);
    expect(input.first.last.last, [4]);
  });

  test('confidence threshold rejects uncertain result', () {
    const results = [PredictionResult(label: 'A', confidence: 0.59)];
    expect(confidenceMessage(results), startsWith('Not confident'));
  });

  test('special labels have friendly display text', () {
    expect(PredictionResult.displayLabelFor('space'), 'Space');
    expect(PredictionResult.displayLabelFor('del'), 'Delete');
    expect(PredictionResult.displayLabelFor('nothing'), 'No Sign');
    expect(PredictionResult.displayLabelFor('a'), 'A');
  });
}
