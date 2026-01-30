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

  /// Stream of authentication state changes.
  /// Emits a User object when signed in, or null when signed out.
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  /// Sign in a user with email and password.
  /// Returns UserCredential if successful, throws FirebaseAuthException on failure.
  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Register a new user with email and password.
  /// Returns UserCredential if successful, throws FirebaseAuthException if email is invalid or already in use.
  Future<UserCredential> signUp(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs the current user out.
  Future<void> signOut() {
    return _auth.signOut();
  }
}
