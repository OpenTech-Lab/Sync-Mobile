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

class _DeviceLoginQrScannerPageState extends State<DeviceLoginQrScannerPage> {
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
            const _ScanOverlay(),
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
            SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 56),
                  child: Text(
                    l10n.profileDeviceLoginScanHint,
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
    const frameSize = 220.0;
    const strokeWidth = 1.0;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameSize,
      height: frameSize,
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = AppPalette.dimOverlay);

    canvas.drawRect(
      rect,
      Paint()
        ..color = AppPalette.neutral300
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
