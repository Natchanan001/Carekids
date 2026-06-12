class Profile {
  final String id;
  final String familyId;
  final String firstName;
  final String lastName;
  final String role; // 'admin' or 'caregiver'

  Profile({
    required this.id,
    required this.familyId,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'],
      familyId: map['family_id'],
      firstName: map['first_name'],
      lastName: map['last_name'],
      role: map['role'],
    );
  }

  bool get isAdmin => role == 'admin';
}