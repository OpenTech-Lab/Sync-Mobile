import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../ui/tokens/colors/app_palette.dart';
import 'call_controller.dart';
import 'call_models.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (mounted) setState(() => _renderersReady = true);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callInfo = ref.watch(callControllerProvider).value;

    if (callInfo == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return const Scaffold(backgroundColor: Colors.black);
    }

    if (!_renderersReady) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    // Assign renderer sources from the current call state on every build
    // (not just via a change listener) — an incoming call's streams may
    // already exist by the time this screen first opens.
    if (callInfo.localStream != null) {
      _localRenderer.srcObject = callInfo.localStream;
    }
    if (callInfo.remoteStream != null) {
      _remoteRenderer.srcObject = callInfo.remoteStream;
    }

    final isVideo = callInfo.callType == CallType.video;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen) or dark background
          if (isVideo && callInfo.remoteStream != null)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            const Positioned.fill(
              child: ColoredBox(color: Color(0xFF1A1A1A)),
            ),

          // Peer name + status
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  callInfo.peerDisplayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _phaseLabel(callInfo.phase),
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),

          // Local video PiP (top-right, video calls only)
          if (isVideo && callInfo.localStream != null)
            Positioned(
              top: 60,
              right: 16,
              width: 100,
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: RTCVideoView(
                  _localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),

          // Controls
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ControlButton(
                  icon: callInfo.isMuted ? Icons.mic_off : Icons.mic,
                  onTap: () =>
                      ref.read(callControllerProvider.notifier).toggleMute(),
                ),
                const SizedBox(width: 24),
                _ControlButton(
                  icon: callInfo.isSpeakerOn
                      ? Icons.volume_up
                      : Icons.volume_down,
                  onTap: () =>
                      ref.read(callControllerProvider.notifier).toggleSpeaker(),
                ),
                const SizedBox(width: 24),
                _HangupButton(
                  onTap: () =>
                      ref.read(callControllerProvider.notifier).hangup(),
                ),
                if (isVideo) ...[
                  const SizedBox(width: 24),
                  _ControlButton(
                    icon: callInfo.isCameraOff
                        ? Icons.videocam_off
                        : Icons.videocam,
                    onTap: () => ref
                        .read(callControllerProvider.notifier)
                        .toggleCamera(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _phaseLabel(CallPhase phase) {
    return switch (phase) {
      CallPhase.calling => 'Calling...',
      CallPhase.ringing => 'Ringing...',
      CallPhase.connecting => 'Connecting...',
      CallPhase.active => 'Active',
      _ => '',
    };
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Color(0xFF333333),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}

class _HangupButton extends StatelessWidget {
  const _HangupButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: AppPalette.danger700,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.call_end, color: Colors.white, size: 30),
      ),
    );
  }
}
