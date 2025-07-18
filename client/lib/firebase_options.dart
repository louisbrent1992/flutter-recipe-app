// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBmOQ9qllTjoyzF-XqFouWSBNK7ytrVUm8',
    appId: '1:826154873845:web:3af1668ffa073a015be6bc',
    messagingSenderId: '826154873845',
    projectId: 'recipe-app-c2fcc',
    authDomain: 'recipe-app-c2fcc.firebaseapp.com',
    databaseURL: 'https://recipe-app-c2fcc-default-rtdb.firebaseio.com',
    storageBucket: 'recipe-app-c2fcc.appspot.com',
    measurementId: 'G-PDC9YY78XE',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCh2vwuvWxGLlfbegNu73zPq0YOUssm0-0',
    appId: '1:826154873845:android:ceb9215bba4474ea5be6bc',
    messagingSenderId: '826154873845',
    projectId: 'recipe-app-c2fcc',
    databaseURL: 'https://recipe-app-c2fcc-default-rtdb.firebaseio.com',
    storageBucket: 'recipe-app-c2fcc.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDGJ4Ds_DsWNb_zPWIeJXyOVW6RyOxb3i0',
    appId: '1:826154873845:ios:a9a2ed9cc06ecc595be6bc',
    messagingSenderId: '826154873845',
    projectId: 'recipe-app-c2fcc',
    databaseURL: 'https://recipe-app-c2fcc-default-rtdb.firebaseio.com',
    storageBucket: 'recipe-app-c2fcc.appspot.com',
    androidClientId:
        '826154873845-2uber91hjcgap6qr688uo3lqeim47mjj.apps.googleusercontent.com',
    iosClientId:
        '826154873845-4904phdrsiv04juljvs6n2reirpje1qg.apps.googleusercontent.com',
    iosBundleId: 'com.recipease.kitchen',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDGJ4Ds_DsWNb_zPWIeJXyOVW6RyOxb3i0',
    appId: '1:826154873845:ios:a9a2ed9cc06ecc595be6bc',
    messagingSenderId: '826154873845',
    projectId: 'recipe-app-c2fcc',
    databaseURL: 'https://recipe-app-c2fcc-default-rtdb.firebaseio.com',
    storageBucket: 'recipe-app-c2fcc.appspot.com',
    androidClientId:
        '826154873845-2uber91hjcgap6qr688uo3lqeim47mjj.apps.googleusercontent.com',
    iosClientId:
        '826154873845-4904phdrsiv04juljvs6n2reirpje1qg.apps.googleusercontent.com',
    iosBundleId: 'com.recipease.kitchen',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBmOQ9qllTjoyzF-XqFouWSBNK7ytrVUm8',
    appId: '1:826154873845:web:3af1668ffa073a015be6bc',
    messagingSenderId: '826154873845',
    projectId: 'recipe-app-c2fcc',
    authDomain: 'recipe-app-c2fcc.firebaseapp.com',
    databaseURL: 'https://recipe-app-c2fcc-default-rtdb.firebaseio.com',
    storageBucket: 'recipe-app-c2fcc.appspot.com',
    measurementId: 'G-PDC9YY78XE',
  );
}
