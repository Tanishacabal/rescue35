import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../constants/app_colors.dart';

/// Shows a destination pin using flutter_map (OpenStreetMap tiles — no
/// API key needed). `destinationAddress` is expected in "lat, lng" format,
/// which is how pickup locations are now stored since the request form
/// switched to a tap-to-select map instead of free-text address.
///
/// Also tracks the responder's live GPS location and draws the driving
/// route from their current position to the destination using OSRM's
/// free public routing API.
class InAppMapScreen extends StatefulWidget {
  final String destinationAddress;
  const InAppMapScreen({super.key, required this.destinationAddress});

  @override
  State<InAppMapScreen> createState() => _InAppMapScreenState();
}

class _InAppMapScreenState extends State<InAppMapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSub;

  LatLng? _destination;
  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];
  String? _locationError;
  bool _loadingRoute = false;
  double? _distanceMeters;
  double? _durationSeconds;
  bool _hasFitBounds = false;

  @override
  void initState() {
    super.initState();
    _destination = _parseLatLng(widget.destinationAddress);
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  LatLng? _parseLatLng(String value) {
    final parts = value.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Future<void> _startLocationTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationError = 'Location services are turned off.');
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _locationError = 'Location permission denied.');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(
        () => _locationError =
            'Location permission permanently denied. Enable it in app settings.',
      );
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _onPosition(position);
    } catch (_) {
      setState(() => _locationError = 'Unable to get current location.');
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen(_onPosition);
  }

  void _onPosition(Position position) {
    final point = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentLocation = point;
      _locationError = null;
    });

    if (_routePoints.isEmpty && !_loadingRoute) {
      _fetchRoute();
    }
    if (!_hasFitBounds && _destination != null) {
      _hasFitBounds = true;
      _fitBounds();
    }
  }

  Future<void> _fetchRoute() async {
    final origin = _currentLocation;
    final dest = _destination;
    if (origin == null || dest == null) return;

    setState(() => _loadingRoute = true);
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final coords = (route['geometry']['coordinates'] as List)
              .map((c) => LatLng((c as List)[1] as double, c[0] as double))
              .toList();
          setState(() {
            _routePoints = coords;
            _distanceMeters = (route['distance'] as num).toDouble();
            _durationSeconds = (route['duration'] as num).toDouble();
          });
        }
      }
    } catch (_) {
      // Falls back to a straight line between the two points below.
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  void _fitBounds() {
    final origin = _currentLocation;
    final dest = _destination;
    if (origin == null || dest == null) return;

    final bounds = LatLngBounds.fromPoints([origin, dest]);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(48, 100, 48, 48),
      ),
    );
  }

  void _recenter() {
    final origin = _currentLocation;
    if (origin == null) return;
    if (_destination != null) {
      _fitBounds();
    } else {
      _mapController.move(origin, 16);
    }
  }

  String get _etaLabel {
    if (_distanceMeters == null || _durationSeconds == null) return '';
    final km = (_distanceMeters! / 1000).toStringAsFixed(1);
    final mins = (_durationSeconds! / 60).ceil();
    return '$km km · ~$mins min';
  }

  @override
  Widget build(BuildContext context) {
    final dest = _destination;

    if (dest == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pickup Location')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to show this location on the map.\n${widget.destinationAddress}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGray),
            ),
          ),
        ),
      );
    }

    final line = _routePoints.isNotEmpty
        ? _routePoints
        : (_currentLocation != null ? [_currentLocation!, dest] : <LatLng>[]);

    return Scaffold(
      appBar: AppBar(title: const Text('Pickup Location')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: dest,
              initialZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                // Palitan ng actual package name mo.
                userAgentPackageName: 'com.yourapp.rescue',
              ),
              if (line.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: line,
                      strokeWidth: 5,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: dest,
                    width: 46,
                    height: 46,
                    child: const Icon(
                      Icons.location_pin,
                      color: AppColors.primary,
                      size: 46,
                    ),
                  ),
                  if (_currentLocation != null)
                    Marker(
                      point: _currentLocation!,
                      width: 26,
                      height: 26,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_locationError != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _InfoBanner(text: _locationError!),
            )
          else if (_etaLabel.isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _InfoBanner(text: _etaLabel, isError: false),
            )
          else if (_loadingRoute)
            const Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _InfoBanner(text: 'Loading route...', isError: false),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _recenter,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final bool isError;
  const _InfoBanner({required this.text, this.isError = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: isError ? AppColors.primary : AppColors.dark,
        ),
      ),
    );
  }
}