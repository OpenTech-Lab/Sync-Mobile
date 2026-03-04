import 'package:flutter/material.dart';
import 'package:mobile/l10n/app_localizations.dart';
import '../../ui/tokens/colors/app_palette.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/friend_qr_payload.dart';

class FriendQrScannerScreen extends StatefulWidget {
  const FriendQrScannerScreen({super.key});

  @override
  State<FriendQrScannerScreen> createState() => _FriendQrScannerScreenState();
}

class _FriendQrScannerScreenState extends State<FriendQrScannerScreen> {
  bool _resolved = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkColor = isDark ? AppPalette.neutral100 : AppPalette.neutral800;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppPalette.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── live camera feed ──────────────────────────────────────────
            MobileScanner(
              onDetect: (capture) {
                if (_resolved) return;
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw == null) continue;
                  final parsed = FriendQrPayload.tryParse(raw);
                  if (parsed == null) continue;
                  _resolved = true;
                  Navigator.of(context).pop(parsed);
                  return;
                }
              },
            ),

            // ── Minimal scan overlay ─────────────────────────────────────────
            const _ScanOverlay(),

            // ── top bar ───────────────────────────────────────────────────
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Text(
                      l10n.actionBack,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        color: inkColor.withValues(alpha: 0.75),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── bottom label ──────────────────────────────────────────────
            SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 56),
                  child: Text(
                    l10n.chatScanFriendQrInstruction,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: AppPalette.neutral500,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// —————————————————————————————————————————————————————
// Scan overlay — darkens outside the target square
// —————————————————————————————————————————————————————

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _OverlayPainter());
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dimColor = AppPalette.dimOverlay;
    const frameSize = 220.0;
    const strokeWidth = 1.0;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: frameSize,
      height: frameSize,
    );

    // dimmed surround
    final dimPaint = Paint()..color = dimColor;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, dimPaint);

    // hairline frame
    final linePaint = Paint()
      ..color = AppPalette.neutral300
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRect(rect, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
