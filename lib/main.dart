import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_datawedge/flutter_datawedge.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TGT Scan',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  String? _errorMessage;
  Timer? _errorTimer;

  @override
  void dispose() {
    _usernameController.dispose();
    _errorTimer?.cancel();
    super.dispose();
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });

    // Cancel any existing timer
    _errorTimer?.cancel();

    // Set new timer to clear error after 5 seconds
    _errorTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  Future<bool> _checkNetworkConnectivity() async {
    try {
      // Simple check: try to resolve a well-known domain
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      // Any error means no connectivity
      return false;
    }
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      _showError('Please enter a username');
      return;
    }

    // Check network connectivity before proceeding
    final hasNetwork = await _checkNetworkConnectivity();
    if (!hasNetwork) {
      _showError('No network connection. Please check your internet connection and try again.');
      return;
    }

    // Check if username is 'admin'
    if (username == 'admin') {
      // Navigate to ScanScreen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ScanScreen()),
        );
      }
    } else {
      _showError('Invalid username. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 220, 242, 245),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(45),
        child: AppBar(
          title: Image.asset(
            'assets/tgtlogo.jpg',
            height: 32,
            fit: BoxFit.contain,
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome to TGT Scan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please login to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
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
                                      style: TextStyle(
                                        color: Colors.red[700],
                                        fontSize: 14,
                                      ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // For SO Number search dialog
  final TextEditingController _searchBarcodeController = TextEditingController();
  final FocusNode _searchBarcodeFocusNode = FocusNode();
  String? _searchResultSoNumber;
  bool _isSearchingSoNumber = false;
  bool _isDialogOpen = false;

  Future<void> _showSoNumberSearchDialog() async {
    _searchBarcodeController.clear();
    _searchResultSoNumber = null;
    _isDialogOpen = true;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        // Request focus after dialog is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchBarcodeFocusNode.requestFocus();
        });

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Search SO Number',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _searchBarcodeController,
                      focusNode: _searchBarcodeFocusNode,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Barcode',
                        hintText: 'Scan barcode here',
                        prefixIcon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                        filled: true,
                        fillColor: Colors.grey[50],
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
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _isSearchingSoNumber
                          ? null
                          : () async {
                            final barcode = _searchBarcodeController.text.trim();
                            if (barcode.isEmpty) return;
                            setState(() {
                              _isSearchingSoNumber = true;
                              _searchResultSoNumber = null;
                            });
                            try {
                              final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'https://api.toyoshimainventory.com';
                              final apiKey = dotenv.env['API_KEY'] ?? '';

                              final response = await http.post(
                                Uri.parse('$apiBaseUrl/product/scanner/'),
                                headers: {
                                  'X-API-Key': apiKey,
                                },
                                body: {
                                  'barcode': barcode,
                                  'action': 'find_so_number',
                                },
                              );
                              if (response.statusCode == 200) {
                                try {
                                  final Map<String, dynamic> json = response.body.isNotEmpty
                                      ? Map<String, dynamic>.from(jsonDecode(response.body))
                                      : {};
                                  final soNumber = json['so_number']?.toString() ?? '';
                                  setState(() {
                                    _searchResultSoNumber = soNumber.isNotEmpty ? soNumber : 'Not found';
                                  });
                                } catch (e) {
                                  setState(() {
                                    _searchResultSoNumber = 'Not found';
                                  });
                                }
                              } else {
                                setState(() {
                                  _searchResultSoNumber = 'Not found';
                                });
                              }
                            } catch (e) {
                              setState(() {
                                _searchResultSoNumber = 'Error: $e';
                              });
                            } finally {
                              setState(() {
                                _isSearchingSoNumber = false;
                              });
                            }
                          },
                      icon: _isSearchingSoNumber
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search),
                      label: Text(_isSearchingSoNumber ? 'Searching...' : 'Search'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _searchResultSoNumber == null
                            ? Colors.grey[100]
                            : (_searchResultSoNumber == 'Not found' || _searchResultSoNumber!.startsWith('Error:'))
                                ? Colors.red[50]
                                : Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _searchResultSoNumber == null
                              ? Colors.grey[300]!
                              : (_searchResultSoNumber == 'Not found' || _searchResultSoNumber!.startsWith('Error:'))
                                  ? Colors.red[200]!
                                  : Colors.green[200]!,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _searchResultSoNumber == null
                                    ? Icons.info_outline
                                    : (_searchResultSoNumber == 'Not found' || _searchResultSoNumber!.startsWith('Error:'))
                                        ? Icons.error_outline
                                        : Icons.check_circle_outline,
                                color: _searchResultSoNumber == null
                                    ? Colors.grey[600]
                                    : (_searchResultSoNumber == 'Not found' || _searchResultSoNumber!.startsWith('Error:'))
                                        ? Colors.red[700]
                                        : Colors.green[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _searchResultSoNumber == null
                                    ? 'Result'
                                    : (_searchResultSoNumber == 'Not found' || _searchResultSoNumber!.startsWith('Error:'))
                                        ? 'Not Found'
                                        : 'Found',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _searchResultSoNumber == null
                                      ? Colors.grey[600]
                                      : (_searchResultSoNumber == 'Not found' || _searchResultSoNumber!.startsWith('Error:'))
                                          ? Colors.red[700]
                                          : Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                          if (_searchResultSoNumber != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _searchResultSoNumber!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: _searchResultSoNumber != 'Not found' &&
                                           !_searchResultSoNumber!.startsWith('Error:')
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton(
                  onPressed: (_searchResultSoNumber != null &&
                              _searchResultSoNumber != 'Not found' &&
                              !_searchResultSoNumber!.startsWith('Error:') &&
                              !_isSearchingSoNumber)
                      ? () {
                          if (_isImport) {
                            _soNumberImportController.text = _searchResultSoNumber!;
                          } else {
                            _soNumberExportController.text = _searchResultSoNumber!;
                          }
                          Navigator.of(context).pop();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Mark dialog as closed
      _isDialogOpen = false;
    });
  }
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _soNumberImportController = TextEditingController();
  final _soNumberExportController = TextEditingController();
  final _weightController = TextEditingController();
  final _dateController = TextEditingController();
  final _noteController = TextEditingController();
  final _venderController = TextEditingController();
  final List<XFile> _imageFiles = [];

  // Dynamic number and qty fields for multiple product creation
  List<TextEditingController> _numberControllers = [TextEditingController()];
  List<TextEditingController> _qtyControllers = [TextEditingController()];

  // FocusNodes for field progression
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _soNumberFocusNode = FocusNode();
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _noteFocusNode = FocusNode();

  bool _isImport = true;

  bool _isLoading = false;

  late FlutterDataWedge _dataWedge;
  late StreamSubscription<ScanResult> _scanSubscription;

  // Helper for compute
  static Future<List<String>> copyImages(List<dynamic> args) async {
    final List<String> imagePaths = List<String>.from(args[0]);
    final String imagePath = args[1] as String;
    final String prefix = args.length > 2 ? args[2] as String : '';
    List<String> savedPaths = [];
    for (int i = 0; i < imagePaths.length; i++) {
      final fileName = prefix.isNotEmpty
          ? '${prefix}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg'
          : '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final savedImage = await File(imagePaths[i]).copy('$imagePath/$fileName');
      savedPaths.add(savedImage.path);
    }
    return savedPaths;
  }

  @override
  void initState() {
    super.initState();
    _dataWedge = FlutterDataWedge();

    // Add listener to auto-select all text when field changes (search dialog)
    _searchBarcodeController.addListener(() {
      if (_isDialogOpen && _searchBarcodeController.text.isNotEmpty) {
        // After text changes, select all so next scan replaces it
        Future.microtask(() {
          if (_isDialogOpen && _searchBarcodeController.text.isNotEmpty) {
            _searchBarcodeController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _searchBarcodeController.text.length,
            );
          }
        });
      }
    });

    // Add listener to detect barcode scan and auto-move to SO Number field
    // Scanner typically sends data quickly, so we use a debounce timer
    Timer? barcodeDebounceTimer;
    String lastBarcodeValue = '';

    _barcodeController.addListener(() {
      if (_isImport && !_isDialogOpen && _barcodeFocusNode.hasFocus) {
        final currentValue = _barcodeController.text;

        // Cancel any existing timer
        barcodeDebounceTimer?.cancel();

        // Only trigger if text was added (not deleted) and has meaningful length
        if (currentValue.isNotEmpty && currentValue.length > lastBarcodeValue.length && currentValue.length >= 3) {
          // Debounce: wait 200ms after last character to ensure scan is complete
          barcodeDebounceTimer = Timer(const Duration(milliseconds: 200), () {
            if (mounted && _isImport && _barcodeFocusNode.hasFocus && _barcodeController.text == currentValue) {
              // Auto-move focus to SO Number field after scan completes
              _soNumberFocusNode.requestFocus();
            }
          });
        }

        lastBarcodeValue = currentValue;

        // Select all text so next scan replaces it
        Future.microtask(() {
          if (_isImport && _barcodeController.text.isNotEmpty && !_isDialogOpen) {
            _barcodeController.selection = TextSelection(
              baseOffset: 0,
              extentOffset: _barcodeController.text.length,
            );
          }
        });
      }
    });

    _scanSubscription = _dataWedge.onScanResult.listen((ScanResult result) {
      // Normal screen scanning behavior only (dialog handled by text input)
      if (!_isDialogOpen) {
        // Use focus state to determine where to put the scanned data
        // If Barcode field has focus (Import mode), put data there and move to SO Number
        // Otherwise, put data in SO Number field
        if (_isImport && _barcodeFocusNode.hasFocus) {
          setState(() {
            _barcodeController.text = result.data;
          });
          // After barcode scan, move to SO Number field with delay to ensure focus change works
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _soNumberFocusNode.requestFocus();
            }
          });
        } else if (_soNumberFocusNode.hasFocus) {
          setState(() {
            if (_isImport) {
              _soNumberImportController.text = result.data.toUpperCase();
            } else {
              _soNumberExportController.text = result.data.toUpperCase();
            }
          });
          // After SO Number scan, move to Weight field (if in import mode) with delay
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _isImport) {
              _weightFocusNode.requestFocus();
            }
          });
        } else {
          // Default: if no specific field has focus, use the old label type logic
          if (result.labelType == 'LABEL-TYPE-EAN13') {
            setState(() {
              _barcodeController.text = result.data;
            });
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && _isImport) {
                _soNumberFocusNode.requestFocus();
              }
            });
          } else {
            setState(() {
              if (_isImport) {
                _soNumberImportController.text = result.data.toUpperCase();
              } else {
                _soNumberExportController.text = result.data.toUpperCase();
              }
            });
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && _isImport) {
                _weightFocusNode.requestFocus();
              }
            });
          }
        }
      }
    });
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Auto-focus on Barcode field when screen first loads (Import mode is default)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _scanSubscription.cancel();
    _searchBarcodeFocusNode.dispose();
    _barcodeFocusNode.dispose();
    _soNumberFocusNode.dispose();
    _weightFocusNode.dispose();
    _noteFocusNode.dispose();
    _barcodeController.dispose();
    _soNumberImportController.dispose();
    _soNumberExportController.dispose();
    _weightController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    _venderController.dispose();
    _searchBarcodeController.dispose();
    for (var controller in _numberControllers) {
      controller.dispose();
    }
    for (var controller in _qtyControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _takePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() {
        _imageFiles.add(image);
      });
    }
  }

  void _removeImage(XFile imageFile) {
    setState(() {
      _imageFiles.remove(imageFile);
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String imagePath = '${appDir.path}/Images';
        await Directory(imagePath).create(recursive: true);

        List<String> savedImagePaths = [];
        if (_isImport) {
          savedImagePaths = await compute(
            copyImages,
            [_imageFiles.map((x) => x.path).toList(), imagePath],
          );
        } else {
          savedImagePaths = await compute(
            copyImages,
            [_imageFiles.map((x) => x.path).toList(), imagePath, _soNumberExportController.text],
          );
        }

        final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? 'https://api.toyoshimainventory.com';
        final apiKey = dotenv.env['API_KEY'] ?? '';

        if (_isImport) {
          // Build list of number-qty pairs to submit
          List<Map<String, String>> itemsToSubmit = [];
          for (int i = 0; i < _numberControllers.length; i++) {
            final number = _numberControllers[i].text.trim();
            final qty = _qtyControllers[i].text.trim();
            if (number.isNotEmpty || qty.isNotEmpty) {
              itemsToSubmit.add({'number': number, 'qty': qty});
            }
          }

          // If no items entered, submit once with empty values
          if (itemsToSubmit.isEmpty) {
            itemsToSubmit = [{'number': '', 'qty': ''}];
          }

          int successCount = 0;
          String? lastError;

          // Submit one product for each number-qty pair
          for (var item in itemsToSubmit) {
            final request = http.MultipartRequest(
              'POST',
              Uri.parse('$apiBaseUrl/product/scanner/'),
            );
            request.headers['X-API-Key'] = apiKey;

            request.fields['action'] = 'inbound';
            request.fields['barcode'] = _barcodeController.text;
            request.fields['so_number'] = _soNumberImportController.text;
            request.fields['vender'] = _venderController.text;
            request.fields['weight'] = _weightController.text;
            request.fields['date'] = _dateController.text;
            request.fields['noted'] = _noteController.text;
            request.fields['current_status'] = '0';
            request.fields['created_by_username'] = 'mobile';
            if (item['number']!.isNotEmpty) {
              request.fields['number'] = item['number']!;
            }
            if (item['qty']!.isNotEmpty) {
              request.fields['qty'] = item['qty']!;
            }

            for (var savedPath in savedImagePaths) {
              request.files.add(
                await http.MultipartFile.fromPath('photos', savedPath),
              );
            }

            final response = await request.send();
            final responseBody = await response.stream.bytesToString();

            if (response.statusCode == 201 || response.statusCode == 200) {
              successCount++;
            } else {
              lastError = responseBody;
            }
          }

          // Show result
          if (successCount == itemsToSubmit.length) {
            _showSuccessDialog(successCount > 1
                ? '$successCount products submitted successfully'
                : 'Data submitted successfully');
          } else if (successCount > 0) {
            _showErrorDialog('$successCount of ${itemsToSubmit.length} products submitted. Error: $lastError');
          } else {
            _showErrorDialog('Failed to submit data: $lastError');
          }
        } else {
          // Export mode - single request, no number field
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('$apiBaseUrl/product/scanner/'),
          );
          request.headers['X-API-Key'] = apiKey;

          request.fields['action'] = 'outbound';
          request.fields['date'] = _dateController.text;
          request.fields['so_number'] = _soNumberExportController.text;
          request.fields['current_status'] = '1';
          request.fields['created_by_username'] = 'mobile';

          for (var savedPath in savedImagePaths) {
            request.files.add(
              await http.MultipartFile.fromPath('photos', savedPath),
            );
          }

          final response = await request.send();
          final responseBody = await response.stream.bytesToString();

          if (response.statusCode == 200) {
            _showSuccessDialog('Data updated successfully');
          } else if (response.statusCode == 404) {
            _showErrorDialog('The product not found.');
          } else {
            _showErrorDialog('Failed to update data: $responseBody');
          }
        }
      } catch (e) {
        _showErrorDialog('An error occurred: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _formKey.currentState!.reset();
                _barcodeController.clear();
                _soNumberImportController.clear();
                _soNumberExportController.clear();
                _weightController.clear();
                _noteController.clear();
                _venderController.clear();
                // Reset number and qty controllers
                for (var controller in _numberControllers) {
                  controller.dispose();
                }
                for (var controller in _qtyControllers) {
                  controller.dispose();
                }
                _numberControllers = [TextEditingController()];
                _qtyControllers = [TextEditingController()];
                FocusScope.of(context).unfocus();
                setState(() {
                  _imageFiles.clear();
                  _dateController.text = DateFormat(
                    'yyyy-MM-dd',
                  ).format(DateTime.now());
                });
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 220, 242, 245),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        toolbarHeight: 0,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildModeSelector(),
                    const SizedBox(height: 16),
                    if (_isImport) ...[
                      _buildTextFormField(
                        _barcodeController,
                        'Barcode',
                        Icons.barcode_reader,
                        focusNode: _barcodeFocusNode,
                        nextFocusNode: _soNumberFocusNode,
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _buildSoNumberField(
                            _isImport ? _soNumberImportController : _soNumberExportController,
                            focusNode: _soNumberFocusNode,
                            nextFocusNode: _isImport ? _weightFocusNode : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.search),
                          tooltip: 'Search by Barcode',
                          onPressed: _showSoNumberSearchDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_isImport) ...[
                      _buildTextFormField(
                        _venderController,
                        'Vender',
                        Icons.business,
                        isRequired: true,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCompactDateField(),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextFormField(
                              _weightController,
                              'Weight',
                              Icons.line_weight,
                              keyboardType: TextInputType.number,
                              focusNode: _weightFocusNode,
                              nextFocusNode: _noteFocusNode,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildNumberFields(),
                      const SizedBox(height: 10),
                      _buildTextFormField(
                        _noteController,
                        'Note',
                        Icons.note,
                        isRequired: false,
                        focusNode: _noteFocusNode,
                      ),
                      const SizedBox(height: 10),
                    ] else ...[
                      _buildDateField(),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _buildTakePhotoButton(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSubmitButton(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildImageGrid(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _isImport = true);
                // Focus on Barcode field when switching to Import
                Future.delayed(const Duration(milliseconds: 100), () {
                  _barcodeFocusNode.requestFocus();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isImport ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Import',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isImport ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _isImport = false);
                // Focus on SO Number field when switching to Export
                Future.delayed(const Duration(milliseconds: 100), () {
                  _soNumberFocusNode.requestFocus();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isImport ? Colors.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Export',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_isImport ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _dateController,
      decoration: InputDecoration(
        labelText: 'Date',
        prefixIcon: const Icon(Icons.calendar_today),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      readOnly: true,
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (pickedDate != null) {
          String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
          setState(() {
            _dateController.text = formattedDate;
          });
        }
      },
    );
  }

  Widget _buildCompactDateField() {
    return TextFormField(
      controller: _dateController,
      decoration: InputDecoration(
        labelText: 'Date',
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(Icons.calendar_today, size: 18),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      style: const TextStyle(fontSize: 14),
      readOnly: true,
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (pickedDate != null) {
          String formattedDate = DateFormat('yyyy-MM-dd').format(pickedDate);
          setState(() {
            _dateController.text = formattedDate;
          });
        }
      },
    );
  }

  Widget _buildTextFormField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool isRequired = true,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
  }) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (KeyEvent event) {
        // Detect Enter key from scanner or keyboard
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          if (nextFocusNode != null) {
            nextFocusNode.requestFocus();
          }
        }
      },
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        keyboardType: keyboardType,
        textInputAction: nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
        onFieldSubmitted: (_) {
          if (nextFocusNode != null) {
            nextFocusNode.requestFocus();
          }
        },
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Please enter a $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSoNumberField(
    TextEditingController controller, {
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        // Convert to uppercase
        TextInputFormatter.withFunction((oldValue, newValue) {
          return newValue.copyWith(text: newValue.text.toUpperCase());
        }),
      ],
      decoration: InputDecoration(
        labelText: 'SO Number',
        prefixIcon: const Icon(Icons.scanner),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      textInputAction: nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: (_) {
        if (nextFocusNode != null) {
          nextFocusNode.requestFocus();
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a SO Number';
        }
        // Check if SO Number starts with valid prefix (letters or numbers)
        if (!RegExp(r'^[A-Z0-9]').hasMatch(value)) {
          return 'SO Number must start with a letter or number';
        }
        // Minimum length check
        if (value.length < 3) {
          return 'SO Number must be at least 3 characters';
        }
        return null;
      },
    );
  }

  Widget _buildNumberFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(_numberControllers.length, (index) {
          final isLast = index == _numberControllers.length - 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Number field - takes 60% of space
                Expanded(
                  flex: 6,
                  child: TextFormField(
                    controller: _numberControllers[index],
                    decoration: InputDecoration(
                      labelText: _numberControllers.length > 1
                          ? 'Number ${index + 1}'
                          : 'Number',
                      hintText: 'Enter number',
                      prefixIcon: const Icon(Icons.tag, color: Colors.blue),
                      filled: true,
                      fillColor: Colors.grey[100],
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
                    keyboardType: TextInputType.text,
                  ),
                ),
                const SizedBox(width: 8),
                // Qty field - takes 30% of space
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _qtyControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Qty',
                      hintText: 'Qty',
                      filled: true,
                      fillColor: Colors.grey[100],
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
                    keyboardType: TextInputType.number,
                  ),
                ),
                // Action buttons
                if (_numberControllers.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _numberControllers[index].dispose();
                        _numberControllers.removeAt(index);
                        _qtyControllers[index].dispose();
                        _qtyControllers.removeAt(index);
                      });
                    },
                  ),
                if (isLast)
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    onPressed: () {
                      setState(() {
                        _numberControllers.add(TextEditingController());
                        _qtyControllers.add(TextEditingController());
                      });
                    },
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildImageGrid() {
    return _imageFiles.isEmpty
        ? Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    'No photos taken yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        : GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
            ),
            itemCount: _imageFiles.length,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Image.file(
                      File(_imageFiles[index].path),
                      fit: BoxFit.cover,
                      height: 150,
                      width: 150,
                      cacheWidth: 150,
                      cacheHeight: 150,
                    ),
                    Container(
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _removeImage(_imageFiles[index]),
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }

  Widget _buildTakePhotoButton() {
    return ElevatedButton.icon(
      onPressed: _takePicture,
      icon: const Icon(Icons.camera_alt, size: 22),
      label: const Text('Photo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submit,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text(
        'Submit',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
    );
  }
}
