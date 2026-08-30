import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen barcode scanner. Pops with the detected barcode string once
/// a code is found, or with null if the user backs out. Not exercised by
/// CI's headless widget tests -- there's no camera to feed it a frame, so
/// this screen is a thin shell around `MobileScanner` and the actual
/// lookup/prefill logic it hands off to lives in code that *is* unit-tested
/// (see OpenFoodFactsService, AppState.foodByBarcode).
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_handled) return;
    final detected = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim() ?? '')
        .firstWhere((code) => code.isNotEmpty, orElse: () => '');
    if (detected.isEmpty) return;
    _handled = true;
    Navigator.pop(context, detected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('סרוק ברקוד'),
        actions: [
          IconButton(
            tooltip: 'פנס',
            icon: const Icon(Icons.flash_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetection,
          ),
          // A fixed visual guide frame -- helps the user line the barcode up
          // and hold the phone at a distance where it's in focus, similar to
          // the framing native camera apps show. It's decorative only: does
          // not narrow what the scanner actually reads (mobile_scanner's
          // scanWindow, which would do that, isn't supported on Flutter Web
          // -- our primary target -- so wiring it would silently no-op there
          // the same way the zoom control just did).
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: const Text(
                'כוון את המצלמה כך שהברקוד ימלא את המסגרת',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
