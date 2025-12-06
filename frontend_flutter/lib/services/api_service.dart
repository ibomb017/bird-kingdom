import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bird.dart';
import '../models/bird_log.dart';
import '../models/reminder.dart';
import '../models/weight_trend.dart';
import '../models/encyclopedia.dart';

class ApiService {
  // Android 模拟器使用 10.0.2.2，真机使用电脑 IP
  static const String baseUrl = 'http://10.0.2.2:8080/api';

  // 单例模式
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ==================== 鸟档案 ====================

  Future<List<Bird>> getBirds() async {
    final response = await http.get(Uri.parse('$baseUrl/birds'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Bird.fromJson(json)).toList();
    }
    throw Exception('获取鸟档案失败: ${response.statusCode}');
  }

  Future<Bird> getBird(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/birds/$id'));
    if (response.statusCode == 200) {
      return Bird.fromJson(json.decode(response.body));
    }
    throw Exception('获取鸟档案失败: ${response.statusCode}');
  }

  Future<Bird> createBird(Bird bird) async {
    final response = await http.post(
      Uri.parse('$baseUrl/birds'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(bird.toJson()),
    );
    if (response.statusCode == 200) {
      return Bird.fromJson(json.decode(response.body));
    }
    throw Exception('创建鸟档案失败: ${response.statusCode}');
  }

  Future<void> deleteBird(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/birds/$id'));
    if (response.statusCode != 204) {
      throw Exception('删除鸟档案失败: ${response.statusCode}');
    }
  }

  // ==================== 日志 ====================

  Future<List<BirdLog>> getLogs() async {
    final response = await http.get(Uri.parse('$baseUrl/logs'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => BirdLog.fromJson(json)).toList();
    }
    throw Exception('获取日志失败: ${response.statusCode}');
  }

  Future<List<BirdLog>> getLogsByBird(int birdId) async {
    final response = await http.get(Uri.parse('$baseUrl/logs/bird/$birdId'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => BirdLog.fromJson(json)).toList();
    }
    throw Exception('获取日志失败: ${response.statusCode}');
  }

  // ==================== 体重趋势 ====================

  Future<List<WeightTrend>> getWeightTrend(
      {int? birdId, String range = 'month'}) async {
    String url = '$baseUrl/logs/weight-trend?range=$range';
    if (birdId != null) {
      url += '&birdId=$birdId';
    }
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => WeightTrend.fromJson(json)).toList();
    }
    throw Exception('获取体重趋势失败: ${response.statusCode}');
  }

  // ==================== 提醒 ====================

  Future<List<Reminder>> getReminders() async {
    final response = await http.get(Uri.parse('$baseUrl/reminders'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Reminder.fromJson(json)).toList();
    }
    throw Exception('获取提醒失败: ${response.statusCode}');
  }

  Future<Reminder> createReminder(String title, String time) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reminders'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'title': title,
        'timeDescription': time,
        'enabled': true,
      }),
    );
    if (response.statusCode == 200) {
      return Reminder.fromJson(json.decode(response.body));
    }
    throw Exception('创建提醒失败: ${response.statusCode}');
  }

  Future<Reminder> toggleReminder(int id) async {
    final response =
        await http.patch(Uri.parse('$baseUrl/reminders/$id/toggle'));
    if (response.statusCode == 200) {
      return Reminder.fromJson(json.decode(response.body));
    }
    throw Exception('切换提醒状态失败: ${response.statusCode}');
  }

  Future<void> deleteReminder(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/reminders/$id'));
    if (response.statusCode != 204) {
      throw Exception('删除提醒失败: ${response.statusCode}');
    }
  }

  // ==================== 鸟类百科 ====================

  Future<List<BirdEncyclopedia>> getEncyclopediaBirds() async {
    final response = await http.get(Uri.parse('$baseUrl/encyclopedia/birds'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => BirdEncyclopedia.fromJson(json)).toList();
    }
    throw Exception('获取鸟类百科失败: ${response.statusCode}');
  }

  Future<BirdEncyclopedia> getEncyclopediaBird(int id) async {
    final response =
        await http.get(Uri.parse('$baseUrl/encyclopedia/birds/$id'));
    if (response.statusCode == 200) {
      return BirdEncyclopedia.fromJson(json.decode(response.body));
    }
    throw Exception('获取鸟类详情失败: ${response.statusCode}');
  }

  Future<List<BirdEncyclopedia>> searchEncyclopediaBirds(String keyword) async {
    final response = await http.get(
      Uri.parse(
          '$baseUrl/encyclopedia/birds/search?keyword=${Uri.encodeComponent(keyword)}'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => BirdEncyclopedia.fromJson(json)).toList();
    }
    throw Exception('搜索鸟类失败: ${response.statusCode}');
  }

  // ==================== 症状速查 ====================

  Future<List<SymptomInfo>> getSymptoms() async {
    final response =
        await http.get(Uri.parse('$baseUrl/encyclopedia/symptoms'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => SymptomInfo.fromJson(json)).toList();
    }
    throw Exception('获取症状列表失败: ${response.statusCode}');
  }

  Future<List<SymptomInfo>> searchSymptoms(String keyword) async {
    final response = await http.get(
      Uri.parse(
          '$baseUrl/encyclopedia/symptoms/search?keyword=${Uri.encodeComponent(keyword)}'),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => SymptomInfo.fromJson(json)).toList();
    }
    throw Exception('搜索症状失败: ${response.statusCode}');
  }

  // ==================== 配色预测 ====================

  Future<List<ColorGene>> getColorGenes() async {
    final response = await http.get(Uri.parse('$baseUrl/encyclopedia/colors'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => ColorGene.fromJson(json)).toList();
    }
    throw Exception('获取羽色基因失败: ${response.statusCode}');
  }

  Future<List<ColorPrediction>> predictColor(
      String fatherCode, String motherCode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/encyclopedia/colors/predict'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'fatherColorCode': fatherCode,
        'motherColorCode': motherCode,
      }),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> predictions = data['predictions'] ?? [];
      return predictions.map((json) => ColorPrediction.fromJson(json)).toList();
    }
    throw Exception('配色预测失败: ${response.statusCode}');
  }
}
