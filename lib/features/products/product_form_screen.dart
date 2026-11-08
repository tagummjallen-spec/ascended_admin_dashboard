import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../services/product_service.dart';
import 'product_image_preview.dart';
import 'product_image_reference.dart';

class ProductFormScreen extends StatefulWidget {
  final String? productId;
  const ProductFormScreen({super.key, this.productId});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class VariantRow {
  final sizeCtrl = TextEditingController();
  final colorCtrl = TextEditingController();
  final stockCtrl = TextEditingController();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _category = TextEditingController(text: 'Tops');
  final _imageUrl = TextEditingController();
  final List<String> _selectedDisciplines = [];
  final List<VariantRow> _variants = [VariantRow()];
  bool _isActive = true;
  bool _loading = false;
  bool _uploadingImage = false;
  Uint8List? _uploadPreviewBytes;
  final _images = <String>[];

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) _loadProduct();
  }

  Future<void> _loadProduct() async {
    final doc = await FirebaseFirestore.instance
        .collection('products')
        .doc(widget.productId)
        .get();
    final data = doc.data()!;
    setState(() {
      _name.text = data['name'] ?? '';
      _desc.text = data['description'] ?? '';
      _price.text = (data['price'] ?? 0).toString();
      _category.text = data['categoryId'] ?? 'Tops';
      _isActive = data['isActive'] ?? true;
      _images.clear();
      final imageData = data['images'];
      if (imageData is Iterable) {
        _images.addAll(imageData.whereType<String>());
      }
      _imageUrl.clear();
      _selectedDisciplines.clear();
      _selectedDisciplines.addAll(List<String>.from(data['disciplines'] ?? []));
      _variants.clear();
      final vars = data['variants'] as List? ?? [];
      for (var v in vars) {
        if (v is Map) {
          final r = VariantRow();
          r.sizeCtrl.text = v['size'] ?? '';
          r.colorCtrl.text = v['color'] ?? '';
          r.stockCtrl.text = (v['stock'] ?? 0).toString();
          _variants.add(r);
        }
      }
      if (_variants.isEmpty) _variants.add(VariantRow());
    });
  }

  /// Compresses selected image bytes to max 400x400 JPEG at quality 60
  /// (progressively lowering size/quality if needed) and returns a Base64
  /// data URL (`data:image/jpeg;base64,...`) that stays under 100KB.
  Future<String> _compressToDataUrl(Uint8List originalBytes) async {
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      throw Exception('Could not decode the selected image.');
    }

    // Start at max 400px on the longer side, quality 60.
    var current = decoded;
    if (current.width > 400 || current.height > 400) {
      current = img.copyResize(
        current,
        width: current.width >= current.height ? 400 : null,
        height: current.height > current.width ? 400 : null,
        interpolation: img.Interpolation.linear,
      );
    }

    var quality = 60;
    var jpgBytes = Uint8List.fromList(img.encodeJpg(current, quality: quality));

    // Aggressively shrink dimensions, then lower quality if still over 100KB.
    while (jpgBytes.lengthInBytes > 100 * 1024) {
      final nextWidth = (current.width * 0.8).round();
      final nextHeight = (current.height * 0.8).round();
      if (nextWidth < 60 || nextHeight < 60) {
        // Dimensions are already tiny: drop quality until it fits.
        while (jpgBytes.lengthInBytes > 100 * 1024 && quality > 20) {
          quality -= 10;
          jpgBytes = Uint8List.fromList(
            img.encodeJpg(current, quality: quality),
          );
        }
        break;
      }
      current = img.copyResize(
        current,
        width: nextWidth,
        height: nextHeight,
        interpolation: img.Interpolation.linear,
      );
      quality = quality > 30 ? quality - 10 : 30;
      jpgBytes = Uint8List.fromList(
        img.encodeJpg(current, quality: quality),
      );
    }

    final base64String = base64Encode(jpgBytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read the selected image. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _uploadPreviewBytes = bytes;
      _uploadingImage = true;
    });

    try {
      final dataUrl = await _compressToDataUrl(bytes);
      if (!mounted) return;

      final updatedImages = appendProductImageReference(_images, dataUrl);
      setState(() {
        _images
          ..clear()
          ..addAll(updatedImages);
        _uploadPreviewBytes = null;
        _uploadingImage = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image compression failed: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _addLocalAsset() {
    // Save the typed value directly as an image reference (no Storage upload).
    // Explicit asset paths like "assets/images/products/shirt.png" are preserved.
    final imageReference = normalizeProductImageReference(_imageUrl.text);
    if (imageReference.isEmpty) return;

    final updatedImages = appendProductImageReference(_images, imageReference);
    setState(() {
      _images
        ..clear()
        ..addAll(updatedImages);
      _imageUrl.clear();
    });
  }

  Future<void> _save() async {
    if (_uploadingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wait for the image upload to finish before saving.'),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    // Add any pending typed reference (asset path/filename/URL) directly to the
    // product's image list. This never triggers Firebase Storage upload.
    if (_imageUrl.text.trim().isNotEmpty) _addLocalAsset();

    // Guard against Firestore's 1MB document limit. Base64 adds ~33% overhead.
    final imagesPayloadSize =
        _images.fold<int>(0, (total, image) => total + image.length);
    if (imagesPayloadSize > 900 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Product images are too large for one Firestore document. '
            'Remove a photo or use a local asset path.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    final variants = _variants
        .map(
          (v) => {
            'size': v.sizeCtrl.text,
            'color': v.colorCtrl.text,
            'stock': int.tryParse(v.stockCtrl.text) ?? 0,
          },
        )
        .toList();

    final data = {
      'name': _name.text.trim(),
      'description': _desc.text.trim(),
      'price': double.tryParse(_price.text) ?? 0,
      'categoryId': _category.text.trim(),
      'disciplines': _selectedDisciplines,
      'images': List<String>.of(_images),
      'variants': variants,
      'isActive': _isActive,
    };

    try {
      final service = ProductService();
      if (widget.productId == null) {
        await service.addProduct(data);
      } else {
        await service.updateProduct(widget.productId!, data);
      }
      if (mounted) context.go('/products');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/products'),
              ),
              const SizedBox(width: 8),
              Text(
                widget.productId == null ? 'Add New Product' : 'Edit Product',
                style: const TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _Card(
                        title: 'Product Information',
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _name,
                              decoration: const InputDecoration(
                                labelText: 'Product Name *',
                              ),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _desc,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Description *',
                              ),
                              validator: (v) => v!.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _price,
                                    decoration: const InputDecoration(
                                      labelText: 'Price (₱) *',
                                    ),
                                    validator: (v) =>
                                        v!.isEmpty ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _category.text.isEmpty
                                        ? 'Tops'
                                        : _category.text,
                                    items: AppConstants.productTypes
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _category.text = v!),
                                    decoration: const InputDecoration(
                                      labelText: 'Product Type',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Card(
                        title: 'Disciplines',
                        child: Wrap(
                          spacing: 8,
                          children: AppConstants.disciplines.map((d) {
                            final selected = _selectedDisciplines.contains(d);
                            return FilterChip(
                              label: Text(d),
                              selected: selected,
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    _selectedDisciplines.add(d);
                                  } else {
                                    _selectedDisciplines.remove(d);
                                  }
                                });
                              },
                              selectedColor: AppColors.primaryAccent.withValues(
                                alpha: 0.3,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Card(
                        title: 'Variants & Stock',
                        child: Column(
                          children: [
                            ..._variants.asMap().entries.map((e) {
                              final i = e.key;
                              final v = e.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: v.sizeCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Size',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: v.colorCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Color',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: v.stockCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Stock',
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: AppColors.error,
                                      ),
                                      onPressed: _variants.length > 1
                                          ? () => setState(
                                              () => _variants.removeAt(i),
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              );
                            }),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () =>
                                    setState(() => _variants.add(VariantRow())),
                                icon: const Icon(Icons.add),
                                label: const Text('ADD VARIANT'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Right column
                Expanded(
                  child: Column(
                    children: [
                      _Card(
                        title: 'Product Images',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add images for this product',
                              style: TextStyle(color: AppColors.secondaryText),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _imageUrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Image reference (asset path or URL)',
                                      hintText:
                                          'e.g. assets/images/products/shirt.png or https://...',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _addLocalAsset,
                                  child: const Text('ADD ASSET'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _uploadingImage
                                      ? null
                                      : _pickAndUpload,
                                  icon: _uploadingImage
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.compress),
                                  label: Text(
                                    _uploadingImage
                                        ? 'COMPRESSING...'
                                        : 'ADD PHOTO',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Local assets folder: assets/images/products/\n'
                              'Picked photos are compressed (<100KB) and saved '
                              'as Base64 data URLs in Firestore.',
                              style: TextStyle(
                                color: AppColors.tertiaryText,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_uploadPreviewBytes != null)
                                  Container(
                                    width: 100,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: AppColors.cardSurface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Image.memory(
                                      _uploadPreviewBytes!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ..._images.map(
                                  (img) => Container(
                                    width: 100,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: AppColors.cardSurface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: ProductImagePreview(
                                      imageReference: img,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Card(
                        title: 'Status',
                        child: SwitchListTile(
                          title: const Text(
                            'Active',
                            style: TextStyle(color: AppColors.primaryText),
                          ),
                          subtitle: const Text(
                            'Visible in customer app',
                            style: TextStyle(color: AppColors.secondaryText),
                          ),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                          activeThumbColor: AppColors.primaryAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading || _uploadingImage ? null : _save,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  widget.productId == null
                                      ? 'CREATE PRODUCT'
                                      : 'UPDATE PRODUCT',
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.secondarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
