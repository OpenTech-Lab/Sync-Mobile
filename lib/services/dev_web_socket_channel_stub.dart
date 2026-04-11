import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connect(Uri uri) {
  return WebSocketChannel.connect(uri);
}
