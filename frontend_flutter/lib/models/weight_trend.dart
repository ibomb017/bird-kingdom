class WeightTrend {
  final int birdId;
  final String birdName;
  final List<WeightPoint> points;

  WeightTrend({
    required this.birdId,
    required this.birdName,
    required this.points,
  });

  factory WeightTrend.fromJson(Map<String, dynamic> json) {
    return WeightTrend(
      birdId: json['birdId'],
      birdName: json['birdName'] ?? '',
      points: (json['points'] as List?)
              ?.map((p) => WeightPoint.fromJson(p))
              .toList() ??
          [],
    );
  }
}

class WeightPoint {
  final DateTime date;
  final double weight;

  WeightPoint({
    required this.date,
    required this.weight,
  });

  factory WeightPoint.fromJson(Map<String, dynamic> json) {
    return WeightPoint(
      date: DateTime.parse(json['date']),
      weight: json['weight']?.toDouble() ?? 0,
    );
  }
}
