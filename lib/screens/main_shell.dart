import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/server_health_service.dart';
import '../state/app_controller.dart';
import '../state/notification_controller.dart';
import '../state/realtime_sync_controller.dart';
import '../state/sticker_controller.dart';
import '../state/unread_counts_controller.dart';
import 'home_tab.dart';
import 'chats_tab.dart';
import 'settings_tab.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({
    super.key,
    required this.serverUrl,
    required this.accessToken,
    required this.currentUserId,
    required this.currentUsername,
    required this.planetInfo,
    required this.onSignOut,
  });

  final String serverUrl;
  final String accessToken;
  final String currentUserId;
  final String? currentUsername;
  final PlanetInfo? planetInfo;
  final Future<void> Function() onSignOut;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final effectiveToken =
          await _effectiveAccessToken() ?? widget.accessToken;
      // Kick off all background services after first frame
      await Future.wait([
        ref
            .read(unreadCountsProvider.notifier)
            .refresh(baseUrl: widget.serverUrl, accessToken: effectiveToken),
        ref
            .read(stickerControllerProvider.notifier)
            .sync(baseUrl: widget.serverUrl, accessToken: effectiveToken),
        ref
            .read(notificationControllerProvider.notifier)
            .initialize(baseUrl: widget.serverUrl, accessToken: effectiveToken),
        _realtimeSyncNotifier.connect(
          baseUrl: widget.serverUrl,
          accessTokenProvider: _effectiveAccessToken,
          currentUserId: widget.currentUserId,
        ),
      ]);
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
      _realtimeSyncNotifier.connect(
        baseUrl: widget.serverUrl,
        accessTokenProvider: _effectiveAccessToken,
        currentUserId: widget.currentUserId,
      );
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

  void _onTabTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
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
        },
      ),
      ChatsTab(
        serverUrl: widget.serverUrl,
        accessToken: widget.accessToken,
        currentUserId: widget.currentUserId,
        initialPartnerId: _activePartnerId,
        onPartnerChanged: (id) => setState(() => _activePartnerId = id),
      ),
      SettingsTab(
        serverUrl: widget.serverUrl,
        planetInfo: widget.planetInfo,
        currentUserId: widget.currentUserId,
        activePartnerId: _activePartnerId,
        onSignOut: widget.onSignOut,
      ),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const mujiPaper = Color(0xFFFAF9F6);
    const mujiPaperDk = Color(0xFF1E1C19);
    const mujiInk = Color(0xFF2C2A27);
    const mujiInkDk = Color(0xFFE8E4DC);
    const mujiMuted = Color(0xFF8A8680);
    const mujiRule = Color(0xFFDDD8CF);
    const mujiRuleDk = Color(0xFF3A3730);
    final bgColor = isDark ? mujiPaperDk : mujiPaper;
    final inkColor = isDark ? mujiInkDk : mujiInk;
    final ruleColor = isDark ? mujiRuleDk : mujiRule;

    const tabIcons = [
      Icons.home_outlined,
      Icons.chat_bubble_outline,
      Icons.settings_outlined,
    ];
    const tabLabels = ['home', 'chats', 'settings'];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: hideTabs
          ? null
          : Container(
              color: bgColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(height: 1, thickness: 1, color: ruleColor),
                  SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: List.generate(tabIcons.length, (i) {
                          final selected = _selectedIndex == i;
                          final isChats = i == 1;
                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _onTabTapped(i),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (selected)
                                      Icon(
                                        tabIcons[i],
                                        size: 19,
                                        color: inkColor,
                                      )
                                    else
                                      Text(
                                        tabLabels[i],
                                        style: const TextStyle(
                                          fontSize: 12,
                                          letterSpacing: 0.2,
                                          fontWeight: FontWeight.w300,
                                          color: mujiMuted,
                                        ),
                                      ),
                                    if (isChats && totalUnread > 0) ...[
                                      const SizedBox(width: 5),
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF9B3A2A),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
