import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'lot_screen.dart';
import 'board_screen.dart';

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
      theme: ThemeData(primarySwatch: Colors.blue),
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
  final TextEditingController _passwordController = TextEditingController(text: 'admin');
  String? _errorMessage;
  Timer? _errorTimer;


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

  static const String _hardcodedUsername = 'Toyoshima';
  static const String _hardcodedPassword = 'admin';

  void _handleLogin() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty) {
      _showError('Please enter a username');
      return;
    }
    if (password.isEmpty) {
      _showError('Please enter a password');
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
      _showError('Invalid username or password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 220, 242, 245),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(45),
        child: AppBar(
          title: Image.asset('assets/tgtlogo.jpg', height: 32, fit: BoxFit.contain),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.person_outline, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'Welcome to TGT Scan',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please login to continue',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                  prefixIcon: const Icon(Icons.person, color: Colors.blue),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleLogin(),
              ),
              const SizedBox(height: 8),
              AnimatedOpacity(
                opacity: _errorMessage != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _errorMessage != null ? null : 0,
                  child: _errorMessage != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[300]!, width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red[700], fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _handleLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String token;
  final String baseUrl;

  const HomeScreen({super.key, required this.token, required this.baseUrl});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      LotScreen(token: widget.token, baseUrl: widget.baseUrl),
      BoardScreen(token: widget.token, baseUrl: widget.baseUrl),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Pallet'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Board'),
        ],
      ),
    );
  }
}

