import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'models/thermal_models.dart';
import 'services/heatway_api.dart';
import 'state/heatway_store.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ============================================================
  // HEATWAY COLORS
  // ============================================================

  // Hot
  static const Color hotColor = Color(0xFFE85D4A);

  // Warm
  static const Color creamColor = Color(0xFFF2B84B);

  // Cool
  static const Color coolColor = Color(0xFF5FAF9B);

  // Main brand / Route
  static const Color darkGreen = Color(0xFF176B67);

  // App background
  static const Color backgroundColor = Color(0xFFF7F5F0);

  // ============================================================
  // DEFAULT VIEW — UNITED STATES
  // ============================================================

  static const LatLng defaultLocation = LatLng(39.8283, -98.5795);

  // ============================================================
  // MAP CONTROLLER
  // ============================================================

  final MapController _mapController = MapController();

  // ============================================================
  // GPS
  // ============================================================

  StreamSubscription<Position>? _positionSubscription;
  LatLng? _currentLocation;
  LatLng? _manualStartLocation;
  bool _isLoadingLocation = false;
  bool? _isLocationSupported;
  LatLng? _destination;
  bool _isLoadingRoute = false;
  bool _isSearchingAddress = false;
  bool _isSearchingStartAddress = false;
  bool _selectingStartOnMap = false;
  String? _requestStatus;

  final HeatWayApi _api = HeatWayApi();
  final HeatWayStore _store = HeatWayStore.instance;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _startAddressController = TextEditingController();

  final List<_BoundaryPolygon> _usBoundaries = [];

  static const List<LatLng> _worldMask = [
    LatLng(-85, -179.999),
    LatLng(85, -179.999),
    LatLng(85, 179.999),
    LatLng(-85, 179.999),
  ];

  // Filled later from the backend ranked-routes response.
  List<LatLng> _selectedRoutePoints = [];
  bool _showAlternativeRoutes = true;
  double? _currentTemperature;

  LatLng? get _routeStart => _manualStartLocation ?? _currentLocation;

  bool get _usesManualStart => _manualStartLocation != null;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareMap();
    });
  }

  Future<void> _prepareMap() async {
    final boundaryLoading = _loadUsBoundaries();
    final shouldEnableLocation = await _showLocationWelcomeDialog();

    await boundaryLoading;

    if (!mounted) return;

    if (shouldEnableLocation) {
      await _initializeLocation();
    } else {
      setState(() {
        _isLocationSupported = false;
        _currentLocation = null;
      });
    }
  }

  Future<bool> _showLocationWelcomeDialog() async {
    final shouldEnableLocation = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: const Icon(
            Icons.location_on_rounded,
            color: darkGreen,
            size: 48,
          ),
          title: const Text(
            'Enable your location',
            textAlign: TextAlign.center,
            style: TextStyle(color: darkGreen, fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'HeatWay needs your location to find temperature-aware routes '
            'and recommend the coolest way.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Not now',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: darkGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.my_location),
              label: const Text('Enable location'),
            ),
          ],
        );
      },
    );

    return shouldEnableLocation == true;
  }

  Future<void> _loadUsBoundaries() async {
    final source = await rootBundle.loadString(
      'assets/geo/us_boundaries.geojson',
    );
    final geoJson = jsonDecode(source) as Map<String, dynamic>;
    final features = geoJson['features'] as List;

    for (final feature in features) {
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final type = geometry['type'] as String;
      final coordinates = geometry['coordinates'] as List;

      if (type == 'Polygon') {
        _addBoundaryPolygon(coordinates);
      } else if (type == 'MultiPolygon') {
        for (final polygon in coordinates) {
          _addBoundaryPolygon(polygon as List);
        }
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _addBoundaryPolygon(List coordinates) {
    if (coordinates.isEmpty) return;

    final rings =
        coordinates
            .map<List<LatLng>>((ring) {
              return (ring as List).map<LatLng>((coordinate) {
                final pair = coordinate as List;
                return LatLng(
                  (pair[1] as num).toDouble(),
                  (pair[0] as num).toDouble(),
                );
              }).toList();
            })
            .where((ring) => ring.length >= 3)
            .toList();

    if (rings.isEmpty) return;

    _usBoundaries.add(
      _BoundaryPolygon(outer: rings.first, holes: rings.skip(1).toList()),
    );
  }

  bool _isInsideSupportedUsArea(LatLng point) {
    return _usBoundaries.any((boundary) {
      if (!_isPointInsideRing(point, boundary.outer)) return false;
      return !boundary.holes.any((hole) => _isPointInsideRing(point, hole));
    });
  }

  bool _isPointInsideRing(LatLng point, List<LatLng> ring) {
    var inside = false;
    var previousIndex = ring.length - 1;

    for (var currentIndex = 0; currentIndex < ring.length; currentIndex++) {
      final current = ring[currentIndex];
      final previous = ring[previousIndex];

      final crossesLatitude =
          (current.latitude > point.latitude) !=
          (previous.latitude > point.latitude);

      if (crossesLatitude) {
        final longitudeAtLatitude =
            (previous.longitude - current.longitude) *
                (point.latitude - current.latitude) /
                (previous.latitude - current.latitude) +
            current.longitude;

        if (point.longitude < longitudeAtLatitude) {
          inside = !inside;
        }
      }

      previousIndex = currentIndex;
    }

    return inside;
  }

  bool _acceptPosition(Position position, {bool moveMap = false}) {
    final location = LatLng(position.latitude, position.longitude);
    final supported = _isInsideSupportedUsArea(location);
    final hasManualStart = _manualStartLocation != null;

    if (!mounted) return false;

    setState(() {
      _isLocationSupported = hasManualStart ? true : supported;
      _currentLocation = supported ? location : null;
      _isLoadingLocation = false;
    });

    if (!supported) {
      if (!hasManualStart) {
        _showMessage(
          'HeatWay is currently available only in supported U.S. locations.',
        );
      }
      return false;
    }

    if (_manualStartLocation == null) {
      _store.updateCurrentLocation(location);
    }

    if (moveMap) {
      _mapController.move(location, 15);
    }

    return true;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _addressController.dispose();
    _startAddressController.dispose();
    _api.close();
    super.dispose();
  }

  // ============================================================
  // INITIALIZE GPS
  // ============================================================

  Future<void> _initializeLocation() async {
    final permission = await _checkLocationPermission();

    if (!permission) {
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // ========================================================
      // PRINT INITIAL GPS COORDINATES
      // ========================================================

      debugPrint('========================================');
      debugPrint('📍 INITIAL GPS LOCATION');
      debugPrint('Latitude: ${position.latitude}');
      debugPrint('Longitude: ${position.longitude}');
      debugPrint('Coordinates: (${position.latitude}, ${position.longitude})');
      debugPrint('Accuracy: ${position.accuracy} meters');
      debugPrint('========================================');

      _acceptPosition(position, moveMap: true);
      _startLocationTracking();
    } catch (e) {
      debugPrint('❌ Error getting current location: $e');
    }
  }

  // ============================================================
  // CHECK LOCATION PERMISSION
  // ============================================================

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) return false;

      final openSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Location is turned off'),
            content: const Text(
              'Please turn on your device location to use HeatWay.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Open settings'),
              ),
            ],
          );
        },
      );

      if (openSettings == true) {
        await Geolocator.openLocationSettings();
      }

      return false;
    }

    LocationPermission permission;

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        if (mounted) {
          _showMessage('Location permission was denied.');
        }

        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showMessage(
          'Location permission is permanently denied. '
          'Please enable it from Settings.',
        );
      }

      return false;
    }

    return true;
  }

  // ============================================================
  // LIVE LOCATION TRACKING
  // ============================================================

  void _startLocationTracking() {
    _positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        // ======================================================
        // PRINT LIVE GPS COORDINATES
        // ======================================================

        debugPrint('========================================');
        debugPrint('📍 LIVE GPS UPDATE');
        debugPrint('Latitude: ${position.latitude}');
        debugPrint('Longitude: ${position.longitude}');
        debugPrint(
          'Coordinates: (${position.latitude}, ${position.longitude})',
        );
        debugPrint('Accuracy: ${position.accuracy} meters');
        debugPrint('Speed: ${position.speed} m/s');
        debugPrint('========================================');

        _acceptPosition(position);
      },
      onError: (error) {
        debugPrint('❌ GPS Stream Error: $error');
      },
    );
  }

  // ============================================================
  // GO TO CURRENT LOCATION
  // ============================================================

  Future<void> _goToCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    final permission = await _checkLocationPermission();

    if (!permission) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }

      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // ========================================================
      // PRINT GPS WHEN BUTTON IS PRESSED
      // ========================================================

      debugPrint('========================================');
      debugPrint('📍 CURRENT LOCATION BUTTON');
      debugPrint('Latitude: ${position.latitude}');
      debugPrint('Longitude: ${position.longitude}');
      debugPrint('Coordinates: (${position.latitude}, ${position.longitude})');
      debugPrint('Accuracy: ${position.accuracy} meters');
      debugPrint('========================================');

      if (mounted) {
        setState(() {
          _manualStartLocation = null;
          _selectingStartOnMap = false;
        });
      }
      _acceptPosition(position, moveMap: true);
    } catch (e) {
      debugPrint('❌ Error getting location: $e');

      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });

        _showMessage('Could not get your current location.');
      }
    }
  }

  void _selectManualStart(LatLng point) {
    if (!_isInsideSupportedUsArea(point)) {
      _showMessage('Please choose a starting point inside the United States.');
      return;
    }

    setState(() {
      _manualStartLocation = point;
      _isLocationSupported = true;
      _selectingStartOnMap = false;
      _selectedRoutePoints = [];
      _currentTemperature = null;
      _requestStatus = 'Starting point selected.';
    });
    _store.updateCurrentLocation(point);
    _mapController.move(point, 14);
    _showMessage(
      'Starting point selected: '
      '${point.latitude.toStringAsFixed(5)}, '
      '${point.longitude.toStringAsFixed(5)}',
    );
  }

  Future<void> _showStartLocationOptions() async {
    if (_isLoadingRoute) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose starting point',
                    style: TextStyle(
                      color: darkGreen,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use GPS, search for an address, or select a point on the map.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(
                      Icons.my_location_rounded,
                      color: darkGreen,
                    ),
                    title: const Text('Use my GPS location'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _goToCurrentLocation();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.search_rounded, color: darkGreen),
                    title: const Text('Enter a starting address'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _promptForStartAddress();
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.add_location_alt_outlined,
                      color: darkGreen,
                    ),
                    title: const Text('Select starting point on map'),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      setState(() => _selectingStartOnMap = true);
                      _showMessage(
                        'Tap the map to choose your starting point.',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _promptForStartAddress() async {
    _startAddressController.clear();
    final address = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: const Text(
              'Starting address',
              style: TextStyle(color: darkGreen, fontWeight: FontWeight.w700),
            ),
            content: TextField(
              controller: _startAddressController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted:
                  (value) => Navigator.of(dialogContext).pop(value.trim()),
              decoration: const InputDecoration(
                hintText: 'Enter a U.S. starting address',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: darkGreen),
                onPressed:
                    () => Navigator.of(
                      dialogContext,
                    ).pop(_startAddressController.text.trim()),
                child: const Text('Use address'),
              ),
            ],
          ),
    );

    if (address == null || address.isEmpty || !mounted) return;
    await _searchStartAddress(address);
  }

  Future<void> _searchStartAddress(String address) async {
    if (_usBoundaries.isEmpty) {
      _showMessage('U.S. boundaries are still loading. Try again shortly.');
      return;
    }

    setState(() => _isSearchingStartAddress = true);
    try {
      final query =
          address.toLowerCase().contains('usa') ? address : '$address, USA';
      final results = await geo.locationFromAddress(query);

      LatLng? supportedResult;
      for (final result in results) {
        final candidate = LatLng(result.latitude, result.longitude);
        if (_isInsideSupportedUsArea(candidate)) {
          supportedResult = candidate;
          break;
        }
      }

      if (!mounted) return;
      if (supportedResult == null) {
        _showMessage('No supported U.S. starting point was found.');
        return;
      }
      _selectManualStart(supportedResult);
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showMessage(
        error.code == 'IO_ERROR'
            ? 'Address search is temporarily unavailable. Try again shortly.'
            : 'Could not search this address: ${error.message ?? error.code}',
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Could not find this starting address. Check it and try again.',
      );
    } finally {
      if (mounted) setState(() => _isSearchingStartAddress = false);
    }
  }

  void _selectDestination(LatLng point) {
    if (!_isInsideSupportedUsArea(point)) {
      _showMessage('Please choose a destination inside the United States.');
      return;
    }

    setState(() {
      _destination = point;
      _selectedRoutePoints = [];
      _currentTemperature = null;
      _requestStatus = 'Destination selected. Tap Find route.';
    });
    _store.selectDestination(point);
  }

  Future<void> _searchAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      _showMessage('Enter a U.S. destination address first.');
      return;
    }
    if (_usBoundaries.isEmpty) {
      _showMessage('U.S. boundaries are still loading. Try again shortly.');
      return;
    }

    setState(() => _isSearchingAddress = true);
    FocusManager.instance.primaryFocus?.unfocus();

    try {
      final query =
          address.toLowerCase().contains('usa') ? address : '$address, USA';
      final results = await geo.locationFromAddress(query);

      LatLng? supportedResult;
      for (final result in results) {
        final candidate = LatLng(result.latitude, result.longitude);
        if (_isInsideSupportedUsArea(candidate)) {
          supportedResult = candidate;
          break;
        }
      }

      if (!mounted) return;
      if (supportedResult == null) {
        _showMessage('No supported U.S. location was found for this address.');
        return;
      }

      _selectDestination(supportedResult);
      _mapController.move(supportedResult, 14);
      _showMessage(
        'Destination selected: '
        '${supportedResult.latitude.toStringAsFixed(5)}, '
        '${supportedResult.longitude.toStringAsFixed(5)}',
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showMessage(
        error.code == 'IO_ERROR'
            ? 'Address search is temporarily unavailable. Try again shortly.'
            : 'Could not search this address: ${error.message ?? error.code}',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not find this address. Check it and try again.');
    } finally {
      if (mounted) {
        setState(() => _isSearchingAddress = false);
      }
    }
  }

  Future<void> _findCoolerRoute() async {
    final start = _routeStart;
    final destination = _destination;

    if (start == null) {
      _showMessage('Choose a GPS or manual starting point first.');
      return;
    }
    if (destination == null) {
      _showMessage(
        'Enter a U.S. address or tap the map to choose your destination.',
      );
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _requestStatus = 'Creating the thermal heatmap...';
    });
    _store.beginHeatmapRequest();

    try {
      // Center the thermal square between the two endpoints so the heatmap
      // covers the route corridor instead of only the user's starting point.
      final routeMidpoint = LatLng(
        (start.latitude + destination.latitude) / 2,
        (start.longitude + destination.longitude) / 2,
      );
      final heatmapCenter =
          _isInsideSupportedUsArea(routeMidpoint) ? routeMidpoint : start;

      final heatmap = await _api.createHeatmap(
        latitude: heatmapCenter.latitude,
        longitude: heatmapCenter.longitude,
      );

      if (!mounted) return;
      _store.saveHeatmap(heatmap);
      setState(() => _requestStatus = 'Finding and ranking routes...');

      final route = await _api.rankRoutes(
        thermalDataId: heatmap.thermalDataId,
        startLatitude: start.latitude,
        startLongitude: start.longitude,
        endLatitude: destination.latitude,
        endLongitude: destination.longitude,
      );

      if (!mounted) return;
      _store.saveRoutes(route);
      unawaited(_loadInsights(heatmap, start));
      setState(() {
        _selectedRoutePoints = route.points;
        _showAlternativeRoutes = true;
        _currentTemperature = _nearestTemperature(heatmap, start);
        _isLoadingRoute = false;
        _requestStatus =
            '${route.temperaturePreference == 'warmer' ? 'Warmest' : 'Coolest'}: '
            '${route.averageTemperature.toStringAsFixed(1)}°C · '
            '${(route.distanceMeters / 1000).toStringAsFixed(1)} km · '
            '${_formatDuration(route.durationSeconds)}';
      });

      _mapController.move(route.points[route.points.length ~/ 2], 13);
      _showRankedRoutesMessage(route);
    } on HeatWayApiException catch (error) {
      if (!mounted) return;
      _store.saveFailure(error.message);
      setState(() {
        _isLoadingRoute = false;
        _requestStatus = null;
      });
      _showMessage(error.message);
    } catch (error) {
      if (!mounted) return;
      _store.saveFailure('Could not create the route: $error');
      setState(() {
        _isLoadingRoute = false;
        _requestStatus = null;
      });
      _showMessage('Could not create the route: $error');
    }
  }

  Future<void> _loadInsights(HeatmapResult heatmap, LatLng location) async {
    _store.beginInsightsRequest();
    try {
      final insights = await _api.createInsights(
        thermalDataId: heatmap.thermalDataId,
        latitude: location.latitude,
        longitude: location.longitude,
      );
      _store.saveInsights(insights);
    } on HeatWayApiException catch (error) {
      _store.saveInsightsFailure(error.message);
    } catch (error) {
      _store.saveInsightsFailure('Could not generate insights: $error');
    }
  }

  double? _nearestTemperature(HeatmapResult heatmap, LatLng location) {
    if (heatmap.points.isEmpty) return null;

    const distance = Distance();
    ThermalPoint nearest = heatmap.points.first;
    var nearestMeters = distance(location, nearest.location);

    for (final point in heatmap.points.skip(1)) {
      final meters = distance(location, point.location);
      if (meters < nearestMeters) {
        nearest = point;
        nearestMeters = meters;
      }
    }
    return nearest.averageTemperature;
  }

  List<Polyline> _routePolylines() {
    final result = _store.routeResult;
    if (result == null) {
      return [
        if (_selectedRoutePoints.isNotEmpty)
          Polyline(
            points: _selectedRoutePoints,
            strokeWidth: 7,
            color: darkGreen,
          ),
      ];
    }

    final preferred = result.preferredRoute;
    final polylines = <Polyline>[];

    if (_showAlternativeRoutes) {
      for (final route in result.rankedRoutes) {
        if (route.routeId == preferred.routeId) continue;
        polylines.add(
          Polyline(
            points: route.points,
            strokeWidth: 3,
            color: _alternativeRouteColor(route.thermalRank),
          ),
        );
      }
    }

    // Add the preferred route last so it is always drawn above alternatives.
    polylines.add(
      Polyline(points: preferred.points, strokeWidth: 8, color: darkGreen),
    );
    return polylines;
  }

  Color _alternativeRouteColor(int rank) {
    const colors = [
      Color(0xFF6096A6),
      Color(0xFFB79052),
      Color(0xFF8B78A8),
      Color(0xFFB26F68),
      Color(0xFF708B75),
    ];
    final index = (rank <= 1 ? 0 : rank - 2) % colors.length;
    return colors[index].withValues(alpha: 0.68);
  }

  void _showRankedRoutesMessage(RouteResult result) {
    final alternatives =
        result.rankedRoutes
            .where((route) => route.routeId != result.preferredRoute.routeId)
            .length;
    if (alternatives == 0 || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$alternatives alternative route'
          '${alternatives == 1 ? '' : 's'} displayed. '
          'The preferred route is highlighted.',
        ),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Hide',
          onPressed: () {
            if (!mounted) return;
            setState(() => _showAlternativeRoutes = false);
          },
        ),
      ),
    );
  }

  String _formatDuration(double durationSeconds) {
    if (durationSeconds < 60) return '< 1 min';
    return '${(durationSeconds / 60).round()} min';
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ======================================================
            // HEADER
            // ======================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HeatWay',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          _routeStart == null && _isLocationSupported == false
                              ? 'United States only'
                              : _routeStart == null
                              ? 'Waiting for location...'
                              : _usesManualStart
                              ? 'Selected starting point'
                              : 'Current location',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: darkGreen,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // CURRENT LOCATION BUTTON
                  // ==================================================
                  GestureDetector(
                    onTap: _showStartLocationOptions,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child:
                          _isLoadingLocation || _isSearchingStartAddress
                              ? const Padding(
                                padding: EdgeInsets.all(13),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: darkGreen,
                                ),
                              )
                              : Icon(
                                _usesManualStart
                                    ? Icons.edit_location_alt_outlined
                                    : Icons.my_location,
                                color: darkGreen,
                              ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: _showStartLocationOptions,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.trip_origin_rounded,
                          color: coolColor,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Starting point',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _routeStart == null
                                    ? 'Choose GPS or enter a location'
                                    : _usesManualStart
                                    ? 'Selected manually'
                                    : 'Using GPS location',
                                style: const TextStyle(
                                  color: darkGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: darkGreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _addressController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchAddress(),
                  decoration: InputDecoration(
                    hintText: 'Enter a U.S. destination address',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: darkGreen,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Search address',
                      onPressed: _isSearchingAddress ? null : _searchAddress,
                      icon:
                          _isSearchingAddress
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: darkGreen,
                                ),
                              )
                              : const Icon(
                                Icons.arrow_forward_rounded,
                                color: darkGreen,
                              ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                  ),
                ),
              ),
            ),

            // ======================================================
            // MAP
            // ======================================================
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // ==================================================
                      // OPEN STREET MAP
                      // ==================================================
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: defaultLocation,
                          initialZoom: 4,
                          minZoom: 3,
                          maxZoom: 18,
                          onTap: (_, point) {
                            if (_selectingStartOnMap) {
                              _selectManualStart(point);
                            } else {
                              _selectDestination(point);
                            }
                          },
                        ),
                        children: [
                          // =================================================
                          // MAP TILES
                          // =================================================
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.example.street_temperature',
                          ),

                          // Everything outside the supported U.S. boundaries
                          // is dimmed. The boundary polygons are transparent
                          // holes in this world-sized overlay.
                          if (_usBoundaries.isNotEmpty)
                            PolygonLayer(
                              polygons: [
                                Polygon(
                                  points: _worldMask,
                                  holePointsList:
                                      _usBoundaries
                                          .map((boundary) => boundary.outer)
                                          .toList(),
                                  color: Colors.blueGrey.withValues(
                                    alpha: 0.58,
                                  ),
                                  borderStrokeWidth: 0,
                                  disableHolesBorder: true,
                                ),
                              ],
                            ),

                          // =================================================
                          // RECOMMENDED ROUTE
                          // =================================================
                          if (_selectedRoutePoints.isNotEmpty)
                            PolylineLayer(polylines: _routePolylines()),

                          // =================================================
                          // LIVE GPS MARKER
                          // =================================================
                          if (_routeStart != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _routeStart!,
                                  width: 55,
                                  height: 55,
                                  child:
                                      _usesManualStart
                                          ? _locationMarker(
                                            Icons.trip_origin_rounded,
                                            coolColor,
                                          )
                                          : _currentLocationMarker(),
                                ),
                              ],
                            ),

                          if (_destination != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _destination!,
                                  width: 52,
                                  height: 52,
                                  child: _locationMarker(
                                    Icons.location_on,
                                    hotColor,
                                  ),
                                ),
                              ],
                            ),

                          // =================================================
                          // OSM ATTRIBUTION
                          // =================================================
                          RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                              ),
                            ],
                          ),
                        ],
                      ),

                      // ======================================================
                      // MAP CONTROLS
                      // ======================================================
                      Positioned(
                        top: 14,
                        right: 14,
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                _mapController.move(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom + 1,
                                );
                              },
                              child: _mapButton(Icons.add),
                            ),

                            const SizedBox(height: 8),

                            GestureDetector(
                              onTap: () {
                                _mapController.move(
                                  _mapController.camera.center,
                                  _mapController.camera.zoom - 1,
                                );
                              },
                              child: _mapButton(Icons.remove),
                            ),
                          ],
                        ),
                      ),

                      if (_isLocationSupported == false)
                        Positioned(
                          left: 18,
                          right: 18,
                          top: 18,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.96),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.location_off, color: hotColor),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'HeatWay is available only in supported '
                                    'U.S. locations.',
                                    style: TextStyle(
                                      color: darkGreen,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      Positioned(
                        right: 14,
                        bottom: 66,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: darkGreen,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _isLoadingRoute ? null : _findCoolerRoute,
                          icon:
                              _isLoadingRoute
                                  ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.alt_route_rounded,
                                    size: 19,
                                  ),
                          label: Text(
                            _isLoadingRoute ? 'Please wait' : 'Find route',
                          ),
                        ),
                      ),

                      if ((_store.routeResult?.rankedRoutes.length ?? 0) > 1)
                        Positioned(
                          left: 14,
                          bottom: 66,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.95,
                              ),
                              foregroundColor: darkGreen,
                              side: const BorderSide(color: darkGreen),
                            ),
                            onPressed: () {
                              setState(() {
                                _showAlternativeRoutes =
                                    !_showAlternativeRoutes;
                              });
                            },
                            icon: Icon(
                              _showAlternativeRoutes
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                            ),
                            label: Text(
                              _showAlternativeRoutes
                                  ? 'Hide alternatives'
                                  : 'Show alternatives',
                            ),
                          ),
                        ),

                      // ======================================================
                      // LEGEND
                      // ======================================================
                      Positioned(
                        left: 14,
                        bottom: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              _LegendItem(color: coolColor, label: 'Cool'),

                              SizedBox(width: 10),

                              _LegendItem(color: creamColor, label: 'Warm'),

                              SizedBox(width: 10),

                              _LegendItem(color: hotColor, label: 'Hot'),

                              SizedBox(width: 10),

                              _LegendItem(color: darkGreen, label: 'Route'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ======================================================
            // CURRENT TEMPERATURE CARD
            // ======================================================
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // ==================================================
                    // ICON
                    // ==================================================
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: creamColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.thermostat_rounded,
                        color: darkGreen,
                        size: 30,
                      ),
                    ),

                    const SizedBox(width: 14),

                    // ==================================================
                    // TEMPERATURE
                    // ==================================================
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current temperature',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            _currentTemperature == null
                                ? '--°C'
                                : '${_currentTemperature!.toStringAsFixed(1)}°C',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: darkGreen,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ==================================================
                    // FEELS LIKE
                    // ==================================================
                    SizedBox(
                      width: 145,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _store.preferredRoute != null
                                ? 'Preferred route'
                                : _isLoadingRoute
                                ? 'Waiting for route'
                                : 'No route selected',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            _requestStatus ??
                                (_currentTemperature == null
                                    ? 'Enter address or tap map'
                                    : 'Updated recently'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOCATION MARKER
  // ============================================================

  Widget _locationMarker(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 25),
    );
  }

  // ============================================================
  // CURRENT GPS MARKER
  // ============================================================

  Widget _currentLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer circle
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: coolColor.withValues(alpha: 0.20),
            shape: BoxShape.circle,
          ),
        ),

        // Inner circle
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: coolColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MAP BUTTON
  // ============================================================

  Widget _mapButton(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6),
        ],
      ),
      child: Icon(icon, size: 20, color: darkGreen),
    );
  }
}

class _BoundaryPolygon {
  final List<LatLng> outer;
  final List<List<LatLng>> holes;

  const _BoundaryPolygon({required this.outer, required this.holes});
}

// ================================================================
// LEGEND ITEM
// ================================================================

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),

        const SizedBox(width: 4),

        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
