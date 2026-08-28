import 'package:flutter/material.dart';

import 'models/thermal_models.dart';
import 'state/heatway_store.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  static const primary = Color(0xFF176B67);
  static const hot = Color(0xFFE85D4A);
  static const warm = Color(0xFFF2B84B);
  static const cool = Color(0xFF5FAF9B);
  static const light = Color(0xFFE6F1EE);
  static const background = Color(0xFFF7F5F0);

  @override
  Widget build(BuildContext context) {
    final store = HeatWayStore.instance;
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: store,
          builder:
              (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HeatWay',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Insights',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _subtitle(store.stage),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (store.isLoading) ...[
                      const LinearProgressIndicator(
                        minHeight: 3,
                        color: primary,
                        backgroundColor: light,
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (store.stage == HeatWayRequestStage.failed) ...[
                      _ErrorCard(message: store.errorMessage),
                      const SizedBox(height: 18),
                    ],
                    if (store.heatmap == null && store.routeResult == null)
                      const _PendingCard(
                        icon: Icons.insights_rounded,
                        title: 'No insights available yet',
                        message:
                            'Choose a destination and create a route from the Map tab first.',
                      )
                    else ...[
                      _InsightsContext(store: store),
                      const SizedBox(height: 22),
                      if (store.insightsLoading) ...[
                        const _PendingCard(
                          icon: Icons.hourglass_top_rounded,
                          title: 'Generating environmental insights',
                          message:
                              'Analyzing conditions from sunrise through sunset...',
                        ),
                        const SizedBox(height: 22),
                      ],
                      if (store.insightsError != null) ...[
                        _ErrorCard(message: store.insightsError),
                        const SizedBox(height: 22),
                      ],
                      _MatchedTemperature(insights: store.insights),
                      const SizedBox(height: 22),
                      const _SectionTitle(
                        title: 'Environmental Overview',
                        icon: Icons.monitor_heart_outlined,
                      ),
                      const SizedBox(height: 12),
                      _EnvironmentalOverview(insights: store.insights),
                      const SizedBox(height: 22),
                      const _SectionTitle(
                        title: 'Route Insight',
                        icon: Icons.alt_route_rounded,
                      ),
                      const SizedBox(height: 12),
                      _PreferredRouteCard(
                        route: store.preferredRoute,
                        temperaturePreference:
                            store.routeResult?.temperaturePreference,
                      ),
                      const SizedBox(height: 22),
                      const _SectionTitle(
                        title: 'Route Comparison',
                        icon: Icons.compare_arrows_rounded,
                      ),
                      const SizedBox(height: 12),
                      _RouteComparison(routes: store.rankedRoutes),
                      const SizedBox(height: 22),
                      _BackendRecommendations(insights: store.insights),
                    ],
                  ],
                ),
              ),
        ),
      ),
    );
  }

  static String _subtitle(HeatWayRequestStage stage) {
    switch (stage) {
      case HeatWayRequestStage.loadingHeatmap:
        return 'Generating environmental thermal data...';
      case HeatWayRequestStage.loadingRoutes:
        return 'Comparing routes using thermal coverage...';
      case HeatWayRequestStage.completed:
        return 'Live results from your latest route analysis.';
      case HeatWayRequestStage.failed:
        return 'The latest analysis could not be completed.';
      case HeatWayRequestStage.idle:
        return 'Temperature and route information in one place.';
    }
  }
}

class _InsightsContext extends StatelessWidget {
  const _InsightsContext({required this.store});
  final HeatWayStore store;

