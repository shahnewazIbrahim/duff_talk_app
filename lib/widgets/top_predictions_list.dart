import 'package:flutter/material.dart';

import '../models/prediction_result.dart';

class TopPredictionsList extends StatelessWidget {
  const TopPredictionsList({super.key, required this.predictions});

  final List<PredictionResult> predictions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Top predictions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (var i = 0; i < predictions.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text(predictions[i].displayLabel),
            trailing: Text(
              '${(predictions[i].confidence * 100).toStringAsFixed(1)}%',
            ),
          ),
      ],
    );
  }
}
