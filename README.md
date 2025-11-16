# Smart Wheelchair System

A comprehensive Flutter-based mobile application designed to provide intelligent control and monitoring capabilities for smart wheelchairs. The system integrates with ESP32 hardware controllers to enable remote wheelchair control, health monitoring, emergency assistance, and comprehensive reporting features.

## 🚀 Features

### 1. **User Authentication**
- Secure Firebase Authentication
- Email/password-based login and registration
- Session management with automatic authentication state tracking
- User profile display

### 2. **Mobile Control Screen**
- **Real-time Wheelchair Movement Control**
  - Forward, reverse, left, and right directional controls
  - Emergency stop functionality
  - Real-time status monitoring via ESP32 HTTP API
  - Connection status indicators
  - Automatic status refresh capabilities
  - Visual feedback for current movement direction

### 3. **SOS Alert System**
- **Emergency Assistance Features**
  - One-tap emergency alert button for urgent situations
  - Assistance request button for non-emergency help
  - Automatic GPS location sharing with caregivers
  - **Twilio SMS Integration**: Sends location-based messages to multiple caregivers
  - Direct phone calling to caregivers
  - Caregiver contact management (add/remove contacts)
  - E.164 phone number format validation
  - Response time tracking
  - Status messages with visual indicators

### 4. **Adjustable Backrest Control**
- **Backrest Angle Management**
  - Slider-based angle adjustment (90° to 160°)
  - Real-time angle display
  - ESP32 integration for hardware control
  - Status polling during adjustments
  - Visual feedback for adjustment progress
  - Manual refresh capability

### 5. **Mobility Reminder & Health Monitoring**
- **Heart Rate Monitoring**
  - Real-time BPM (Beats Per Minute) display
  - Continuous monitoring via ESP32 sensor integration
  - Heart rate history visualization (last minute)
  - Connection status indicators
  
- **Inactivity Detection**
  - Automatic detection of prolonged inactivity
  - Local push notifications for posture reminders
  - Visual and vibration alerts
  - Configurable inactivity thresholds
  - Reset tracking functionality

### 6. **Comprehensive Reporting System**
- **Usage Analytics**
  - Total operation time tracking
  - Session history with start/end times
  - Last active timestamp
  
- **Health Monitoring Reports**
  - Heart rate statistics (min, max, average)
  - Pulse trend visualization
  - Inactivity alert history
  - Pressure risk assessments
  - Assistance request logs with response times
  
- **Adjustment History**
  - Backrest adjustment events
  - Duration tracking for each adjustment
  - Timestamp logging

## 🛠️ Technology Stack

### Core Framework
- **Flutter** (Dart SDK ^3.7.0)
- **Material Design 3** UI components

### Backend Services
- **Firebase Authentication** - User authentication and session management
- **Firebase Core** - Firebase initialization and configuration
- **Twilio API** - SMS messaging service for emergency alerts

### Hardware Integration
- **ESP32** - Microcontroller for wheelchair control and sensor data
- HTTP REST API communication

### Key Dependencies
- `firebase_auth: ^5.5.2` - Authentication
- `firebase_core: ^3.13.0` - Firebase initialization
- `geolocator: ^14.0.0` - GPS location services
- `http: ^1.3.0` - HTTP client for API communication
- `flutter_local_notifications: ^19.1.0` - Local push notifications
- `shared_preferences: ^2.2.1` - Local data storage
- `permission_handler: ^11.0.1` - Runtime permissions
- `flutter_phone_direct_caller: ^2.1.1` - Direct phone calling
- `provider: ^6.1.4` - State management
- `flutter_dotenv: ^5.2.1` - Environment variable management

## 📋 Prerequisites

- Flutter SDK (3.7.0 or higher)
- Dart SDK (3.7.0 or higher)
- Firebase project with Authentication enabled
- Twilio account (for SMS functionality)
- ESP32 device configured with HTTP server endpoints
- Android Studio / Xcode (for mobile development)

## 🔧 Setup Instructions

