import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/jwt_service.dart';
import '../services/remote_user_profile_service.dart';
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
    required this.savedEmail,
    required this.connectionStatus,
    required this.connectionError,
    required this.planetInfo,
    required this.isSubmitting,
    required this.authError,
  });

  final String? serverUrl;
  final String? accessToken;
  final String? currentUserId;
  final String? currentUsername;
  final String? savedEmail;
  final ConnectionStatus connectionStatus;
  final String? connectionError;
  final PlanetInfo? planetInfo;
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
    String? savedEmail,
    bool clearSavedEmail = false,
    ConnectionStatus? connectionStatus,
    String? connectionError,
    bool clearConnectionError = false,
    PlanetInfo? planetInfo,
    bool clearPlanetInfo = false,
    bool? isSubmitting,
    String? authError,
    bool clearAuthError = false,
  }) {
    return AppState(
      serverUrl: serverUrl ?? this.serverUrl,
      accessToken: accessToken ?? this.accessToken,
      currentUserId: currentUserId ?? this.currentUserId,
      currentUsername: currentUsername ?? this.currentUsername,
      savedEmail: clearSavedEmail ? null : savedEmail ?? this.savedEmail,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      connectionError: clearConnectionError
          ? null
          : connectionError ?? this.connectionError,
      planetInfo: clearPlanetInfo ? null : planetInfo ?? this.planetInfo,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      authError: clearAuthError ? null : authError ?? this.authError,
    );
  }
}

