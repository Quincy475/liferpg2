import 'dart:convert';
import 'dart:math';

/// Inlogcode: een lang willekeurig geheim dat het wachtwoord van het account
/// vervangt. De code bevat ook het inlog-e-mailadres (base64url), zodat je op
/// een ander toestel alleen de code hoeft in te vullen.
///
/// Formaat: `<base64url(email)>.<geheim>` — de '.' komt niet voor in beide delen.

// 32 tekens, zonder 0/O en 1/I zodat overtypen minder fout gaat.
const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

const loginCodeEmailDomain = 'code.liferpg.app';

String _randomString(int length, Random random) =>
    List.generate(length, (_) => _alphabet[random.nextInt(_alphabet.length)]).join();

/// Geheim van 20 tekens (~100 bit), gebruikt als wachtwoord.
String generateLoginSecret({Random? random}) => _randomString(20, random ?? Random.secure());

/// Intern e-mailadres voor anonieme accounts die nog geen echte e-mail hebben.
String syntheticLoginEmail({Random? random}) =>
    '${_randomString(12, random ?? Random.secure()).toLowerCase()}@$loginCodeEmailDomain';

String encodeLoginToken(String email, String secret) {
  final encoded = base64Url.encode(utf8.encode(email)).replaceAll('=', '');
  return '$encoded.$secret';
}

/// Geeft null als de tekst geen geldige inlogcode is.
({String email, String secret})? decodeLoginToken(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'\s+'), '');
  final parts = cleaned.split('.');
  if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) return null;

  final padded = parts[0] + '=' * ((4 - parts[0].length % 4) % 4);
  final String email;
  try {
    email = utf8.decode(base64Url.decode(padded));
  } on FormatException {
    return null;
  }
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return null;
  return (email: email, secret: parts[1]);
}
