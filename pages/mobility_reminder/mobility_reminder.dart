import 'dart:async';
import 'dart:convert';
import 'dart:typed_data'; // For Int64List in notifications
import 'dart:math'; // For min function
import 'package:flutter/material.dart';
import 'package:smart_wheelchair_system/services/report_data_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MobilityReminderScreen extends StatefulWidget {
  const MobilityReminderScreen({super.key});

  @override
  State<MobilityReminderScreen> createState() => _MobilityReminderScreenState();
}

class _MobilityReminderScreenState extends State<MobilityReminderScreen> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  int _bpm = 0;
  final List<int> _bpmHistory = [];
  Timer? _timer;
  bool _isConnected = false;
  DateTime? _lastSuccessfulFetch;
  String _statusMessage = "Initializing...";

  // Configuration settings
  final String _esp32Url =
      'http://${dotenv.env['ESP32_IP']}/bpm'; // Loaded from .env
  final int _fetchIntervalSeconds = 5;
  final int _inactivityThreshold = 3; // BPM variation threshold
  final int _historyLength =
      12; // Number of readings to track (1 minute at 5 sec interval)
  final int _connectionTimeoutSeconds = 10;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _startMonitoring();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification taps here
        if (response.payload == 'inactivity_alert') {
          _resetInactivityTracking();
        }
      },
    );

    // Request notification permissions on iOS
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  void _startMonitoring() {
    _timer = Timer.periodic(Duration(seconds: _fetchIntervalSeconds), (timer) {
      _fetchBPM();
      _checkConnectionStatus();
    });
  }

  void _checkConnectionStatus() {
    if (_lastSuccessfulFetch != null) {
      final difference = DateTime.now().difference(_lastSuccessfulFetch!);
      if (difference.inSeconds > _connectionTimeoutSeconds && _isConnected) {
        setState(() {
          _isConnected = false;
          _statusMessage = "Connection lost. Retrying...";
        });
      }
    }
  }

  Future<void> _fetchBPM() async {
    try {
      final response = await http
          .get(Uri.parse(_esp32Url), headers: {'Connection': 'keep-alive'})
          .timeout(
            Duration(seconds: _connectionTimeoutSeconds),
            onTimeout: () => http.Response('Error: Connection timeout', 408),
          );

      if (response.statusCode == 200) {
        _handleSuccessfulResponse(response);
      } else {
        _handleErrorResponse(response.statusCode);
      }
    } catch (e) {
      setState(() {
        _isConnected = false;
        _statusMessage =
            "Error: ${e.toString().substring(0, min(e.toString().length, 50))}";
      });
    }
  }

  void _handleSuccessfulResponse(http.Response response) {
    // Log pulse reading
    ReportDataService().logPulse(_bpm);
    try {
      // Try to parse as JSON first
      final jsonData = json.decode(response.body);
      final int bpm = jsonData['bpm'] ?? int.parse(jsonData.toString());
      _updateBPMData(bpm);
    } catch (_) {
      // If not JSON, try plain text
      try {
        final int bpm = int.parse(response.body.trim());
        _updateBPMData(bpm);
      } catch (e) {
        setState(() {
          _statusMessage = "Error parsing BPM data";
        });
      }
    }
  }

  void _updateBPMData(int bpm) {
    if (bpm < 0 || bpm > 250) {
      // Validate BPM is in reasonable range
      setState(() {
        _statusMessage = "Invalid BPM reading: $bpm";
      });
      return;
    }

    setState(() {
      _bpm = bpm;
      _bpmHistory.add(bpm);
      if (_bpmHistory.length > _historyLength) {
        _bpmHistory.removeAt(0);
      }
      _isConnected = true;
      _statusMessage = "Connected";
      _lastSuccessfulFetch = DateTime.now();
    });

    _checkInactivity();
  }

  void _handleErrorResponse(int statusCode) {
    setState(() {
      _isConnected = false;
      _statusMessage = "Failed to fetch BPM: HTTP $statusCode";
    });
  }

  void _checkInactivity() {
    if (_bpmHistory.length < _historyLength) return;

    final int maxBPM = _bpmHistory.reduce((a, b) => a > b ? a : b);
    final int minBPM = _bpmHistory.reduce((a, b) => a < b ? a : b);

    // Check for minimal variation in pulse readings
    if ((maxBPM - minBPM) < _inactivityThreshold) {
      // Log pressure risk (example: duration = 1 hour, risk = 'High')
      ReportDataService().logPressureRisk(Duration(hours: 1), 'High');
      _showInactivityNotification();
      setState(() {
        _statusMessage = "Inactivity detected! Please change posture.";
      });
    }
  }

  void _resetInactivityTracking() {
    setState(() {
      _bpmHistory.clear();
      _statusMessage = "Movement detected. Tracking reset.";
    });
  }

  Future<void> _showInactivityNotification() async {
    // Log inactivity alert
    ReportDataService().logInactivityAlert();
    AndroidNotificationDetails
    androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'inactivity_channel',
      'Inactivity Alerts',
      channelDescription: 'Notifications for detected inactivity',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      // Ensure you have notification_sound.mp3 or .wav in android/app/src/main/res/raw/
      // sound: RawResourceAndroidNotificationSound('notification_sound'),
      // Ensure you have a drawable named notification_icon in your resources
      // icon: 'notification_icon',
    );

    const DarwinNotificationDetails
    iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // Ensure you have notification_sound.aiff in your iOS project, otherwise use default
      // sound: 'notification_sound.aiff',
    );

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Inactivity Detected',
      'Please change your posture for better circulation.',
      platformChannelSpecifics,
      payload: 'inactivity_alert',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobility Reminder'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.wifi : Icons.wifi_off,
                  color: _isConnected ? Colors.green : Colors.red,
                  size: 26,
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.favorite, color: Colors.red, size: 28),
                const SizedBox(width: 4),
                Text(
                  '$_bpm',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('BPM', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- PROMINENT STATUS CARD ---
            Card(
              elevation: 4,
              color: _statusMessage.contains("Inactivity detected")
                  ? Colors.red.shade100
                  : Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      _statusMessage.contains("Inactivity detected")
                          ? Icons.warning_amber_rounded
                          : Icons.directions_run_rounded,
                      color: _statusMessage.contains("Inactivity detected")
                          ? Colors.red.shade700
                          : Colors.blue.shade700,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: _statusMessage.contains("Inactivity detected")
                            ? Colors.red.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- BPM HISTORY CHART ---
            if (_bpmHistory.isNotEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.show_chart, color: Colors.red),
                          SizedBox(width: 6),
                          Text(
                            'Heart Rate History (Last Minute)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 80,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(
                            _bpmHistory.length,
                            (index) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                                child: Container(
                                  height: ((_bpmHistory[index] / 200 * 70).clamp(8, 70)).toDouble(),
                                  color: Colors.red.shade300,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 28),

            // --- ACTION BUTTONS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _resetInactivityTracking,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Reset Tracking'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    // Optionally: snooze/acknowledge/remind later
                  },
                  icon: const Icon(Icons.snooze, color: Colors.blue),
                  label: const Text('Snooze'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blue.shade300, width: 2),
                    foregroundColor: Colors.blue.shade800,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
