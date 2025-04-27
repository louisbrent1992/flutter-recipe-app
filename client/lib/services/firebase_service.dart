import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create user profile in Firestore
    await _firestore.collection('users').doc(result.user!.uid).set({
      'displayName': displayName,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update display name
    await result.user!.updateDisplayName(displayName);

    return result;
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw 'Google sign in aborted';

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  }

  // Sign out
  Future<void> signOut() async {
    await Future.wait([_googleSignIn.signOut(), _auth.signOut()]);
  }

  // Get user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    final doc =
        await _firestore.collection('users').doc(currentUser!.uid).get();
    return doc.data() ?? {};
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? email,
    String? photoURL,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (displayName != null) updates['displayName'] = displayName;
    if (email != null) updates['email'] = email;
    if (photoURL != null) updates['photoURL'] = photoURL;

    await Future.wait([
      _firestore.collection('users').doc(currentUser!.uid).update(updates),
      if (displayName != null) currentUser!.updateDisplayName(displayName),
      if (email != null) currentUser!.verifyBeforeUpdateEmail(email),
      if (photoURL != null) currentUser!.updatePhotoURL(photoURL),
    ]);
  }

  // Get user's favorite recipes
  Future<List<String>> getFavoriteRecipes() async {
    final doc =
        await _firestore.collection('favorites').doc(currentUser!.uid).get();
    return List<String>.from(doc.data()?['recipes'] ?? []);
  }

  // Add recipe to favorites
  Future<void> addToFavorites(String recipeId) async {
    await _firestore.collection('favorites').doc(currentUser!.uid).set({
      'recipes': FieldValue.arrayUnion([recipeId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Remove recipe from favorites
  Future<void> removeFromFavorites(String recipeId) async {
    await _firestore.collection('favorites').doc(currentUser!.uid).update({
      'recipes': FieldValue.arrayRemove([recipeId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Check if recipe is in favorites
  Future<bool> isRecipeFavorite(String recipeId) async {
    final favorites = await getFavoriteRecipes();
    return favorites.contains(recipeId);
  }
}
