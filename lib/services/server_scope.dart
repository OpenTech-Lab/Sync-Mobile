String normalizeServerUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.endsWith('/')) {
    return trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

/// Use the planet domain as the stable local-storage namespace key.
String serverDomainKeyFromUrl(String serverUrl) {
  final normalized = normalizeServerUrl(serverUrl);
  final parsed = Uri.tryParse(normalized);
  final host = parsed?.host.trim().toLowerCase() ?? '';
  if (host.isNotEmpty) {
    return host;
  }
  return normalized.toLowerCase();
}

String scopedStorageKey(
  String prefix,
  String serverUrl, {
  String? suffix,
}) {
  final scope = serverDomainKeyFromUrl(serverUrl);
  final normalizedSuffix = suffix?.trim();
  if (normalizedSuffix == null || normalizedSuffix.isEmpty) {
    return '$prefix::$scope';
  }
  return '$prefix::$scope::$normalizedSuffix';
}

String serverDatabaseSlug(String serverUrl) {
  final scope = serverDomainKeyFromUrl(serverUrl);
  return scope.replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
}
