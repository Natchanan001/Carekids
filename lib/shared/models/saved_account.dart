class SavedAccount {
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String? role; // 'admin' หรือ 'caregiver', null ถ้ายังไม่ onboarding เสร็จ
  final String refreshToken;
  final DateTime lastUsedAt;

  SavedAccount({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.refreshToken,
    required this.lastUsedAt,
  });

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }

  String get initial => displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'role': role,
        'refreshToken': refreshToken,
        'lastUsedAt': lastUsedAt.toIso8601String(),
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
        userId: json['userId'],
        email: json['email'],
        firstName: json['firstName'] ?? '',
        lastName: json['lastName'] ?? '',
        role: json['role'],
        refreshToken: json['refreshToken'],
        lastUsedAt: DateTime.parse(json['lastUsedAt']),
      );
}