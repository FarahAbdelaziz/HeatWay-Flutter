import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class ThermalPoint {
  const ThermalPoint({
    required this.location,
    required this.averageTemperature,
    this.minimumTemperature,
    this.maximumTemperature,
  });

  final LatLng location;
  final double averageTemperature;
  final double? minimumTemperature;
  final double? maximumTemperature;

  factory ThermalPoint.fromGeoJson(Map<String, dynamic> feature) {
    final geometry = _asMap(feature['geometry']);
    final properties = _asMap(feature['properties']);
    final coordinates = geometry['coordinates'] as List<dynamic>?;

    if (geometry['type'] != 'Point' ||
        coordinates == null ||
        coordinates.length < 2) {
      throw const FormatException('Invalid thermal-point geometry.');
    }

    final longitude = _asDouble(coordinates[0]);
    final latitude = _asDouble(coordinates[1]);

    if (latitude == null || longitude == null) {
      throw const FormatException('Thermal point has invalid coordinates.');
    }

    final average = _asDouble(properties['average_temperature']);

    if (average == null) {
      throw FormatException(
        'Thermal point has no average_temperature. '
        'Available properties: ${properties.keys.toList()}',
      );
    }

    return ThermalPoint(
      location: LatLng(latitude, longitude),
      averageTemperature: average,
      minimumTemperature: _asDouble(properties['min_temperature']),
      maximumTemperature: _asDouble(properties['max_temperature']),
    );
  }
}

class HeatmapResult {
  const HeatmapResult({
    required this.thermalDataId,
    required this.targetDate,
    required this.cacheHit,
    required this.points,
    required this.rawStats,
  });

  final String thermalDataId;
  final String targetDate;
  final bool cacheHit;
  final List<ThermalPoint> points;
  final Map<String, dynamic> rawStats;

  double? get averageTemperature {
    if (points.isEmpty) {
      return null;
    }

    final total = points.fold<double>(
      0,
      (sum, point) => sum + point.averageTemperature,
    );

    return total / points.length;
  }

  double? get minimumTemperature {
    if (points.isEmpty) {
      return null;
    }

    return points
        .map((point) => point.minimumTemperature ?? point.averageTemperature)
        .reduce((left, right) => left < right ? left : right);
  }

  double? get maximumTemperature {
    if (points.isEmpty) {
      return null;
    }

    return points
        .map((point) => point.maximumTemperature ?? point.averageTemperature)
        .reduce((left, right) => left > right ? left : right);
  }

  factory HeatmapResult.fromJson(Map<String, dynamic> json) {
    final heatmap = _asMap(json['heatmap']);
    final rawFeatures = heatmap['features'];
    final features =
        rawFeatures is List<dynamic> ? rawFeatures : const <dynamic>[];

    debugPrint('HEATMAP FEATURES COUNT: ${features.length}');

    if (features.isNotEmpty) {
      debugPrint('FIRST HEATMAP FEATURE: ${features.first}');
    }

    final points = <ThermalPoint>[];
    var hasLoggedParseError = false;

    for (final rawFeature in features) {
      try {
        if (rawFeature is! Map) {
          throw const FormatException('Thermal feature is not a JSON object.');
        }

        points.add(
          ThermalPoint.fromGeoJson(Map<String, dynamic>.from(rawFeature)),
        );
      } on FormatException catch (error) {
        if (!hasLoggedParseError) {
          debugPrint('THERMAL POINT PARSE ERROR: $error');
          hasLoggedParseError = true;
        }
      } on TypeError catch (error) {
        if (!hasLoggedParseError) {
          debugPrint('THERMAL POINT TYPE ERROR: $error');
          hasLoggedParseError = true;
        }
      }
    }

    debugPrint('PARSED THERMAL POINTS COUNT: ${points.length}');

    final thermalDataId = json['thermal_data_id']?.toString();
    final targetDate = json['target_date']?.toString();

    if (thermalDataId == null || thermalDataId.isEmpty) {
      throw const FormatException('Heatmap response has no thermal_data_id.');
    }

    if (targetDate == null || targetDate.isEmpty) {
      throw const FormatException('Heatmap response has no target_date.');
    }

    return HeatmapResult(
      thermalDataId: thermalDataId,
      targetDate: targetDate,
      cacheHit: json['cache_hit'] == true,
      points: List<ThermalPoint>.unmodifiable(points),
      rawStats: Map<String, dynamic>.unmodifiable(_asMap(heatmap['stats'])),
    );
  }
}

