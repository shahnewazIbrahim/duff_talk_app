import 'dart:typed_data';

import 'package:flutter/material.dart';

class SelectedImageCard extends StatelessWidget {
  const SelectedImageCard({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Selected hand sign image',
      image: true,
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ColoredBox(
            color: Colors.black,
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}
