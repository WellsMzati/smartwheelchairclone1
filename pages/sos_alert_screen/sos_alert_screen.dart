// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:smart_wheelchair_system/services/report_data_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smart_wheelchair_system/pages/chat_screen/chat_screen.dart';

class SosAlertScreen extends StatefulWidget {
  const SosAlertScreen({super.key});
  @override
  State<SosAlertScreen> createState() => _SosAlertScreenState();
}

// Model class for Caregiver data
class Caregiver {
  final String name;
  final String phone;

  Caregiver({required this.name, required this.phone});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory Caregiver.fromJson(Map<String, dynamic> json) {
    return Caregiver(
      name: json['name'] as String,
      phone: json['phone'] as String,
    );
  }
}

class _SosAlertScreenState extends State<SosAlertScreen> {
  List<Caregiver> caregivers = [];
  bool _isProcessing = false;
  String _statusMessage = "Ready";
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isSendingEmergency = false;

  // Twilio configuration
  String? _twilioAccountSid;
  String? _twilioAuthToken;
  String? _twilioPhoneNumber;
  bool _twilioConfigured = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _checkPermissions();
    _loadTwilioConfig(); // Load Twilio credentials
    _loadCaregiverNumbers();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('Firebase initialization failed: $e');
    }
  }

  Future<void> _loadCaregiverNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final caregiverJson = prefs.getStringList('caregivers') ?? [];

    setState(() {
      caregivers =
          caregiverJson
              .map((json) => Caregiver.fromJson(jsonDecode(json)))
              .toList();
    });
  }

  Future<void> _saveCaregiverNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final caregiverJson =
        caregivers.map((caregiver) => jsonEncode(caregiver.toJson())).toList();
    await prefs.setStringList('caregivers', caregiverJson);
  }

  void _addCaregiver(String name, String phone) {
    // Check if phone already exists
    bool phoneExists = caregivers.any((caregiver) => caregiver.phone == phone);

    if (phone.isNotEmpty && name.isNotEmpty && !phoneExists) {
      setState(() {
        caregivers.add(Caregiver(name: name, phone: phone));
      });
      _saveCaregiverNumbers();
      _phoneController.clear();
      _nameController.clear();
    }
  }

  void _removeCaregiver(Caregiver caregiver) {
    setState(() {
      caregivers.removeWhere((c) => c.phone == caregiver.phone);
    });
    _saveCaregiverNumbers();
  }

  Future<void> _checkPermissions() async {
    // Check location permission
    LocationPermission locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
      if (locationPermission == LocationPermission.denied ||
          locationPermission == LocationPermission.deniedForever) {
        if (mounted) _showPermissionError('Location');
      }
    }
  }

  // Load Twilio configuration from .env file
  Future<void> _loadTwilioConfig() async {
    print('Loading Twilio configuration...');
    try {
      _twilioAccountSid = dotenv.env['TWILIO_ACCOUNT_SID'];
      _twilioAuthToken = dotenv.env['TWILIO_AUTH_TOKEN'];
      _twilioPhoneNumber = dotenv.env['TWILIO_PHONE_NUMBER'];

      if (_twilioAccountSid != null &&
          _twilioAuthToken != null &&
          _twilioPhoneNumber != null &&
          _twilioAccountSid!.isNotEmpty &&
          _twilioAuthToken!.isNotEmpty &&
          _twilioPhoneNumber!.isNotEmpty) {
        _twilioConfigured = true;
        print('Twilio configuration loaded successfully');

        // Verify credentials with a test request
        await _testTwilioConnection();
      } else {
        print('Twilio configuration incomplete or missing');
        if (mounted) {
          setState(() {
            _statusMessage = "Twilio configuration missing - check .env file";
          });
        }
        _twilioConfigured = false;
      }
    } catch (e) {
      print('Error loading Twilio configuration: $e');
      if (mounted) {
        setState(() {
          _statusMessage = "Error loading Twilio configuration: $e";
        });
      }
      _twilioConfigured = false;
    }
  }

  // Test Twilio connection to verify credentials
  Future<void> _testTwilioConnection() async {
    try {
      final auth = base64Encode(
        utf8.encode('$_twilioAccountSid:$_twilioAuthToken'),
      );
      final url = Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid.json',
      );

      final response = await http.get(
        url,
        headers: {'Authorization': 'Basic $auth'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('Twilio connection test successful');
        if (mounted) {
          setState(() {
            _statusMessage = "Ready - Twilio messaging enabled";
          });
        }
      } else {
        print('Twilio connection test failed: ${response.statusCode}');
        print('Response body: ${response.body}');
        if (mounted) {
          setState(() {
            _statusMessage =
                "Twilio credentials invalid - please check .env file";
          });
        }
        _twilioConfigured = false;
      }
    } catch (e) {
      print('Error testing Twilio connection: $e');
      if (mounted) {
        setState(() {
          _statusMessage = "Error connecting to Twilio: $e";
        });
      }
      _twilioConfigured = false;
    }
  }

  void _showPermissionError(String permissionType) {
    if (mounted) {
      setState(() {
        _statusMessage =
            "$permissionType permission is required for the SOS feature";
      });
    }
  }

  Future<Position?> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _statusMessage =
              "Location services are disabled. Please enable location (GPS) in your device settings.";
        });
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Enable Location Services"),
                content: const Text(
                  "Location services are disabled. Please enable location (GPS) in your device settings and try again.",
                ),
                actions: [
                  TextButton(
                    child: const Text("OK"),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
        );
      }
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      if (mounted) {
        setState(() {
          _statusMessage =
              "Location permission denied. Please allow location access to send your SOS location.";
        });
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Location Permission Required"),
                content: const Text(
                  "Location permission is required for the SOS feature. Please grant location access in your device settings.",
                ),
                actions: [
                  TextButton(
                    child: const Text("OK"),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
        );
      }
      return null;
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _statusMessage =
              "Location permission permanently denied. Please enable location permission in app settings.";
        });
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Location Permission Permanently Denied"),
                content: const Text(
                  "Location permission is permanently denied. Please open app settings and enable location permission.",
                ),
                actions: [
                  TextButton(
                    child: const Text("Open Settings"),
                    onPressed: () {
                      Geolocator.openAppSettings();
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: const Text("Cancel"),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
        );
      }
      return null;
    }

    try {
      final locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
      return await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = "Error getting location: $e";
        });
      }
      return null;
    }
  }

  // Send SMS using Twilio API
  Future<void> _sendSmsWithLocation(Position position, bool isEmergency) async {
    print('=== Starting Twilio SMS sending process ===');
    print('Position: ${position.latitude}, ${position.longitude}');
    print('isEmergency: $isEmergency');

    // Check if we have any caregivers
    if (caregivers.isEmpty) {
      print('Error: No caregivers added!');
      if (mounted) {
        setState(() {
          _statusMessage = "No caregiver contacts added";
        });
      }
      return;
    }
    print('Found ${caregivers.length} caregivers');

    // Make sure Twilio is configured
    if (!_twilioConfigured) {
      print('Twilio not configured properly');
      if (mounted) {
        setState(() {
          _statusMessage = "Cannot send SMS: Twilio not configured";
        });
      }
      return;
    }

    // Construct the message
    String message;
    if (isEmergency) {
      message =
          "EMERGENCY! Help needed at: https://maps.google.com/?q=${position.latitude},${position.longitude}";
    } else {
      message =
          "I need assistance when you're available. My location: https://maps.google.com/?q=${position.latitude},${position.longitude}";
    }

    // Update UI to show we're sending
    if (mounted) {
      setState(() {
        _statusMessage =
            isEmergency
                ? "Sending emergency message to caregivers via Twilio..."
                : "Sending assistance request to caregivers via Twilio...";
      });
    }

    bool anySuccess = false;
    List<String> failedRecipients = [];

    // Send SMS to each caregiver using Twilio
    for (var caregiver in caregivers) {
      bool sentSuccessfully = false;

      // Try up to 3 times for each recipient
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          if (attempt > 1) {
            print('Attempt $attempt to send SMS to ${caregiver.name}');
          }

          final response = await _sendTwilioSms(caregiver.phone, message);
          final responseBody = jsonDecode(response.body);

          if (response.statusCode >= 200 &&
              response.statusCode < 300 &&
              responseBody['status'] != 'failed') {
            print('Successfully sent SMS to ${caregiver.name} via Twilio');
            sentSuccessfully = true;
            anySuccess = true;
            break; // Exit retry loop on success
          } else {
            print(
              'Failed to send SMS to ${caregiver.name} (Attempt $attempt): ${response.statusCode}',
            );
            final errorMsg = responseBody['message'] ?? "Unknown error";
            print('Error: $errorMsg');
            if (mounted) {
              setState(() {
                _statusMessage = "Twilio error: $errorMsg";
              });
            }
            if (attempt < 3) {
              // Wait before retrying
              await Future.delayed(const Duration(seconds: 1));
            }
          }
        } catch (e) {
          print(
            'Error sending SMS to ${caregiver.name} (Attempt $attempt): $e',
          );

          if (attempt < 3) {
            // Wait before retrying
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }

      // After all retry attempts
      if (!sentSuccessfully) {
        print('Failed to send SMS to ${caregiver.name} after 3 attempts');
        failedRecipients.add(caregiver.name);

        // No backup method: after 3 failed attempts, just record failure and continue.
        // All caregiver messages are sent exclusively via Twilio.
      }
    }

    print('Twilio SMS sending process completed. Success: $anySuccess');

    // Update the UI with results
    if (mounted) {
      setState(() {
        if (anySuccess) {
          if (failedRecipients.isEmpty) {
            _statusMessage =
                isEmergency
                    ? "Emergency message sent to all caregivers!"
                    : "Assistance request sent to all caregivers!";
          } else {
            _statusMessage =
                "Message sent to some caregivers. Failed: ${failedRecipients.join(', ')}";
          }
        } else {
          _statusMessage =
              "Failed to send messages. Please check Twilio configuration and try again.";
        }
      });
    }
  }

  // Helper function to send SMS via Twilio API
  Future<http.Response> _sendTwilioSms(String to, String messageBody) async {
    final auth = base64Encode(
      utf8.encode('$_twilioAccountSid:$_twilioAuthToken'),
    );

    // Format phone numbers to E.164 format if not already
    if (!to.startsWith('+')) {
      // This is a simplistic approach - in a real app, proper phone number formatting
      // should be used based on the country code
      to = '+$to';
    }

    final url = Uri.parse(
      'https://api.twilio.com/2010-04-01/Accounts/$_twilioAccountSid/Messages.json',
    );

    print('Sending Twilio SMS to: $to');

    // Make POST request to Twilio API
    return await http.post(
      url,
      headers: {
        'Authorization': 'Basic $auth',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'From': _twilioPhoneNumber, 'To': to, 'Body': messageBody},
    );
  }

  // Backup SMS method for when Twilio fails
  // Backup SMS method removed. All messages are sent directly via Twilio API.
  // This ensures no external SMS apps are launched and all messaging is handled in-app.
  // If Twilio fails, display an error to the user and do not attempt to launch any URI.

  Future<void> _callEmergency() async {
    if (caregivers.isEmpty) {
      // If no caregivers are available, call emergency services
      setState(() {
        _statusMessage = "No caregivers - calling emergency services (112)";
      });
      try {
        bool? callResult = await FlutterPhoneDirectCaller.callNumber("112");
        if (mounted) {
          setState(() {
            _statusMessage =
                callResult == true
                    ? "Emergency call initiated"
                    : "Failed to initiate emergency call";
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _statusMessage = "Error making emergency call: $e";
          });
        }
      }
      return;
    }

    // Get the first caregiver's phone (or you could implement a selection process)
    final String caregiverPhone = caregivers[0].phone;

    try {
      // Direct call using the flutter_phone_direct_caller package
      bool? callResult = await FlutterPhoneDirectCaller.callNumber(
        caregiverPhone,
      );

      if (mounted) {
        setState(() {
          _statusMessage =
              callResult == true
                  ? "Calling caregiver..."
                  : "Failed to initiate call";
        });
      }
    } catch (e) {
      print('Failed to make direct call: $e');
      if (mounted) {
        setState(() {
          _statusMessage = "Error: Could not make direct call";
        });
      }
    }
  }

  Future<void> _triggerSOS(bool isEmergency) async {
    // Log the SOS/assistance request (response time will be null for now)
    ReportDataService().logAssistanceRequest();
    if (_isProcessing) return;

    if (caregivers.isEmpty) {
      setState(() {
        _statusMessage = "Please add at least one caregiver contact first";
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _isSendingEmergency = isEmergency;
      _statusMessage =
          isEmergency
              ? "Sending emergency message..."
              : "Sending assistance request...";
    });

    try {
      // Get current location first
      final position = await _getLocation();
      if (position != null) {
        print('Location obtained: ${position.latitude}, ${position.longitude}');

        // Send SMS with location - BOTH buttons send SMS
        await _sendSmsWithLocation(position, isEmergency);

        if (mounted) {
          setState(() {
            _statusMessage =
                isEmergency
                    ? "Emergency message sent to caregivers!"
                    : "Assistance request sent to caregivers!";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _statusMessage = "Could not determine your location";
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      print('Error in _triggerSOS: $e');
      if (mounted) {
        setState(() {
          _statusMessage = "Error: $e";
          _isProcessing = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSendingEmergency = false;
        });
      }
    }
  }

  void _showAddCaregiverDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Add Caregiver Contact"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Name",
                    hintText: "Enter caregiver's name",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: "Phone Number",
                    hintText: "Enter caregiver's phone",
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCEL"),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = _nameController.text.trim();
                  final phone = _phoneController.text.trim();
                  final e164RegExp = RegExp(r'^\+[1-9]\d{1,14}$');
                  if (name.isEmpty || phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Name and phone number are required.'),
                      ),
                    );
                    return;
                  }
                  if (!e164RegExp.hasMatch(phone)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Phone number must be in E.164 format (e.g. +1234567890).',
                        ),
                      ),
                    );
                    return;
                  }
                  _addCaregiver(name, phone);
                  Navigator.pop(context);
                },
                child: const Text("ADD"),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Alert'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAddCaregiverDialog,
            tooltip: 'Add Caregiver',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Caregiver List
                if (caregivers.isNotEmpty) ...[
                  Text(
                    'Caregivers',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    height: 120,
                    child: ListView.builder(
                      itemCount: caregivers.length,
                      itemBuilder: (context, index) {
                        final caregiver = caregivers[index];
                        return ListTile(
                          dense: true,
                          title: Text(caregiver.name),
                          subtitle: Text(caregiver.phone),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeCaregiver(caregiver),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Main emergency buttons
                Row(
                  children: [
                    // Emergency Help Button
                    Expanded(
                      child: GestureDetector(
                        onTap: _isProcessing ? null : () => _triggerSOS(true),
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _isProcessing && _isSendingEmergency
                                  ? CircularProgressIndicator(color: Colors.blue)
                                  : Icon(
                                      Icons.emergency,
                                      size: 50,
                                      color: Colors.blue,
                                    ),
                              SizedBox(height: 12),
                              Text(
                                'EMERGENCY',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Need urgent assistance',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Assistance Button
                    Expanded(
                      child: GestureDetector(
                        onTap: _isProcessing ? null : () => _triggerSOS(false),
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _isProcessing && !_isSendingEmergency
                                  ? CircularProgressIndicator(color: Colors.blue)
                                  : Icon(
                                      Icons.wheelchair_pickup,
                                      size: 50,
                                      color: Colors.blue,
                                    ),
                              SizedBox(height: 12),
                              Text(
                                'ASSISTANCE',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Request caregiver help',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Call Caregiver Button
                ElevatedButton.icon(
                  onPressed: caregivers.isEmpty ? null : _callEmergency,
                  icon: Icon(Icons.call, color: Colors.white),
                  label: Text(
                    caregivers.isEmpty
                        ? 'ADD CAREGIVERS FIRST'
                        : 'DIRECT CALL CAREGIVER',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    disabledBackgroundColor: Colors.grey.shade400,
                  ),
                ),

                const SizedBox(height: 24),

                // Status Message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _statusMessage.contains("Error")
                        ? Colors.red.shade50
                        : (_statusMessage.contains("emergency"))
                            ? Colors.red.shade50
                            : (_statusMessage.contains("assistance"))
                                ? Colors.orange.shade50
                                : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _statusMessage.contains("Error")
                          ? Colors.red.shade200
                          : (_statusMessage.contains("emergency"))
                              ? Colors.red.shade200
                              : (_statusMessage.contains("assistance"))
                                  ? Colors.orange.shade200
                                  : Colors.blue.shade100,
                    ),
                  ),
                  child: Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _statusMessage.contains("Error")
                          ? Colors.red.shade700
                          : (_statusMessage.contains("emergency"))
                              ? Colors.red.shade700
                              : (_statusMessage.contains("assistance"))
                                  ? Colors.orange.shade700
                                  : Colors.blue.shade700,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Caregiver Responded Button
                ElevatedButton.icon(
                  onPressed: _onCaregiverResponseAcknowledged,
                  icon: Icon(Icons.check_circle, color: Colors.white),
                  label: Text('Chat With Caregiver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onCaregiverResponseAcknowledged() {
    // Log the response time for the most recent request (if any)
    final requests = ReportDataService().assistanceRequests;
    if (requests.isNotEmpty) {
      final last = requests.last;
      last.responseTime ??= Duration(minutes: 1);
    }
    
    // Get the first caregiver's name if available
    String? caregiverName;
    if (caregivers.isNotEmpty) {
      caregiverName = caregivers.first.name;
    }
    
    // Navigate to chat screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          caregiverName: caregiverName,
        ),
      ),
    );
    
    setState(() {
      _statusMessage = "Caregiver response acknowledged. Thank you!";
    });
  }
}
