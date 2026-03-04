import 'dart:convert';

import 'package:http/http.dart' as http;

import 'dev_http_client.dart';
import '../models/sticker.dart';

class StickerService {
  StickerService([http.Client? httpClient])
    : _httpClient = createDevHttpClient(httpClient);

  final http.Client _httpClient;

  Future<List<Sticker>> syncAll({
    required String baseUrl,
    required String accessToken,
  }) async {
    final listUri = Uri.parse(
      '${_normalizeBaseUrl(baseUrl)}/api/stickers/list',
    );
    final listResponse = await _httpClient
        .get(listUri, headers: _headers(accessToken))
        .timeout(const Duration(seconds: 10));

    if (listResponse.statusCode != 200) {
      throw StateError('Sticker list failed (${listResponse.statusCode})');
    }

    final list = jsonDecode(listResponse.body) as List<dynamic>;
    final ids = list
        .map((item) => (item as Map<String, dynamic>)['id'] as String)
        .toList(growable: false);

    final stickers = <Sticker>[];
    for (final id in ids) {
      final detailUri = Uri.parse(
        '${_normalizeBaseUrl(baseUrl)}/api/stickers/$id',
      );
      final detailResponse = await _httpClient
          .get(detailUri, headers: _headers(accessToken))
          .timeout(const Duration(seconds: 10));

      if (detailResponse.statusCode == 200) {
        final detail = jsonDecode(detailResponse.body) as Map<String, dynamic>;
        stickers.add(Sticker.fromDetailJson(detail));
      }
    }

    return stickers;
  }

  Map<String, String> _headers(String accessToken) => {
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/json',
  };

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
