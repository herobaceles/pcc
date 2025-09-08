class Branch {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String contact;
  final String email;
  final List<String> services;


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

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      contact: json['contact'],
      email: json['email'],
    );
  }
}
