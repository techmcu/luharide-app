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
  /// Admin-gated: when true, verified driver can re-upload once (then goes pending again).
  final bool driverKycReuploadAllowed;
  /// Short bio, max 20 words (API enforced)
  final String? bio;
  /// Driver: e.g. "1 bag", "2 bags" – luggage per passenger
  final String? luggageAllowancePerPassenger;
  /// Short shareable code for drivers to join unions / be found easily
  final String? driverCode;
  /// True only for global app admin (super admin)
  final bool isAppAdmin;

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
    this.driverKycReuploadAllowed = false,
    this.bio,
    this.luggageAllowancePerPassenger,
    this.driverCode,
    this.isAppAdmin = false,
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
      driverKycReuploadAllowed: json['driver_kyc_reupload_allowed'] == true ||
          json['driverKycReuploadAllowed'] == true,
      bio: json['bio']?.toString(),
      luggageAllowancePerPassenger: json['luggage_allowance_per_passenger'] ?? json['luggageAllowancePerPassenger']?.toString(),
      driverCode: json['driver_code']?.toString() ?? json['driverCode']?.toString(),
      isAppAdmin: json['isAppAdmin'] == true || json['is_app_admin'] == true,
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
      'driverKycReuploadAllowed': driverKycReuploadAllowed,
      'bio': bio,
      'luggageAllowancePerPassenger': luggageAllowancePerPassenger,
      'driverCode': driverCode,
      'isAppAdmin': isAppAdmin,
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
    bool? driverKycReuploadAllowed,
    String? bio,
    String? luggageAllowancePerPassenger,
    String? driverCode,
    bool? isAppAdmin,
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
      driverKycReuploadAllowed: driverKycReuploadAllowed ?? this.driverKycReuploadAllowed,
      bio: bio ?? this.bio,
      luggageAllowancePerPassenger: luggageAllowancePerPassenger ?? this.luggageAllowancePerPassenger,
      driverCode: driverCode ?? this.driverCode,
      isAppAdmin: isAppAdmin ?? this.isAppAdmin,
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
