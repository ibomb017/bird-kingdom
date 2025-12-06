import 'dart:ui';

/// 鸟类百科
class BirdEncyclopedia {
  final int id;
  final String name;
  final String? scientificName;
  final String? category;
  final List<String> tags;
  final String? description;
  final String? feedingTips;
  final String? habitat;
  final int? lifespan;
  final String? colorHex;
  final String? imageUrl;

  BirdEncyclopedia({
    required this.id,
    required this.name,
    this.scientificName,
    this.category,
    this.tags = const [],
    this.description,
    this.feedingTips,
    this.habitat,
    this.lifespan,
    this.colorHex,
    this.imageUrl,
  });

  factory BirdEncyclopedia.fromJson(Map<String, dynamic> json) {
    return BirdEncyclopedia(
      id: json['id'],
      name: json['name'] ?? '',
      scientificName: json['scientificName'],
      category: json['category'],
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      description: json['description'],
      feedingTips: json['feedingTips'],
      habitat: json['habitat'],
      lifespan: json['lifespan'],
      colorHex: json['colorHex'],
      imageUrl: json['imageUrl'],
    );
  }

  Color get color {
    if (colorHex == null || colorHex!.isEmpty) {
      return const Color(0xFF1C6758);
    }
    try {
      return Color(int.parse(colorHex!.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF1C6758);
    }
  }
}

/// 症状信息
class SymptomInfo {
  final int id;
  final String name;
  final String? description;
  final List<String> possibleCauses;
  final List<String> suggestions;
  final String? severity;

  SymptomInfo({
    required this.id,
    required this.name,
    this.description,
    this.possibleCauses = const [],
    this.suggestions = const [],
    this.severity,
  });

  factory SymptomInfo.fromJson(Map<String, dynamic> json) {
    return SymptomInfo(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      possibleCauses: (json['possibleCauses'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      suggestions:
          (json['suggestions'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      severity: json['severity'],
    );
  }
}

/// 羽色基因
class ColorGene {
  final int id;
  final String name;
  final String? code;
  final String? displayColor;
  final bool? isDominant;
  final String? description;

  ColorGene({
    required this.id,
    required this.name,
    this.code,
    this.displayColor,
    this.isDominant,
    this.description,
  });

  factory ColorGene.fromJson(Map<String, dynamic> json) {
    return ColorGene(
      id: json['id'],
      name: json['name'] ?? '',
      code: json['code'],
      displayColor: json['displayColor'],
      isDominant: json['isDominant'],
      description: json['description'],
    );
  }

  Color get color {
    if (displayColor == null || displayColor!.isEmpty) {
      return const Color(0xFF888888);
    }
    try {
      return Color(int.parse(displayColor!.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}

/// 配色预测结果
class ColorPrediction {
  final String name;
  final String colorHex;
  final int percentage;

  ColorPrediction({
    required this.name,
    required this.colorHex,
    required this.percentage,
  });

  factory ColorPrediction.fromJson(Map<String, dynamic> json) {
    return ColorPrediction(
      name: json['name'] ?? '',
      colorHex: json['colorHex'] ?? '#888888',
      percentage: json['percentage'] ?? 0,
    );
  }

  Color get color {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF888888);
    }
  }
}
