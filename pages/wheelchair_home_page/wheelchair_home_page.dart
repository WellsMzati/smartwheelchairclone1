import 'package:flutter/material.dart';
import 'package:smart_wheelchair_system/pages/Report/report.dart';
import 'package:smart_wheelchair_system/pages/sos_alert_screen/sos_alert_screen.dart';

import '../adjustable_backrest_screen/adjustable_backrest_screen.dart';
import '../mobile_control_screen/mobile_control_screen.dart';
import '../mobility_reminder/mobility_reminder.dart';

class WheelchairHomePage extends StatefulWidget {
  const WheelchairHomePage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _WheelchairHomePageState createState() => _WheelchairHomePageState();
}

class _WheelchairHomePageState extends State<WheelchairHomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    MobileControlScreen(espIpAddress: ''),
    SosAlertScreen(),
    AdjustableBackrestScreen(espIpAddress: ''),
    MobilityReminderScreen(),
    ReportPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Smart Wheelchair')),
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: _pages[_currentIndex],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        elevation: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.gamepad), label: 'Control'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'SOS'),
          BottomNavigationBarItem(icon: Icon(Icons.chair), label: 'Backrest'),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Mobility',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.report), label: 'Report'),
        ],
      ),
    );
  }
}
