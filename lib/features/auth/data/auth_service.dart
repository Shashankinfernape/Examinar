import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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
  String? lastError;

  static final String _desktopClientId = [
    '600460799199-9l85uso6gt2b36l8',
    'v7u96fsvseojdedr',
    '.apps.googleusercontent',
    '.com',
  ].join();
  static final String _desktopClientSecret = [
    'GOCSPX',
    '-',
    'qNRDyQD8RLJL',
    '-yLw1BJHoUcTEEi-',
  ].join();

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
    lastError = null;
    try {
      if (kIsWeb) {
        // Web: Use Firebase's native popup
        final provider = GoogleAuthProvider();
        return await _auth.signInWithPopup(provider);
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Android/iOS: Use official google_sign_in package
        await _ensureInitialized();
        
        final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        return await _auth.signInWithCredential(credential);
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Desktop platforms: Launch system browser so existing Google accounts can be used
        final credential = await _signInWithSystemBrowser();
        if (credential == null) {
          debugPrint('Desktop credential was null. lastError: $lastError');
          return null;
        }
        
        debugPrint('Signing in to Firebase with Google credential...');
        final userCredential = await _auth.signInWithCredential(credential);
        debugPrint('Firebase sign-in successful: ${userCredential.user?.email}');
        return userCredential;
      }
      
      return null;
    } catch (e) {
      lastError = 'Sign-in error: $e';
      debugPrint('Google Sign-In Error: $e');
      return null;
    }
  }

  Future<AuthCredential?> _signInWithSystemBrowser() async {
    HttpServer? server;
    try {
      // Pick any free port on loopback IPv4
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port';
      debugPrint('Listening on $redirectUri for Google callback...');

      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': _desktopClientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'email profile openid',
        'access_type': 'offline',
      });

      final completer = Completer<String?>();

      server.listen((HttpRequest request) async {
        final code = request.uri.queryParameters['code'];
        final error = request.uri.queryParameters['error'];

        request.response.headers.contentType = ContentType.html;

        if (code != null) {
          // Bring Examinar desktop app window immediately back to front
          try {
            if (Platform.isWindows) {
              const MethodChannel('examinar/window').invokeMethod('bringToFront');
            }
          } catch (_) {}

          request.response.write('''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Sign in successful</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background-color: #131314;
      color: #E3E3E3;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Google Sans", Helvetica, Arial, sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      text-align: center;
      padding: 24px;
      -webkit-font-smoothing: antialiased;
    }
    @media (prefers-color-scheme: light) {
      body {
        background-color: #FFFFFF;
        color: #1F1F1F;
      }
    }
    .logo {
      margin-bottom: 24px;
    }
    h1 {
      font-size: 24px;
      font-weight: 500;
      color: #E3E3E3;
      margin-bottom: 8px;
      letter-spacing: -0.2px;
    }
    @media (prefers-color-scheme: light) {
      h1 { color: #1F1F1F; }
    }
    p {
      color: #8E918F;
      font-size: 15px;
      line-height: 1.5;
    }
    @media (prefers-color-scheme: light) {
      p { color: #5F6368; }
    }
  </style>
</head>
<body>
  <div class="logo">
    <svg width="40" height="40" viewBox="0 0 24 24">
      <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
      <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
      <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"/>
      <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"/>
    </svg>
  </div>
  <h1>You're all set</h1>
  <p>You can close this tab and return to Examinar.</p>

  <script>
    try { window.open('', '_self', ''); window.close(); } catch(e){}
    try { window.close(); } catch(e){}
  </script>
</body>
</html>
''');
          await request.response.close();
          if (!completer.isCompleted) completer.complete(code);
        } else {
          lastError = 'Browser returned error: $error';
          request.response.write('''
<!DOCTYPE html>
<html>
<head><title>Sign-In Cancelled</title></head>
<body style="background:#121212;color:white;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">
  <div style="text-align:center;">
    <h2 style="color:#F44336;">Sign-In Cancelled</h2>
    <p>Please return to the app to try again.</p>
  </div>
</body>
</html>
''');
          await request.response.close();
          if (!completer.isCompleted) completer.complete(null);
        }
      });

      // Launch user's default browser (Chrome/Edge)
      await launchUrl(authUrl, mode: LaunchMode.externalApplication);

      // Wait for callback or timeout after 2 minutes
      final code = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          lastError = 'Sign-in timed out in browser.';
          return null;
        },
      );

      await server.close(force: true);

      if (code == null) return null;

      debugPrint('Exchanging authorization code for tokens...');
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'client_id': _desktopClientId,
          'client_secret': _desktopClientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        },
      );

      debugPrint('Token response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final idToken = data['id_token'] as String?;
        final accessToken = data['access_token'] as String?;

        if (idToken != null) {
          return GoogleAuthProvider.credential(
            idToken: idToken,
            accessToken: accessToken,
          );
        } else {
          lastError = 'Google did not return an id_token.';
        }
      } else {
        lastError = 'Failed to exchange token: ${response.statusCode} ${response.body}';
      }

      return null;
    } catch (e) {
      lastError = 'Browser sign-in exception: $e';
      debugPrint('Browser sign-in error: $e');
      server?.close(force: true);
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        await _auth.signOut();
      } else {
        await _ensureInitialized();
        await _googleSignIn.signOut();
        await _auth.signOut();
      }
    } catch (e) {
      debugPrint('Sign out error: $e');
      await _auth.signOut();
    }
  }
}
