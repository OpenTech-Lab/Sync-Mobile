import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// ALTCHA proof-of-work challenge from the server.
class AltchaChallenge {
  const AltchaChallenge({
    required this.algorithm,
    required this.challenge,
    required this.salt,
    required this.signature,
    required this.maxNumber,
  });

  factory AltchaChallenge.fromJson(Map<String, dynamic> json) {
    return AltchaChallenge(
      algorithm: json['algorithm'] as String? ?? 'SHA-256',
      challenge: json['challenge'] as String,
      salt: json['salt'] as String,
      signature: json['signature'] as String,
      maxNumber: (json['maxnumber'] as num?)?.toInt() ?? 1000000,
    );
  }

  final String algorithm;
  final String challenge;
  final String salt;
  final String signature;
  final int maxNumber;
}

// ── Isolate entry ─────────────────────────────────────────────────────────────

/// Parameters passed into the background isolate.
class _SolveParams {
  const _SolveParams({
    required this.salt,
    required this.challenge,
    required this.maxNumber,
  });

  final String salt;
  final String challenge;
  final int maxNumber;
}

/// Runs in a worker isolate so the UI thread stays responsive.
/// Returns the winning number, or -1 if no solution was found.
int _solveInIsolate(_SolveParams p) {
  final target = p.challenge.toLowerCase();
  for (var n = 0; n <= p.maxNumber; n++) {
    final input = utf8.encode('${p.salt}$n');
    final digest = sha256.convert(input).toString().toLowerCase();
    if (digest == target) {
      return n;
    }
  }
  return -1;
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Fetches an ALTCHA challenge from [challengeUrl] and solves the
/// proof-of-work puzzle in a background isolate.
///
/// Returns:
/// - A base64-encoded JSON payload string on success — pass this to the
///   corresponding auth endpoints as `altcha_payload`.
/// - `null` when ALTCHA is **disabled** on the server (HTTP 404) or the
///   network request fails — the caller should proceed without a payload.
///
/// Throws if a challenge was received but solving failed (e.g. maxNumber too
/// small or algorithm mismatch).
Future<String?> fetchAndSolveAltcha(String challengeUrl) async {
  // ── 1. Fetch challenge ────────────────────────────────────────────────────
  http.Response response;
  try {
    response = await http.get(Uri.parse(challengeUrl));
  } catch (_) {
    // Network unreachable — proceed without ALTCHA.
    return null;
  }

  if (response.statusCode == 404) {
    // ALTCHA is not configured on this server instance.
    return null;
  }
  if (response.statusCode != 200) {
    // Unexpected error — proceed without ALTCHA so login is not hard-blocked.
    return null;
  }

  final Map<String, dynamic> json;
  try {
    json = jsonDecode(response.body) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }

  final challenge = AltchaChallenge.fromJson(json);

  if (challenge.algorithm.toUpperCase() != 'SHA-256') {
    // Only SHA-256 is supported.
    throw UnsupportedError(
      'ALTCHA: unsupported algorithm "${challenge.algorithm}"',
    );
  }

  // ── 2. Solve in background isolate ───────────────────────────────────────
  final started = DateTime.now();

  final number = await Isolate.run(
    () => _solveInIsolate(
      _SolveParams(
        salt: challenge.salt,
        challenge: challenge.challenge,
        maxNumber: challenge.maxNumber,
      ),
    ),
  );

  if (number < 0) {
    throw StateError('ALTCHA: could not find a solution within maxNumber');
  }

  final took = DateTime.now().difference(started).inMilliseconds;

  // ── 3. Build and encode payload ───────────────────────────────────────────
  final payload = {
    'algorithm': challenge.algorithm,
    'challenge': challenge.challenge,
    'number': number,
    'salt': challenge.salt,
    'signature': challenge.signature,
    'took': took,
  };

  return base64.encode(utf8.encode(jsonEncode(payload)));
}
