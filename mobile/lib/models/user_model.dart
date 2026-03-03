class UserModel {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String role; // 'passenger', 'driver', 'union_admin'
  final bool isVerified;
  final bool isActive;
  final String? profileImage;
  final String? whatsappNumber;
  final DateTime? lastLogin;
  final DateTime? createdAt;
  /// Driver verification: 'none' | 'pending' | 'approved' | 'rejected'
  final String driverVerificationStatus;
  /// Short bio, max 20 words (API enforced)
  final String? bio;
  /// Driver: e.g. "1 bag", "2 bags" – luggage per passenger
  final String? luggageAllowancePerPassenger;
  /// Short shareable code for drivers to join unions / be found easily
  final String? driverCode;

  UserModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    required this.role,
    required this.isVerified,
    required this.isActive,
    this.profileImage,
    this.whatsappNumber,
    this.lastLogin,
    this.createdAt,
    this.driverVerificationStatus = 'none',
    this.bio,
    this.luggageAllowancePerPassenger,
    this.driverCode,
  });

  bool get isDriverVerified => driverVerificationStatus == 'approved';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'passenger',
      isVerified: json['is_verified'] ?? json['isVerified'] ?? false,
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      profileImage: json['profile_image_url'] ?? json['profileImage'],
      whatsappNumber: json['whatsapp_number'] ?? json['whatsappNumber'],
      lastLogin: (json['last_login'] ?? json['lastLogin']) != null
          ? DateTime.tryParse((json['last_login'] ?? json['lastLogin']).toString())
          : null,
      createdAt: (json['created_at'] ?? json['createdAt']) != null
          ? DateTime.tryParse((json['created_at'] ?? json['createdAt']).toString())
          : null,
      driverVerificationStatus: json['driver_verification_status'] ?? json['driverVerificationStatus'] ?? 'none',
      bio: json['bio']?.toString(),
      luggageAllowancePerPassenger: json['luggage_allowance_per_passenger'] ?? json['luggageAllowancePerPassenger']?.toString(),
      driverCode: json['driver_code']?.toString() ?? json['driverCode']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'isVerified': isVerified,
      'isActive': isActive,
      'profileImage': profileImage,
      'whatsappNumber': whatsappNumber,
      'lastLogin': lastLogin?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'driverVerificationStatus': driverVerificationStatus,
      'bio': bio,
      'luggageAllowancePerPassenger': luggageAllowancePerPassenger,
      'driverCode': driverCode,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? role,
    bool? isVerified,
    bool? isActive,
    String? profileImage,
    String? whatsappNumber,
    DateTime? lastLogin,
    DateTime? createdAt,
    String? driverVerificationStatus,
    String? bio,
    String? luggageAllowancePerPassenger,
    String? driverCode,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      profileImage: profileImage ?? this.profileImage,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
      driverVerificationStatus: driverVerificationStatus ?? this.driverVerificationStatus,
      bio: bio ?? this.bio,
      luggageAllowancePerPassenger: luggageAllowancePerPassenger ?? this.luggageAllowancePerPassenger,
      driverCode: driverCode ?? this.driverCode,
    );
  }
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }
}
