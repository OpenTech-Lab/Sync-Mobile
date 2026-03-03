import 'package:http/http.dart' as http;

import 'dev_http_client_stub.dart'
    if (dart.library.io) 'dev_http_client_io.dart' as impl;

http.Client createDevHttpClient([http.Client? override]) {
  return override ?? impl.createClient();
}
