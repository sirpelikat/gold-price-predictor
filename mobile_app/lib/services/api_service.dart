import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const Duration timeoutDuration = Duration(seconds: 15);

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://127.0.0.1:8000/api';
  }

  static Future<Map<String, dynamic>?> getCurrentPriceData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/current-price')).timeout(timeoutDuration);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final currentPriceData = data['current_price'];
        if (currentPriceData is Map) {
          return Map<String, dynamic>.from(currentPriceData);
        }
      }
    } catch (e) {
      debugPrint('Error fetching current price: $e');
    }
    return null;
  }

  static Future<double?> getCurrentPrice() async {
    final data = await getCurrentPriceData();
    if (data != null) {
      return (data['myr_per_g'] as num?)?.toDouble();
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getHistoricalData({int days = 7}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/historical?days=$days')).timeout(timeoutDuration);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      }
    } catch (e) {
      debugPrint('Error fetching historical data: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getPredictionData({int days = 7}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/prediction?days=$days')).timeout(timeoutDuration);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['predictions']);
      }
    } catch (e) {
      debugPrint('Error fetching prediction data: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getModelMetrics() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/model-metrics')).timeout(timeoutDuration);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching model metrics: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getPredictionLogs() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/prediction-logs')).timeout(timeoutDuration);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching prediction logs: $e');
    }
    return null;
  }

  static Future<bool> syncPredictionLogs() async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/prediction-logs/sync')).timeout(timeoutDuration);
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error syncing prediction logs: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getMalaysiaMacroData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/malaysia-macro')).timeout(timeoutDuration);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching Malaysia macro data: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getRetrainingStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/retraining-status')).timeout(timeoutDuration);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching retraining status: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> triggerRetraining({bool force = false}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/retrain?force=$force'),
      ).timeout(const Duration(seconds: 45));
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error triggering retraining: $e');
    }
    return null;
  }
}
