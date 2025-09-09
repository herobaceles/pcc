import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/branch.dart';

class BranchService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Loads all branches from Firestore collection "branches"
  static Future<List<Branch>> loadBranches() async {
    try {
      final querySnapshot = await _firestore.collection('branches').get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Branch.fromJson({
          'id': doc.id,  // Include document ID
          ...data,
        });
      }).toList();
    } catch (e) {
      print("Error loading branches from Firebase: $e");
      return [];
    }
  }
}
