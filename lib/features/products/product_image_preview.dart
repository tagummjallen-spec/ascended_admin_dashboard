import 'dart:convert';

import 'package:flutter/material.dart';

class ProductImagePreview extends StatelessWidget {
  final String imageReference;

  const ProductImagePreview({super.key, required this.imageReference});

  @override
  Widget build(BuildContext context) {
    final ref = imageReference.trim();
    if (ref.isEmpty) {
      return const Center(child: Icon(Icons.image_outlined));
    }
    if (ref.startsWith('data:image/')) {
      try {
        final commaIndex = ref.indexOf(',');
        if (commaIndex >= 0 && commaIndex < ref.length - 1) {
          final data = base64Decode(ref.substring(commaIndex + 1));
          return Image.memory(
            data,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
          );
        }
      } catch (_) {}
      return const Center(child: Icon(Icons.broken_image));
    }
    if (ref.startsWith('assets/')) {
      return Image.asset(
        ref,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
      );
    }
    if (ref.startsWith('http')) {
      return Image.network(
        ref,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
      );
    }

    return const Center(child: Icon(Icons.broken_image));
  }
}
