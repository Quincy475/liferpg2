import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  const AuthRepository(this._auth);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<User> ensureSignedInAnonymously() async {
    final cur = _auth.currentUser;
    if (cur != null) return cur;
    final cred = await _auth.signInAnonymously();
    return cred.user!;
  }

  // Later kun je hiermee upgraden (linken) naar Google/Apple
  Future<void> linkWithCredential(AuthCredential credential) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('No current user');
    await u.linkWithCredential(credential);
  }

  Future<void> signOut() => _auth.signOut();
}