final appControllerProvider = AsyncNotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends AsyncNotifier<AppState> {
  final _serverPreferences = ServerPreferences();
  final _sessionStorage = const SessionStorage();
  final _serverHealthService = ServerHealthService();
  final _authService = AuthService();
  final _jwtService = const JwtService();
  final _userProfilePreferences = UserProfilePreferences();
  final _remoteUserProfileService = RemoteUserProfileService();

  @override
  Future<AppState> build() async {
    final serverUrl = await _serverPreferences.readServerUrl();
    final savedEmail = serverUrl != null && serverUrl.isNotEmpty
        ? await _serverPreferences.readSavedEmail(serverUrl)
        : null;
    var accessToken = await _sessionStorage.readAccessToken();

    // Proactively refresh an expired (or nearly-expired) access token so that
    // the rest of the startup flow has a valid token to work with.
    if (accessToken != null &&
        accessToken.isNotEmpty &&
        serverUrl != null &&
        serverUrl.isNotEmpty &&
        _jwtService.isExpiredOrExpiringSoon(accessToken)) {
      try {
        final storedRefresh = await _sessionStorage.readRefreshToken();
        if (storedRefresh != null && storedRefresh.isNotEmpty) {
          final tokens = await _authService.refresh(
            baseUrl: serverUrl,
            refreshToken: storedRefresh,
          );
          await _sessionStorage.writeTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
          );
          accessToken = tokens.accessToken;
        }
      } catch (_) {
        // Refresh failed — continue with the stale token; routes will 401.
      }
    }

    final currentUserId = accessToken == null
        ? null
        : _jwtService.tryReadUserId(accessToken);
    final tokenDisplayName = accessToken == null
        ? null
        : _jwtService.tryReadDisplayName(accessToken);
    final storedDisplayName = currentUserId == null
        ? null
        : await _userProfilePreferences.readDisplayName(currentUserId);
    var currentUsername = tokenDisplayName ?? storedDisplayName;

    if (currentUserId != null && tokenDisplayName != null) {
      await _userProfilePreferences.writeDisplayName(
        currentUserId,
        tokenDisplayName,
      );
    }

    if (serverUrl != null &&
        serverUrl.isNotEmpty &&
        accessToken != null &&
        currentUserId != null) {
      try {
        final profile = await _remoteUserProfileService.getMyProfile(
          baseUrl: serverUrl,
          accessToken: accessToken,
        );
        currentUsername = profile.username.trim().isEmpty
            ? currentUsername
            : profile.username.trim();
        await _userProfilePreferences.writeDisplayName(
          currentUserId,
          currentUsername,
        );
        await _userProfilePreferences.writeAvatarBase64(
          currentUserId,
          profile.avatarBase64,
        );
      } catch (_) {}
    }

    return AppState(
      serverUrl: serverUrl,
      accessToken: accessToken,
      currentUserId: currentUserId,
      currentUsername: currentUsername,
      savedEmail: savedEmail,
      connectionStatus: ConnectionStatus.idle,
      connectionError: null,
      planetInfo: null,
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
        clearPlanetInfo: true,
      ),
    );

    try {
      final planetInfo = await _serverHealthService.validate(rawUrl);
      state = AsyncData(
        current.copyWith(
          connectionStatus: ConnectionStatus.success,
          clearConnectionError: true,
          planetInfo: planetInfo,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          connectionStatus: ConnectionStatus.failure,
          connectionError: error.toString(),
          clearPlanetInfo: true,
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
        clearPlanetInfo: true,
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
      current.copyWith(isSubmitting: true, clearAuthError: true),
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

      final userId = _jwtService.tryReadUserId(tokens.accessToken);
      var username = _jwtService.tryReadDisplayName(tokens.accessToken);
      if (current.serverUrl != null && userId != null) {
        try {
          final profile = await _remoteUserProfileService.getMyProfile(
            baseUrl: current.serverUrl!,
            accessToken: tokens.accessToken,
          );
          username = profile.username.trim().isEmpty
              ? username
              : profile.username.trim();
          await _userProfilePreferences.writeAvatarBase64(
            userId,
            profile.avatarBase64,
          );
        } catch (_) {}
      }

      final normalizedEmail = email.trim().toLowerCase();
      await _serverPreferences.writeSavedEmail(
        current.serverUrl!,
        normalizedEmail,
      );

      state = AsyncData(
        current.copyWith(
          accessToken: tokens.accessToken,
          currentUserId: userId,
          currentUsername: username,
          savedEmail: normalizedEmail,
          isSubmitting: false,
          clearAuthError: true,
        ),
      );

      if (userId != null && username != null) {
        await _userProfilePreferences.writeDisplayName(userId, username);
      }
    } catch (error) {
      state = AsyncData(
        current.copyWith(isSubmitting: false, authError: error.toString()),
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
      current.copyWith(isSubmitting: true, clearAuthError: true),
    );

    try {
      await _authService.register(
        baseUrl: current.serverUrl!,
        username: username.trim(),
        email: email.trim().toLowerCase(),
        password: password,
      );
      await _serverPreferences.writeSavedEmail(
        current.serverUrl!,
        email.trim().toLowerCase(),
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

      final userId = _jwtService.tryReadUserId(tokens.accessToken);
      var resolvedName =
          _jwtService.tryReadDisplayName(tokens.accessToken) ?? username.trim();
      if (current.serverUrl != null && userId != null) {
        try {
          final profile = await _remoteUserProfileService.getMyProfile(
            baseUrl: current.serverUrl!,
            accessToken: tokens.accessToken,
          );
          resolvedName = profile.username.trim().isEmpty
              ? resolvedName
              : profile.username.trim();
          await _userProfilePreferences.writeAvatarBase64(
            userId,
            profile.avatarBase64,
          );
        } catch (_) {}
      }

      state = AsyncData(
        current.copyWith(
          accessToken: tokens.accessToken,
          currentUserId: userId,
          currentUsername: resolvedName,
          savedEmail: email.trim().toLowerCase(),
          isSubmitting: false,
          clearAuthError: true,
        ),
      );

      if (userId != null && resolvedName.isNotEmpty) {
        await _userProfilePreferences.writeDisplayName(userId, resolvedName);
      }
    } catch (error) {
      state = AsyncData(
        current.copyWith(isSubmitting: false, authError: error.toString()),
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

  /// Returns a valid (non-expired) access token.
  /// If the current token is expired or expiring within 60 s, it silently
  /// exchanges the stored refresh token for a fresh pair and updates AppState.
  /// Falls back to the existing token if refresh fails.
  Future<String?> ensureFreshAccessToken() async {
    final current = state.value;
    final token = current?.accessToken;
    if (token == null || token.isEmpty) return token;

    if (!_jwtService.isExpiredOrExpiringSoon(token)) return token;

    final serverUrl = current?.serverUrl;
    if (serverUrl == null || serverUrl.isEmpty) return token;

    try {
      final storedRefresh = await _sessionStorage.readRefreshToken();
      if (storedRefresh == null || storedRefresh.isEmpty) return token;

      final tokens = await _authService.refresh(
        baseUrl: serverUrl,
        refreshToken: storedRefresh,
      );

      await _sessionStorage.writeTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      state = AsyncData(current!.copyWith(accessToken: tokens.accessToken));
      return tokens.accessToken;
    } catch (_) {
      return token; // best-effort: return stale token, caller handles 401
    }
  }

  void setCurrentUsername(String username) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final normalized = username.trim();
    state = AsyncData(current.copyWith(currentUsername: normalized));
  }
}
