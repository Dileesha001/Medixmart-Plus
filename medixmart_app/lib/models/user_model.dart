class UserModel {
  final int id;
  final String username;
  final String role; // 'admin' or 'pharmacist'
  final String? fullName;

  const UserModel({
    required this.id,
    required this.username,
    required this.role,
    this.fullName,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isPharmacist => role.toLowerCase() == 'pharmacist';

  String get displayName => fullName ?? username;

  String get roleLabel => isAdmin ? 'Administrator' : 'Pharmacist';

  String get initials {
    final source = (fullName != null && fullName!.trim().isNotEmpty)
        ? fullName!.trim()
        : username.trim();
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return source.length >= 2
        ? source.substring(0, 2).toUpperCase()
        : source.toUpperCase();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      role: json['role'] as String,
      fullName: json['full_name'] as String? ?? json['fullName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'role': role,
        if (fullName != null) 'fullName': fullName,
      };
}

class AuthResponse {
  final String token;
  final UserModel user;
  final String expiresIn;

  const AuthResponse({
    required this.token,
    required this.user,
    required this.expiresIn,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      expiresIn: json['expiresIn'] as String,
    );
  }
}
