import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chats/room_detail_page.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/models/chat_room.dart';
import 'package:mobile/services/local_chat_repository.dart';
import 'package:mobile/services/remote_chat_service.dart';
import 'package:mobile/state/app_controller.dart';
import 'package:mobile/state/conversation_messages_controller.dart';
import 'package:mobile/state/user_profile_controller.dart';

class _FakeAppController extends AppController {
  @override
  Future<AppState> build() async {
    return const AppState(
      serverUrl: 'https://example.com',
      accessToken: 'token',
      currentUserId: 'owner-id',
      currentUsername: 'owner',
      savedUserId: 'owner-id',
      connectionStatus: ConnectionStatus.idle,
      connectionError: null,
      planetInfo: null,
      isSubmitting: false,
      authError: null,
    );
  }

  @override
  Future<String?> ensureFreshAccessToken() async => 'token';
}

class _FakeRemoteChatService extends RemoteChatService {
  _FakeRemoteChatService(this.detail) : super();

  RoomDetail detail;
  int leaveRoomCallCount = 0;
  int deleteRoomCallCount = 0;
  int renameRoomCallCount = 0;

  @override
  Future<RoomDetail> getRoom({
    required String baseUrl,
    required String accessToken,
    required String roomId,
  }) async {
    return detail;
  }

  @override
  Future<List<ChatRoom>> listRooms({
    required String baseUrl,
    required String accessToken,
  }) async {
    return [
      ChatRoom(
        id: detail.id,
        name: detail.name,
        memberCount: detail.memberCount,
        unreadCount: 0,
        createdAt: detail.createdAt,
        updatedAt: detail.updatedAt,
      ),
    ];
  }

  @override
  Future<void> leaveRoom({
    required String baseUrl,
    required String accessToken,
    required String roomId,
  }) async {
    leaveRoomCallCount += 1;
  }

  @override
  Future<void> deleteRoom({
    required String baseUrl,
    required String accessToken,
    required String roomId,
  }) async {
    deleteRoomCallCount += 1;
  }

  @override
  Future<RoomDetail> renameRoom({
    required String baseUrl,
    required String accessToken,
    required String roomId,
    required String name,
  }) async {
    renameRoomCallCount += 1;
    detail = RoomDetail(
      id: detail.id,
      name: name.trim(),
      createdBy: detail.createdBy,
      memberCount: detail.memberCount,
      createdAt: detail.createdAt,
      updatedAt: DateTime.utc(2026, 3, 13, 12, 0),
      members: detail.members,
    );
    return detail;
  }
}

RoomDetail _buildRoomDetail() {
  return RoomDetail(
    id: 'room-1',
    name: 'Focus Room',
    createdBy: 'owner-id',
    memberCount: 2,
    createdAt: DateTime.utc(2026, 3, 12, 10, 0),
    updatedAt: DateTime.utc(2026, 3, 12, 10, 0),
    members: [
      RoomMemberProfile(
        userId: 'owner-id',
        username: 'Owner',
        role: 'owner',
        joinedAt: DateTime.utc(2026, 3, 12, 10, 0),
      ),
      RoomMemberProfile(
        userId: 'member-id',
        username: 'Member',
        role: 'member',
        joinedAt: DateTime.utc(2026, 3, 12, 10, 1),
      ),
    ],
  );
}

