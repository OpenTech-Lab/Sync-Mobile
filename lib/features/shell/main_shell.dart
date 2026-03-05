import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/components/organisms/app_bottom_nav.dart';
import '../../services/server_health_service.dart';
import '../../state/app_controller.dart';
import '../../state/backup_controller.dart';
import '../../state/chat_visibility_controller.dart';
import '../../state/notification_controller.dart';
import '../../state/realtime_sync_controller.dart';
import '../../state/unread_counts_controller.dart';
import '../home/home_page.dart';
import '../planet/planet_page.dart';
import '../chats/chats_page.dart';
import '../settings/settings_page.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({
    super.key,
    required this.serverUrl,
    required this.accessToken,
    required this.currentUserId,
    required this.currentUsername,
    required this.planetInfo,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final String serverUrl;
  final String accessToken;
  final String currentUserId;
  final String? currentUsername;
  final PlanetInfo? planetInfo;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onDeleteAccount;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String? _activePartnerId;
  // Cache the notifier so we can call disconnect() in dispose() without
  // touching `ref` (which may already be invalid at that point).
  late RealtimeSyncController _realtimeSyncNotifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtimeSyncNotifier = ref.read(realtimeSyncControllerProvider.notifier);
    _syncChatVisibility();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final effectiveToken =
          await _effectiveAccessToken() ?? widget.accessToken;
      // Kick off all background services after first frame
      await Future.wait([
        ref
            .read(unreadCountsProvider.notifier)
            .refresh(baseUrl: widget.serverUrl, accessToken: effectiveToken),
        ref
            .read(notificationControllerProvider.notifier)
            .initialize(baseUrl: widget.serverUrl, accessToken: effectiveToken),
        _realtimeSyncNotifier.connect(
          baseUrl: widget.serverUrl,
          accessTokenProvider: _effectiveAccessToken,
          currentUserId: widget.currentUserId,
        ),
      ]);
      await ref
          .read(backupControllerProvider.notifier)
          .maybeAutoBackup(
            baseUrl: widget.serverUrl,
            accessToken: effectiveToken,
          );
    });
  }

  Future<String?> _effectiveAccessToken() async {
    final fresh = await ref
        .read(appControllerProvider.notifier)
        .ensureFreshAccessToken();
    if (fresh != null && fresh.isNotEmpty) {
      return fresh;
    }
    final appState = ref.read(appControllerProvider).value;
    final current = appState?.accessToken;
    if (current != null && current.isNotEmpty) {
      return current;
    }
    return widget.accessToken;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future(() async {
        _realtimeSyncNotifier.connect(
          baseUrl: widget.serverUrl,
          accessTokenProvider: _effectiveAccessToken,
          currentUserId: widget.currentUserId,
        );
        final token = await _effectiveAccessToken();
        if (token == null || token.isEmpty) {
          return;
        }
        await ref
            .read(backupControllerProvider.notifier)
            .maybeAutoBackup(baseUrl: widget.serverUrl, accessToken: token);
      });
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _realtimeSyncNotifier.disconnect();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeSyncNotifier.disconnect();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _selectedIndex = index);
    _syncChatVisibility();
  }

  void _syncChatVisibility() {
    Future(() {
      if (!mounted) {
        return;
      }
      ref.read(chatVisibilityProvider.notifier).state = ChatVisibilityState(
        isChatsTabSelected: _selectedIndex == 1,
        activePartnerId: _activePartnerId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hideTabs = _selectedIndex == 1 && _activePartnerId != null;
    final unreadCounts =
        ref.watch(unreadCountsProvider).value ?? const <String, int>{};
    final totalUnread = unreadCounts.values.fold(0, (s, v) => s + v);

    final tabs = [
      HomeTab(
        serverUrl: widget.serverUrl,
        accessToken: widget.accessToken,
        currentUserId: widget.currentUserId,
        currentUsername: widget.currentUsername,
        onOpenChat: (friendId) {
          // Switch to Chats tab and pre-select the friend
          setState(() {
            _selectedIndex = 1;
            _activePartnerId = friendId;
          });
          _syncChatVisibility();
        },
      ),
      ChatsTab(
        serverUrl: widget.serverUrl,
        accessToken: widget.accessToken,
        currentUserId: widget.currentUserId,
        initialPartnerId: _activePartnerId,
        onPartnerChanged: (id) {
          setState(() => _activePartnerId = id);
          _syncChatVisibility();
        },
      ),
      PlanetTab(serverUrl: widget.serverUrl, accessToken: widget.accessToken),
      SettingsTab(
        serverUrl: widget.serverUrl,
        planetInfo: widget.planetInfo,
        currentUserId: widget.currentUserId,
        activePartnerId: _activePartnerId,
        onSignOut: widget.onSignOut,
        onDeleteAccount: widget.onDeleteAccount,
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: tabs),
        bottomNavigationBar: hideTabs
            ? null
            : AppBottomNav(
                selectedIndex: _selectedIndex,
                onTap: _onTabTapped,
                totalUnread: totalUnread,
              ),
      ),
    );
  }
}
