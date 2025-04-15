import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
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
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw 'Google sign in aborted';

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Get user profile
  Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final doc =
          await _firestore.collection('users').doc(currentUser!.uid).get();
      return doc.data() ?? {};
    } catch (e) {
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? email,
    String? photoURL,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (displayName != null) updates['displayName'] = displayName;
      if (email != null) updates['email'] = email;
      if (photoURL != null) updates['photoURL'] = photoURL;

      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .update(updates);

      if (displayName != null) {
        await currentUser!.updateDisplayName(displayName);
      }
      if (email != null) {
        await currentUser!.verifyBeforeUpdateEmail(email);
      }
      if (photoURL != null) {
        await currentUser!.updatePhotoURL(photoURL);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get user's favorite recipes
  Future<List<String>> getFavoriteRecipes() async {
    try {
      final doc =
          await _firestore.collection('favorites').doc(currentUser!.uid).get();
      return List<String>.from(doc.data()?['recipes'] ?? []);
    } catch (e) {
      rethrow;
    }
  }

  // Add recipe to favorites
  Future<void> addToFavorites(String recipeId) async {
    try {
      await _firestore.collection('favorites').doc(currentUser!.uid).set({
        'recipes': FieldValue.arrayUnion([recipeId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  // Remove recipe from favorites
  Future<void> removeFromFavorites(String recipeId) async {
    try {
      await _firestore.collection('favorites').doc(currentUser!.uid).update({
        'recipes': FieldValue.arrayRemove([recipeId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Check if recipe is in favorites
  Future<bool> isRecipeFavorite(String recipeId) async {
    try {
      final favorites = await getFavoriteRecipes();
      return favorites.contains(recipeId);
    } catch (e) {
      rethrow;
    }
  }
}
