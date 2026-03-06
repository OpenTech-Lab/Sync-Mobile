import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/jwt_service.dart';
import '../services/message_e2ee_service.dart';
import '../services/remote_user_profile_service.dart';
import '../services/server_scope.dart';
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
    required this.savedUserId,
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
  final String? savedUserId;
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
    String? savedUserId,
    bool clearSavedUserId = false,
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
      savedUserId: clearSavedUserId ? null : savedUserId ?? this.savedUserId,
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

final activeServerUrlProvider = Provider<String?>((ref) {
  final appState = ref.watch(appControllerProvider);
  return appState.maybeWhen(
    data: (state) {
      final serverUrl = state.serverUrl?.trim();
      if (serverUrl == null || serverUrl.isEmpty) {
        return null;
      }
      return serverUrl;
    },
    orElse: () => null,
  );
});

class AppController extends AsyncNotifier<AppState> {
  static const _genericConnectError =
      'Connection failed. Please try again later or ask planet manager.';

  final _serverPreferences = ServerPreferences();
  final _sessionStorage = const SessionStorage();
  final _serverHealthService = ServerHealthService();
  final _authService = AuthService();
  final _jwtService = const JwtService();
  final _messageE2eeService = MessageE2eeService();
  final _userProfilePreferences = UserProfilePreferences();
  final _remoteUserProfileService = RemoteUserProfileService();

  bool _isAuthIdentityInvalidError(Object error) {
    final raw = error.toString();
    return raw.contains('(401)') || raw.contains('(404)');
  }

  @override
  Future<AppState> build() async {
    final serverUrl = await _serverPreferences.readServerUrl();
    final normalizedServerUrl = normalizeServerUrl(serverUrl ?? '');
    final savedUserId = serverUrl != null && serverUrl.isNotEmpty
        ? await _serverPreferences.readSavedUserId(serverUrl)
        : null;
    final cachedPlanet = serverUrl != null && serverUrl.isNotEmpty
        ? await _serverPreferences.readPlanetInfo(serverUrl)
        : null;
    var accessToken = serverUrl == null || serverUrl.isEmpty
        ? null
        : await _sessionStorage.readAccessToken(serverUrl);

    if (accessToken != null &&
        accessToken.isNotEmpty &&
        serverUrl != null &&
        serverUrl.isNotEmpty &&
        _jwtService.isExpiredOrExpiringSoon(accessToken)) {
      try {
        final storedRefresh = await _sessionStorage.readRefreshToken(serverUrl);
        if (storedRefresh != null && storedRefresh.isNotEmpty) {
          final tokens = await _authService.refresh(
            baseUrl: serverUrl,
            refreshToken: storedRefresh,
          );
          await _sessionStorage.writeTokens(
            serverUrl: serverUrl,
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
          );
          accessToken = tokens.accessToken;
        }
      } catch (_) {}
    }

    var currentUserId = accessToken == null
        ? null
        : _jwtService.tryReadUserId(accessToken);
    final tokenDisplayName = accessToken == null
        ? null
        : _jwtService.tryReadDisplayName(accessToken);
    final storedDisplayName = currentUserId == null
        ? null
        : await _userProfilePreferences.readDisplayName(
            serverUrl ?? '',
            currentUserId,
          );
    var currentUsername = tokenDisplayName ?? storedDisplayName;

    if (currentUserId != null && tokenDisplayName != null) {
      await _userProfilePreferences.writeDisplayName(
        serverUrl ?? '',
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
          serverUrl,
          currentUserId,
          currentUsername,
        );
        await _userProfilePreferences.writeAvatarBase64(
          serverUrl,
          currentUserId,
          profile.avatarBase64,
        );
        await _ensureChatPublicKeyRegistered(
          serverUrl: serverUrl,
          accessToken: accessToken,
          remoteProfilePublicKey: profile.messagePublicKey,
        );
      } catch (error) {
        if (_isAuthIdentityInvalidError(error)) {
          await _sessionStorage.clearTokens(serverUrl);
          accessToken = null;
          currentUserId = null;
          currentUsername = null;
        }
      }
    }

