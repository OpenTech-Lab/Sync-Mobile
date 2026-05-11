import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/tokens/colors/app_palette.dart';
import 'call_controller.dart';
import 'call_models.dart';
import 'call_screen.dart';

class IncomingCallScreen extends ConsumerWidget {
  const IncomingCallScreen({super.key, required this.callInfo});

  final CallInfo callInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If the call was cancelled/rejected while this screen is open, pop.
    ref.listen<AsyncValue<CallInfo?>>(callControllerProvider, (_, next) {
      if (next.valueOrNull == null && context.mounted) {
        Navigator.of(context).pop();
      }
    });

    final isVideo = callInfo.callType == CallType.video;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(
              isVideo ? 'Incoming video call' : 'Incoming voice call',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              callInfo.peerDisplayName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w300,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 64),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline
                  _CallAction(
                    icon: Icons.call_end,
                    color: AppPalette.danger700,
                    label: 'Decline',
                    onTap: () {
                      ref.read(callControllerProvider.notifier).rejectCall();
                      // ref.listen above pops this screen when state → null
                    },
                  ),

                  // Accept
                  _CallAction(
                    icon: Icons.call,
                    color: const Color(0xFF2E7D32),
                    label: 'Accept',
                    onTap: () async {
                      await ref
                          .read(callControllerProvider.notifier)
                          .acceptCall();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => const CallScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallAction extends StatelessWidget {
  const _CallAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}