  @override
  Widget build(BuildContext context) {
    final insights = store.insights;
    final current = store.currentLocation;
    return _Panel(
      child: Column(
        children: [
          _ContextRow(
            icon: Icons.location_on_rounded,
            title: 'Current location',
            value:
                insights != null
                    ? _coordinates(insights.latitude, insights.longitude)
                    : current == null
                    ? 'Waiting for GPS'
                    : _coordinates(current.latitude, current.longitude),
          ),
          const _SoftDivider(),
          _ContextRow(
            icon: Icons.public_rounded,
            title: 'Timezone',
            value: insights?.timezone ?? 'Waiting for insights',
          ),
          const _SoftDivider(),
          Row(
            children: [
              Expanded(
                child: _SunValue(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Sunrise',
                  value: insights?.sunrise ?? '--:--',
                  color: InsightsScreen.warm,
                ),
              ),
              Container(width: 1, height: 42, color: Colors.black12),
              Expanded(
                child: _SunValue(
                  icon: Icons.wb_twilight_outlined,
                  label: 'Sunset',
                  value: insights?.sunset ?? '--:--',
                  color: InsightsScreen.hot,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _coordinates(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

class _MatchedTemperature extends StatelessWidget {
  const _MatchedTemperature({required this.insights});
  final ThermalInsightsResult? insights;

  @override
  Widget build(BuildContext context) {
    final result = insights;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            InsightsScreen.hot.withValues(alpha: 0.16),
            InsightsScreen.primary.withValues(alpha: 0.09),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: InsightsScreen.warm.withValues(alpha: 0.24),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.thermostat_rounded,
              color: InsightsScreen.hot,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Matched temperature',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 3),
                Text(
                  _temperature(result?.temperatureCelsius),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: InsightsScreen.primary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 145,
            child: Text(
              result == null
                  ? 'Waiting for environmental analysis'
                  : 'Nearest heatmap node · ${_meters(result.matchDistanceMeters)} away',
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentalOverview extends StatelessWidget {
  const _EnvironmentalOverview({required this.insights});
  final ThermalInsightsResult? insights;

  @override
  Widget build(BuildContext context) {
    const cards = [
      _IndicatorData(
        title: 'Heat index',
        key: 'heat_index_celsius',
        unit: '°C',
        icon: Icons.device_thermostat_rounded,
        color: InsightsScreen.hot,
        description:
            'Heat index combines air temperature and humidity to estimate '
            'how hot conditions feel to the human body. Higher values mean '
            'greater heat stress and a higher risk of heat-related illness.',
      ),
      _IndicatorData(
        title: 'Apparent temperature',
        key: 'apparent_temperature_celsius',
        unit: '°C',
        icon: Icons.thermostat_auto_rounded,
        color: Color(0xFFE58C45),
        description:
            'Apparent temperature describes how the weather feels after '
            'considering humidity, wind and solar exposure. It may differ '
            'from the measured air temperature.',
      ),
      _IndicatorData(
        title: 'Wet bulb temperature',
        key: 'wet_bulb_temperature_celsius',
        unit: '°C',
        icon: Icons.water_drop_outlined,
        color: Color(0xFF4D91C6),
        description:
            'Wet bulb temperature shows how effectively the body can cool '
            'through sweat evaporation. Higher values indicate less effective '
            'cooling and greater heat stress.',
      ),
      _IndicatorData(
        title: 'Solar irradiance',
        key: 'solar_irradiance',
        unit: ' W/m²',
        icon: Icons.wb_sunny_outlined,
        color: InsightsScreen.warm,
        description:
            'Solar irradiance is the solar energy reaching one square meter '
            'of surface. Higher values mean stronger sunlight and greater '
            'direct solar heat exposure.',
      ),
      _IndicatorData(
        title: 'Precipitation',
        key: 'precipitation_mm',
        unit: ' mm',
        icon: Icons.umbrella_outlined,
        color: Color(0xFF657FC1),
        description:
            'Precipitation measures rainfall during the observation period. '
            'Higher values mean more rain and a greater possibility of wet '
            'or slippery road conditions.',
      ),
      _IndicatorData(
        title: 'Cloud cover',
        key: 'cloud_cover_octas',
        unit: '%',
        icon: Icons.cloud_outlined,
        color: Color(0xFF7B8794),
        description:
            'Cloud cover is the percentage of the sky covered by clouds. '
            'Higher values mean more cloud coverage, which can reduce direct '
            'sunlight but may also retain heat.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _IndicatorCard(
                  data: card,
                  statistic: insights?.statistic(card.key),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PreferredRouteCard extends StatelessWidget {
  const _PreferredRouteCard({
    required this.route,
    required this.temperaturePreference,
  });
  final ThermalRoute? route;
  final String? temperaturePreference;

  @override
  Widget build(BuildContext context) {
    final preferred = route;
    if (preferred == null) {
      return const _PendingCard(
        icon: Icons.alt_route_rounded,
        title: 'Waiting for route data',
        message: 'Create a route from the Map tab to see its thermal insight.',
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: InsightsScreen.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      temperaturePreference == 'warmer'
                          ? 'Preferred warmer route'
                          : 'Preferred cooler route',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Thermal rank #${preferred.thermalRank}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _temperature(preferred.averageTemperature),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.20), height: 1),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RouteMetric('Distance', _distance(preferred.distanceMeters)),
              _RouteMetric('Time', _duration(preferred.durationSeconds)),
              _RouteMetric('Coverage', _coverage(preferred.thermalCoverage)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteComparison extends StatelessWidget {
  const _RouteComparison({required this.routes});
  final List<ThermalRoute> routes;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return const _PendingCard(
        icon: Icons.compare_arrows_rounded,
        title: 'No ranked routes yet',
        message: 'Alternative routes will appear after route analysis.',
      );
    }
    final visibleRoutes = routes.take(5).toList();
    return _Panel(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        children: [
          for (var index = 0; index < visibleRoutes.length; index++) ...[
            _RouteRow(
              route: visibleRoutes[index],
              preferred: visibleRoutes[index].thermalRank == 1,
            ),
            if (index != visibleRoutes.length - 1) const _SoftDivider(),
          ],
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.route, required this.preferred});
  final ThermalRoute route;
  final bool preferred;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: preferred ? InsightsScreen.light : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Text(
            '#${route.thermalRank}',
            style: TextStyle(
              color: preferred ? InsightsScreen.primary : Colors.grey.shade700,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      preferred ? 'Preferred route' : 'Alternative route',
                      style: const TextStyle(
                        color: InsightsScreen.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (preferred) ...[
                    const SizedBox(width: 6),
                    const _Pill(label: 'Preferred'),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${_distance(route.distanceMeters)} · ${_duration(route.durationSeconds)} · ${_coverage(route.thermalCoverage)} coverage',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _temperature(route.averageTemperature),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: preferred ? InsightsScreen.cool : InsightsScreen.hot,
          ),
        ),
      ],
    ),
  );
}

class _BackendRecommendations extends StatelessWidget {
  const _BackendRecommendations({required this.insights});
  final ThermalInsightsResult? insights;

  @override
  Widget build(BuildContext context) {
    final recommendations = insights?.recommendations ?? const <String>[];
    if (recommendations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Recommendations',
          icon: Icons.health_and_safety_outlined,
        ),
        const SizedBox(height: 12),
        _Panel(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              for (var index = 0; index < recommendations.length; index++) ...[
                _GuidanceRow(
                  icon: _recommendationIcon(recommendations[index]),
                  color: _recommendationColor(recommendations[index]),
                  text: recommendations[index],
                ),
                if (index != recommendations.length - 1) const _SoftDivider(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Environmental guidance is generated by the Heat Way backend and is not medical advice.',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  IconData _recommendationIcon(String message) {
    final text = message.toLowerCase();
    if (text.contains('heat') || text.contains('stroke')) {
      return Icons.warning_amber_rounded;
    }
    if (text.contains('solar') || text.contains('sun')) {
      return Icons.wb_sunny_outlined;
    }
    if (text.contains('precipitation') || text.contains('rain')) {
      return Icons.umbrella_outlined;
    }
    if (text.contains('cloud')) return Icons.cloud_outlined;
    return Icons.health_and_safety_outlined;
  }

  Color _recommendationColor(String message) {
    final text = message.toLowerCase();
    if (text.contains('extreme') || text.contains('stroke')) {
      return InsightsScreen.hot;
    }
    if (text.contains('solar') || text.contains('sun')) {
      return InsightsScreen.warm;
    }
    if (text.contains('rain') || text.contains('precipitation')) {
      return const Color(0xFF4D91C6);
    }
    return InsightsScreen.primary;
  }
}

class _IndicatorData {
  const _IndicatorData({
    required this.title,
    required this.key,
    required this.unit,
    required this.icon,
    required this.color,
    required this.description,
  });

  final String title;
  final String key;
  final String unit;
  final IconData icon;
  final Color color;
  final String description;
}

class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({required this.data, required this.statistic});
  final _IndicatorData data;
  final EnvironmentalStatistic? statistic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border(top: BorderSide(color: data.color, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, color: data.color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: InsightsScreen.primary,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Tooltip(
                message: 'What is ${data.title}?',
                child: InkWell(
                  onTap: () => _showIndicatorInformation(context, data),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: data.color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _indicatorValue(statistic?.average, data.unit),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: InsightsScreen.primary,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Daily average',
            style: TextStyle(fontSize: 9, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          _MiniStat(
            label: 'Max',
            value: _indicatorValue(statistic?.maximum, data.unit),
            time: _localTime(statistic?.maximumTime),
            color: InsightsScreen.hot,
          ),
          const SizedBox(height: 5),
          _MiniStat(
            label: 'Min',
            value: _indicatorValue(statistic?.minimum, data.unit),
            time: _localTime(statistic?.minimumTime),
            color: InsightsScreen.cool,
          ),
          const SizedBox(height: 9),
          Text(
            '${statistic?.count ?? 0} observations',
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

Future<void> _showIndicatorInformation(
  BuildContext context,
  _IndicatorData data,
) {
  return showDialog<void>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, color: data.color, size: 27),
          ),
          title: Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: InsightsScreen.primary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            data.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF3E4A46),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: InsightsScreen.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.time,
    required this.color,
  });
  final String label;
  final String value;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 25,
        child: Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.grey),
        ),
      ),
      Expanded(
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
        ),
      ),
      Text(time, style: TextStyle(fontSize: 8, color: color)),
    ],
  );
}

class _SunValue extends StatelessWidget {
  const _SunValue({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, color: color, size: 25),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: InsightsScreen.primary,
            ),
          ),
        ],
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: InsightsScreen.primary),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: InsightsScreen.primary,
        ),
      ),
    ],
  );
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: InsightsScreen.light,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 19, color: InsightsScreen.primary),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: InsightsScreen.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _GuidanceRow extends StatelessWidget {
  const _GuidanceRow({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, color: color, size: 21),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, color: Color(0xFF3E4A46)),
          ),
        ),
      ],
    ),
  );
}

class _RouteMetric extends StatelessWidget {
  const _RouteMetric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: InsightsScreen.light,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: InsightsScreen.primary,
        fontSize: 9,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: InsightsScreen.light,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: InsightsScreen.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: InsightsScreen.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                message,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: InsightsScreen.hot.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: InsightsScreen.hot),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message ?? 'The latest request failed.',
            style: const TextStyle(fontSize: 11, color: InsightsScreen.hot),
          ),
        ),
      ],
    ),
  );
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();
  @override
  Widget build(BuildContext context) =>
      Divider(color: Colors.grey.withValues(alpha: 0.15), height: 17);
}

String _temperature(double? value) =>
    value == null ? '--°C' : '${value.toStringAsFixed(1)}°C';

String _distance(double meters) =>
    meters < 1000
        ? '${meters.round()} m'
        : '${(meters / 1000).toStringAsFixed(1)} km';

String _duration(double seconds) =>
    seconds < 60 ? '< 1 min' : '${(seconds / 60).round()} min';

String _coverage(double? value) =>
    value == null ? '--' : '${(value * 100).toStringAsFixed(0)}%';

String _indicatorValue(double? value, String unit) =>
    value == null ? '--' : '${value.toStringAsFixed(1)}$unit';

String _localTime(String? timestamp) {
  if (timestamp == null || timestamp.isEmpty) return '--:--';
  final match = RegExp(r'T(\d{2}:\d{2})').firstMatch(timestamp);
  return match?.group(1) ?? timestamp;
}

String _meters(double? value) =>
    value == null ? '-- m' : '${value.toStringAsFixed(1)} m';