    return AppState(
      serverUrl: serverUrl,
      accessToken: accessToken,
      currentUserId: currentUserId,
      currentUsername: currentUsername,
      savedUserId: savedUserId,
      connectionStatus: ConnectionStatus.idle,
      connectionError: null,
      planetInfo: cachedPlanet == null
          ? null
          : PlanetInfo(
              baseUrl: normalizedServerUrl,
              host: Uri.tryParse(normalizedServerUrl)?.host ?? '',
              scheme: Uri.tryParse(normalizedServerUrl)?.scheme ?? 'https',
              instanceName: cachedPlanet.instanceName,
              instanceDescription: cachedPlanet.instanceDescription,
              instanceImageUrl: cachedPlanet.instanceImageUrl,
              memberCount: cachedPlanet.memberCount,
              linkedPlanets: cachedPlanet.linkedPlanets,
              instanceDomain: cachedPlanet.instanceDomain,
              countryCode: cachedPlanet.countryCode,
              countryName: cachedPlanet.countryName,
              serverCreatedAt: cachedPlanet.serverCreatedAt,
              healthStatus: cachedPlanet.healthStatus,
              latencyMs: cachedPlanet.latencyMs,
              checkedAt: cachedPlanet.checkedAt,
              registrationRequiresApproval:
                  cachedPlanet.registrationRequiresApproval,
            ),
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
      await _serverPreferences.writePlanetInfo(
        serverUrl: planetInfo.baseUrl,
        planetInfo: planetInfo,
      );
      state = AsyncData(
        current.copyWith(
          connectionStatus: ConnectionStatus.success,
          clearConnectionError: true,
          planetInfo: planetInfo,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('validateServer failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      state = AsyncData(
        current.copyWith(
          connectionStatus: ConnectionStatus.failure,
          connectionError: _genericConnectError,
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
    final candidateFromHealth = current.planetInfo?.baseUrl;
    final resolvedServerUrl =
        candidateFromHealth != null && candidateFromHealth.isNotEmpty
        ? candidateFromHealth
        : normalized;
    await _serverPreferences.writeServerUrl(resolvedServerUrl);
    final accessToken = await _sessionStorage.readAccessToken(resolvedServerUrl);
    final savedUserId = await _serverPreferences.readSavedUserId(
      resolvedServerUrl,
    );
    final currentUserId = accessToken == null || accessToken.isEmpty
        ? null
        : _jwtService.tryReadUserId(accessToken);
    final tokenDisplayName = accessToken == null || accessToken.isEmpty
        ? null
        : _jwtService.tryReadDisplayName(accessToken);
    final storedDisplayName = currentUserId == null
        ? null
        : await _userProfilePreferences.readDisplayName(
            resolvedServerUrl,
            currentUserId,
          );

    state = AsyncData(
      current.copyWith(
        serverUrl: resolvedServerUrl,
        accessToken: accessToken ?? '',
        currentUserId: currentUserId,
        currentUsername: tokenDisplayName ?? storedDisplayName,
        savedUserId: savedUserId,
        connectionStatus: ConnectionStatus.idle,
        clearConnectionError: true,
        clearAuthError: true,
      ),
    );
  }

  Future<void> loginWithDeviceIdentity({String? altchaPayload}) async {
    final current = state.value;
    if (current == null || current.serverUrl == null || current.isSubmitting) {
      return;
    }

    state = AsyncData(
      current.copyWith(isSubmitting: true, clearAuthError: true),
    );

    try {
      final deviceAuthPublicKey = await _messageE2eeService
          .ensureDevicePublicKeyBase64();
      final tokens = await _authService.deviceLogin(
        baseUrl: current.serverUrl!,
        deviceAuthPublicKey: deviceAuthPublicKey,
        altchaPayload: altchaPayload,
      );
      await _sessionStorage.writeTokens(
        serverUrl: current.serverUrl!,
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      final userId = _jwtService.tryReadUserId(tokens.accessToken);
      var username = _jwtService.tryReadDisplayName(tokens.accessToken);
      if (current.serverUrl != null && userId != null) {
        await _serverPreferences.writeSavedUserId(current.serverUrl!, userId);
        try {
          final profile = await _remoteUserProfileService.getMyProfile(
            baseUrl: current.serverUrl!,
            accessToken: tokens.accessToken,
          );
          username = profile.username.trim().isEmpty
              ? username
              : profile.username.trim();
          await _userProfilePreferences.writeAvatarBase64(
            current.serverUrl!,
            userId,
            profile.avatarBase64,
          );
          await _ensureChatPublicKeyRegistered(
            serverUrl: current.serverUrl!,
            accessToken: tokens.accessToken,
            remoteProfilePublicKey: profile.messagePublicKey,
          );
        } catch (_) {}
      }

      state = AsyncData(
        current.copyWith(
          accessToken: tokens.accessToken,
          currentUserId: userId,
          currentUsername: username,
          savedUserId: userId,
          isSubmitting: false,
          clearAuthError: true,
        ),
      );

      if (userId != null && username != null) {
        await _userProfilePreferences.writeDisplayName(
          current.serverUrl!,
          userId,
          username,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('loginWithDeviceIdentity failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      final errorMessage = error is AccountPendingApprovalException
          ? (error.message ?? 'Your account is pending admin approval.')
          : _genericConnectError;
      state = AsyncData(
        current.copyWith(isSubmitting: false, authError: errorMessage),
      );
    }
  }

  /// Fetches an ALTCHA challenge from the server using the dev-aware HTTP
  /// client.  Returns `null` when ALTCHA is disabled on this server instance.
  Future<Map<String, dynamic>?> fetchAltchaChallenge(String serverUrl) =>
      _authService.fetchAltchaChallenge(serverUrl);

  Future<void> resetServerUrl() async {
    final current = state.value;
    if (current == null) {
      return;
    }

    final currentServerUrl = current.serverUrl;
    if (currentServerUrl != null && currentServerUrl.isNotEmpty) {
      await _sessionStorage.clearTokens(currentServerUrl);
    }
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

    final currentServerUrl = current.serverUrl;
    if (currentServerUrl != null && currentServerUrl.isNotEmpty) {
      await _sessionStorage.clearTokens(currentServerUrl);
    }
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

  Future<void> deleteAccount() async {
    final current = state.value;
    if (current == null ||
        current.serverUrl == null ||
        current.accessToken == null) {
      return;
    }

    try {
      final freshToken = await ensureFreshAccessToken() ?? current.accessToken!;
      await _remoteUserProfileService.deleteMyAccount(
        baseUrl: current.serverUrl!,
        accessToken: freshToken,
      );
    } catch (_) {
      // Best-effort: clear locally even if server call fails.
    }

    final currentServerUrl = current.serverUrl;
    if (currentServerUrl != null && currentServerUrl.isNotEmpty) {
      await _sessionStorage.clearTokens(currentServerUrl);
    }
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

  String _normalizeBaseUrl(String raw) {
    return normalizeServerUrl(raw);
  }

  Future<String?> ensureFreshAccessToken() async {
    final current = state.value;
    final token = current?.accessToken;
    if (token == null || token.isEmpty) return token;

    if (!_jwtService.isExpiredOrExpiringSoon(token)) return token;

    final serverUrl = current?.serverUrl;
    if (serverUrl == null || serverUrl.isEmpty) return token;

    try {
      final storedRefresh = await _sessionStorage.readRefreshToken(serverUrl);
      if (storedRefresh == null || storedRefresh.isEmpty) return token;

      final tokens = await _authService.refresh(
        baseUrl: serverUrl,
        refreshToken: storedRefresh,
      );

      await _sessionStorage.writeTokens(
        serverUrl: serverUrl,
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );

      state = AsyncData(current!.copyWith(accessToken: tokens.accessToken));
      return tokens.accessToken;
    } catch (_) {
      return token;
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

  Future<void> _ensureChatPublicKeyRegistered({
    required String serverUrl,
    required String accessToken,
    required String? remoteProfilePublicKey,
  }) async {
    String? localPublicKey;
    try {
      localPublicKey = await _messageE2eeService.ensureDevicePublicKeyBase64();
    } catch (_) {
      localPublicKey = await _messageE2eeService.readStoredPublicKey();
    }
    if (localPublicKey == null || localPublicKey.isEmpty) {
      return;
    }
    if (remoteProfilePublicKey == localPublicKey) {
      return;
    }
    try {
      await _remoteUserProfileService.updateMyProfile(
        baseUrl: serverUrl,
        accessToken: accessToken,
        messagePublicKey: localPublicKey,
      );
    } catch (_) {}
  }
}
