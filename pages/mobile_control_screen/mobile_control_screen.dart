import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

/// A widget that provides movement control for a wheelchair via
/// communication with an ESP32 controller.
///
/// This widget presents directional buttons (forward, reverse, left, right)
/// and a stop button to control the wheelchair's movement.
class MobileControlScreen extends StatefulWidget {
  /// IP address of the ESP32 device controlling the wheelchair
  final String espIpAddress;

  /// Creates a WheelchairMovementControl with the required ESP32 IP address
  const MobileControlScreen({super.key, required this.espIpAddress});

  @override
  // ignore: library_private_types_in_public_api
  _MobileControlScreenState createState() => _MobileControlScreenState();
}

class _MobileControlScreenState extends State<MobileControlScreen> {
  // The currently authenticated Firebase user
  final User? user = FirebaseAuth.instance.currentUser;
  // Instance of the Auth helper class for authentication actions
  final Auth _auth = Auth();

  Future<void> signOut() async {
    await Auth().signOut();
  }

  /// Widget to display the current user's email (or a placeholder)
  Widget _userID() {
    return Text(
      user?.email ?? 'user email',
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

  /// Widget to display a sign out button for the user
  /// On press, signs out the user and navigates to the login screen
  Widget _signOutButton() {
    return ElevatedButton(
      onPressed: () async {
        await _auth.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.blue,
        elevation: 0,
      ),
      child: const Text('Sign Out'),
    );
  }

  // State variables
  /// Current movement direction of the wheelchair
  String _currentDirection = "stopped";

  /// Status message to display to the user
  String _statusMessage = "Ready";

  /// Flag indicating whether a command is being processed
  bool _isProcessing = false;

  /// Timer for polling the movement status
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    // Fetch the current status when the widget initializes
    _fetchCurrentStatus();
  }

  @override
  void dispose() {
    // Cancel any active timers to prevent memory leaks
    _statusTimer?.cancel();
    super.dispose();
  }

  /// Fetches the current movement status from the ESP32
  Future<void> _fetchCurrentStatus() async {
    try {
      // Send GET request to the ESP32 with a 5-second timeout
      final response = await http
          .get(Uri.parse('http://${widget.espIpAddress}/wheelchair/status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // Parse the JSON response
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            // Update the current direction
            _currentDirection = data['direction'] as String? ?? "stopped";
            _statusMessage = "Ready";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _statusMessage =
                "Error: Could not fetch status (${response.statusCode})";
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

  /// Sends a movement command to the ESP32
  Future<void> _sendMovementCommand(String direction) async {
    if (_isProcessing) return;

    if (mounted) {
      setState(() {
        _isProcessing = true;
        _statusMessage = "Sending command...";
      });
    }

    try {
      // Send POST request with the movement direction
      final response = await http
          .post(
            Uri.parse('http://${widget.espIpAddress}/wheelchair/move'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'direction': direction}),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _currentDirection = direction;
            _statusMessage = "Moving $direction";
            _isProcessing = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage =
                "Error: Failed to send command (${response.statusCode})";
          });
        }
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = "Error: Connection timed out";
        });
      }
    } on http.ClientException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = "Network error: ${e.message}";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = "Connection error: $e";
        });
      }
    }
  }

  /// Sends an emergency stop command to the ESP32
  Future<void> _sendStopCommand() async {
    if (_isProcessing) return;

    if (mounted) {
      setState(() {
        _isProcessing = true;
        _statusMessage = "Stopping...";
      });
    }

    try {
      // Send POST request for the stop command
      final response = await http
          .post(
            Uri.parse('http://${widget.espIpAddress}/wheelchair/stop'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _currentDirection = "stopped";
            _statusMessage = "Wheelchair stopped";
            _isProcessing = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = "Error: Failed to stop (${response.statusCode})";
          });
        }
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = "Error: Connection timed out";
        });
      }
    } on http.ClientException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = "Network error: ${e.message}";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = "Connection error: $e";
        });
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // User info and sign out row
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // User info and sign out
                  // User info and sign out row (top of card)
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Expanded(child: _userID()), _signOutButton()],
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Wheelchair Movement Control',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Current status display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Current Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentDirection.toUpperCase(),
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              _currentDirection == "stopped"
                                  ? Colors.red.shade700
                                  : Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Direction controls
                Column(
                  children: [
                    // Forward button
                    SizedBox(
                      width: 120,
                      height: 80,
                      child: ElevatedButton(
                        onPressed:
                            _isProcessing
                                ? null
                                : () => _sendMovementCommand('forward'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _currentDirection == 'forward'
                                  ? Colors.blue.shade400
                                  : null,
                          foregroundColor:
                              _currentDirection == 'forward'
                                  ? Colors.white
                                  : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_upward, size: 32),
                            Text('Forward'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Left, Stop, Right row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Left button
                        Expanded(
                          child: SizedBox(
                            height: 80,
                            child: ElevatedButton(
                              onPressed:
                                  _isProcessing
                                      ? null
                                      : () => _sendMovementCommand('left'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _currentDirection == 'left'
                                        ? Colors.blue.shade400
                                        : null,
                                foregroundColor:
                                    _currentDirection == 'left'
                                        ? Colors.white
                                        : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_back, size: 32),
                                  Text('Left'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Stop button
                        Expanded(
                          child: SizedBox(
                            height: 80,
                            child: ElevatedButton(
                              onPressed:
                                  _isProcessing ? null : _sendStopCommand,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.stop, size: 32),
                                  Text(
                                    'STOP',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Right button
                        Expanded(
                          child: SizedBox(
                            height: 80,
                            child: ElevatedButton(
                              onPressed:
                                  _isProcessing
                                      ? null
                                      : () => _sendMovementCommand('right'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _currentDirection == 'right'
                                        ? Colors.blue.shade400
                                        : null,
                                foregroundColor:
                                    _currentDirection == 'right'
                                        ? Colors.white
                                        : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_forward, size: 32),
                                  Text('Right'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Reverse button
                    SizedBox(
                      width: 120,
                      height: 80,
                      child: ElevatedButton(
                        onPressed:
                            _isProcessing
                                ? null
                                : () => _sendMovementCommand('reverse'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _currentDirection == 'reverse'
                                  ? Colors.blue.shade400
                                  : null,
                          foregroundColor:
                              _currentDirection == 'reverse'
                                  ? Colors.white
                                  : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_downward, size: 32),
                            Text('Reverse'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Status message display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color:
                        _statusMessage.contains("Error")
                            ? Colors.red.shade50
                            : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          _statusMessage.contains("Error")
                              ? Colors.red.shade200
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
                              : Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Refresh button
                TextButton.icon(
                  onPressed: _isProcessing ? null : _fetchCurrentStatus,
                  icon: Icon(
                    Icons.refresh,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: Text(
                    'Refresh Status',
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
      ),
    );
  }
}

/// Example usage of the WheelchairMovementControl in a complete app
class WheelchairApp extends StatelessWidget {
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
                // Movement control widget
                MobileControlScreen(
                  espIpAddress: dotenv.env['ESP32_IP'] ?? '192.168.1.100',
                ),

                // Add other control widgets here (like the backrest control)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
