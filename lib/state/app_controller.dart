import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/jwt_service.dart';
import '../services/server_health_service.dart';
import '../services/server_preferences.dart';
import '../services/session_storage.dart';
import '../services/user_profile_preferences.dart';

enum AppStage { onboarding, login, home }

enum ConnectionStatus { idle, validating, success, failure }

class AppState {
  const AppState({
    required this.serverUrl,
    required this.accessToken,
    required this.currentUserId,
    required this.currentUsername,
    required this.connectionStatus,
    required this.connectionError,
    required this.isSubmitting,
    required this.authError,
  });

  final String? serverUrl;
  final String? accessToken;
  final String? currentUserId;
  final String? currentUsername;
  final ConnectionStatus connectionStatus;
  final String? connectionError;
  final bool isSubmitting;
  final String? authError;

  AppStage get stage {
    if (serverUrl == null || serverUrl!.isEmpty) {
      return AppStage.onboarding;
    }
    if (accessToken == null || accessToken!.isEmpty) {
      return AppStage.login;
    }
    return AppStage.home;
  }

  AppState copyWith({
    String? serverUrl,
    String? accessToken,
    String? currentUserId,
    String? currentUsername,
    ConnectionStatus? connectionStatus,
    String? connectionError,
    bool clearConnectionError = false,
    bool? isSubmitting,
    String? authError,
    bool clearAuthError = false,
  }) {
    return AppState(
      serverUrl: serverUrl ?? this.serverUrl,
      accessToken: accessToken ?? this.accessToken,
      currentUserId: currentUserId ?? this.currentUserId,
      currentUsername: currentUsername ?? this.currentUsername,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      connectionError:
          clearConnectionError ? null : connectionError ?? this.connectionError,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      authError: clearAuthError ? null : authError ?? this.authError,
    );
  }
}

final appControllerProvider =
    AsyncNotifierProvider<AppController, AppState>(AppController.new);

class AppController extends AsyncNotifier<AppState> {
  final _serverPreferences = ServerPreferences();
  final _sessionStorage = const SessionStorage();
  final _serverHealthService = ServerHealthService();
  final _authService = AuthService();
  final _jwtService = const JwtService();
  final _userProfilePreferences = UserProfilePreferences();

  @override
  Future<AppState> build() async {
    final serverUrl = await _serverPreferences.readServerUrl();
    final accessToken = await _sessionStorage.readAccessToken();
    final currentUserId = accessToken == null
        ? null
        : _jwtService.tryReadUserId(accessToken);
    final tokenDisplayName = accessToken == null
        ? null
        : _jwtService.tryReadDisplayName(accessToken);
    final storedDisplayName = currentUserId == null
        ? null
        : await _userProfilePreferences.readDisplayName(currentUserId);
    final currentUsername = tokenDisplayName ?? storedDisplayName;

    if (currentUserId != null && tokenDisplayName != null) {
      await _userProfilePreferences.writeDisplayName(
        currentUserId,
        tokenDisplayName,
      );
    }

    return AppState(
      serverUrl: serverUrl,
      accessToken: accessToken,
      currentUserId: currentUserId,
      currentUsername: currentUsername,
      connectionStatus: ConnectionStatus.idle,
      connectionError: null,
      isSubmitting: false,
      authError: null,
    );
  }

  Future<void> validateServer(String rawUrl) async {
    final current = state.value;
    if (current == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        connectionStatus: ConnectionStatus.validating,
        clearConnectionError: true,
      ),
    );

    try {
      await _serverHealthService.validate(rawUrl);
      state = AsyncData(
        current.copyWith(
          connectionStatus: ConnectionStatus.success,
          clearConnectionError: true,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          connectionStatus: ConnectionStatus.failure,
          connectionError: error.toString(),
        ),
      );
    }
  }

  Future<void> completeOnboarding(String rawUrl) async {
    final current = state.value;
    if (current == null) {
      return;
    }

    final normalized = _normalizeBaseUrl(rawUrl);
    await _serverPreferences.writeServerUrl(normalized);

    state = AsyncData(
      current.copyWith(
        serverUrl: normalized,
        connectionStatus: ConnectionStatus.idle,
        clearConnectionError: true,
        clearAuthError: true,
      ),
    );
  }

  Future<void> login({required String email, required String password}) async {
    final current = state.value;
    if (current == null || current.serverUrl == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        isSubmitting: true,
        clearAuthError: true,
      ),
    );

    try {
      final tokens = await _authService.login(
        baseUrl: current.serverUrl!,
        email: email.trim().toLowerCase(),
        password: password,
      );
      await _sessionStorage.writeTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      state = AsyncData(
        current.copyWith(
          accessToken: tokens.accessToken,
          currentUserId: _jwtService.tryReadUserId(tokens.accessToken),
          currentUsername: _jwtService.tryReadDisplayName(tokens.accessToken),
          isSubmitting: false,
          clearAuthError: true,
        ),
      );

      final userId = _jwtService.tryReadUserId(tokens.accessToken);
      final username = _jwtService.tryReadDisplayName(tokens.accessToken);
      if (userId != null && username != null) {
        await _userProfilePreferences.writeDisplayName(userId, username);
      }
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isSubmitting: false,
          authError: error.toString(),
        ),
      );
    }
  }

  Future<void> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    final current = state.value;
    if (current == null || current.serverUrl == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        isSubmitting: true,
        clearAuthError: true,
      ),
    );

    try {
      await _authService.register(
        baseUrl: current.serverUrl!,
        username: username.trim(),
        email: email.trim().toLowerCase(),
        password: password,
      );
      final tokens = await _authService.login(
        baseUrl: current.serverUrl!,
        email: email.trim().toLowerCase(),
        password: password,
      );
      await _sessionStorage.writeTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      state = AsyncData(
        current.copyWith(
          accessToken: tokens.accessToken,
          currentUserId: _jwtService.tryReadUserId(tokens.accessToken),
          currentUsername:
              _jwtService.tryReadDisplayName(tokens.accessToken) ?? username.trim(),
          isSubmitting: false,
          clearAuthError: true,
        ),
      );

      final userId = _jwtService.tryReadUserId(tokens.accessToken);
      final resolvedName =
          _jwtService.tryReadDisplayName(tokens.accessToken) ?? username.trim();
      if (userId != null && resolvedName.isNotEmpty) {
        await _userProfilePreferences.writeDisplayName(userId, resolvedName);
      }
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isSubmitting: false,
          authError: error.toString(),
        ),
      );
    }
  }

  Future<void> resetServerUrl() async {
    final current = state.value;
    if (current == null) {
      return;
    }

    await _sessionStorage.clearTokens();
    await _serverPreferences.writeServerUrl('');

    state = AsyncData(
      current.copyWith(
        serverUrl: '',
        accessToken: '',
        currentUserId: null,
        currentUsername: null,
        connectionStatus: ConnectionStatus.idle,
        clearConnectionError: true,
        clearAuthError: true,
      ),
    );
  }

  Future<void> logout() async {
    final current = state.value;
    if (current == null) {
      return;
    }

    await _sessionStorage.clearTokens();
    state = AsyncData(
      current.copyWith(
        accessToken: '',
        currentUserId: null,
        currentUsername: null,
        clearAuthError: true,
      ),
    );
  }

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }
}
