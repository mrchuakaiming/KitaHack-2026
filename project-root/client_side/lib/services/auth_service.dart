import 'package:firebase_auth/firebase_auth.dart';

// HOW TO USE?
/*
final AuthService _authService = AuthService();

// Listen for authentication changes (reactive UI)
_authService.authStateChanges().listen((User? user) {
  if (user == null) {
    print('User is signed out');
    // Could navigate to login screen here
  } else {
    print('User is signed in: ${user.email}');
    // Could navigate to home/dashboard screen here
  }
});

// Sign in a user
try {
  final userCredential = await _authService.signIn('test@example.com', 'password123');
  print('Signed in as: ${userCredential.user?.email}');
} on FirebaseAuthException catch (e) {
  print('Failed to sign in: ${e.message}');
}

// Sign up a new user
try {
  final userCredential = await _authService.signUp('newuser@example.com', 'password123');
  print('User created: ${userCredential.user?.email}');
} on FirebaseAuthException catch (e) {
  print('Failed to sign up: ${e.message}');
}

// Sign out the current user
await _authService.signOut();
print('User signed out');
*/

class AuthService {
  // FirebaseAuth instance for interacting with Firebase Authentication
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Expose the currently signed-in user
  User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes.
  /// Emits a User object when signed in, or null when signed out.
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges().handleError((error) {
      if (error is FirebaseAuthException) {
        throw Exception('Auth state stream error: ${error.code}');
      }
      throw error;
    });
  }

  /// Sign in a user with email and password.
  /// Throws a Dart Exception on failure.
  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception('Sign-in failed: ${e.code} - ${e.message}');
    } catch (e) {
      throw Exception('Sign-in failed: $e');
    }
  }

  /// Register a new user with email and password.
  /// Throws a Dart Exception on failure.
  Future<UserCredential> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw Exception('Sign-up failed: ${e.code} - ${e.message}');
    } catch (e) {
      throw Exception('Sign-up failed: $e');
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Sign-out failed: $e');
    }
  }

  /// Sends a password reset email.
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw Exception('Password reset failed: ${e.code} - ${e.message}');
    } catch (e) {
      throw Exception('Password reset failed: $e');
    }
  }
}
