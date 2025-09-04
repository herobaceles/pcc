import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/branch.dart';

class BranchService {
  static Future<List<Branch>> loadBranches() async {
    try {
      final data = await rootBundle.loadString('assets/branches.json');
      final jsonList = json.decode(data) as List<dynamic>;
      return jsonList.map((e) => Branch.fromJson(e)).toList();
    } catch (e) {
      print("Error loading branches: $e");
      return [];
    }
  }
}
