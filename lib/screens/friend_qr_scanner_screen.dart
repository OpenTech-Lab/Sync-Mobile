import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/friend_qr_payload.dart';

class FriendQrScannerScreen extends StatefulWidget {
  const FriendQrScannerScreen({super.key});

  @override
  State<FriendQrScannerScreen> createState() => _FriendQrScannerScreenState();
}

class _FriendQrScannerScreenState extends State<FriendQrScannerScreen> {
  bool _resolved = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Friend QR')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_resolved) return;
          for (final barcode in capture.barcodes) {
            final raw = barcode.rawValue;
            if (raw == null) {
              continue;
            }
            final parsed = FriendQrPayload.tryParse(raw);
            if (parsed == null) {
              continue;
            }
            _resolved = true;
            Navigator.of(context).pop(parsed);
            return;
          }
        },
      ),
    );
  }
}
