import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'mapbox_service.dart';

class EnhancedLocationService extends ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;
  bool _permissionGranted = false;
  String? _currentAddress;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get permissionGranted => _permissionGranted;
  String? get currentAddress => _currentAddress;

  Future<void> initializeLocation() async {
    _setLoading(true);
    _error = null;
    
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS.');
      }

      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied. Please grant location access.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable in settings.');
      }

      _permissionGranted = true;
      
      // Get current position
      await getCurrentLocation();
      
    } catch (e) {
      _error = e.toString();
      print('Location initialization error: $e');
      // Fallback to Karachi center coordinates
      _currentPosition = Position(
        longitude: 67.0011, // Karachi center longitude
        latitude: 24.8607,  // Karachi center latitude
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> getCurrentLocation() async {
    if (!_permissionGranted) {
      await initializeLocation();
      return;
    }
    
    _setLoading(true);
    _error = null;
    
    try {
      // Try to get last known position first (faster)
      Position? lastKnownPosition = await Geolocator.getLastKnownPosition();
      if (lastKnownPosition != null) {
        print('📍 LocationService: Using last known position: ${lastKnownPosition.latitude}, ${lastKnownPosition.longitude}');
        print('📍 LocationService: Accuracy: ${lastKnownPosition.accuracy}m, Age: ${DateTime.now().difference(lastKnownPosition.timestamp).inMinutes} minutes');
        
        // Only use last known position if it's recent (less than 5 minutes old)
        if (DateTime.now().difference(lastKnownPosition.timestamp).inMinutes < 5) {
          _currentPosition = lastKnownPosition;
          await _resolveAddress();
          _setLoading(false);
          return;
        } else {
          print('📍 LocationService: Last known position is too old, getting fresh location');
        }
      }

      // Get current position with better accuracy settings
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 30), // Increased timeout
        forceAndroidLocationManager: false, // Use Google Play Services if available
      );
      
      print('📍 LocationService: Got fresh current position: ${position.latitude}, ${position.longitude}');
      print('📍 LocationService: Accuracy: ${position.accuracy}m, Timestamp: ${position.timestamp}');
      _currentPosition = position;
      await _resolveAddress();
      
    } catch (e) {
      _error = 'Failed to get current location: ${e.toString()}';
      print('Location error: $e');
      
      // Use last known position or fallback to Karachi center
      if (_currentPosition == null) {
        _currentPosition = Position(
          longitude: 67.0011, // Karachi center longitude
          latitude: 24.8607,  // Karachi center latitude
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
        print('⚠️ LocationService: Using fallback coordinates for Karachi center - this may cause incorrect distances!');
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _resolveAddress() async {
    if (_currentPosition == null) return;
    
    try {
      _currentAddress = await MapboxService.getAddressFromCoordinates(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      notifyListeners();
    } catch (e) {
      print('Error resolving address: $e');
      _currentAddress = null;
    }
  }

  Future<String?> getAddressForCoordinates(double latitude, double longitude) async {
    try {
      return await MapboxService.getAddressFromCoordinates(latitude, longitude);
    } catch (e) {
      print('Error getting address for coordinates: $e');
      return null;
    }
  }

  Future<Map<String, double>?> getCoordinatesForAddress(String address) async {
    try {
      return await MapboxService.getCoordinatesFromAddress(address);
    } catch (e) {
      print('Error getting coordinates for address: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyPlaces({double radius = 1000}) async {
    if (_currentPosition == null) return [];
    
    try {
      return await MapboxService.getNearbyPlaces(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        radius: radius,
      );
    } catch (e) {
      print('Error getting nearby places: $e');
      return [];
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  /// Force refresh current location with high accuracy
  Future<void> refreshLocation() async {
    print('🔄 LocationService: Force refreshing location...');
    _setLoading(true);
    _error = null;
    
    try {
      // Force get current position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 45), // Longer timeout for better accuracy
        forceAndroidLocationManager: false,
      );
      
      print('📍 LocationService: Refreshed position: ${position.latitude}, ${position.longitude}');
      print('📍 LocationService: Accuracy: ${position.accuracy}m, Timestamp: ${position.timestamp}');
      
      _currentPosition = position;
      await _resolveAddress();
      
    } catch (e) {
      _error = 'Failed to refresh location: ${e.toString()}';
      print('❌ LocationService: Refresh error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Check if current location is in Karachi area
  bool isInKarachiArea() {
    if (_currentPosition == null) return false;
    
    // Karachi bounding box (roughly)
    const double karachiMinLat = 24.7;
    const double karachiMaxLat = 25.2;
    const double karachiMinLng = 66.8;
    const double karachiMaxLng = 67.4;
    
    return _currentPosition!.latitude >= karachiMinLat && 
           _currentPosition!.latitude <= karachiMaxLat &&
           _currentPosition!.longitude >= karachiMinLng && 
           _currentPosition!.longitude <= karachiMaxLng;
  }

  /// Get distance to a location in meters
  double getDistanceTo(double latitude, double longitude) {
    if (_currentPosition == null) return double.infinity;
    
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      latitude,
      longitude,
    );
  }

  /// Get formatted distance string
  String getFormattedDistanceTo(double latitude, double longitude) {
    double distance = getDistanceTo(latitude, longitude);
    
    if (distance < 1000) {
      return '${distance.round()}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }
} 