import 'dart:async';

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
import '../../state/sticker_controller.dart';
import '../../state/unread_counts_controller.dart';
import '../calls/call_controller.dart';
import '../calls/call_models.dart';
import '../calls/incoming_call_screen.dart';
import '../home/home_page.dart';
import '../planet/planet_page.dart';
import '../chats/chats_page.dart';
import '../settings/settings_page.dart';

const _shellTabTransitionDuration = Duration(milliseconds: 260);
const _shellTabHiddenOffset = 0.035;

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
      unawaited(
        ref
            .read(stickerControllerProvider.notifier)
            .sync(baseUrl: widget.serverUrl, accessToken: effectiveToken),
      );
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
            .read(notificationControllerProvider.notifier)
            .initialize(baseUrl: widget.serverUrl, accessToken: token);
        unawaited(
          ref
              .read(stickerControllerProvider.notifier)
              .sync(baseUrl: widget.serverUrl, accessToken: token),
        );
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

    // Show IncomingCallScreen when a call arrives in the ringing phase
    ref.listen<AsyncValue<CallInfo?>>(callControllerProvider, (prev, next) {
      final info = next.valueOrNull;
      if (info?.phase == CallPhase.ringing &&
          prev?.valueOrNull?.phase != CallPhase.ringing) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => IncomingCallScreen(callInfo: info!),
          ),
        );
      }
    });

    final tabs = [
      HomeTab(
        serverUrl: widget.serverUrl,
        accessToken: widget.accessToken,
        currentUserId: widget.currentUserId,
        currentUsername: widget.currentUsername,
        planetInfo: widget.planetInfo,
        onOpenChat: (friendId) {
          // Switch to Chats tab and pre-select the friend
          setState(() {
            _selectedIndex = 1;
            _activePartnerId = friendId;
          });
          _syncChatVisibility();
        },
        onOpenSettings: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SettingsTab(
                serverUrl: widget.serverUrl,
                activePartnerId: _activePartnerId,
                onSignOut: widget.onSignOut,
                onDeleteAccount: widget.onDeleteAccount,
              ),
            ),
          );
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
      PlanetTab(
        serverUrl: widget.serverUrl,
        accessToken: widget.accessToken,
        planetInfo: widget.planetInfo,
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
        body: Stack(
          children: [
            for (final index in [
              ...List<int>.generate(
                tabs.length,
                (i) => i,
              ).where((i) => i != _selectedIndex),
              _selectedIndex,
            ])
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: index != _selectedIndex,
                  child: ExcludeSemantics(
                    excluding: index != _selectedIndex,
                    child: TickerMode(
                      enabled: index == _selectedIndex,
                      child: AnimatedSlide(
                        duration: _shellTabTransitionDuration,
                        curve: Curves.easeOutCubic,
                        offset: index == _selectedIndex
                            ? Offset.zero
                            : Offset(
                                index < _selectedIndex
                                    ? -_shellTabHiddenOffset
                                    : _shellTabHiddenOffset,
                                0,
                              ),
                        child: AnimatedOpacity(
                          duration: _shellTabTransitionDuration,
                          curve: Curves.easeOutCubic,
                          opacity: index == _selectedIndex ? 1 : 0,
                          child: KeyedSubtree(
                            key: ValueKey('main_shell_tab_$index'),
                            child: tabs[index],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
