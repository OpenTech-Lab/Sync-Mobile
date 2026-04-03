import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/remote_admin_service.dart';
import 'app_controller.dart';

final remoteAdminServiceProvider = Provider<RemoteAdminService>((ref) {
  return RemoteAdminService();
});

final adminUsersProvider = FutureProvider<List<AdminUser>>((ref) async {
  final appState = await ref.watch(appControllerProvider.future);
  final serverUrl = appState.serverUrl?.trim();
  final accessToken = appState.accessToken?.trim();
  if (serverUrl == null ||
      serverUrl.isEmpty ||
      accessToken == null ||
      accessToken.isEmpty) {
    return const <AdminUser>[];
  }
  return ref
      .read(remoteAdminServiceProvider)
      .listUsers(baseUrl: serverUrl, accessToken: accessToken);
});