void main() {
  testWidgets('creator sees Remove this room action in the app bar', (
    tester,
  ) async {
    final remote = _FakeRemoteChatService(_buildRoomDetail());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith(_FakeAppController.new),
          remoteChatServiceProvider.overrideWithValue(remote),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RoomDetailPage(
            serverUrl: 'https://example.com',
            roomId: 'room-1',
            currentUserId: 'owner-id',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final appBar = find.byType(AppBar);
    final bodyList = find.byType(ListView);
    final removeLabel = find.text('REMOVE THIS ROOM');

    expect(find.descendant(of: appBar, matching: removeLabel), findsOneWidget);
    expect(find.descendant(of: bodyList, matching: removeLabel), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    final openChatLabel = find.text('OPEN CHAT');
    final leaveRoomLabel = find.text('LEAVE THIS ROOM');
    expect(openChatLabel, findsOneWidget);
    expect(leaveRoomLabel, findsOneWidget);

    final openChatCenter = tester.getCenter(openChatLabel);
    final leaveRoomCenter = tester.getCenter(leaveRoomLabel);
    expect((openChatCenter.dy - leaveRoomCenter.dy).abs(), lessThan(1));
    expect(openChatCenter.dx, lessThan(leaveRoomCenter.dx));
  });

  testWidgets('leave room asks for confirmation before leaving', (
    tester,
  ) async {
    final remote = _FakeRemoteChatService(_buildRoomDetail());
    Future<RoomDetailAction?>? resultFuture;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith(_FakeAppController.new),
          chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
          remoteChatServiceProvider.overrideWithValue(remote),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    resultFuture = Navigator.of(context).push<RoomDetailAction>(
                      MaterialPageRoute(
                        builder: (_) => const RoomDetailPage(
                          serverUrl: 'https://example.com',
                          roomId: 'room-1',
                          currentUserId: 'owner-id',
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(RoomDetailPage), findsOneWidget);

    await tester.tap(find.text('LEAVE THIS ROOM'));
    await tester.pumpAndSettle();

    expect(find.text('LEAVE ROOM'), findsOneWidget);
    expect(find.text('Leave Focus Room?'), findsOneWidget);
    expect(remote.leaveRoomCallCount, 0);

    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(RoomDetailPage), findsOneWidget);
    expect(find.text('LEAVE ROOM'), findsNothing);
    expect(remote.leaveRoomCallCount, 0);

    await tester.tap(find.text('LEAVE THIS ROOM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('L E A V E'));
    await tester.pumpAndSettle();

    expect(remote.leaveRoomCallCount, 1);
    expect(await resultFuture, RoomDetailAction.left);
    expect(find.byType(RoomDetailPage), findsNothing);
  });

  testWidgets('remove room asks for confirmation before deleting', (
    tester,
  ) async {
    final remote = _FakeRemoteChatService(_buildRoomDetail());
    Future<RoomDetailAction?>? resultFuture;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith(_FakeAppController.new),
          chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
          remoteChatServiceProvider.overrideWithValue(remote),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    resultFuture = Navigator.of(context).push<RoomDetailAction>(
                      MaterialPageRoute(
                        builder: (_) => const RoomDetailPage(
                          serverUrl: 'https://example.com',
                          roomId: 'room-1',
                          currentUserId: 'owner-id',
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('REMOVE THIS ROOM'));
    await tester.pumpAndSettle();

    expect(find.text('REMOVE ROOM'), findsOneWidget);
    expect(find.text('Remove Focus Room?'), findsOneWidget);
    expect(remote.deleteRoomCallCount, 0);

    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(RoomDetailPage), findsOneWidget);
    expect(find.text('REMOVE ROOM'), findsNothing);
    expect(remote.deleteRoomCallCount, 0);

    await tester.tap(find.text('REMOVE THIS ROOM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('R E M O V E'));
    await tester.pumpAndSettle();

    expect(remote.deleteRoomCallCount, 1);
    expect(await resultFuture, RoomDetailAction.deleted);
    expect(find.byType(RoomDetailPage), findsNothing);
  });

  testWidgets('invite button shows app dialog when no friends can be invited', (
    tester,
  ) async {
    final remote = _FakeRemoteChatService(_buildRoomDetail());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith(_FakeAppController.new),
          remoteChatServiceProvider.overrideWithValue(remote),
          friendIdsProvider.overrideWith((ref) async => const <String>[]),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RoomDetailPage(
            serverUrl: 'https://example.com',
            roomId: 'room-1',
            currentUserId: 'owner-id',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add_alt_1_rounded));
    await tester.pumpAndSettle();

    expect(find.text('INVITE'), findsOneWidget);
    expect(find.text('No friends available to invite.'), findsOneWidget);

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(find.byType(RoomDetailPage), findsOneWidget);
    expect(find.text('No friends available to invite.'), findsNothing);
  });

  testWidgets('owner can rename room from the detail page', (tester) async {
    final remote = _FakeRemoteChatService(_buildRoomDetail());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith(_FakeAppController.new),
          chatRepositoryProvider.overrideWithValue(InMemoryChatRepository()),
          remoteChatServiceProvider.overrideWithValue(remote),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RoomDetailPage(
            serverUrl: 'https://example.com',
            roomId: 'room-1',
            currentUserId: 'owner-id',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('EDIT ROOM'), findsOneWidget);
    expect(find.text('Change room name'), findsOneWidget);

    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    await tester.enterText(field, 'Renamed Focus Room');
    await tester.pump();

    await tester.tap(find.text('S A V E'));
    await tester.pumpAndSettle();

    expect(remote.renameRoomCallCount, 1);
    expect(find.text('Renamed Focus Room'), findsOneWidget);
    expect(find.text('Focus Room'), findsNothing);
    expect(find.text('Room name updated.'), findsOneWidget);
  });
}
