import 'package:flutter/material.dart';
import 'package:smart_wheelchair_system/auth.dart';
import 'package:smart_wheelchair_system/pages/login/login.dart';
import 'package:smart_wheelchair_system/pages/wheelchair_home_page/wheelchair_home_page.dart';

class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Auth().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return WheelchairHomePage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
