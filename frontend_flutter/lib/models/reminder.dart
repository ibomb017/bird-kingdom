class Reminder {
  final int id;
  final String title;
  final String timeDescription;
  final String? reminderType;
  final bool enabled;
  final int? birdId;
  final String? birdName;

  Reminder({
    required this.id,
    required this.title,
    required this.timeDescription,
    this.reminderType,
    required this.enabled,
    this.birdId,
    this.birdName,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'],
      title: json['title'] ?? '',
      timeDescription: json['timeDescription'] ?? '',
      reminderType: json['reminderType'],
      enabled: json['enabled'] ?? true,
      birdId: json['birdId'],
      birdName: json['birdName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'timeDescription': timeDescription,
      'reminderType': reminderType,
      'enabled': enabled,
      'birdId': birdId,
    };
  }
}
