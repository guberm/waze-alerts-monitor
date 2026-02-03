import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/waze_service.dart';
import '../models/alert_model.dart';

class HomeScreen extends StatefulWidget {
  final Function(bool)? onThemeChanged;
  
  const HomeScreen({Key? key, this.onThemeChanged}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late FlutterTts flutterTts;
  late WazeService wazeService;
  late SharedPreferences prefs;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  
  bool isMonitoring = false;
  bool isLoadingLocation = false;
  Position? currentPosition;
  String currentAddress = '';
  List<AlertModel> alerts = [];
  String region = 'row';
  double searchRadius = 1.0; // km
  int refreshInterval = 60; // seconds (default 60s = 1 min)
  bool isDarkMode = false;
  bool showPolice = true;
  bool showHazard = true;
  bool showAccident = true;
  bool showSpeedCamera = true;
  bool showRedLightCamera = false; // Disabled by default
  
  // Address caching
  Map<String, String> addressCache = {};
  StreamSubscription<Position>? positionStream;
  
  Timer? monitoringTimer;
  Set<String> announcedAlerts = {};

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    wazeService = WazeService();
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    prefs = await SharedPreferences.getInstance();
    await _loadConfig();
    await _initializeNotifications();
    _initializeTTS();
    _requestPermissions();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _loadConfig() async {
    setState(() {
      searchRadius = prefs.getDouble('searchRadius') ?? 1.0;
      region = prefs.getString('region') ?? 'row';
      refreshInterval = prefs.getInt('refreshInterval') ?? 60; // Default 60 seconds
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
      showPolice = prefs.getBool('showPolice') ?? true;
      showHazard = prefs.getBool('showHazard') ?? true;
      showAccident = prefs.getBool('showAccident') ?? true;
      showSpeedCamera = prefs.getBool('showSpeedCamera') ?? true;
      showRedLightCamera = prefs.getBool('showRedLightCamera') ?? false; // Default disabled
    });
  }

  Future<void> _saveConfig() async {
    await prefs.setDouble('searchRadius', searchRadius);
    await prefs.setString('region', region);
    await prefs.setInt('refreshInterval', refreshInterval);
    await prefs.setBool('isDarkMode', isDarkMode);
    await prefs.setBool('showPolice', showPolice);
    await prefs.setBool('showHazard', showHazard);
    await prefs.setBool('showAccident', showAccident);
    await prefs.setBool('showSpeedCamera', showSpeedCamera);
    await prefs.setBool('showRedLightCamera', showRedLightCamera);
  }

  Future<void> _initializeTTS() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.8);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
    
    flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _requestPermissions() async {
    // Check current permission status first
    var locationStatus = await Permission.location.status;
    
    bool needsRequest = false;
    
    // Only request if not granted
    if (!locationStatus.isGranted) {
      locationStatus = await Permission.location.request();
      needsRequest = true;
    }
    
    // Show dialog only if we asked AND were denied
    if (needsRequest && !locationStatus.isGranted) {
      _showDialog('Permissions Required', 'Location permission is needed for this app to work.');
    }
    
    // Auto-start monitoring if location permission is granted
    if (locationStatus.isGranted) {
      // Wait longer for location services to be ready
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        try {
          await _getCurrentLocation();
          await _startMonitoring();
        } catch (e) {
          _showSnackBar('Error starting monitoring: $e');
        }
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => isLoadingLocation = true);
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Location request timed out');
        },
      );
      
      setState(() {
        currentPosition = position;
        isLoadingLocation = false;
      });
      
      // Get address
      await _getAddressFromCoordinates(position.latitude, position.longitude);
      
      // Auto-detect region
      _detectRegion(position.latitude, position.longitude);
      
      _showSnackBar('Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}');
    } catch (e) {
      setState(() => isLoadingLocation = false);
      _showSnackBar('Error getting location: $e');
    }
  }

  Future<void> _getAddressFromCoordinates(double lat, double lon) async {
    // Create cache key with 3 decimal precision (~ 100m accuracy)
    final cacheKey = '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';
    
    // Check cache first
    if (addressCache.containsKey(cacheKey)) {
      setState(() {
        currentAddress = addressCache[cacheKey]!;
      });
      return;
    }
    
    try {
      final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'WazeAlertsApp/1.0'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['display_name'] ?? 'Unknown location';
        setState(() {
          currentAddress = address;
        });
        // Cache the address
        addressCache[cacheKey] = address;
        // Limit cache size to prevent memory issues
        if (addressCache.length > 50) {
          addressCache.remove(addressCache.keys.first);
        }
      }
    } catch (e) {
      setState(() => currentAddress = 'Address not available');
    }
  }

  void _detectRegion(double lat, double lon) {
    // North America: roughly between 15°-85° N, -170° to -50° W
    if (lat >= 15 && lat <= 85 && lon >= -170 && lon <= -50) {
      setState(() => region = 'na');
    }
    // Israel: roughly 29°-33° N, 34°-36° E
    else if (lat >= 29 && lat <= 33 && lon >= 34 && lon <= 36) {
      setState(() => region = 'il');
    }
    // Rest of World
    else {
      setState(() => region = 'row');
    }
    _saveConfig();
  }

  Future<void> _fetchAlerts() async {
    if (currentPosition == null) {
      _showSnackBar('Please get your location first');
      return;
    }

    try {
      final radius = searchRadius / 111.0; // Convert km to degrees
      final top = currentPosition!.latitude + radius;
      final bottom = currentPosition!.latitude - radius;
      final left = currentPosition!.longitude - radius;
      final right = currentPosition!.longitude + radius;

      final data = await wazeService.fetchAlerts(top, bottom, left, right, region);
      
      // Filter alerts based on user preferences
      final filteredAlerts = data.where((alert) {
        switch (alert.type) {
          case 'POLICE':
            return showPolice;
          case 'HAZARD':
            return showHazard;
          case 'ACCIDENT':
            return showAccident;
          case 'SPEED_CAMERA':
            return showSpeedCamera;
          case 'RED_LIGHT_CAMERA':
            return showRedLightCamera;
          default:
            return true;
        }
      }).toList();
      
      setState(() {
        alerts = filteredAlerts;
      });

      if (alerts.isNotEmpty) {
        _announceAlerts();
        _updateMonitoringNotification();
      } else {
        _showSnackBar('No alerts found in your area');
      }
    } catch (e) {
      _showSnackBar('Error fetching alerts: $e');
    }
  }

  Future<void> _startMonitoring() async {
    if (currentPosition == null) {
      _showSnackBar('Please get your location first');
      return;
    }

    setState(() => isMonitoring = true);
    announcedAlerts.clear();
    final intervalText = refreshInterval < 60 ? '$refreshInterval sec' : '${(refreshInterval / 60).toStringAsFixed(0)} min';
    _showSnackBar('Monitoring started (every $intervalText)');
    
    // Show persistent notification
    _showMonitoringNotification();

    // Start real-time location tracking
    _startLocationTracking();

    // Periodic alert fetching based on refresh interval
    monitoringTimer = Timer.periodic(Duration(seconds: refreshInterval), (_) async {
      if (currentPosition != null) {
        await _fetchAlerts();
      }
    });
  }
  
  void _startLocationTracking() {
    // Real-time location tracking with high accuracy
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // Update every 50 meters
    );
    
    positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        if (mounted) {
          setState(() {
            currentPosition = position;
          });
          // Update address with caching
          _getAddressFromCoordinates(position.latitude, position.longitude);
        }
      },
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );
  }

  void _stopMonitoring() {
    monitoringTimer?.cancel();
    positionStream?.cancel();
    setState(() => isMonitoring = false);
    flutterLocalNotificationsPlugin.cancel(1);
    _showSnackBar('Monitoring stopped');
  }

  Future<void> _showMonitoringNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'waze_alerts_channel',
      'Waze Alerts',
      channelDescription: 'Real-time Waze alert monitoring',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      1,
      'Waze Alerts Monitoring',
      'Monitoring active - ${refreshInterval < 60 ? "$refreshInterval sec" : "${(refreshInterval / 60).toStringAsFixed(0)} min"} interval',
      platformChannelSpecifics,
    );
  }

  Future<void> _updateMonitoringNotification() async {
    if (alerts.isEmpty || currentPosition == null) return;
    
    // Find closest alert
    AlertModel? closestAlert;
    double closestDistance = double.infinity;
    
    for (final alert in alerts) {
      if (alert.latitude != null && alert.longitude != null) {
        final distance = Geolocator.distanceBetween(
          currentPosition!.latitude,
          currentPosition!.longitude,
          alert.latitude!,
          alert.longitude!,
        );
        
        if (distance < closestDistance) {
          closestDistance = distance;
          closestAlert = alert;
        }
      }
    }
    
    if (closestAlert != null) {
      String typeEmoji = '';
      switch (closestAlert.type) {
        case 'POLICE':
          typeEmoji = '🚔';
          break;
        case 'HAZARD':
          typeEmoji = '⚠️';
          break;
        case 'ACCIDENT':
          typeEmoji = '🚨';
          break;
        case 'SPEED_CAMERA':
          typeEmoji = '📸';
          break;
        case 'RED_LIGHT_CAMERA':
          typeEmoji = '🚦';
          break;
        default:
          typeEmoji = '📍';
      }
      
      final distanceKm = (closestDistance / 1000).toStringAsFixed(1);
      final notificationTitle = '$typeEmoji ${closestAlert.type}';
      final notificationBody = '${closestAlert.street} (${distanceKm}km away)';
      
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'waze_alerts_channel',
        'Waze Alerts',
        channelDescription: 'Real-time Waze alert monitoring',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);
      
      await flutterLocalNotificationsPlugin.show(
        1,
        notificationTitle,
        notificationBody,
        platformChannelSpecifics,
      );
    }
  }

  Future<void> _announceAlerts() async {
    for (final alert in alerts) {
      final alertKey = '${alert.type}_${alert.street}_${alert.city}';
      
      if (!announcedAlerts.contains(alertKey)) {
        announcedAlerts.add(alertKey);
        
        final message = _buildAlertMessage(alert);
        await flutterTts.speak(message);
        
        // Wait for speech to complete
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  String _buildAlertMessage(AlertModel alert) {
    String typeMessage = '';
    switch (alert.type) {
      case 'POLICE':
        typeMessage = 'Police ahead';
        break;
      case 'HAZARD':
        typeMessage = 'Hazard on road';
        break;
      case 'ACCIDENT':
        typeMessage = 'Accident reported';
        break;
      default:
        typeMessage = alert.type;
    }

    return '$typeMessage at ${alert.street}, ${alert.city}';
  }

  Future<void> _openWazeNavigation(AlertModel alert) async {
    if (alert.latitude == null || alert.longitude == null) {
      _showSnackBar('Location data not available');
      return;
    }

    try {
      // Try native Waze scheme first
      final wazeUrl = 'waze://?ll=${alert.latitude},${alert.longitude}';
      final fallbackUrl = 'https://waze.com/ul?ll=${alert.latitude},${alert.longitude}';
      
      try {
        if (await canLaunchUrl(Uri.parse(wazeUrl))) {
          await launchUrl(Uri.parse(wazeUrl));
        } else {
          // Fallback to web URL
          await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        // If waze scheme fails, use web URL
        await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _showSnackBar('Could not open Waze: $e');
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Menu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                _showSettingsDialog();
              },
            ),
            ListTile(
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                _showDialog('About', 'Waze Alerts Monitor v1.0.0\n\nReal-time alert notifications with voice');
              },
            ),
            ListTile(
              title: const Text('Exit'),
              onTap: () {
                Navigator.pop(context);
                _exitApp();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    double tempRadius = searchRadius;
    int tempInterval = refreshInterval;
    String tempRegion = region;
    bool tempDarkMode = isDarkMode;
    bool tempShowPolice = showPolice;
    bool tempShowHazard = showHazard;
    bool tempShowAccident = showAccident;
    bool tempShowSpeedCamera = showSpeedCamera;
    bool tempShowRedLightCamera = showRedLightCamera;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                    Switch(
                      value: tempDarkMode,
                      onChanged: (value) {
                        setDialogState(() => tempDarkMode = value);
                        setState(() {
                          isDarkMode = value;
                        });
                        _saveConfig();
                        if (widget.onThemeChanged != null) {
                          widget.onThemeChanged!(value);
                        }
                      },
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Alert Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('🚔 Police'),
                  value: tempShowPolice,
                  onChanged: (value) {
                    setDialogState(() => tempShowPolice = value ?? true);
                  },
                ),
                CheckboxListTile(
                  title: const Text('⚠️ Hazard'),
                  value: tempShowHazard,
                  onChanged: (value) {
                    setDialogState(() => tempShowHazard = value ?? true);
                  },
                ),
                CheckboxListTile(
                  title: const Text('🚨 Accident'),
                  value: tempShowAccident,
                  onChanged: (value) {
                    setDialogState(() => tempShowAccident = value ?? true);
                  },
                ),
                CheckboxListTile(
                  title: const Text('📸 Speed Camera'),
                  value: tempShowSpeedCamera,
                  onChanged: (value) {
                    setDialogState(() => tempShowSpeedCamera = value ?? true);
                  },
                ),
                CheckboxListTile(
                  title: const Text('🚦 Red Light Camera'),
                  value: tempShowRedLightCamera,
                  onChanged: (value) {
                    setDialogState(() => tempShowRedLightCamera = value ?? true);
                  },
                ),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Search Radius (km)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${tempRadius.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (double radius in <double>[0.3, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0])
                      ElevatedButton(
                        onPressed: () {
                          setDialogState(() => tempRadius = radius);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (tempRadius - radius).abs() < 0.01 ? Colors.blue : Colors.grey[300],
                          foregroundColor: (tempRadius - radius).abs() < 0.01 ? Colors.white : Colors.black,
                          minimumSize: const Size(45, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(radius.toStringAsFixed(1)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Refresh Interval', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  tempInterval < 60 
                    ? '$tempInterval seconds' 
                    : '${(tempInterval / 60).toStringAsFixed(0)} minute(s)',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    // 10s - 60s by 10s
                    for (int seconds in [10, 20, 30, 40, 50, 60])
                      ElevatedButton(
                        onPressed: () {
                          setDialogState(() => tempInterval = seconds);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tempInterval == seconds ? Colors.blue : Colors.grey[300],
                          foregroundColor: tempInterval == seconds ? Colors.white : Colors.black,
                          minimumSize: const Size(45, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text('${seconds}s'),
                      ),
                    // 2min - 10min by 1min
                    for (int minutes in [2, 3, 4, 5, 6, 7, 8, 9, 10])
                      ElevatedButton(
                        onPressed: () {
                          setDialogState(() => tempInterval = minutes * 60);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tempInterval == minutes * 60 ? Colors.blue : Colors.grey[300],
                          foregroundColor: tempInterval == minutes * 60 ? Colors.white : Colors.black,
                          minimumSize: const Size(45, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text('${minutes}m'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Region', style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('(Auto-detected by GPS)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: tempRegion,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'na', child: Text('North America')),
                    DropdownMenuItem(value: 'row', child: Text('Rest of World')),
                    DropdownMenuItem(value: 'il', child: Text('Israel')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => tempRegion = value ?? 'row');
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  searchRadius = tempRadius;
                  refreshInterval = tempInterval;
                  region = tempRegion;
                  isDarkMode = tempDarkMode;
                  showPolice = tempShowPolice;
                  showHazard = tempShowHazard;
                  showAccident = tempShowAccident;
                  showSpeedCamera = tempShowSpeedCamera;
                  showRedLightCamera = tempShowRedLightCamera;
                });
                _saveConfig();
                
                // Notify parent widget of theme change
                if (widget.onThemeChanged != null) {
                  widget.onThemeChanged!(tempDarkMode);
                }
                
                Navigator.pop(context);
                _showSnackBar('Settings saved');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _exitApp() {
    _stopMonitoring();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App?'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  void _setRadius(double radius) {
    setState(() => searchRadius = radius);
    _saveConfig();
    _showSnackBar('Radius changed to ${(searchRadius * 1000).toInt()}m');
  }

  void _adjustRadius(double delta) {
    double newRadius = searchRadius + delta;
    if (newRadius < 0.3) newRadius = 0.3;
    if (newRadius > 20) newRadius = 20;
    
    setState(() => searchRadius = newRadius);
    _saveConfig();
    _showSnackBar('Radius: ${(searchRadius * 1000).toInt()}m');
  }

  @override
  void dispose() {
    monitoringTimer?.cancel();
    positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showMenu();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Waze Alerts'),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: _showMenu,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await _getCurrentLocation();
            await _fetchAlerts();
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Location Status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text('Current Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (isLoadingLocation)
                        const Center(child: CircularProgressIndicator())
                      else if (currentPosition != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentAddress.isNotEmpty ? currentAddress : 'Loading address...',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${currentPosition!.latitude.toStringAsFixed(4)}, ${currentPosition!.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'monospace'),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Region: ${region == 'na' ? 'North America' : region == 'il' ? 'Israel' : 'Rest of World'} • Radius: ${searchRadius.toStringAsFixed(1)}km',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        )
                      else
                        const Text('No location obtained'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 16),

              // Alerts List
              if (alerts.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alerts (${alerts.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...alerts.map((alert) => _buildAlertCard(alert)),
                  ],
                )
              else
                const Text('No alerts to display'),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(AlertModel alert) {
    IconData icon;
    Color color;

    switch (alert.type) {
      case 'POLICE':
        icon = Icons.local_police;
        color = Colors.blue;
        break;
      case 'HAZARD':
        icon = Icons.warning;
        color = Colors.orange;
        break;
      case 'ACCIDENT':
        icon = Icons.directions_car_filled;
        color = Colors.red;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    // Calculate distance from current location
    String distanceText = 'N/A';
    if (currentPosition != null && alert.latitude != null && alert.longitude != null) {
      final distanceInMeters = Geolocator.distanceBetween(
        currentPosition!.latitude,
        currentPosition!.longitude,
        alert.latitude!,
        alert.longitude!,
      );
      final distanceInKm = distanceInMeters / 1000;
      distanceText = '${distanceInKm.toStringAsFixed(1)} km';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(alert.type),
        subtitle: Text('${alert.street}, ${alert.city}'),
        trailing: Text(distanceText, style: const TextStyle(fontSize: 12)),
        onTap: () => _openWazeNavigation(alert),
      ),
    );
  }
}
