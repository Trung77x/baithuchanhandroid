import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

// Wrapper User model so screens don't depend directly on firebase_auth
class User {
  final String? email;
  final String? displayName;
  final String uid;

  User({this.email, this.displayName, required this.uid});
}

class AuthService {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal();

  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/calendar',
      'https://www.googleapis.com/auth/calendar.events',
    ],
    serverClientId:
        '413360382904-lcbr0ndivgtu7qt2vo5glbfkmh6c7eck.apps.googleusercontent.com',
  );

  // Convert Firebase User → our User model
  User? _fromFirebase(fb.User? fbUser) {
    if (fbUser == null) return null;
    return User(
      email: fbUser.email,
      displayName: fbUser.displayName,
      uid: fbUser.uid,
    );
  }

  // Stream of authentication state changes (from Firebase)
  Stream<User?> get authStateChanges =>
      _firebaseAuth.authStateChanges().map(_fromFirebase);

  // Get current user
  User? get currentUser => _fromFirebase(_firebaseAuth.currentUser);

  // Sign up with email and password
  Future<String?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Update display name
      await credential.user?.updateDisplayName(displayName);
      await credential.user?.reload();
      return null;
    } on fb.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          return 'Mật khẩu quá yếu';
        case 'email-already-in-use':
          return 'Email đã được sử dụng';
        case 'invalid-email':
          return 'Email không hợp lệ';
        default:
          return 'Lỗi đăng ký: ${e.message}';
      }
    } catch (e) {
      return 'Đã xảy ra lỗi: $e';
    }
  }

  // Sign in with email and password
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on fb.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'Không tìm thấy tài khoản';
        case 'wrong-password':
          return 'Sai mật khẩu';
        case 'invalid-email':
          return 'Email không hợp lệ';
        case 'user-disabled':
          return 'Tài khoản đã bị vô hiệu hóa';
        case 'invalid-credential':
          return 'Email hoặc mật khẩu không đúng';
        default:
          return 'Lỗi đăng nhập: ${e.message}';
      }
    } catch (e) {
      return 'Đã xảy ra lỗi: $e';
    }
  }

  // Sign in with Google
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return 'Đăng nhập Google đã bị hủy';
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final fb.OAuthCredential credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _firebaseAuth.signInWithCredential(credential);
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return 'Lỗi đăng nhập Google: ${e.message}';
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('ApiException: 10') ||
          errorStr.contains('DEVELOPER_ERROR') ||
          errorStr.contains('sign_in_failed')) {
        return 'Google Sign-In chưa được cấu hình đúng.\n'
            'Kiểm tra SHA-1 trong Firebase Console.';
      }
      return 'Lỗi đăng nhập Google: $e';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  // Check if user is signed in
  bool isSignedIn() {
    return _firebaseAuth.currentUser != null;
  }

  /// Check if Google Calendar is available (user signed in with Google)
  Future<bool> checkGoogleCalendarAvailable() async {
    try {
      if (_googleSignIn.currentUser != null) return true;
      final account = await _googleSignIn.signInSilently();
      return account != null;
    } catch (e) {
      debugPrint('checkGoogleCalendarAvailable error: $e');
      return false;
    }
  }

  /// Get Google auth headers for API calls
  Future<Map<String, String>?> getGoogleAuthHeaders() async {
    try {
      GoogleSignInAccount? account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      if (account == null) {
        debugPrint('getGoogleAuthHeaders: No Google account signed in');
        return null;
      }
      final headers = await account.authHeaders;
      debugPrint('getGoogleAuthHeaders: Got headers for ${account.email}');
      return headers;
    } catch (e) {
      debugPrint('getGoogleAuthHeaders error: $e');
      // Token expired, try re-authenticating
      try {
        final account = await _googleSignIn.signIn();
        if (account == null) return null;
        return await account.authHeaders;
      } catch (e2) {
        debugPrint('getGoogleAuthHeaders re-auth error: $e2');
        return null;
      }
    }
  }

  /// Request Calendar scope (for email/password users who want Calendar)
  Future<bool> requestCalendarAccess() async {
    try {
      GoogleSignInAccount? account = _googleSignIn.currentUser;
      account ??= await _googleSignIn.signInSilently();
      if (account == null) {
        // User not signed in with Google yet, trigger sign-in
        account = await _googleSignIn.signIn();
        if (account == null) {
          debugPrint('requestCalendarAccess: User cancelled Google sign-in');
          return false;
        }
        debugPrint('requestCalendarAccess: Signed in as ${account.email}');
      }
      // Request calendar scopes explicitly
      final granted = await _googleSignIn.requestScopes([
        'https://www.googleapis.com/auth/calendar',
        'https://www.googleapis.com/auth/calendar.events',
      ]);
      debugPrint('requestCalendarAccess: Scopes granted = $granted');
      return granted;
    } catch (e) {
      debugPrint('requestCalendarAccess error: $e');
      return false;
    }
  }

  /// Get current Google account email (for display)
  String? get googleEmail => _googleSignIn.currentUser?.email;

  // Reset password
  Future<String?> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return 'Lỗi: ${e.message}';
    } catch (e) {
      return 'Đã xảy ra lỗi: $e';
    }
  }
}
