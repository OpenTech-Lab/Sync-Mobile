import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'dev_http_client_io.dart';

WebSocketChannel connect(Uri uri) {
  final client = HttpClient();
  configureDevBadCertificateCallback(client);
  return IOWebSocketChannel.connect(uri, customClient: client);
}
