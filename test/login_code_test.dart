import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:household_rpg/core/login_code.dart';

void main() {
  test('token roundtrip behoudt e-mail en geheim', () {
    final secret = generateLoginSecret();
    final token = encodeLoginToken('quincy+test@example.com', secret);
    final decoded = decodeLoginToken(token);
    expect(decoded, isNotNull);
    expect(decoded!.email, 'quincy+test@example.com');
    expect(decoded.secret, secret);
  });

  test('witruimte en regeleindes (plakken) worden genegeerd', () {
    final token = encodeLoginToken('a@b.nl', 'ABCDEFGH');
    final decoded = decodeLoginToken('  ${token.substring(0, 5)}\n${token.substring(5)} ');
    expect(decoded?.email, 'a@b.nl');
    expect(decoded?.secret, 'ABCDEFGH');
  });

  test('ongeldige tokens geven null', () {
    expect(decodeLoginToken(''), isNull);
    expect(decodeLoginToken('geenpunt'), isNull);
    expect(decodeLoginToken('a.b.c'), isNull);
    expect(decodeLoginToken('!!!.SECRET'), isNull);
    // geldige base64 maar geen e-mail
    expect(decodeLoginToken('aGVsbG8.SECRET'), isNull);
  });

  test('geheim: lengte, alfabet en variatie', () {
    final a = generateLoginSecret(random: Random(1));
    final b = generateLoginSecret(random: Random(2));
    expect(a.length, 20);
    expect(RegExp(r'^[A-HJ-NP-Z2-9]+$').hasMatch(a), isTrue);
    expect(a, isNot(b));
  });

  test('synthetisch e-mailadres is geldig en klein geschreven', () {
    final e = syntheticLoginEmail();
    expect(e, endsWith('@$loginCodeEmailDomain'));
    expect(e, e.toLowerCase());
    expect(decodeLoginToken(encodeLoginToken(e, 'X'))?.email, e);
  });
}
