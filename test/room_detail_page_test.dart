import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chats/room_detail_page.dart';
import 'package:mobile/models/chat_room.dart';
import 'package:mobile/services/remote_chat_service.dart';
import 'package:mobile/state/app_controller.dart';
import 'package:mobile/state/conversation_messages_controller.dart';

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

  final RoomDetail detail;

  @override
  Future<RoomDetail> getRoom({
    required String baseUrl,
    required String accessToken,
    required String roomId,
  }) async {
    return detail;
  }
}

void main() {
  testWidgets('creator sees Remove this room action in the app bar', (
    tester,
  ) async {
    final remote = _FakeRemoteChatService(
      RoomDetail(
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
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith(_FakeAppController.new),
          remoteChatServiceProvider.overrideWithValue(remote),
        ],
        child: const MaterialApp(
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
    final openChatLabel = find.text('OPEN CHAT');
    final leaveRoomLabel = find.text('LEAVE THIS ROOM');
    expect(openChatLabel, findsOneWidget);
    expect(leaveRoomLabel, findsOneWidget);

    final openChatCenter = tester.getCenter(openChatLabel);
    final leaveRoomCenter = tester.getCenter(leaveRoomLabel);
    expect((openChatCenter.dy - leaveRoomCenter.dy).abs(), lessThan(1));
    expect(openChatCenter.dx, lessThan(leaveRoomCenter.dx));
  });
}
