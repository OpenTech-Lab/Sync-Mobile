import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/qr_login_payload.dart';
import '../../ui/tokens/colors/app_palette.dart';

class DeviceLoginQrScannerPage extends StatefulWidget {
  const DeviceLoginQrScannerPage({super.key});

  @override
  State<DeviceLoginQrScannerPage> createState() =>
      _DeviceLoginQrScannerPageState();
}

class _DeviceLoginQrScannerPageState extends State<DeviceLoginQrScannerPage>
    with SingleTickerProviderStateMixin {
  bool _resolved = false;
  late final AnimationController _beamController;
  late final Animation<double> _beamAnimation;

  @override
  void initState() {
    super.initState();
    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _beamAnimation = CurvedAnimation(
      parent: _beamController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _beamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
                  final parsed = QrLoginPayload.tryParse(raw);
                  if (parsed == null) continue;
                  _resolved = true;
                  Navigator.of(context).pop(parsed);
                  return;
                }
              },
            ),

            // ── animated scan overlay ─────────────────────────────────────
            AnimatedBuilder(
              animation: _beamAnimation,
              builder: (context, _) => CustomPaint(
                painter: _ScanOverlayPainter(
                  beamProgress: _beamAnimation.value,
                ),
              ),
            ),

            // ── top bar ───────────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      l10n.profileDeviceLoginPageTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── bottom instruction panel ──────────────────────────────────
            SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 18,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.devices_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.profileDeviceLoginScanHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                            letterSpacing: 0.2,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.profileDeviceLoginHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withValues(alpha: 0.55),
                            letterSpacing: 0.3,
                            height: 1.5,
                          ),
                        ),
                      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Overlay: dimmed surround + corner bracket markers + animated scan beam
// ─────────────────────────────────────────────────────────────────────────────

class _ScanOverlayPainter extends CustomPainter {
  const _ScanOverlayPainter({required this.beamProgress});

  final double beamProgress;

  static const double _frameSize = 240.0;
  static const double _cornerLen = 26.0;
  static const double _cornerRadius = 4.0;
  static const double _strokeWidth = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: _frameSize,
      height: _frameSize,
    );

    // — dimmed surround —
    final dimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(_cornerRadius)),
      )
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(dimPath, Paint()..color = const Color(0xBB000000));

    // — corner bracket marks —
    final bracketPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawCorner(canvas, bracketPaint, rect.topLeft, 1, 1);       // TL
    _drawCorner(canvas, bracketPaint, rect.topRight, -1, 1);     // TR
    _drawCorner(canvas, bracketPaint, rect.bottomRight, -1, -1); // BR
    _drawCorner(canvas, bracketPaint, rect.bottomLeft, 1, -1);   // BL

    // — animated scan beam —
    final beamY = rect.top + beamProgress * _frameSize;
    final beamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.65),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(rect)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(rect.left + 6, beamY),
      Offset(rect.right - 6, beamY),
      beamPaint,
    );
  }

  void _drawCorner(
    Canvas canvas,
    Paint paint,
    Offset corner,
    double dx,
    double dy,
  ) {
    final path = Path()
      ..moveTo(corner.dx + dx * _cornerLen, corner.dy)
      ..lineTo(corner.dx + dx * _cornerRadius, corner.dy)
      ..arcToPoint(
        Offset(corner.dx, corner.dy + dy * _cornerRadius),
        radius: const Radius.circular(_cornerRadius),
        clockwise: dx * dy < 0,
      )
      ..lineTo(corner.dx, corner.dy + dy * _cornerLen);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) =>
      old.beamProgress != beamProgress;
}
