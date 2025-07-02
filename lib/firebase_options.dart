// lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // این قسمت را ویرایش کنید
      return const FirebaseOptions(
        apiKey: "AIzaSyAUr6bFkj_249JlKPxcht1njYEtchwWLws",
        authDomain: "solvix-f2e4c.firebaseapp.com",
        projectId: "solvix-f2e4c",
        storageBucket: "solvix-f2e4c.firebasestorage.app",
        messagingSenderId: "177581789113",
        appId: "1:177581789113:web:775695a0d2056333c3b068",
        measurementId: "G-KZESBQ0DC9",
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return const FirebaseOptions(
        apiKey: 'AIzaSyB0eCocLrwzi7pWpG2Bz6Ua-Yt3_jnic4A',
        appId: '1:177581789113:android:372ff4adedd80cc3c3b068',
        messagingSenderId: '177581789113',
        projectId: 'solvix-f2e4c',
        storageBucket: 'solvix-f2e4c.firebasestorage.app',
      );
    }

    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }
}
