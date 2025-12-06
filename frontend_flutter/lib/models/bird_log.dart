class BirdLog {
  final int id;
  final int birdId;
  final String birdName;
  final DateTime logDate;
  final double? weight;
  final double? feedAmount;
  final double? waterAmount;
  final String? mood;
  final String? behavior;
  final bool? isMolting;
  final bool? isBreeding;
  final double? temperature;
  final double? humidity;
  final bool? isCleaned;
  final int? healthScore;
  final String? notes;
  final DateTime? createdAt;

  BirdLog({
    required this.id,
    required this.birdId,
    required this.birdName,
    required this.logDate,
    this.weight,
    this.feedAmount,
    this.waterAmount,
    this.mood,
    this.behavior,
    this.isMolting,
    this.isBreeding,
    this.temperature,
    this.humidity,
    this.isCleaned,
    this.healthScore,
    this.notes,
    this.createdAt,
  });

  factory BirdLog.fromJson(Map<String, dynamic> json) {
    return BirdLog(
      id: json['id'],
      birdId: json['birdId'],
      birdName: json['birdName'] ?? '',
      logDate: DateTime.parse(json['logDate']),
      weight: json['weight']?.toDouble(),
      feedAmount: json['feedAmount']?.toDouble(),
      waterAmount: json['waterAmount']?.toDouble(),
      mood: json['mood'],
      behavior: json['behavior'],
      isMolting: json['isMolting'],
      isBreeding: json['isBreeding'],
      temperature: json['temperature']?.toDouble(),
      humidity: json['humidity']?.toDouble(),
      isCleaned: json['isCleaned'],
      healthScore: json['healthScore'],
      notes: json['notes'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  String get moodText {
    switch (mood) {
      case 'HAPPY':
        return '开心';
      case 'NORMAL':
        return '正常';
      case 'QUIET':
        return '安静';
      case 'ANXIOUS':
        return '焦虑';
      default:
        return mood ?? '';
    }
  }

  String get summary {
    final parts = <String>[];
    if (weight != null) parts.add('体重${weight}g');
    if (mood != null) parts.add(moodText);
    if (notes != null && notes!.isNotEmpty) parts.add(notes!);
    return parts.join(' · ');
  }
}
