import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../config/api_config.dart';
import '../models/thermal_models.dart';

Map<String, dynamic> _decodeJsonMap(String responseBody) {
  final Object? decoded = jsonDecode(responseBody);

  if (decoded is! Map) {
    throw const FormatException(
      'Expected the backend response to be a JSON object.',
    );
  }

  return Map<String, dynamic>.from(decoded);
}

class HeatWayApiException implements Exception {
  const HeatWayApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class HeatWayApi {
  HeatWayApi({http.Client? client})
    : _client = client ?? IOClient(_createHttpClient());

  // Optional date used only for testing.
  //
  // If it is empty, Flutter automatically sends the date from two days ago.
  //
  // Override during testing with:
  //
  // --dart-define=HEATWAY_TARGET_DATE=2026-08-26
  static const String targetDateOverride = String.fromEnvironment(
    'HEATWAY_TARGET_DATE',
    defaultValue: '',
  );

  final http.Client _client;

  static String _twoDaysAgo() {
    final date = DateTime.now().subtract(const Duration(days: 2));
    return _formatDate(date);
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static HttpClient _createHttpClient() {
    return HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(minutes: 40);
  }

  Future<bool> checkConnection() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/openapi.json'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<HeatmapResult> createHeatmap({
    required double latitude,
    required double longitude,
  }) async {
    final targetDate =
        targetDateOverride.trim().isEmpty
            ? _twoDaysAgo()
            : targetDateOverride.trim();

    debugPrint('HeatWay heatmap request: ${ApiConfig.baseUrl}/heatmap');
    debugPrint('HeatWay target date: $targetDate');

    final json = await _post('/heatmap', {
      'latitude': latitude,
      'longitude': longitude,
      'target_date': targetDate,
    }, timeout: const Duration(minutes: 35));

    final result = HeatmapResult.fromJson(json);

    if (result.thermalDataId.trim().isEmpty) {
      throw const HeatWayApiException(
        'The backend returned an invalid thermal data ID.',
      );
    }

    if (result.points.isEmpty) {
      throw const HeatWayApiException(
        'No thermal data is available yet. Please try again later.',
      );
    }

    return result;
  }

  Future<RouteResult> rankRoutes({
    required String thermalDataId,
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) async {
    if (thermalDataId.trim().isEmpty) {
      throw const HeatWayApiException(
        'Generate a valid heatmap before requesting routes.',
      );
    }

    final json = await _post('/routes/rank', {
      'thermal_data_id': thermalDataId,
      'start_lat': startLatitude,
      'start_lon': startLongitude,
      'end_lat': endLatitude,
      'end_lon': endLongitude,
    }, timeout: const Duration(minutes: 15));

    return RouteResult.fromJson(json);
  }

  Future<ThermalInsightsResult> createInsights({
    required String thermalDataId,
    required double latitude,
    required double longitude,
  }) async {
    if (thermalDataId.trim().isEmpty) {
      throw const HeatWayApiException(
        'Generate a valid heatmap before requesting insights.',
      );
    }

    final json = await _post('/insights', {
      'thermal_data_id': thermalDataId,
      'latitude': latitude,
      'longitude': longitude,
    }, timeout: const Duration(minutes: 20));

    return ThermalInsightsResult.fromJson(json);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    required Duration timeout,
  }) async {
    try {
      final response = await _sendPostWithConnectionRetry(
        path,
        body,
        timeout: timeout,
      );

      final Map<String, dynamic> decoded;

      try {
        decoded = await compute(_decodeJsonMap, response.body);
      } on FormatException catch (error) {
        throw HeatWayApiException(
          'Invalid response received from the backend: $error',
          statusCode: response.statusCode,
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded['detail'];

        throw HeatWayApiException(
          detail?.toString() ?? 'Backend request failed.',
          statusCode: response.statusCode,
        );
      }

      return decoded;
    } on TimeoutException {
      throw const HeatWayApiException(
        'The request took too long. Please try again.',
      );
    } on SocketException catch (error) {
      throw HeatWayApiException(
        'Cannot reach the HeatWay backend at '
        '${ApiConfig.baseUrl}: ${error.message}',
      );
    } on http.ClientException catch (error) {
      throw HeatWayApiException('Network error: ${error.message}');
    }
  }

  Future<http.Response> _sendPostWithConnectionRetry(
    String path,
    Map<String, dynamic> body, {
    required Duration timeout,
  }) async {
    const maximumAttempts = 2;
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final encodedBody = jsonEncode(body);

    for (var attempt = 1; attempt <= maximumAttempts; attempt++) {
      try {
        return await _client
            .post(
              uri,
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: encodedBody,
            )
            .timeout(timeout);
      } on http.ClientException catch (error) {
        final connectionClosed = error.message.toLowerCase().contains(
          'connection closed while receiving data',
        );
        final isLastAttempt = attempt == maximumAttempts;

        if (!connectionClosed || isLastAttempt) {
          rethrow;
        }

        debugPrint(
          'HeatWay connection closed while receiving $path. '
          'Retrying once.',
        );
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }

    throw const HeatWayApiException(
      'The backend response could not be received.',
    );
  }

  void close() {
    _client.close();
  }
}
