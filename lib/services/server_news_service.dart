import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/server_news.dart';
import 'dev_http_client.dart';

class ServerNewsService {
  ServerNewsService([http.Client? httpClient])
    : _httpClient = createDevHttpClient(httpClient);

  final http.Client _httpClient;

  Future<List<ServerNewsItem>> listNews({
    required String baseUrl,
    required String accessToken,
    int limit = 30,
  }) async {
    final uri = Uri.parse(
      '${_normalizeBaseUrl(baseUrl)}/api/planet-news?limit=$limit',
    );
    final response = await _httpClient
        .get(uri, headers: _headers(accessToken))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw StateError('Server news list failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ServerNewsItem.fromJson)
        .toList(growable: false);
  }

  Future<ServerNewsItem> getNewsDetail({
    required String baseUrl,
    required String accessToken,
    required String newsId,
  }) async {
    final uri = Uri.parse(
      '${_normalizeBaseUrl(baseUrl)}/api/planet-news/$newsId',
    );
    final response = await _httpClient
        .get(uri, headers: _headers(accessToken))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw StateError('Server news detail failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid server news detail payload');
    }

    return ServerNewsItem.fromJson(decoded);
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
