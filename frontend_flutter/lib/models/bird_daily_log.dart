class BirdDailyLog {
  BirdDailyLog({
    required this.date,
    required this.birdName,
    this.weightGram,
    this.feedAmountGram,
    this.waterMl,
    this.feedTimes,
    this.spiritStatus,
    this.stoolStatus,
    this.activityLevel,
    this.socialStatus,
    this.vocalAbnormal,
    this.eggCount,
    this.eggShellStatus,
    this.incubationDay,
    this.moltStatus,
    this.temperature,
    this.humidity,
    this.cageCleaned,
    this.notes,
    this.healthScore,
  });

  final DateTime date;
  final String birdName;

  final double? weightGram;
  final double? feedAmountGram;
  final double? waterMl;
  final int? feedTimes; // 0-3 次

  final String? spiritStatus; // 良好 / 一般 / 萎靡
  final String? stoolStatus; // 正常 / 稀 / 颜色异常

  final String? activityLevel; // 安静 / 正常 / 活泼
  final String? socialStatus; // 单独 / 与同伴互动 / 攻击
  final bool? vocalAbnormal; // 是否鸣叫异常

  final int? eggCount;
  final String? eggShellStatus; // 正常 / 软壳 / 破损
  final int? incubationDay; // 孵化第几天
  final String? moltStatus; // 未开始 / 进行中 / 已结束

  final double? temperature; // °C
  final double? humidity; // %
  final bool? cageCleaned; // 是否清理笼子

  final String? notes;
  final int? healthScore; // 0-100
}
