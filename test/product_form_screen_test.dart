import 'package:ascended_admin_dashboard/features/products/product_image_preview.dart';
import 'package:ascended_admin_dashboard/features/products/product_image_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('product image references', () {
    test('normalizes a filename to the bundled products directory', () {
      expect(
        normalizeProductImageReference('  rashguard.png  '),
        'assets/images/products/rashguard.png',
      );
    });

    test('preserves asset paths and remote URLs', () {
      expect(
        normalizeProductImageReference('assets/images/products/gi.png'),
        'assets/images/products/gi.png',
      );
      expect(
        normalizeProductImageReference('https://cdn.example.test/gi.png'),
        'https://cdn.example.test/gi.png',
      );
    });

    test('does not append duplicate image references', () {
      expect(
        appendProductImageReference([
          'assets/images/products/gi.png',
        ], 'assets/images/products/gi.png'),
        ['assets/images/products/gi.png'],
      );
    });
  });

  testWidgets('asset references render through Image.asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 100,
          height: 120,
          child: ProductImagePreview(
            imageReference: 'assets/images/products/rashguard.png',
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/images/products/rashguard.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('remote URLs render through Image.network', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 100,
          height: 120,
          child: ProductImagePreview(
            imageReference: 'https://cdn.example.test/rashguard.png',
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url ==
                'https://cdn.example.test/rashguard.png',
      ),
      findsOneWidget,
    );
  });
}
