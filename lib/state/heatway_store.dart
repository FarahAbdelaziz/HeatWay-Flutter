import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/thermal_models.dart';

enum HeatWayRequestStage {
  idle,
  loadingHeatmap,
  loadingRoutes,
  completed,
  failed,
}

class HeatWayStore extends ChangeNotifier {
  HeatWayStore._();

  static final HeatWayStore instance = HeatWayStore._();

  LatLng? currentLocation;
  LatLng? destination;

  HeatmapResult? heatmap;
  RouteResult? routeResult;
  ThermalInsightsResult? insights;

  bool insightsLoading = false;
  String? insightsError;

  HeatWayRequestStage stage = HeatWayRequestStage.idle;
  String? errorMessage;

  // The thermal data ID returned by the most recent
  // successful heatmap request.
  String? get thermalDataId => heatmap?.thermalDataId;

  bool get hasValidThermalDataId {
    final id = thermalDataId;
    return id != null && id.trim().isNotEmpty;
  }

  bool get isLoading {
    return stage == HeatWayRequestStage.loadingHeatmap ||
        stage == HeatWayRequestStage.loadingRoutes;
  }

  List<ThermalRoute> get rankedRoutes {
    return routeResult?.rankedRoutes ?? const <ThermalRoute>[];
  }

  ThermalRoute? get preferredRoute {
    return routeResult?.preferredRoute;
  }

  void updateCurrentLocation(LatLng location) {
    currentLocation = location;
    notifyListeners();
  }

  void selectDestination(LatLng location) {
    destination = location;
    routeResult = null;
    insights = null;
    insightsError = null;
    insightsLoading = false;
    errorMessage = null;
    stage = HeatWayRequestStage.idle;
    notifyListeners();
  }

  void beginHeatmapRequest() {
    // Remove the old thermal data ID before starting a new
    // heatmap request. This prevents routes and insights from
    // using an ID from an older location.
    heatmap = null;
    routeResult = null;
    insights = null;
    insightsError = null;
    insightsLoading = false;
    errorMessage = null;
    stage = HeatWayRequestStage.loadingHeatmap;
    notifyListeners();
  }

  void saveHeatmap(HeatmapResult result) {
    if (result.thermalDataId.trim().isEmpty) {
      throw const HeatWayStoreException(
        'Cannot save an empty thermal data ID.',
      );
    }

    if (result.points.isEmpty) {
      throw const HeatWayStoreException(
        'Cannot save a heatmap without thermal nodes.',
      );
    }

    heatmap = result;
    errorMessage = null;
    stage = HeatWayRequestStage.loadingRoutes;
    notifyListeners();
  }

  void saveRoutes(RouteResult result) {
    routeResult = result;
    errorMessage = null;
    stage = HeatWayRequestStage.completed;
    notifyListeners();
  }

  void beginInsightsRequest() {
    insights = null;
    insightsError = null;
    insightsLoading = true;
    notifyListeners();
  }

  void saveInsights(ThermalInsightsResult result) {
    insights = result;
    insightsError = null;
    insightsLoading = false;
    notifyListeners();
  }

  void saveInsightsFailure(String message) {
    insightsError = message;
    insightsLoading = false;
    notifyListeners();
  }

  void saveFailure(String message) {
    errorMessage = message;
    stage = HeatWayRequestStage.failed;
    notifyListeners();
  }

  void reset() {
    destination = null;
    heatmap = null;
    routeResult = null;
    insights = null;
    insightsError = null;
    insightsLoading = false;
    errorMessage = null;
    stage = HeatWayRequestStage.idle;
    notifyListeners();
  }
}

class HeatWayStoreException implements Exception {
  const HeatWayStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
