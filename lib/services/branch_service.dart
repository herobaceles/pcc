import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/branch.dart';

class BranchService {
  static Future<List<Branch>> loadBranches() async {
    final jsonString = await rootBundle.loadString('assets/branches.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => Branch.fromJson(json)).toList();
  }
}
