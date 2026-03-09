import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyChSJ1WF85wuoo-9EmR7sHWxq2eQafid9k',
    appId: '1:413360382904:android:351bbe219aff9821ae654d',
    messagingSenderId: '413360382904',
    projectId: 'smart-note-2e53e',
    storageBucket: 'smart-note-2e53e.firebasestorage.app',
  );

  // Placeholder – update when you add an iOS app in Firebase Console
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyChSJ1WF85wuoo-9EmR7sHWxq2eQafid9k',
    appId: '1:413360382904:android:351bbe219aff9821ae654d',
    messagingSenderId: '413360382904',
    projectId: 'smart-note-2e53e',
    storageBucket: 'smart-note-2e53e.firebasestorage.app',
    iosBundleId: 'com.example.flutterApplication1',
  );

  // Placeholder – update when you add a Windows app in Firebase Console
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyChSJ1WF85wuoo-9EmR7sHWxq2eQafid9k',
    appId: '1:413360382904:android:351bbe219aff9821ae654d',
    messagingSenderId: '413360382904',
    projectId: 'smart-note-2e53e',
    storageBucket: 'smart-note-2e53e.firebasestorage.app',
  );
}
