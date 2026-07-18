class PredictionResult {
  const PredictionResult({required this.label, required this.confidence});

  final String label;
  final double confidence;

  String get displayLabel => displayLabelFor(label);

  static String displayLabelFor(String label) {
    switch (label.toLowerCase()) {
      case 'space':
        return 'Space';
      case 'del':
        return 'Delete';
      case 'nothing':
        return 'No Sign';
      default:
        return label.toUpperCase();
    }
  }

  static List<PredictionResult> sorted(
    List<String> labels,
    List<double> confidences,
  ) {
    if (labels.length != confidences.length) {
      throw ArgumentError('Label and confidence counts must match.');
    }
    final results = List.generate(
      labels.length,
      (index) => PredictionResult(
        label: labels[index],
        confidence: confidences[index],
      ),
    );
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }
}

String? confidenceMessage(
  List<PredictionResult> predictions, {
  double threshold = 0.60,
}) {
  if (predictions.isEmpty || predictions.first.confidence < threshold) {
    return 'Not confident — please retake the photo with better lighting and a clearer background.';
  }
  return null;
}
