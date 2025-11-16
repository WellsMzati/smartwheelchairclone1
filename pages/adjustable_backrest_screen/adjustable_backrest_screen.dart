import 'package:flutter/material.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

/// A screen widget that allows controlling the adjustable backrest of a wheelchair
/// via communication with an ESP32 controller.
///
/// This widget provides UI controls to adjust the backrest angle and displays
/// the current status of the backrest.
class AdjustableBackrestScreen extends StatefulWidget {
  /// IP address of the ESP32 device controlling the wheelchair backrest
  final String espIpAddress;

  /// Creates an AdjustableBackrestScreen with the required ESP32 IP address
  const AdjustableBackrestScreen({super.key, required this.espIpAddress});

  @override
  // ignore: library_private_types_in_public_api
  _AdjustableBackrestScreenState createState() =>
      _AdjustableBackrestScreenState();
}

class _AdjustableBackrestScreenState extends State<AdjustableBackrestScreen> {
  // State variables
  /// Current angle of the backrest (in degrees)
  double _currentAngle = 0.0;

  /// Target angle that the user has selected (in degrees)
  double _targetAngle = 0.0;

  /// Flag indicating whether the backrest is currently adjusting
  bool _isAdjusting = false;

  /// Status message to display to the user
  String _statusMessage = "Ready";

  /// Timer for polling the backrest status during adjustment
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    // Fetch the current angle when the widget initializes
    _fetchCurrentAngle();
  }

  @override
  void dispose() {
    // Cancel any active timers to prevent memory leaks
    _statusTimer?.cancel();
    super.dispose();
  }

  /// Fetches the current backrest angle from the ESP32
  Future<void> _fetchCurrentAngle() async {
    try {
      // Send GET request to the ESP32 with a 5-second timeout
      final response = await http
          .get(
            Uri.parse('http://${widget.espIpAddress}/backrest/current-angle'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Parse the JSON response
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            // Safely convert to double using 'num' type with null check
            _currentAngle =
                data['angle'] != null ? (data['angle'] as num).toDouble() : 0.0;
            _targetAngle = _currentAngle;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _statusMessage =
                "Error: Could not fetch current angle (${response.statusCode})";
          });
        }
      }
    } on TimeoutException {
      // Handle timeout specifically
      if (mounted) {
        setState(() {
          _statusMessage = "Error: Connection timed out";
        });
      }
    } on http.ClientException catch (e) {
      // Handle network errors
      if (mounted) {
        setState(() {
          _statusMessage = "Network error: ${e.message}";
        });
      }
    } catch (e) {
      // Handle all other exceptions
      if (mounted) {
        setState(() {
          _statusMessage = "Connection error: $e";
        });
      }
    }
  }

  /// Sends the target angle to the ESP32 to adjust the backrest
  Future<void> _sendTargetAngle() async {
    if (mounted) {
      setState(() {
        _isAdjusting = true;
        _statusMessage = "Sending target angle...";
      });
    }

    try {
      // Send POST request with the target angle
      final response = await http
          .post(
            Uri.parse('http://${widget.espIpAddress}/backrest/set-angle'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'angle': _targetAngle}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Log the adjustment event (duration is not known yet, so log after polling completes)
        _startPollingStatus();
      } else {
        if (mounted) {
          setState(() {
            _isAdjusting = false;
            _statusMessage = "Error setting angle: ${response.statusCode}";
          });
        }
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _isAdjusting = false;
          _statusMessage = "Error: Connection timed out";
        });
      }
    } on http.ClientException catch (e) {
      if (mounted) {
        setState(() {
          _isAdjusting = false;
          _statusMessage = "Network error: ${e.message}";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAdjusting = false;
          _statusMessage = "Connection error: $e";
        });
      }
    }
  }

  /// Starts a timer to periodically check the status of the backrest adjustment
  void _startPollingStatus() {
    // Cancel any existing timer to avoid multiple concurrent timers
    _statusTimer?.cancel();

    // Create a new timer that fires every 500ms
    _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _checkMovementStatus();
    });
  }

  /// Checks the current status of the backrest adjustment
  Future<void> _checkMovementStatus() async {
    // Track when adjustment started

    try {
      // Send GET request to check status
      final response = await http
          .get(Uri.parse('http://${widget.espIpAddress}/backrest/status'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final status = data['status'] as String?;

        // Safely handle the value that might be null or of different type
        final currentPosition =
            data['currentAngle'] != null
                ? (data['currentAngle'] as num).toDouble()
                : _currentAngle;

        if (mounted) {
          setState(() {
            _currentAngle = currentPosition;

            // Update UI based on the status
            if (status == 'in_progress') {
              _statusMessage = "Adjusting backrest...";
            } else if (status == 'completed') {
              _statusMessage = "Backrest adjusted successfully!";
              _isAdjusting = false;
              _statusTimer?.cancel();
              _statusTimer = null;
            } else if (status == 'error') {
              _statusMessage = "Error: ${data['message'] ?? 'Unknown error'}";
              _isAdjusting = false;
              _statusTimer?.cancel();
              _statusTimer = null;
            }
          });
        }
      }
    } catch (e) {
      // Keep trying unless we've stopped adjusting
      if (!_isAdjusting && mounted) {
        _statusTimer?.cancel();
        _statusTimer = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              Text(
                'Adjustable Backrest Control',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Current angle display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text('Current Angle', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      '${_currentAngle.toStringAsFixed(1)}°',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Angle adjustment slider
              Row(
                children: [
                  const Text('0°'),
                  Expanded(
                    child: Slider(
                      value: _targetAngle.clamp(90.0, 160.0),
                      min: 90.0,
                      max: 160.0,
                      divisions: 70,
                      label: '${_targetAngle.toStringAsFixed(1)}°',
                      onChanged:
                          _isAdjusting
                              ? null
                              : (value) {
                                if (mounted) {
                                  setState(() {
                                    _targetAngle = value;
                                  });
                                }
                              },
                    ),
                  ),

                  // Max value label
                  const Text('160°'),
                ],
              ),

              const SizedBox(height: 16),

              // Apply button
              ElevatedButton(
                // Disable button when adjustment is in progress
                onPressed: _isAdjusting ? null : () => _sendTargetAngle(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(_isAdjusting ? 'Adjusting...' : 'Apply Angle'),
              ),

              const SizedBox(height: 16),

              // Status message display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color:
                      _statusMessage.contains("Error")
                          ? Colors.red.shade50
                          : _statusMessage.contains("success")
                          ? Colors.green.shade50
                          : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        _statusMessage.contains("Error")
                            ? Colors.red.shade200
                            : _statusMessage.contains("success")
                            ? Colors.green.shade200
                            : Colors.blue.shade100,
                  ),
                ),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        _statusMessage.contains("Error")
                            ? Colors.red.shade700
                            : _statusMessage.contains("success")
                            ? Colors.green.shade700
                            : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Refresh button to manually update the current angle
              TextButton.icon(
                // Disable button when adjustment is in progress
                onPressed: _isAdjusting ? null : _fetchCurrentAngle,
                icon: Icon(
                  Icons.refresh,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: Text(
                  'Refresh Angle',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Main app widget for the wheelchair control application
class WheelchairApp extends StatelessWidget {
  /// Creates a wheelchair control application
  const WheelchairApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wheelchair Control',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Wheelchair Controls'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Backrest control widget
                AdjustableBackrestScreen(
                  espIpAddress: dotenv.env['ESP32_IP'] ?? '',
                ),

                // Add other wheelchair control widgets here if needed
              ],
            ),
          ),
        ),
      ),
    );
  }
}
