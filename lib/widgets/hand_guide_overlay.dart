import 'package:flutter/material.dart';

class HandGuideOverlay extends StatelessWidget {
  const HandGuideOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.72,
          heightFactor: 0.72,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
    );
  }
}
