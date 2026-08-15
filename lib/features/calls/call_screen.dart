import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../ui/tokens/colors/app_palette.dart';
import 'call_controller.dart';
import 'call_models.dart';
import 'webrtc_call_service.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen>
    with SingleTickerProviderStateMixin {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
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
    _pulseController.dispose();
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        ref.read(callControllerProvider.notifier).hangup();
        Navigator.of(context).pop();
      },
      child: Scaffold(
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

          // Ringing/connecting indicator in the centre of the screen.
          if (callInfo.phase != CallPhase.active)
            Positioned.fill(
              child: Center(
                child: _CallingPulse(
                  controller: _pulseController,
                  isVideo: isVideo,
                ),
              ),
            ),

          // Once connected, show that audio is actually flowing each way.
          // Sits above the controls so it never covers the remote video.
          if (callInfo.phase == CallPhase.active)
            Positioned(
              left: 32,
              right: 32,
              bottom: 150,
              child: _VoiceBars(peerName: callInfo.peerDisplayName),
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

/// Expanding rings shown while the call is still being established, so the
/// screen doesn't look frozen between dialling and connecting.
class _CallingPulse extends StatelessWidget {
  const _CallingPulse({required this.controller, required this.isVideo});

  final AnimationController controller;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Three rings, evenly offset in the cycle, each fading as it grows.
              for (var i = 0; i < 3; i++)
                _pulseRing((controller.value + i / 3) % 1.0),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFF333333),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVideo ? Icons.videocam : Icons.call,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pulseRing(double t) {
    final size = 64.0 + (160.0 - 64.0) * t;
    return Opacity(
      opacity: (1.0 - t) * 0.45,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }
}

/// Live level meters for the microphone and the incoming audio.
///
/// These double as the quickest way to tell where audio has broken: if the
/// "You" bar moves while you speak but the peer's never does, media isn't
/// arriving or isn't decoding; if the peer's bar moves and you still hear
/// nothing, capture and transport are fine and the problem is playback.
class _VoiceBars extends ConsumerWidget {
  const _VoiceBars({required this.peerName});

  final String peerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels =
        ref.watch(callAudioLevelsProvider).valueOrNull ??
        const CallAudioLevels();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LevelBar(label: 'You', level: levels.local),
        const SizedBox(height: 10),
        _LevelBar(label: peerName, level: levels.remote),
      ],
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.label, required this.level});

  final String label;
  final double level;

  @override
  Widget build(BuildContext context) {
    // Speech sits low in the 0..1 range, so square-root it to make normal
    // talking fill a useful part of the bar instead of a sliver.
    final filled = math.sqrt(level.clamp(0.0, 1.0));

    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(height: 6, color: Colors.white24),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 120),
                  widthFactor: filled,
                  alignment: Alignment.centerLeft,
                  child: Container(height: 6, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