class ThermalRoute {
  const ThermalRoute({
    required this.routeId,
    required this.thermalRank,
    required this.points,
    required this.averageTemperature,
    required this.minimumTemperature,
    required this.maximumTemperature,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.thermalCoverage,
    required this.eligibleForThermalSelection,
  });

  final int routeId;
  final int thermalRank;
  final List<LatLng> points;
  final double averageTemperature;
  final double? minimumTemperature;
  final double? maximumTemperature;
  final double distanceMeters;
  final double durationSeconds;
  final double? thermalCoverage;
  final bool eligibleForThermalSelection;

  factory ThermalRoute.fromGeoJson(Map<String, dynamic> feature) {
    final geometry = _asMap(feature['geometry']);
    final properties = _asMap(feature['properties']);
    final rawCoordinates = geometry['coordinates'];

    final coordinates =
        rawCoordinates is List<dynamic> ? rawCoordinates : const <dynamic>[];

    if (geometry['type'] != 'LineString' || coordinates.isEmpty) {
      throw const FormatException('A ranked route has no LineString geometry.');
    }

    final average =
        _asDouble(properties['average_route_temperature']) ??
        _asDouble(properties['distance_weighted_average_temperature']);

    if (average == null) {
      throw const FormatException('A ranked route has no thermal result.');
    }

    final points = <LatLng>[];

    for (final rawCoordinate in coordinates) {
      if (rawCoordinate is! List || rawCoordinate.length < 2) {
        continue;
      }

      final longitude = _asDouble(rawCoordinate[0]);
      final latitude = _asDouble(rawCoordinate[1]);

      if (latitude == null || longitude == null) {
        continue;
      }

      points.add(LatLng(latitude, longitude));
    }

    if (points.isEmpty) {
      throw const FormatException('A ranked route has no valid coordinates.');
    }

    return ThermalRoute(
      routeId: _asInt(properties['route_id']) ?? _asInt(feature['id']) ?? 0,
      thermalRank: _asInt(properties['thermal_rank']) ?? 0,
      points: List<LatLng>.unmodifiable(points),
      averageTemperature: average,
      minimumTemperature: _asDouble(properties['minimum_route_temperature']),
      maximumTemperature: _asDouble(properties['maximum_route_temperature']),
      distanceMeters: _asDouble(properties['distance_meters']) ?? 0,
      durationSeconds: _asDouble(properties['duration_seconds']) ?? 0,
      thermalCoverage: _asDouble(properties['thermal_coverage']),
      eligibleForThermalSelection:
          properties['eligible_for_thermal_selection'] == true,
    );
  }
}

class RouteResult {
  const RouteResult({
    required this.preferredRoute,
    required this.rankedRoutes,
    required this.cacheHit,
    required this.routesGenerated,
    required this.routesRanked,
    required this.rankingDate,
    required this.season,
    required this.temperaturePreference,
  });

  final ThermalRoute preferredRoute;
  final List<ThermalRoute> rankedRoutes;
  final bool cacheHit;
  final int routesGenerated;
  final int routesRanked;
  final String rankingDate;
  final String season;
  final String temperaturePreference;

  List<LatLng> get points => preferredRoute.points;

  double get averageTemperature => preferredRoute.averageTemperature;

  double? get minimumTemperature => preferredRoute.minimumTemperature;

  double? get maximumTemperature => preferredRoute.maximumTemperature;

  double get distanceMeters => preferredRoute.distanceMeters;

  double get durationSeconds => preferredRoute.durationSeconds;

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    final rankedCollection = _asMap(json['ranked_routes']);
    final rawFeaturesValue = rankedCollection['features'];

    final rawFeatures =
        rawFeaturesValue is List<dynamic>
            ? rawFeaturesValue
            : const <dynamic>[];

    final routes = <ThermalRoute>[];

    for (final rawFeature in rawFeatures) {
      try {
        if (rawFeature is! Map) {
          continue;
        }

        routes.add(
          ThermalRoute.fromGeoJson(Map<String, dynamic>.from(rawFeature)),
        );
      } on FormatException {
        // Keep valid routes even if one route is malformed.
      } on TypeError {
        // Keep valid routes even if one route has invalid field types.
      }
    }

    routes.sort((left, right) {
      final leftRank = left.thermalRank == 0 ? 999999 : left.thermalRank;
      final rightRank = right.thermalRank == 0 ? 999999 : right.thermalRank;

      return leftRank.compareTo(rightRank);
    });

    final recommendedFeature = _asMap(
      json['recommended_route'] ?? json['coolest_route'],
    );

    if (recommendedFeature.isEmpty) {
      throw const FormatException('Route response has no recommended_route.');
    }

