class ChildProfile {
  final String id;
  final String familyId;
  final String name;
  final DateTime birthdate;
  final double weightKg;
  final DateTime weightUpdatedAt;
  final String? gender;
  final String? photoUrl;

  ChildProfile({
    required this.id,
    required this.familyId,
    required this.name,
    required this.birthdate,
    required this.weightKg,
    required this.weightUpdatedAt,
    this.gender,
    this.photoUrl,
  });

  factory ChildProfile.fromMap(Map<String, dynamic> map) {
    return ChildProfile(
      id: map['id'],
      familyId: map['family_id'],
      name: map['name'],
      birthdate: DateTime.parse(map['birthdate']),
      weightKg: (map['weight_kg'] as num).toDouble(),
      weightUpdatedAt: DateTime.parse(map['weight_updated_at']),
      gender: map['gender'],
      photoUrl: map['photo_url'],
    );
  }

  String get ageLabel {
    final now = DateTime.now();
    int years = now.year - birthdate.year;
    int months = now.month - birthdate.month;
    int days = now.day - birthdate.day;

    if (days < 0) months--;
    if (months < 0) {
      years--;
      months += 12;
    }

    if (years <= 0) {
      return months <= 1 ? '$months month old' : '$months months old';
    }
    if (months == 0) {
      return years == 1 ? '$years year old' : '$years years old';
    }
    return '$years yr $months mo old';
  }

  // weekly weight update reminder (F004)
  bool get isWeightStale {
    return DateTime.now().difference(weightUpdatedAt).inDays >= 7;
  }
}
