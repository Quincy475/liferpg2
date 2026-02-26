import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  const AuthRepository(this._auth);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signOut() => _auth.signOut();

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
