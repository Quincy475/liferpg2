import 'package:firebase_auth/firebase_auth.dart';

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
