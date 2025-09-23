import 'package:cloud_firestore/cloud_firestore.dart';

class Branch {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String contact;
  final String email;
  final List<String> services; // stores service IDs available in this branch

  Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.contact,
    required this.email,
    this.services = const [],
  });

  /// For JSON imports (e.g., APIs)
  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      contact: json['contact'],
      email: json['email'],
      // services usually injected later by BranchService
      services: List<String>.from(json['services'] ?? []),
    );
  }

  /// For Firestore documents
  factory Branch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Branch(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      contact: data['contact'] ?? '',
      email: data['email'] ?? '',
      // 🔹 Don’t rely on Firestore here; services will be attached in BranchService
      services: const [],
    );
  }

  /// Handy copyWith method for updating services after creation
  Branch copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? contact,
    String? email,
    List<String>? services,
  }) {
    return Branch(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      contact: contact ?? this.contact,
      email: email ?? this.email,
      services: services ?? this.services,
    );
  }
}
