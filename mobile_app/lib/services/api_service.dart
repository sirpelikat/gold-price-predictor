import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 127.0.0.1 for windows desktop execution
  // 10.0.2.2 for android emulator
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static Future<double?> getCurrentPrice() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/current-price'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['current_price'] as num?)?.toDouble();
      }
    } catch (e) {
      print('Error fetching current price: $e');
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getHistoricalData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/historical?days=7'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
    } catch (e) {
      print('Error fetching historical data: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getPredictionData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/prediction'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['predictions']);
      }
    } catch (e) {
      print('Error fetching prediction data: $e');
    }
    return [];
  }
}
