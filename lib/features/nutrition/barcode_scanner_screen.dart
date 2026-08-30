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
  double _zoom = 0;

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
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'כוון את המצלמה לברקוד על גבי האריזה',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.zoom_out, color: Colors.white, size: 20),
                      Expanded(
                        child: Slider(
                          value: _zoom,
                          onChanged: (v) {
                            setState(() => _zoom = v);
                            _controller.setZoomScale(v);
                          },
                        ),
                      ),
                      const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
