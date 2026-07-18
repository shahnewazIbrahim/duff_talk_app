import 'package:flutter/material.dart';

import '../models/prediction_result.dart';
import 'top_predictions_list.dart';

class PredictionResultCard extends StatelessWidget {
  const PredictionResultCard({
    super.key,
    required this.predictions,
    required this.onSpeak,
    this.confidenceThreshold = 0.60,
  });

  final List<PredictionResult> predictions;
  final VoidCallback onSpeak;
  final double confidenceThreshold;

  @override
  Widget build(BuildContext context) {
    final best = predictions.first;
    final lowConfidence = confidenceMessage(
      predictions,
      threshold: confidenceThreshold,
    );
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (lowConfidence != null) ...[
              Icon(
                Icons.lightbulb_outline,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                lowConfidence,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ] else ...[
              Text(
                'Detected letter',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                best.displayLabel,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${(best.confidence * 100).toStringAsFixed(1)}% confidence',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: best.confidence.clamp(0, 1)),
              const SizedBox(height: 12),
              Align(
                child: FilledButton.tonalIcon(
                  onPressed: onSpeak,
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('Speak'),
                ),
              ),
            ],
            const Divider(height: 32),
            TopPredictionsList(predictions: predictions),
          ],
        ),
      ),
    );
  }
}
