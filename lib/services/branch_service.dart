import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/branch.dart';

class BranchService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Loads all branches and attaches their service IDs + names
  static Future<List<Branch>> loadBranches() async {
    try {
      final branchSnap = await _firestore.collection('branches').get();
      final serviceSnap = await _firestore.collection('services').get();

      // 🔹 Map branchId -> list of services (id + name)
      final Map<String, List<Map<String, String>>> branchServices = {};

      for (var service in serviceSnap.docs) {
        final serviceId = service.id;
        final data = service.data() as Map<String, dynamic>;
        final serviceName = data['test_name'] ?? '';
        final availability = List.from(data['availability'] ?? []);

        for (var ref in availability) {
          String? branchId;

          if (ref is DocumentReference) {
            branchId = ref.id;
          } else if (ref is String) {
            branchId = ref.split("/").last.trim();
          } else {
            print("⚠️ Unexpected type in availability: $ref");
          }

          if (branchId != null) {
            branchServices.putIfAbsent(branchId, () => []).add({
              "id": serviceId,
              "name": serviceName,
            });
            print("🔗 Service $serviceName ($serviceId) → Branch $branchId");
          }
        }
      }

      // 🔹 Build Branch objects with attached services (IDs only for now)
      final branches = branchSnap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final attachedServices =
            (branchServices[doc.id] ?? []).map((s) => s["id"]!).toList();

        if (attachedServices.isEmpty) {
          print("❌ Branch ${doc.id} (${data['name']}) has NO services");
        } else {
          print("🏥 Branch ${doc.id} (${data['name']}) → $attachedServices");
        }

        return Branch.fromJson({
          'id': doc.id,
          ...data,
          'services': attachedServices,
        });
      }).toList();

      print("✅ Loaded ${branches.length} branches with services");
      return branches;
    } catch (e, st) {
      print("❌ Error loading branches from Firebase: $e");
      print(st);
      return [];
    }
  }

  /// Loads full service details for a specific branch (name, description, etc.)
  static Future<List<Map<String, dynamic>>> loadServicesForBranch(
      String branchId) async {
    try {
      final serviceSnap = await _firestore.collection('services').get();

      final services = serviceSnap.docs.where((doc) {
        final availability = List.from(doc['availability'] ?? []);
        return availability.any((ref) {
          if (ref is DocumentReference) {
            return ref.id == branchId;
          } else if (ref is String) {
            return ref.split("/").last.trim() == branchId;
          }
          return false;
        });
      }).map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['test_name'] ?? '',
          'description': data['test_description'] ?? '',
          'tat': data['results_tat'] ?? '',
          'days': data['running_days'] ?? '',
          'prep': data['patient_preparation'] ?? '',
        };
      }).toList();

      print("📌 Branch $branchId → ${services.length} services loaded");
      return services;
    } catch (e, st) {
      print("❌ Error loading services for branch $branchId: $e");
      print(st);
      return [];
    }
  }

  /// Loads all available services (for filter dropdowns etc.)
  static Future<List<Map<String, dynamic>>> loadAllServices() async {
    try {
      final serviceSnap = await _firestore.collection('services').get();

      final services = serviceSnap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['test_name'] ?? '',
          'description': data['test_description'] ?? '',
        };
      }).toList();

      print("📌 Loaded ${services.length} total services");
      return services;
    } catch (e, st) {
      print("❌ Error loading all services: $e");
      print(st);
      return [];
    }
  }
}
