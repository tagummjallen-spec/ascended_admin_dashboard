String normalizeProductImageReference(String input) {
  final value = input.trim();
  if (value.isEmpty) return '';

  final lowerCaseValue = value.toLowerCase();
  if (lowerCaseValue.startsWith('http://') ||
      lowerCaseValue.startsWith('https://') ||
      lowerCaseValue.startsWith('data:image/') ||
      value.startsWith('assets/')) {
    return value;
  }

  final filename = value.replaceFirst(RegExp(r'^/+'), '');
  return 'assets/images/products/$filename';
}

List<String> appendProductImageReference(List<String> existing, String input) {
  final normalized = normalizeProductImageReference(input);
  if (normalized.isEmpty || existing.contains(normalized)) {
    return List<String>.of(existing);
  }
  return [...existing, normalized];
}
