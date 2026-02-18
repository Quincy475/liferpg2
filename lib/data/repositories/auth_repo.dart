import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  const AuthRepository(this._auth);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<UserCredential> signInAnonymously() => _auth.signInAnonymously();

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> linkAnonymousWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('No current user');
    final credential = EmailAuthProvider.credential(email: email, password: password);
    return u.linkWithCredential(credential);
  }

  Future<void> linkWithCredential(AuthCredential credential) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('No current user');
    await u.linkWithCredential(credential);
  }

  Future<void> signOut() => _auth.signOut();
}
