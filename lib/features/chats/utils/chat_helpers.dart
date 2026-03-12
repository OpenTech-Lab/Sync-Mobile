import 'package:flutter/material.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../models/chat_room.dart';
import '../../../ui/tokens/colors/app_palette.dart';

const Duration chatPaneTransitionDuration = Duration(milliseconds: 260);
const Duration chatPaneTransitionReverseDuration = Duration(milliseconds: 220);
const double chatPaneBackGestureVelocityThreshold = 450;
const double chatPaneBackGestureDismissThreshold = 0.35;
const double chatPaneBackgroundParallaxFactor = 0.33;
const Curve chatPaneTransitionCurve = Curves.easeOutCubic;

double chatPaneBackgroundParallaxProgress(
  double transitionProgress, {
  required bool linearTransition,
}) {
  final clamped = transitionProgress.clamp(0.0, 1.0);
  final adjusted = linearTransition
      ? clamped
      : chatPaneTransitionCurve.transform(clamped);
  return adjusted * chatPaneBackgroundParallaxFactor;
}

bool shouldCompleteChatBackGesture({
  required double transitionProgress,
  required double velocity,
}) {
  final clamped = transitionProgress.clamp(0.0, 1.0);
  return velocity > chatPaneBackGestureVelocityThreshold ||
      clamped <= (1 - chatPaneBackGestureDismissThreshold);
}

bool isSameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

String dayLabel(BuildContext context, DateTime dt) {
  final local = dt.toLocal();
  final now = DateTime.now();
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return AppLocalizations.of(context)!.chatToday;
  }
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '${local.year}-$m-$d';
}

String displayNameOrFallback(String userId, String? displayName) {
  final normalized = (displayName ?? '').trim();
  if (normalized.isNotEmpty) return normalized;
  return userId.length >= 8 ? userId.substring(0, 8) : userId;
}

String timeLabel(DateTime dt) {
  final local = dt.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

bool friendMatchesSelectedTag({
  required Iterable<String> friendTags,
  required String? selectedFriendTag,
}) {
  final normalizedTag = selectedFriendTag?.trim().toLowerCase();
  if (normalizedTag == null || normalizedTag.isEmpty) {
    return true;
  }
  for (final tag in friendTags) {
    if (tag.trim().toLowerCase() == normalizedTag) {
      return true;
    }
  }
  return false;
}

bool conversationMatchesSelectedFriendTag({
  required String conversationId,
  required String? selectedFriendTag,
  required Map<String, List<String>> friendTagsById,
}) {
  final normalizedTag = selectedFriendTag?.trim();
  if (normalizedTag == null || normalizedTag.isEmpty) {
    return true;
  }
  if (isRoomConversationId(conversationId)) {
    return false;
  }
  return friendMatchesSelectedTag(
    friendTags: friendTagsById[conversationId] ?? const <String>[],
    selectedFriendTag: normalizedTag,
  );
}

class DayDivider extends StatelessWidget {
  const DayDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppPalette.neutral500.withValues(alpha: 0.22),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppPalette.neutral300,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppPalette.neutral500.withValues(alpha: 0.22),
          ),
        ),
      ],
    );
  }
}
