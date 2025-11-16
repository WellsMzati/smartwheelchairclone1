import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../auth.dart';

// ROLE PAGES
import '../roles/admin_page.dart';
import '../roles/caregiver_page.dart';
import '../roles/wheelchair_user_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _controllerEmail = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();

  String? _errorMessage = '';
  bool _isLogin = true;
  bool _loading = false;

  /// Checks if the database already has an admin
  Future<bool> _adminExists() async {
    QuerySnapshot check = await FirebaseFirestore.instance
        .collection("users")
        .where("role", isEqualTo: "admin")
        .get();

    return check.docs.isNotEmpty;
  }

  Widget _errorMessageWidget() {
    return _errorMessage == null || _errorMessage == ''
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          );
  }

  /// LOGIN USER
  Future<void> signInWithEmailAndPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await Auth().signInWithEmailAndPassword(
        email: _controllerEmail.text.trim(),
        password: _controllerPassword.text.trim(),
      );

      await _routeUser();

    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message);
    }

    setState(() => _loading = false);
  }

  /// CREATE USER (FIRST USER = ADMIN ONLY)
  Future<void> createUserWithEmailAndPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      bool adminExists = await _adminExists();

      if (adminExists) {
        setState(() => _errorMessage = "Registration disabled. Admin already exists.");
        setState(() => _loading = false);
        return;
      }

      // Create the FIRST USER (ADMIN)
      await Auth().createUserwithEmailAndPassword(
        email: _controllerEmail.text.trim(),
        password: _controllerPassword.text.trim(),
      );

      // Save role to Firestore
      User? user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection("users").doc(user!.uid).set({
        "email": user.email,
        "role": "admin",
      });

      await _routeUser();

    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message);
    }

    setState(() => _loading = false);
  }

  /// ROUTE BASED ON ROLE
  Future<void> _routeUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentSnapshot snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!snap.exists) {
      setState(() => _errorMessage = "User document not found.");
      return;
    }

    final role = snap.get('role');

    if (role == "admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminPage()),
      );
    } else if (role == "caregiver") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CaregiverPage()),
      );
    } else if (role == "wheelchair_user") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WheelchairUserPage()),
      );
    } else {
      setState(() => _errorMessage = "Unknown user role.");
    }
  }

  Widget _submitButton() {
    return ElevatedButton(
      onPressed: _loading
          ? null
          : (_isLogin
              ? signInWithEmailAndPassword
              : createUserWithEmailAndPassword),
      child: _loading
          ? const CircularProgressIndicator(color: Colors.white)
          : Text(_isLogin ? 'Login' : 'Register Admin'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'lib/assets/Logo.jpg',
                      width: 150,
                      height: 150,
                    ),

                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _controllerEmail,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty
                              ? "Enter your email"
                              : null,
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _controllerPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty
                              ? "Enter your password"
                              : null,
                    ),

                    const SizedBox(height: 24),

                    _errorMessageWidget(),
                    SizedBox(
                      width: double.infinity,
                      child: _submitButton(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
