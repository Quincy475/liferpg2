import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Payload-prefix voor de koppel-QR (deeplink-stijl, met kale code als inhoud).
const _coupleScheme = 'huishoudenrpg://couple?code=';

String coupleQrPayload(String code) => '$_coupleScheme${code.toUpperCase()}';

/// Toon een QR-code met de koppelcode (om door de partner te laten scannen
/// met een gewone camera-/QR-app; handmatig overtypen kan ook altijd).
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