### 1. Clone the Repository
```bash
git clone <repository-url>
cd smart_wheelchair_system
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Firebase Configuration
1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication (Email/Password)
3. Download `google-services.json` for Android
4. Place it in `android/app/` directory
5. Configure iOS Firebase (if needed)

### 4. Environment Configuration
Create a `.env` file in the root directory with the following variables:
```env
ESP32_IP=192.168.1.100
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_PHONE_NUMBER=+1234567890
```

### 5. ESP32 Endpoints
Ensure your ESP32 device exposes the following HTTP endpoints:
- `GET /wheelchair/status` - Get current wheelchair status
- `POST /wheelchair/move` - Send movement command (body: `{"direction": "forward|reverse|left|right"}`)
- `POST /wheelchair/stop` - Emergency stop
- `GET /backrest/current-angle` - Get current backrest angle
- `POST /backrest/set-angle` - Set backrest angle (body: `{"angle": <degrees>`)
- `GET /backrest/status` - Get backrest adjustment status
- `GET /bpm` - Get heart rate reading (returns JSON `{"bpm": <value>}` or plain integer)

### 6. Run the Application
```bash
flutter run
```

## 📱 Platform Support

- ✅ Android
- ✅ iOS
- ✅ Web (limited functionality)
- ✅ Windows (limited functionality)
- ✅ macOS (limited functionality)
- ✅ Linux (limited functionality)

## 🔐 Permissions Required

### Android
- `INTERNET` - Network communication
- `ACCESS_FINE_LOCATION` - GPS location for SOS alerts
- `ACCESS_COARSE_LOCATION` - Approximate location
- `CALL_PHONE` - Direct phone calling
- `SEND_SMS` - SMS functionality (if using fallback)

### iOS
- Location Services
- Phone calling permissions
- Notification permissions

## 🏗️ Project Structure

```
lib/
├── main.dart                 # Application entry point
├── auth.dart                # Firebase authentication service
├── widget_tree.dart         # Authentication state routing
├── assets/
│   └── Logo.jpg            # Application logo
├── pages/
│   ├── login/              # Login and registration screen
│   ├── wheelchair_home_page/  # Main navigation container
│   ├── mobile_control_screen/  # Wheelchair movement controls
│   ├── sos_alert_screen/      # Emergency assistance features
│   ├── adjustable_backrest_screen/  # Backrest angle control
│   ├── mobility_reminder/     # Health monitoring and reminders
│   └── Report/               # Analytics and reporting
└── services/
    └── report_data_service.dart  # Data logging and reporting service
```

## 🎯 Key Features in Detail

### Emergency SOS System
- Automatically captures GPS location when activated
- Sends SMS messages to all registered caregivers via Twilio
- Includes Google Maps link with exact coordinates
- Supports both emergency and non-emergency assistance requests
- Tracks response times for caregiver accountability

### Health Monitoring
- Continuous heart rate monitoring from ESP32 sensors
- Detects inactivity patterns based on BPM variation
- Sends local notifications when inactivity is detected
- Logs all health metrics for reporting

### Data Logging
All system activities are automatically logged:
- Usage sessions (start/end times)
- Movement commands
- Backrest adjustments
- Assistance requests
- Health readings
- Inactivity alerts
- Pressure risk assessments

## 🔒 Security Considerations

- Firebase Authentication ensures secure user access
- Environment variables for sensitive API keys
- Phone number validation (E.164 format)
- Location permissions handled securely
- HTTPS communication with ESP32 (recommended)

## 🐛 Troubleshooting

### Connection Issues
- Verify ESP32 IP address in `.env` file
- Ensure ESP32 and mobile device are on the same network
- Check firewall settings

### SMS Not Sending
- Verify Twilio credentials in `.env`
- Check Twilio account balance
- Ensure phone numbers are in E.164 format (+country code)

### Location Not Working
- Grant location permissions in device settings
- Enable GPS/location services
- Check app permission settings

## 📝 License

This project is private and not intended for public distribution.

## 👥 Contributing

This is a private project. For contributions or questions, please contact the project maintainers.

## 📞 Support

For technical support or feature requests, please open an issue in the project repository.

---

**Note**: This application requires compatible ESP32 hardware and proper network configuration to function fully. Some features may require additional hardware setup and configuration.
