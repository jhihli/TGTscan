import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'lot_screen.dart';
import 'industrial.dart';

// Login is temporarily bypassed. To re-enable: change MyApp.home back to
// LoginScreen() and ensure a Django user with valid credentials exists.
const bool _loginEnabled = true;

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseUrl =
        dotenv.env['API_BASE_URL'] ?? 'https://api.toyoshimainventory.com';
    return MaterialApp(
      title: 'TGT Scan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Ind.bg,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: Ind.amber,
          onPrimary: Ind.bg,
          secondary: Ind.amber,
          surface: Ind.panel,
          onSurface: Ind.text,
          error: Ind.danger,
        ),
        datePickerTheme: const DatePickerThemeData(
          backgroundColor: Ind.panel,
        ),
      ),
      home: _loginEnabled
          ? const LoginScreen()
          : HomeScreen(token: '', baseUrl: baseUrl),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController =
      TextEditingController(text: 'Toyoshima');
  final TextEditingController _passwordController =
      TextEditingController(text: 'admin');
  String? _errorMessage;
  Timer? _errorTimer;

  static const String _hardcodedUsername = 'Toyoshima';
  static const String _hardcodedPassword = 'admin';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _errorTimer?.cancel();
    super.dispose();
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    _errorTimer?.cancel();
    _errorTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _errorMessage = null);
    });
  }

  void _handleLogin() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty) {
      _showError('Enter an operator ID');
      return;
    }
    if (password.isEmpty) {
      _showError('Enter an access code');
      return;
    }

    if (username == _hardcodedUsername && password == _hardcodedPassword) {
      final baseUrl =
          dotenv.env['API_BASE_URL'] ?? 'https://api.toyoshimainventory.com';
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(token: '', baseUrl: baseUrl),
        ),
      );
    } else {
      _showError('Access denied — check ID and code');
    }
  }

  InputDecoration _decoration(String hint, IconData icon) {
    OutlineInputBorder side(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          fontSize: 12, color: Ind.textDim, letterSpacing: 1),
      prefixIcon: Icon(icon, size: 18, color: Ind.amber),
      filled: true,
      fillColor: Ind.inset,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      enabledBorder: side(Ind.border),
      focusedBorder: side(Ind.amber, 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ind.bg,
      body: SafeArea(
        child: Column(
          children: [
            const HazardStripe(height: 6),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo placard
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Ind.panel,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Ind.border),
                          ),
                          child: Image.asset('assets/tgtlogo.jpg',
                              height: 40, fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'RECEIVING TERMINAL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Ind.text,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'PALLET INBOUND · AUTHORIZED OPERATORS ONLY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: Ind.mono,
                          fontSize: 10,
                          color: Ind.textDim,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Padding(
                        padding: EdgeInsets.only(left: 2, bottom: 6),
                        child: Text('OPERATOR ID', style: Ind.label),
                      ),
                      TextFormField(
                        controller: _usernameController,
                        cursorColor: Ind.amber,
                        style: const TextStyle(color: Ind.text, fontSize: 15),
                        decoration:
                            _decoration('Operator ID', Icons.badge_outlined),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.only(left: 2, bottom: 6),
                        child: Text('ACCESS CODE', style: Ind.label),
                      ),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        cursorColor: Ind.amber,
                        style: const TextStyle(color: Ind.text, fontSize: 15),
                        decoration:
                            _decoration('Access code', Icons.lock_outline),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                      ),
                      const SizedBox(height: 10),
                      AnimatedOpacity(
                        opacity: _errorMessage != null ? 1 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: _errorMessage != null
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Ind.inset,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Ind.danger),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: Ind.danger, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(_errorMessage!,
                                          style: const TextStyle(
                                              color: Ind.danger, fontSize: 13)),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Ind.amber,
                            foregroundColor: Ind.bg,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login, size: 20),
                              SizedBox(width: 8),
                              Text('SIGN IN',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final String token;
  final String baseUrl;

  const HomeScreen({super.key, required this.token, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    return LotScreen(token: token, baseUrl: baseUrl);
  }
}
