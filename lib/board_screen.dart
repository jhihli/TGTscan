import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_datawedge/flutter_datawedge.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class BoardScreen extends StatefulWidget {
  final String token;
  final String baseUrl;

  const BoardScreen({super.key, required this.token, required this.baseUrl});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final _formKey = GlobalKey<FormState>();

  // SO Number
  final TextEditingController _soNumberController = TextEditingController();
  final FocusNode _soNumberFocusNode = FocusNode();

  // SO inline search state
  List<Map<String, dynamic>> _soResults = [];
  bool _isSearchingSo = false;
  Timer? _soSearchDebounce;
  OverlayEntry? _soOverlayEntry;
  final LayerLink _soLayerLink = LayerLink();

  // Selected SO info (set when user picks from dropdown)
  String? _selectedSoId;
  String? _selectedSoVendor;
  String? _selectedSoDate;

  // Pallets for selected SO
  List<Map<String, dynamic>> _soPallets = [];
  int? _selectedPalletId;
  bool _palletsLoading = false;

  // Barcodes (dynamic list)
  List<TextEditingController> _barcodeControllers = [TextEditingController()];
  final FocusNode _firstBarcodeFocusNode = FocusNode();

  // Other fields
  final TextEditingController _catalogController = TextEditingController();
  final TextEditingController _mpnController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _chipQtyController = TextEditingController(text: '1');
  final TextEditingController _noteController = TextEditingController();

  List<XFile> _imageFiles = [];
  bool _isLoading = false;

  late FlutterDataWedge _dataWedge;
  late StreamSubscription<ScanResult> _scanSubscription;

  @override
  void initState() {
    super.initState();

    _dataWedge = FlutterDataWedge();
    _scanSubscription = _dataWedge.onScanResult.listen((ScanResult result) {
      final emptyIdx =
          _barcodeControllers.indexWhere((c) => c.text.isEmpty);
      setState(() {
        if (emptyIdx >= 0) {
          _barcodeControllers[emptyIdx].text = result.data;
        } else {
          _barcodeControllers.add(TextEditingController(text: result.data));
        }
      });
    });

    _soNumberFocusNode.addListener(() {
      if (!_soNumberFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 150), _removeSoOverlay);
      }
    });
  }

  @override
  void dispose() {
    _soSearchDebounce?.cancel();
    _removeSoOverlay();
    _scanSubscription.cancel();
    _soNumberController.dispose();
    _soNumberFocusNode.dispose();
    for (final c in _barcodeControllers) {
      c.dispose();
    }
    _firstBarcodeFocusNode.dispose();
    _catalogController.dispose();
    _mpnController.dispose();
    _weightController.dispose();
    _chipQtyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ── Photos ─────────────────────────────────────────────────────────────────

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
    if (image != null) setState(() => _imageFiles.add(image));
  }

  void _removeImage(XFile imageFile) {
    setState(() => _imageFiles.remove(imageFile));
  }

  Widget _buildImageGrid() {
    if (_imageFiles.isEmpty) {
      return Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 20, color: Colors.grey),
            SizedBox(width: 8),
            Text('No photo taken yet',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }
    return GridView.builder(
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

  // ── SO Number inline search ─────────────────────────────────────────────────

  Future<void> _fetchPallets(String soId) async {
    setState(() { _palletsLoading = true; _soPallets = []; _selectedPalletId = null; });
    try {
      final apiKey = dotenv.env['API_KEY'] ?? '';
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/product/scanner/sos/$soId/pallets/'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'X-Api-Key': apiKey,
        },
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final list = (jsonDecode(response.body) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        setState(() {
          _soPallets = list;
          if (list.length == 1) _selectedPalletId = list[0]['id'] as int;
        });
      }
    } catch (_) {
      // Silently fail — _buildPalletPicker will show the "no pallets" warning
    } finally {
      if (mounted) setState(() => _palletsLoading = false);
    }
  }

  String _palletLabel(Map<String, dynamic> pallet) {
    final licence = pallet['licence_number'] as String? ?? '';
    final payload = pallet['payload_number'] as String? ?? '';
    if (licence.isNotEmpty || payload.isNotEmpty) {
      return [licence, payload].where((s) => s.isNotEmpty).join('-');
    }
    final seq = pallet['pallet_seq'] as int? ?? 0;
    return '#${seq.toString().padLeft(2, '0')}';
  }

  Widget _buildPalletPicker() {
    if (_selectedSoId == null) return const SizedBox.shrink();

    if (_palletsLoading) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading pallets…',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    if (_soPallets.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined,
                size: 16, color: Colors.orange[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No pallets for this SO. Submit a pallet inbound first.',
                style: TextStyle(fontSize: 13, color: Colors.orange[800]),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Pallet',
          labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          prefixIcon: const Icon(Icons.inventory_2, size: 18),
          filled: true,
          fillColor: const Color(0xFFFFF8E7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: _selectedPalletId,
            isDense: true,
            isExpanded: true,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            hint: const Text('Select pallet',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
            items: _soPallets.map((p) {
              return DropdownMenuItem<int>(
                value: p['id'] as int,
                child: Text(_palletLabel(p)),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedPalletId = val),
          ),
        ),
      ),
    );
  }

  void _onSoNumberChanged(String query) {
    // Clear selected SO info and pallets when user edits the field
    if (_selectedSoVendor != null ||
        _selectedSoDate != null ||
        _selectedSoId != null) {
      setState(() {
        _selectedSoVendor = null;
        _selectedSoDate = null;
        _selectedSoId = null;
        _soPallets = [];
        _selectedPalletId = null;
      });
    }
    _soSearchDebounce?.cancel();
    if (query.length < 3) {
      _removeSoOverlay();
      setState(() => _soResults = []);
      return;
    }
    _soSearchDebounce =
        Timer(const Duration(milliseconds: 400), () => _searchSoNumbers(query));
  }

  void _showNetworkAlert(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Connection Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSearchSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _searchSoNumbers(String query) async {
    if (!mounted) return;
    setState(() => _isSearchingSo = true);
    try {
      final apiKey = dotenv.env['API_KEY'] ?? '';
      final response = await http.post(
        Uri.parse('${widget.baseUrl}/product/scanner/'),
        headers: {
          'Content-Type': 'application/json',
          'X-Api-Key': apiKey,
        },
        body: jsonEncode({'action': 'so_search', 'q': query}),
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final results = (decoded['data'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        setState(() => _soResults = results);
        if (results.isNotEmpty && _soNumberFocusNode.hasFocus) {
          _showSoOverlay();
        } else {
          _removeSoOverlay();
          if (results.isEmpty) {
            _showSearchSnackBar(
                'No SO numbers found for "$query"', Colors.orange.shade700);
          }
        }
      } else {
        _removeSoOverlay();
        _showSearchSnackBar(
            'Server error (${response.statusCode}) — please try again',
            Colors.red.shade700);
      }
    } on TimeoutException {
      if (mounted) {
        _removeSoOverlay();
        _showNetworkAlert('SO search timed out. Please check your network connection.');
      }
    } on SocketException {
      if (mounted) {
        _removeSoOverlay();
        _showNetworkAlert('Cannot reach the server. Please check your network connection.');
      }
    } catch (_) {
      if (mounted) {
        _removeSoOverlay();
        _showSearchSnackBar(
            'Search failed — unexpected error', Colors.red.shade700);
      }
    } finally {
      if (mounted) setState(() => _isSearchingSo = false);
    }
  }

  void _showSoOverlay() {
    _removeSoOverlay();
    _soOverlayEntry = OverlayEntry(
      builder: (ctx) => CompositedTransformFollower(
        link: _soLayerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 52),
        child: Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 32,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _soResults.length,
                  itemBuilder: (ctx, i) {
                    final so = _soResults[i];
                    final soNumber = so['so_number']?.toString() ?? '';
                    final vendor = so['vendor_name']?.toString() ?? '';
                    return InkWell(
                      onTap: () {
                        final soId = so['id']?.toString();
                        _soNumberController.text = soNumber;
                        setState(() {
                          _selectedSoVendor =
                              vendor.isNotEmpty ? vendor : null;
                          _selectedSoDate = so['date']?.toString();
                          _selectedSoId = soId;
                          _soResults = [];
                          _soPallets = [];
                          _selectedPalletId = null;
                        });
                        _removeSoOverlay();
                        _soNumberFocusNode.unfocus();
                        if (soId != null) _fetchPallets(soId);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long,
                                size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(soNumber,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  if (vendor.isNotEmpty)
                                    Text(vendor,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600])),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) Overlay.of(context).insert(_soOverlayEntry!);
  }

  void _removeSoOverlay() {
    _soOverlayEntry?.remove();
    _soOverlayEntry = null;
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Block if SO number was typed manually without selecting from dropdown
    if (_selectedSoId == null) {
      _showSearchSnackBar(
          'Please search and select an SO from the dropdown results.',
          Colors.orange.shade700);
      _soNumberFocusNode.requestFocus();
      return;
    }

    // Block if pallets are still loading
    if (_palletsLoading) {
      _showSearchSnackBar(
          'Pallets are still loading, please wait.', Colors.orange.shade700);
      return;
    }

    // Block if SO selected but has no pallets yet
    if (_soPallets.isEmpty) {
      _showSearchSnackBar(
          'No pallets for this SO. Submit a pallet inbound first.',
          Colors.orange.shade700);
      return;
    }

    // Block if pallets loaded but none selected
    if (_soPallets.isNotEmpty && _selectedPalletId == null) {
      _showSearchSnackBar('Please select a pallet.', Colors.orange.shade700);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final apiKey = dotenv.env['API_KEY'] ?? '';
      final barcodes = _barcodeControllers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final body = <String, dynamic>{
        'action': 'board_inbound',
        'so_number': _soNumberController.text,
        'barcodes': barcodes,
        if (_selectedPalletId != null) 'pallet_id': _selectedPalletId,
      };
      if (_catalogController.text.isNotEmpty) {
        body['catalog'] = _catalogController.text;
      }
      if (_mpnController.text.isNotEmpty) body['mpn'] = _mpnController.text;
      if (_weightController.text.isNotEmpty) {
        body['weight'] = _weightController.text;
      }
      if (_chipQtyController.text.isNotEmpty) {
        body['qty'] = _chipQtyController.text;
      }
      if (_noteController.text.isNotEmpty) body['note'] = _noteController.text;

      final response = await http
          .post(
            Uri.parse('${widget.baseUrl}/product/scanner/'),
            headers: {
              'Authorization': 'Bearer ${widget.token}',
              'Content-Type': 'application/json',
              'X-Api-Key': apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Upload photo to each created board
        if (_imageFiles.isNotEmpty) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          final boards = (decoded['data'] as List<dynamic>? ?? []);
          for (final board in boards) {
            final boardId = board['id']?.toString();
            if (boardId == null) continue;
            for (final img in _imageFiles) {
              try {
                final photoReq = http.MultipartRequest(
                  'POST',
                  Uri.parse('${widget.baseUrl}/product/scanner/boards/$boardId/photo/'),
                );
                photoReq.headers['X-Api-Key'] = apiKey;
                photoReq.files.add(await http.MultipartFile.fromPath('photo', img.path));
                await photoReq.send().timeout(const Duration(seconds: 30));
              } catch (_) {}
            }
          }
        }
        if (!mounted) return;
        _resetForm();
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${barcodes.length} board${barcodes.length != 1 ? 's' : ''} submitted successfully'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final msg =
            decoded['error'] ?? 'Submission failed (${response.statusCode})';
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.toString()),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on TimeoutException {
      if (!mounted) return;
      _showNetworkAlert('Request timed out. Please check your network connection and try again.');
    } on SocketException {
      if (!mounted) return;
      _showNetworkAlert('Cannot reach the server. Please check your network connection.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('An unexpected error occurred: $e'),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    // SO Number, SO info, and pallet selection persist across submits;
    // barcodes and detail fields reset so worker can scan the next board batch
    for (final c in _barcodeControllers) {
      c.dispose();
    }
    _catalogController.clear();
    _mpnController.clear();
    _weightController.clear();
    _noteController.clear();
    setState(() {
      _barcodeControllers = [TextEditingController()];
      _imageFiles = [];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _firstBarcodeFocusNode.requestFocus();
    });
  }

  // ── Field builders ──────────────────────────────────────────────────────────

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool isRequired = false,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: isRequired ? const Color(0xFFFFF8E7) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      style: const TextStyle(fontSize: 14),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction:
          nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: (_) => nextFocusNode?.requestFocus(),
      validator: isRequired
          ? (value) {
              if (value == null || value.isEmpty) return 'Please enter $label';
              return null;
            }
          : null,
    );
  }

  Widget _buildBarcodeFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_barcodeControllers.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _barcodeControllers[index],
                  focusNode:
                      index == 0 ? _firstBarcodeFocusNode : null,
                  decoration: InputDecoration(
                    labelText: _barcodeControllers.length > 1
                        ? 'Barcode ${index + 1}'
                        : 'Barcode',
                    labelStyle:
                        const TextStyle(fontSize: 13, color: Colors.grey),
                    prefixIcon: const Icon(Icons.qr_code,
                        size: 18, color: Colors.blue),
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
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                  ),
                  style: const TextStyle(fontSize: 14),
                  textInputAction: TextInputAction.next,
                ),
              ),
              if (index == 0)
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  onPressed: () {
                    setState(() {
                      _barcodeControllers.add(TextEditingController());
                    });
                  },
                ),
              if (index > 0)
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _barcodeControllers[index].dispose();
                      _barcodeControllers.removeAt(index);
                    });
                  },
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSoInfoRow() {
    if (_selectedSoVendor == null && _selectedSoDate == null) {
      return const SizedBox.shrink();
    }
    final parts = <String>[
      if (_selectedSoVendor != null) _selectedSoVendor!,
      if (_selectedSoDate != null) _selectedSoDate!,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: Colors.green[700]),
          const SizedBox(width: 8),
          Text(
            parts.join(' · '),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green[800]),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SO Number with inline search suggestions
                  CompositedTransformTarget(
                    link: _soLayerLink,
                    child: TextFormField(
                      controller: _soNumberController,
                      focusNode: _soNumberFocusNode,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) =>
                            newValue.copyWith(
                                text: newValue.text.toUpperCase())),
                      ],
                      onChanged: _onSoNumberChanged,
                      decoration: InputDecoration(
                        labelText: 'SO Number',
                        labelStyle:
                            const TextStyle(fontSize: 13, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _isSearchingSo
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFFFF8E7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                      ),
                      style: const TextStyle(fontSize: 14),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a SO Number';
                        }
                        if (value.length < 3) {
                          return 'SO Number must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // SO Info row (shown after selecting from dropdown)
                  _buildSoInfoRow(),

                  // Pallet picker (shown after SO is selected)
                  _buildPalletPicker(),

                  // MPN
                  _buildTextField(
                    _mpnController,
                    'MPN',
                    Icons.code,
                    isRequired: true,
                  ),
                  const SizedBox(height: 8),

                  // Dynamic barcode fields
                  _buildBarcodeFields(),

                  // Catalog
                  _buildTextField(
                    _catalogController,
                    'Catalog',
                    Icons.category,
                  ),
                  const SizedBox(height: 8),

                  // Weight + Chip Qty side by side
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          _weightController,
                          'Weight',
                          Icons.line_weight,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'))
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _chipQtyController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Chip Qty',
                            labelStyle: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                            prefixIcon:
                                const Icon(Icons.memory, size: 18),
                            filled: true,
                            fillColor: Colors.grey[300],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 12),
                          ),
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Note
                  _buildTextField(
                    _noteController,
                    'Note',
                    Icons.note,
                  ),
                  const SizedBox(height: 8),

                  // Photo + Submit
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _takePicture,
                          icon: const Icon(Icons.camera_alt, size: 22),
                          label: const Text('Photo',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w900)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Submit',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Photos
                  _buildImageGrid(),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
