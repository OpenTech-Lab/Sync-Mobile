class ObjectionableContentException implements Exception {
  const ObjectionableContentException(this.message);

  final String message;

  @override
  String toString() => message;
}

const List<String> _blockedTerms = <String>[
  'child porn',
  'cp',
  'cunt',
  'faggot',
  'fuck',
  'fucker',
  'fucking',
  'kill yourself',
  'kike',
  'nigger',
  'nigga',
  'rape',
  'rapist',
  'retard',
  'shit',
];

String? detectBlockedTerm(String value) {
  final lowercase = value.trim().toLowerCase();
  if (lowercase.isEmpty) {
    return null;
  }

  final tokens = lowercase
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.isNotEmpty)
      .toSet();

  for (final term in _blockedTerms) {
    if (term.contains(' ')) {
      if (lowercase.contains(term)) {
        return term;
      }
      continue;
    }
    if (tokens.contains(term)) {
      return term;
    }
  }

  return null;
}

void ensureUserGeneratedTextAllowed(String fieldName, String value) {
  final blockedTerm = detectBlockedTerm(value);
  if (blockedTerm == null) {
    return;
  }
  throw ObjectionableContentException(
    '$fieldName contains objectionable content and cannot be sent.',
  );
}
