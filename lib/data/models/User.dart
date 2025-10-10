import 'dart:convert';

class User {
  final String id;
  final String email;
  final String? phoneNumber;
  final String role;
  final String? name;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String>? roles; // For multiple roles support
  final List<String>? assignedMachines;

  User({
    required this.id,
    required this.email,
    this.phoneNumber,
    required this.role,
    this.name,
    required this.isActive,
    this.lastLogin,
    required this.createdAt,
    required this.updatedAt,
    this.roles,
    this.assignedMachines,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Parse roles from JSON string or array
    List<String>? parsedRoles;
    if (json['role'] != null) {
      try {
        if (json['role'] is String) {
          // Try to parse as JSON array first
          try {
            parsedRoles = List<String>.from(jsonDecode(json['role']));
          } catch (e) {
            // If not JSON, treat as single role
            parsedRoles = [json['role']];
          }
        } else if (json['role'] is List) {
          parsedRoles = List<String>.from(json['role']);
        }
      } catch (e) {
        parsedRoles = [json['role'].toString()];
      }
    }

    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      role: json['role'] as String,
      name: json['name'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      lastLogin: json['lastLogin'] != null ? DateTime.parse(json['lastLogin']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      roles: parsedRoles,
      assignedMachines: json['assignedMachines'] != null 
          ? List<String>.from(json['assignedMachines']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role,
      'name': name,
      'isActive': isActive,
      'lastLogin': lastLogin?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'roles': roles,
      'assignedMachines': assignedMachines,
    };
  }

  // Helper method to check if user has a specific role
  bool hasRole(String role) {
    return roles?.contains(role) ?? this.role == role;
  }

  // Helper method to check if user has any of the specified roles
  bool hasAnyRole(List<String> roles) {
    return roles.any((role) => hasRole(role));
  }

  // Helper method to get primary role (first role or main role)
  String get primaryRole {
    return roles?.isNotEmpty == true ? roles!.first : role;
  }
}

