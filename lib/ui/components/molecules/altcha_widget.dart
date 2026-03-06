import 'package:flutter/material.dart';
import '../../tokens/colors/app_palette.dart';

/// A self-contained ALTCHA proof-of-work widget.
///
/// On construction the widget immediately invokes [solver], which should
/// fetch a challenge from the server (using the dev-aware HTTP client) and
/// solve the proof-of-work puzzle in a background isolate.  Visual states:
///
/// * **solving** — shows a compact indeterminate progress bar
/// * **verified** — shows a checkmark row (similar to the JS widget)
/// * **error**   — shows a retry link
///
/// [onResponse] is called with the base64-encoded payload once verified, or
/// with `null` when ALTCHA is disabled on the server (caller should proceed
/// without a payload).
class AltchaWidget extends StatefulWidget {
  const AltchaWidget({
    super.key,
    required this.solver,
    required this.onResponse,
  });

  /// Fetches and solves the ALTCHA challenge.  Use [AuthService] +
  /// [solveAltchaChallenge] so the HTTP call goes through the dev-aware
  /// client (TLS bypass, emulator IP fallbacks).
  final Future<String?> Function() solver;
  final void Function(String? payload) onResponse;

  @override
  State<AltchaWidget> createState() => _AltchaWidgetState();
}

class _AltchaWidgetState extends State<AltchaWidget> {
  _Status _status = _Status.solving;

  @override
  void initState() {
    super.initState();
    _solve();
  }

  Future<void> _solve() async {
    setState(() => _status = _Status.solving);
    try {
      final payload = await widget.solver();
      if (!mounted) return;
      if (payload == null) {
        // ALTCHA disabled on this server — call back immediately so the form
        // does not stay locked.
        widget.onResponse(null);
        // Don't render anything — widget becomes invisible.
        setState(() => _status = _Status.disabled);
      } else {
        setState(() => _status = _Status.verified);
        widget.onResponse(payload);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _Status.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppPalette.neutral700 : AppPalette.neutral300;
    final textColor = isDark ? AppPalette.neutral300 : AppPalette.neutral700;
    final mutedColor = AppPalette.neutral500;

    if (_status == _Status.disabled) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: switch (_status) {
        _Status.solving => Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: mutedColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Verifying you\'re human…',
                style: TextStyle(fontSize: 13, color: mutedColor),
              ),
            ],
          ),
        _Status.verified => Row(
            children: [
              Icon(Icons.check_circle_outline, size: 18, color: textColor),
              const SizedBox(width: 12),
              Text(
                'Verified',
                style: TextStyle(fontSize: 13, color: textColor),
              ),
              const Spacer(),
              Text(
                'Protected by ALTCHA',
                style: TextStyle(
                  fontSize: 10,
                  color: mutedColor,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        _Status.error => Row(
            children: [
              const Icon(Icons.error_outline, size: 18, color: AppPalette.danger700),
              const SizedBox(width: 12),
              Text(
                'Verification failed. ',
                style: const TextStyle(fontSize: 13, color: AppPalette.danger700),
              ),
              GestureDetector(
                onTap: _solve,
                child: Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        _Status.disabled => const SizedBox.shrink(),
      },
    );
  }
}

enum _Status { solving, verified, error, disabled }
