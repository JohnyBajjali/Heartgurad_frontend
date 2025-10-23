// lib/models/user.dart
class User {
  final int id;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? role;
  final Map<String, dynamic>? hospital; // nested object if present

  User({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    this.email,
    this.role,
    this.hospital,
  });

  // Safe parser – tolerate missing/extra fields
  factory User.fromJsonSafe(Map<String, dynamic> json) {
    // id can be int or string
    int parsedId;
    final rawId = json['id'];
    if (rawId is int) {
      parsedId = rawId;
    } else if (rawId is String) {
      parsedId = int.tryParse(rawId) ?? -1;
    } else {
      parsedId = -1;
    }

    return User(
      id: parsedId,
      username: (json['username'] ?? '').toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      email: json['email']?.toString(),
      role: json['role']?.toString(),
      hospital: json['hospital'] is Map<String, dynamic> ? (json['hospital'] as Map<String, dynamic>) : null,
    );
  }
}
