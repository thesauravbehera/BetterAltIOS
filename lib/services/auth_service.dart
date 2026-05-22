import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:fat_burner/models/user_model.dart';
import 'package:fat_burner/services/auth_result.dart';

/// Handles user authentication via Firebase Auth.
/// Stores user UID, email, phone in Firestore and syncs with auth state.
class AuthService {
  AuthService._() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _usersCollection = 'users';

  UserModel? _currentUser;
  final ValueNotifier<bool> authState = ValueNotifier(false);

  UserModel? get currentUser => _currentUser;

  bool get isLoggedIn => _auth.currentUser != null;

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      _currentUser = null;
      authState.value = false;
      return;
    }
    _currentUser = await _loadUserProfile(user);
    authState.value = true;
  }

  UserModel _userFromFirebaseUser(User user) {
    return UserModel(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      phone: user.phoneNumber,
      createdAt: user.metadata.creationTime,
    );
  }

  Future<UserModel> _loadUserProfile(User user) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return UserModel(
          id: user.uid,
          email: data['email'] as String? ?? user.email ?? '',
          displayName: data['displayName'] as String? ?? user.displayName,
          phone: data['phone'] as String? ?? user.phoneNumber,
          createdAt: data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : user.metadata.creationTime,
        );
      }
    } catch (_) {}
    return _userFromFirebaseUser(user);
  }

  Future<void> _saveUserProfile(UserModel user) async {
    await _firestore.collection(_usersCollection).doc(user.id).set({
      'email': user.email,
      'displayName': user.displayName,
      'phone': user.phone,
      'createdAt': user.createdAt != null
          ? Timestamp.fromDate(user.createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Login with email and password.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return const AuthSuccess();
    } on FirebaseAuthException catch (e) {
      return AuthFailure(_messageFromCode(e.code));
    } catch (e) {
      return AuthFailure('Login failed. Please try again.');
    }
  }

  /// Sign up with email, password, and optional display name and phone.
  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? displayName,
    String? phone,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        if (displayName != null && displayName.trim().isNotEmpty) {
          await user.updateDisplayName(displayName.trim());
        }

        final userModel = UserModel(
          id: user.uid,
          email: user.email ?? email.trim(),
          displayName: displayName?.trim().isNotEmpty == true
              ? displayName!.trim()
              : user.displayName,
          phone: phone?.trim().isNotEmpty == true ? phone!.trim() : null,
          createdAt: DateTime.now(),
        );
        await _saveUserProfile(userModel);
        _currentUser = userModel;
      }
      return const AuthSuccess();
    } on FirebaseAuthException catch (e) {
      return AuthFailure(_messageFromCode(e.code));
    } catch (e) {
      return AuthFailure('Sign up failed. Please try again.');
    }
  }

  /// Logout the current user.
  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
  }

  /// Check if user has an active session (Firebase persists automatically).
  Future<bool> checkSession() async {
    return _auth.currentUser != null;
  }

  String _messageFromCode(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Contact support.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
