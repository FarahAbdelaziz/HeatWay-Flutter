import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'models/thermal_models.dart';
import 'state/heatway_store.dart';

class HeatmapScreen extends StatelessWidget {
  const HeatmapScreen({super.key});

  static const hotColor = Color(0xFFE86A5B);
  static const warmColor = Color(0xFFF4C95D);
  static const coolColor = Color(0xFF5FA89B);
  static const primaryColor = Color(0xFF2F7D73);
  static const deepTeal = Color(0xFF245B57);
  static const backgroundColor = Color(0xFFF7F8F4);
  static const usCenter = LatLng(39.8283, -98.5795);

  @override
  Widget build(BuildContext context) {
    final store = HeatWayStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final data = store.heatmap;
        final loading = store.stage == HeatWayRequestStage.loadingHeatmap;
        return Scaffold(
          backgroundColor: backgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                _header(data, loading),
                _summary(data),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _map(store, data, loading),
                    ),
                  ),
                ),
                _footer(store, data),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(HeatmapResult? data, bool loading) {
    final subtitle =
        loading
            ? 'Generating thermal data...'
            : data == null
            ? 'Waiting for thermal data'
            : 'Latest available thermal data';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HeatWay',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Heatmap',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: deepTeal,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  )
                else
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: primaryColor,
                  ),
                const SizedBox(width: 5),
                Text(
                  data?.cacheHit == true ? 'Cached' : 'Latest',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: deepTeal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(HeatmapResult? data) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 5, 20, 12),
    child: Row(
      children: [
        _infoCard(
          Icons.thermostat_rounded,
          'Average',
          _temp(data?.averageTemperature),
        ),
        const SizedBox(width: 10),
        _infoCard(
          Icons.local_fire_department_rounded,
          'Highest',
          _temp(data?.maximumTemperature),
        ),
        const SizedBox(width: 10),
        _infoCard(
          Icons.ac_unit_rounded,
          'Lowest',
          _temp(data?.minimumTemperature),
        ),
      ],
    ),
  );

  Widget _map(HeatWayStore store, HeatmapResult? data, bool loading) {
    final points = data?.points ?? const <ThermalPoint>[];
    final hasData = points.isNotEmpty;
    final center =
        hasData ? _centerOf(points) : store.currentLocation ?? usCenter;
    final sampled =
        hasData ? _sample(points, maximumCount: 700) : const <ThermalPoint>[];

    return Stack(
      children: [
        FlutterMap(
          key: ValueKey(data?.thermalDataId ?? 'empty-heatmap'),
          options: MapOptions(
            initialCenter: center,
            initialZoom: hasData || store.currentLocation != null ? 13 : 4,
            minZoom: 3,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.street_temperature',
            ),
            if (hasData)
              CircleLayer(
                circles: sampled
                    .map(
                      (point) => CircleMarker(
                        point: point.location,
                        radius: 180,
                        useRadiusInMeter: true,
                        color: _color(
                          point.averageTemperature,
                          data!.minimumTemperature!,
                          data.maximumTemperature!,
                        ).withValues(alpha: 0.48),
                        borderColor: Colors.transparent,
                        borderStrokeWidth: 0,
                      ),
                    )
                    .toList(growable: false),
              ),
            if (store.currentLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: store.currentLocation!,
                    width: 48,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 7,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        if (!hasData && !loading) const Center(child: _EmptyMessage()),
        if (loading)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.white.withValues(alpha: 0.82),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: primaryColor),
                    SizedBox(height: 14),
                    Text(
                      'Generating heatmap...',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: deepTeal,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'This may take several minutes the first time.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (hasData)
          Positioned(left: 14, right: 14, bottom: 14, child: _legend(data!)),
      ],
    );
  }

  Widget _legend(HeatmapResult data) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [coolColor, warmColor, hotColor],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _temp(data.minimumTemperature),
              style: const TextStyle(fontSize: 10),
            ),
            Text(
              _temp(data.averageTemperature),
              style: const TextStyle(fontSize: 10),
            ),
            Text(
              _temp(data.maximumTemperature),
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _footer(HeatWayStore store, HeatmapResult? data) {
    final failed =
        store.stage == HeatWayRequestStage.failed && store.errorMessage != null;
    final text =
        failed
            ? store.errorMessage!
            : data == null
            ? 'Create a route from the Map tab to generate thermal data.'
            : '${data.points.length} thermal points loaded.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Row(
        children: [
          Icon(
            failed ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 18,
            color: failed ? hotColor : primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _infoCard(IconData icon, String title, String value) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: primaryColor),
              const SizedBox(height: 7),
              Text(
                title,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: deepTeal,
                ),
              ),
            ],
          ),
        ),
      );

  static List<ThermalPoint> _sample(
    List<ThermalPoint> points, {
    required int maximumCount,
  }) {
    if (points.length <= maximumCount) return points;

    final minimumLatitude = points
        .map((point) => point.location.latitude)
        .reduce(math.min);
    final maximumLatitude = points
        .map((point) => point.location.latitude)
        .reduce(math.max);
    final minimumLongitude = points
        .map((point) => point.location.longitude)
        .reduce(math.min);
    final maximumLongitude = points
        .map((point) => point.location.longitude)
        .reduce(math.max);

    final latitudeSpan = math.max(maximumLatitude - minimumLatitude, 0.000001);
    final longitudeSpan = math.max(
      maximumLongitude - minimumLongitude,
      0.000001,
    );
    final gridSide = math.sqrt(maximumCount).floor();
    final buckets = <int, ThermalPoint>{};

    for (final point in points) {
      final row =
          (((point.location.latitude - minimumLatitude) / latitudeSpan) *
                  (gridSide - 1))
              .floor();
      final column =
          (((point.location.longitude - minimumLongitude) / longitudeSpan) *
                  (gridSide - 1))
              .floor();
      final key = row * gridSide + column;
      buckets.putIfAbsent(key, () => point);
    }

    return buckets.values.take(maximumCount).toList(growable: false);
  }

  static LatLng _centerOf(List<ThermalPoint> points) {
    var latitudeTotal = 0.0;
    var longitudeTotal = 0.0;
    for (final point in points) {
      latitudeTotal += point.location.latitude;
      longitudeTotal += point.location.longitude;
    }
    return LatLng(
      latitudeTotal / points.length,
      longitudeTotal / points.length,
    );
  }

  static Color _color(double value, double minimum, double maximum) {
    if (maximum <= minimum) return warmColor;
    final normalized =
        ((value - minimum) / (maximum - minimum)).clamp(0, 1).toDouble();
    if (normalized <= 0.5) {
      return Color.lerp(coolColor, warmColor, normalized * 2) ?? warmColor;
    }
    return Color.lerp(warmColor, hotColor, (normalized - 0.5) * 2) ?? hotColor;
  }

  static String _temp(double? value) =>
      value == null ? '--°C' : '${value.toStringAsFixed(1)}°C';
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(24),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10),
      ],
    ),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.thermostat_rounded,
          color: HeatmapScreen.primaryColor,
          size: 30,
        ),
        SizedBox(height: 8),
        Text(
          'No heatmap available yet',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: HeatmapScreen.deepTeal,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Choose a destination from the Map tab and request a route.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    ),
  );
}
