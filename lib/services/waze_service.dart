import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/alert_model.dart';

class WazeService {
  static const String _baseUrl = 'https://www.waze.com/live-map/api/georss';
  
  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Referer': 'https://www.waze.com/live-map/directions',
  };

  Future<List<AlertModel>> fetchAlerts(
    double top,
    double bottom,
    double left,
    double right,
    String region,
  ) async {
    try {
      final params = {
        'top': top.toString(),
        'bottom': bottom.toString(),
        'left': left.toString(),
        'right': right.toString(),
        'env': region,
        'types': 'alerts',
      };

      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timeout'),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load alerts: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final alertsList = data['alerts'] as List<dynamic>? ?? [];

      return alertsList
          .map((item) => AlertModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching alerts: $e');
    }
  }
}
