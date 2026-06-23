import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  String? _phoneVerificationId;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException error) onFailed,
    void Function(UserCredential credential)? onAutoVerified,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      verificationCompleted: (PhoneAuthCredential credential) async {
        final result = await _auth.signInWithCredential(credential);
        onAutoVerified?.call(result);
      },
      verificationFailed: onFailed,
      codeSent: (verificationId, _) {
        _phoneVerificationId = verificationId;
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _phoneVerificationId = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<UserCredential> verifyOtp(String smsCode) async {
    final id = _phoneVerificationId;
    if (id == null) {
      throw FirebaseAuthException(
        code: 'no-verification-in-progress',
        message: 'No phone verification in progress. Request a code first.',
      );
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: id,
      smsCode: smsCode.trim(),
    );
    return _auth.signInWithCredential(credential);
  }

  /// Throws [FirebaseAuthException] (`invalid-email`, `user-not-found`,
  /// `too-many-requests`) that the UI translates into a friendly
  /// message.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();
}
