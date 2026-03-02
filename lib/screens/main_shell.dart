import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    required this.onSignOut,
  });

  final String serverUrl;
  final String accessToken;
  final String currentUserId;
  final Future<void> Function() onSignOut;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;
  String? _activePartnerId;
  // Cache the notifier so we can call disconnect() in dispose() without
  // touching `ref` (which may already be invalid at that point).
  late RealtimeSyncController _realtimeSyncNotifier;

  @override
  void initState() {
    super.initState();
    _realtimeSyncNotifier = ref.read(realtimeSyncControllerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Kick off all background services after first frame
      await Future.wait([
        ref.read(unreadCountsProvider.notifier).refresh(
              baseUrl: widget.serverUrl,
              accessToken: widget.accessToken,
            ),
        ref.read(stickerControllerProvider.notifier).sync(
              baseUrl: widget.serverUrl,
              accessToken: widget.accessToken,
            ),
        ref.read(notificationControllerProvider.notifier).initialize(
              baseUrl: widget.serverUrl,
              accessToken: widget.accessToken,
            ),
        _realtimeSyncNotifier.connect(
              baseUrl: widget.serverUrl,
              accessToken: widget.accessToken,
              currentUserId: widget.currentUserId,
            ),
      ]);
    });
  }

  @override
  void dispose() {
    _realtimeSyncNotifier.disconnect();
    super.dispose();
  }

  void _onTabTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hideTabs = _selectedIndex == 1 && _activePartnerId != null;
    final unreadCounts =
        ref.watch(unreadCountsProvider).value ?? const <String, int>{};
    final totalUnread =
        unreadCounts.values.fold(0, (s, v) => s + v);

    final tabs = [
      HomeTab(
        serverUrl: widget.serverUrl,
        currentUserId: widget.currentUserId,
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
        onPartnerChanged: (id) => setState(() => _activePartnerId = id),
      ),
      SettingsTab(
        serverUrl: widget.serverUrl,
        currentUserId: widget.currentUserId,
        activePartnerId: _activePartnerId,
        onSignOut: widget.onSignOut,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: tabs,
      ),
      bottomNavigationBar: hideTabs
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onTabTapped,
              labelBehavior:
                  NavigationDestinationLabelBehavior.alwaysShow,
              height: 60,
              indicatorColor: cs.primaryContainer,
              backgroundColor: cs.surface,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined, size: 22),
                  selectedIcon: Icon(Icons.home, size: 22),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: totalUnread > 0,
                    label: Text(
                      totalUnread > 99 ? '99+' : '$totalUnread',
                      style: const TextStyle(fontSize: 9),
                    ),
                    child: const Icon(Icons.chat_bubble_outline, size: 22),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: totalUnread > 0,
                    label: Text(
                      totalUnread > 99 ? '99+' : '$totalUnread',
                      style: const TextStyle(fontSize: 9),
                    ),
                    child: const Icon(Icons.chat_bubble, size: 22),
                  ),
                  label: 'Chats',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.settings_outlined, size: 22),
                  selectedIcon: Icon(Icons.settings, size: 22),
                  label: 'Settings',
                ),
              ],
            ),
    );
  }
}
