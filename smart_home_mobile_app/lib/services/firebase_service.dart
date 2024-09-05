import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Future<void> initialize() async {
  //   if (kIsWeb) {
  //     await Firebase.initializeApp(
  //       options: const FirebaseOptions(
  //         apiKey: "AIzaSyAelfmpmBp4j65TA9sxLJ1zKKcXLdXR6Ms",
  //         authDomain: "tats-660da.firebaseapp.com",
  //         projectId: "tats-660da",
  //         storageBucket: "tats-660da.appspot.com",
  //         messagingSenderId: "129731850885",
  //         appId: "1:129731850885:web:fb43718bb6649a77e7afec",
  //         measurementId: "G-F5CK0G2RQK",
  //       ),
  //     );
  //   } 
  // }

  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}
