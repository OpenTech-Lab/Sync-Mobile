import 'package:web_socket_channel/web_socket_channel.dart';

import 'dev_web_socket_channel_stub.dart'
    if (dart.library.io) 'dev_web_socket_channel_io.dart'
    as impl;

WebSocketChannel connectDevWebSocketChannel(Uri uri) {
  return impl.connect(uri);
}
