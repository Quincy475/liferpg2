import 'package:firebase_auth/firebase_auth.dart';
import 'package:household_rpg/core/login_code.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  const AuthRepository(this._auth);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Of de huidige user een anoniem account is (geen e-mail gekoppeld).
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  Future<void> signOut() => _auth.signOut();

  /// Maak direct een anoniem account aan (geen inlogscherm nodig).
  Future<UserCredential> signInAnonymously() => _auth.signInAnonymously();

  /// Koppel een e-mail/wachtwoord aan het bestaande (anonieme) account.
  /// Behoudt dezelfde uid, dus alle voortgang blijft staan.
  Future<UserCredential> linkEmailPassword({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Geen actieve sessie om een e-mail aan te koppelen.');
    }
    final cred = EmailAuthProvider.credential(email: email.trim(), password: password);
    return user.linkWithCredential(cred);
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Maakt een inlogcode die het wachtwoord vervangt en geeft de code terug.
  /// Anoniem account: koppelt een intern e-mailadres (zelfde uid, voortgang blijft).
  /// Account met e-mail: het wachtwoord wordt het geheim uit de code.
  /// Een eerdere inlogcode vervalt. Kan `requires-recent-login` gooien.
  Future<String> createLoginCode() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Geen actieve sessie om een inlogcode voor te maken.');
    }
    final secret = generateLoginSecret();

    if (user.isAnonymous) {
      for (var attempt = 0; attempt < 5; attempt++) {
        final email = syntheticLoginEmail();
        try {
          await user.linkWithCredential(
            EmailAuthProvider.credential(email: email, password: secret),
          );
          return encodeLoginToken(email, secret);
        } on FirebaseAuthException catch (e) {
          if (e.code != 'email-already-in-use') rethrow;
        }
      }
      throw StateError('Kon geen unieke inlogcode maken. Probeer opnieuw.');
    }

    final email = user.email;
    if (email == null) {
      throw StateError('Dit account heeft geen e-mailadres; een inlogcode is niet mogelijk.');
    }
    await user.updatePassword(secret);
    return encodeLoginToken(email, secret);
  }

  /// Inloggen met een inlogcode (zie [createLoginCode]).
  Future<UserCredential> signInWithLoginCode(String token) {
    final decoded = decodeLoginToken(token);
    if (decoded == null) {
      throw FirebaseAuthException(code: 'invalid-login-code', message: 'Ongeldige inlogcode.');
    }
    return _auth.signInWithEmailAndPassword(email: decoded.email, password: decoded.secret);
  }

  /// Opnieuw bevestigen met het huidige wachtwoord (nodig bij `requires-recent-login`).
  Future<void> reauthenticateWithPassword(String password) {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('Geen account met e-mail om opnieuw mee te bevestigen.');
    }
    return user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> updateDisplayName({required String name}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user to update name for.');
    }
    await user.updateDisplayName(name.trim());
    await user.reload();
  }
}
