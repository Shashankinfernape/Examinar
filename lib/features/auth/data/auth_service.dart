import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  
  bool _initialized = false;

  AuthService(this._auth);

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await _googleSignIn.initialize();
      _initialized = true;
    }
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }
  
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: Use Firebase's native popup
        final provider = GoogleAuthProvider();
        return await _auth.signInWithPopup(provider);
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Android/iOS: Use official google_sign_in package
        await _ensureInitialized();
        
        // Trigger the authentication flow
        final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
        
        // Obtain the auth details from the request
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        // Create a new credential using ONLY the idToken
        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        return await _auth.signInWithCredential(credential);
      } else {
        // Windows/Linux/macOS:
        throw Exception('Google Sign-In requires Android, iOS, or Web.');
      }
    } catch (e) {
      print('Google Sign-In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        // Desktop platforms: only sign out of Firebase Auth
        await _auth.signOut();
      } else {
        // Mobile/Web: sign out of both GoogleSignIn and Firebase Auth
        await _ensureInitialized();
        await _googleSignIn.signOut();
        await _auth.signOut();
      }
    } catch (e) {
      print('Sign out error: $e');
      // Always ensure Firebase auth signs out even if google_sign_in fails
      await _auth.signOut();
    }
  }
}
