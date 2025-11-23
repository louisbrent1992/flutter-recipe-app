import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'collection_service.dart';
import '../firebase_options.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // For iOS, use explicit client ID
    // For Android, don't specify clientId - it will be auto-detected from google-services.json
    clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? DefaultFirebaseOptions.ios.iosClientId
        : null,
    scopes: ['email', 'profile'],
  );
  final CollectionService _collectionService = CollectionService();

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

    // Create default collections for new user
    try {
      await _collectionService.createDefaultCollections();
      print('Default collections created for new user: ${result.user!.uid}');
    } catch (e) {
      print('Error creating default collections: $e');
      // Don't fail the registration if collections creation fails
    }

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
    String? photoURL, // Can be null to delete
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (displayName != null) updates['displayName'] = displayName;
    if (email != null) updates['email'] = email;
    if (photoURL != null) {
      updates['photoURL'] = photoURL;
    }

    final futures = <Future>[
      _firestore.collection('users').doc(currentUser!.uid).update(updates),
    ];

    if (displayName != null) {
      futures.add(currentUser!.updateDisplayName(displayName));
    }
    if (email != null) {
      futures.add(currentUser!.verifyBeforeUpdateEmail(email));
    }
    if (photoURL != null) {
      futures.add(currentUser!.updatePhotoURL(photoURL));
    }

    await Future.wait(futures);
  }
}
