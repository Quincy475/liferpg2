import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Payload-prefix voor de koppel-QR (deeplink-stijl, met kale code als inhoud).
const _coupleScheme = 'huishoudenrpg://couple?code=';

String coupleQrPayload(String code) => '$_coupleScheme${code.toUpperCase()}';

/// Haal de koppelcode uit een gescande QR-waarde (deeplink of kale code).
String parseCoupleCode(String raw) {
  final value = raw.trim();
  final idx = value.indexOf('code=');
  if (idx >= 0) {
    return value.substring(idx + 'code='.length).toUpperCase();
  }
  return value.toUpperCase();
}

/// Toon een QR-code met de koppelcode (om door de partner te laten scannen).
Future<void> showCoupleQrDialog(BuildContext context, String code) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Laat je partner scannen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: QrImageView(
              data: coupleQrPayload(code),
              size: 220,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            code.toUpperCase(),
            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(letterSpacing: 3),
          ),
        ],
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Klaar')),
      ],
    ),
  );
}

/// Open de camera en geef de gescande koppelcode terug (of null bij annuleren).
Future<String?> scanCoupleCode(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const _CoupleScannerPage()),
  );
}

class _CoupleScannerPage extends StatefulWidget {
  const _CoupleScannerPage();

  @override
  State<_CoupleScannerPage> createState() => _CoupleScannerPageState();
}

class _CoupleScannerPageState extends State<_CoupleScannerPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan koppelcode')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          for (final barcode in capture.barcodes) {
            final raw = barcode.rawValue;
            if (raw == null || raw.isEmpty) continue;
            _handled = true;
            Navigator.of(context).pop(parseCoupleCode(raw));
            return;
          }
        },
      ),
    );
  }
}
