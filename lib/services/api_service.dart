import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/prayer_time_model.dart';

class ApiService {
  static const String baseUrl = 'https://api.aladhan.com/v1';

  Future<PrayerTimings> getPrayerTimings({
    required String city,
    required String country,
    DateTime? targetDate,
    int method = 2,
  }) async {
    final date = DateFormat('dd-MM-yyyy').format(targetDate ?? DateTime.now());
    final Uri url = Uri.parse(
      '$baseUrl/timingsByCity/$date?city=$city&country=$country&method=$method',
    );
    return _fetchTimings(url);
  }

  Future<PrayerTimings> getPrayerTimingsByLocation({
    required double latitude,
    required double longitude,
    DateTime? targetDate,
    int method = 3,
  }) async {
    final date = DateFormat('dd-MM-yyyy').format(targetDate ?? DateTime.now());
    final Uri url = Uri.parse(
      '$baseUrl/timings/$date?latitude=$latitude&longitude=$longitude&method=$method',
    );
    return _fetchTimings(url);
  }

  Future<PrayerTimings> _fetchTimings(Uri url) async {
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          return PrayerTimings.fromJson(data['data']);
        } else {
          throw Exception('Failed to load prayer timings: ${data['status']}');
        }
      } else {
        throw Exception(
          'Failed to load prayer timings: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching prayer timings: $e');
    }
  }
}