    final preferredFromResponse = ThermalRoute.fromGeoJson(recommendedFeature);

    final selectedId = _asInt(json['selected_route_id']);
    var preferred = preferredFromResponse;
    final preferredId = selectedId ?? preferredFromResponse.routeId;

    for (final route in routes) {
      if (route.routeId == preferredId) {
        preferred = route;
        break;
      }
    }

    if (!routes.any((route) => route.routeId == preferred.routeId)) {
      routes.insert(0, preferred);
    }

    return RouteResult(
      preferredRoute: preferred,
      rankedRoutes: List<ThermalRoute>.unmodifiable(routes),
      cacheHit: json['route_cache_hit'] == true,
      routesGenerated: _asInt(json['routes_generated']) ?? routes.length,
      routesRanked: _asInt(json['routes_ranked']) ?? routes.length,
      rankingDate: json['ranking_date']?.toString() ?? '',
      season: json['season']?.toString() ?? '',
      temperaturePreference:
          json['temperature_preference']?.toString() ?? 'cooler',
    );
  }
}

class EnvironmentalStatistic {
  const EnvironmentalStatistic({
    required this.average,
    required this.maximum,
    required this.minimum,
    required this.maximumTime,
    required this.minimumTime,
    required this.count,
  });

  final double? average;
  final double? maximum;
  final double? minimum;
  final String? maximumTime;
  final String? minimumTime;
  final int count;

  factory EnvironmentalStatistic.fromJson(Map<String, dynamic> json) {
    return EnvironmentalStatistic(
      average: _asDouble(json['average']),
      maximum: _asDouble(json['maximum']),
      minimum: _asDouble(json['minimum']),
      maximumTime: json['maximum_time']?.toString(),
      minimumTime: json['minimum_time']?.toString(),
      count: _asInt(json['count']) ?? 0,
    );
  }
}

class ThermalInsightsResult {
  const ThermalInsightsResult({
    required this.thermalDataId,
    required this.heatmapNodesUsed,
    required this.activityId,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.date,
    required this.sunrise,
    required this.sunset,
    required this.temperatureCelsius,
    required this.temperatureSource,
    required this.matchDistanceMeters,
    required this.analysis,
    required this.recommendations,
  });

  final String thermalDataId;
  final int heatmapNodesUsed;
  final String? activityId;
  final double latitude;
  final double longitude;
  final String timezone;
  final String date;
  final String sunrise;
  final String sunset;
  final double temperatureCelsius;
  final String temperatureSource;
  final double? matchDistanceMeters;
  final Map<String, EnvironmentalStatistic> analysis;
  final List<String> recommendations;

  EnvironmentalStatistic? statistic(String key) => analysis[key];

  factory ThermalInsightsResult.fromJson(Map<String, dynamic> json) {
    final location = _asMap(json['location']);
    final sun = _asMap(json['sun']);
    final temperature = _asMap(json['temperature']);
    final rawAnalysis = _asMap(json['analysis']);

    final parsedAnalysis = <String, EnvironmentalStatistic>{};

    for (final entry in rawAnalysis.entries) {
      parsedAnalysis[entry.key] = EnvironmentalStatistic.fromJson(
        _asMap(entry.value),
      );
    }

    final selectedTemperature = _asDouble(temperature['value_celsius']);

    if (selectedTemperature == null) {
      throw const FormatException('Insights response has no temperature.');
    }

    return ThermalInsightsResult(
      thermalDataId: json['thermal_data_id']?.toString() ?? '',
      heatmapNodesUsed: _asInt(json['heatmap_nodes_used']) ?? 0,
      activityId: json['activity_id']?.toString(),
      latitude: _asDouble(location['latitude']) ?? 0,
      longitude: _asDouble(location['longitude']) ?? 0,
      timezone: location['timezone']?.toString() ?? 'Unknown timezone',
      date: json['date']?.toString() ?? '',
      sunrise: sun['sunrise']?.toString() ?? '--:--',
      sunset: sun['sunset']?.toString() ?? '--:--',
      temperatureCelsius: selectedTemperature,
      temperatureSource:
          temperature['source']?.toString() ?? 'nearest_heatmap_node',
      matchDistanceMeters: _asDouble(temperature['match_distance_meters']),
      analysis: Map<String, EnvironmentalStatistic>.unmodifiable(
        parsedAnalysis,
      ),
      recommendations: List<String>.unmodifiable(
        (json['recommendations'] as List<dynamic>? ?? const <dynamic>[]).map(
          (item) => item.toString(),
        ),
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}

double? _asDouble(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString());
}

int? _asInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString());
}
