class Bird {
  final int id;
  final String nickname;
  final String species;
  final String? gender;
  final DateTime? birthDate;
  final String? featherColor;
  final String? source;
  final String? avatarUrl;
  final String? notes;
  final int? ageMonths;

  Bird({
    required this.id,
    required this.nickname,
    required this.species,
    this.gender,
    this.birthDate,
    this.featherColor,
    this.source,
    this.avatarUrl,
    this.notes,
    this.ageMonths,
  });

  factory Bird.fromJson(Map<String, dynamic> json) {
    return Bird(
      id: json['id'],
      nickname: json['nickname'] ?? '',
      species: json['species'] ?? '',
      gender: json['gender'],
      birthDate:
          json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
      featherColor: json['featherColor'],
      source: json['source'],
      avatarUrl: json['avatarUrl'],
      notes: json['notes'],
      ageMonths: json['ageMonths'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'species': species,
      'gender': gender,
      'birthDate': birthDate?.toIso8601String().split('T')[0],
      'featherColor': featherColor,
      'source': source,
      'avatarUrl': avatarUrl,
      'notes': notes,
    };
  }

  String get ageText {
    if (ageMonths == null) return '';
    if (ageMonths! >= 12) {
      final years = ageMonths! ~/ 12;
      final months = ageMonths! % 12;
      if (months == 0) return '$years岁';
      return '$years岁$months个月';
    }
    return '$ageMonths个月';
  }
}
