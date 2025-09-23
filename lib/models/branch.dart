import 'package:cloud_firestore/cloud_firestore.dart';

class Branch {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String contact;
  final String email;
  final List<String> services;      // service IDs
  final List<String> serviceNames;  // service names

  Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.contact,
    required this.email,
    this.services = const [],
    this.serviceNames = const [],
  });

  /// ✅ Safe JSON factory (avoids null crashes)
  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      contact: json['contact'] ?? '',
      email: json['email'] ?? '',
      services: List<String>.from(json['services'] ?? const []),
      serviceNames: List<String>.from(json['serviceNames'] ?? const []),
    );
  }

  /// ✅ Firestore-safe constructor
  factory Branch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Branch(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      contact: data['contact'] ?? '',
      email: data['email'] ?? '',
      services: List<String>.from(data['services'] ?? const []),
      serviceNames: List<String>.from(data['serviceNames'] ?? const []),
    );
  }

  /// ✅ Handy copyWith method
  Branch copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? contact,
    String? email,
    List<String>? services,
    List<String>? serviceNames,
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
      serviceNames: serviceNames ?? this.serviceNames,
    );
  }

  /// ✅ For debugging
  @override
  String toString() {
    return 'Branch(id: $id, name: $name, services: $services, serviceNames: $serviceNames)';
  }
}
