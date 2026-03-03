import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client createClient() {
  final io = HttpClient();
  io.badCertificateCallback = (X509Certificate _, String host, int port) {
    if (port <= 0) {
      return false;
    }
    final h = host.toLowerCase().trim();
    return h == 'localhost' ||
        h == '127.0.0.1' ||
        h == '::1' ||
        h == '10.0.2.2' ||
        h == '10.0.3.2' ||
        h.endsWith('.localhost');
  };
  return IOClient(io);
}
