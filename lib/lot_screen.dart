import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_datawedge/flutter_datawedge.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'industrial.dart';

class LotScreen extends StatefulWidget {
  final String token;
  final String baseUrl;

  const LotScreen({super.key, required this.token, required this.baseUrl});

  @override
  State<LotScreen> createState() => _LotScreenState();
}

class _LotScreenState extends State<LotScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _soNumberController = TextEditingController();
  final TextEditingController _vendorController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  final FocusNode _soNumberFocusNode = FocusNode();
  final FocusNode _vendorFocusNode = FocusNode();

  final TextEditingController _licenceController = TextEditingController();
  final TextEditingController _palletWeightController = TextEditingController();
  final TextEditingController _materialTypeController = TextEditingController();

  final FocusNode _licenceFocusNode = FocusNode();
  final FocusNode _palletWeightFocusNode = FocusNode();

  // Gate No — type-or-select combobox of 1–100 (same widget as Vendor).
  final TextEditingController _gateController = TextEditingController();
  final FocusNode _gateFocusNode = FocusNode();

  // Location — composed from Zone (A–Z) · Row (1–10) · Column (1–200),
  // sent to the backend as "Zone-Row-Column" (e.g. "A-2-3").
  String? _locZone;
  int? _locRow;
  int? _locCol;

  // The LOCATION group (date, material type, location) collapses; closed by default.
  bool _detailsExpanded = false;

  // The PHOTOS canvas collapses; closed by default, opens when a photo is taken.
  bool _photosExpanded = false;

  List<Map<String, dynamic>> _vendors = [];
  bool _vendorsLoading = false;
  String? _vendorLoadError;

  List<XFile> _imageFiles = [];
  bool _isLoading = false;

  late FlutterDataWedge _dataWedge;
  late StreamSubscription<ScanResult> _scanSubscription;

  // A single fixed height keeps every instrument field the same size.
  static const double _fieldHeight = 46; // default height for most fields
  static const double _vendorHeight = 46; // ← tune VENDOR height here
  static const double _gateHeight = 46; // ← tune GATE NO height here

  // Debounced lookup that auto-fills the vendor/gate from an existing SO.
  Timer? _soLookupDebounce;
  bool _soLookingUp = false;
  // Track whether vendor/gate were filled by the SO lookup (vs. picked by the
  // worker) so we can clear them when the SO no longer matches.
  bool _vendorAuto = false;
  bool _gateAuto = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadVendors();

    _dataWedge = FlutterDataWedge();
    _scanSubscription = _dataWedge.onScanResult.listen((ScanResult result) {
      if (_soNumberFocusNode.hasFocus) {
        final so = result.data.toUpperCase();
        setState(() => _soNumberController.text = so);
        _lookupSo(so);
        // Vendor/Gate auto-fill from the SO; advance straight to Barcode.
        _licenceFocusNode.requestFocus();
        return;
      }
      if (_licenceFocusNode.hasFocus) {
        setState(() => _licenceController.text = result.data);
        _palletWeightFocusNode.requestFocus();
        return;
      }
      if (_palletWeightFocusNode.hasFocus) {
        setState(() => _palletWeightController.text = result.data);
      }
    });
  }

  @override
  void dispose() {
    _scanSubscription.cancel();
    _soLookupDebounce?.cancel();
    _soNumberController.dispose();
    _vendorController.dispose();
    _dateController.dispose();
    _soNumberFocusNode.dispose();
    _vendorFocusNode.dispose();
    _licenceController.dispose();
    _palletWeightController.dispose();
    _materialTypeController.dispose();
    _gateController.dispose();
    _licenceFocusNode.dispose();
    _palletWeightFocusNode.dispose();
    _gateFocusNode.dispose();
    super.dispose();
  }

  // ── Networking ───────────────────────────────────────────────────────────────

  Future<void> _loadVendors() async {
    setState(() {
      _vendorsLoading = true;
      _vendorLoadError = null;
    });
    try {
      final apiKey = dotenv.env['API_KEY'] ?? '';
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/product/scanner/vendors/'),
        headers: {'X-Api-Key': apiKey},
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (mounted) {
          setState(() => _vendors = list.cast<Map<String, dynamic>>());
        }
      } else {
        if (mounted) {
          setState(() => _vendorLoadError = 'HTTP ${response.statusCode}');
        }
      }
    } on TimeoutException {
      if (mounted) setState(() => _vendorLoadError = 'Timed out');
    } on SocketException catch (e) {
      if (mounted) {
        setState(() => _vendorLoadError =
            'Cannot reach ${widget.baseUrl}\n${e.message}');
      }
    } catch (e) {
      if (mounted) setState(() => _vendorLoadError = e.toString());
    } finally {
      if (mounted) setState(() => _vendorsLoading = false);
    }
  }

  // Debounce SO typing, then look the SO up to auto-fill vendor/gate.
  void _onSoChanged(String value) {
    _soLookupDebounce?.cancel();
    // Any edit to the SO invalidates the auto-fill — clear + re-enable vendor/
    // gate immediately; the debounced lookup re-fills them if the new SO matches.
    _clearAutoFills();
    final so = value.trim();
    if (so.length < 3) return;
    _soLookupDebounce =
        Timer(const Duration(milliseconds: 500), () => _lookupSo(so));
  }

  // Clear vendor/gate ONLY if they were auto-filled by a previous SO lookup;
  // values the worker picked manually are left alone.
  void _clearAutoFills() {
    if (!_vendorAuto && !_gateAuto) return;
    setState(() {
      if (_vendorAuto) {
        _vendorController.clear();
        _vendorAuto = false;
      }
      if (_gateAuto) {
        _gateController.clear();
        _gateAuto = false;
      }
    });
  }

  // A brand-new SO (generated or typed, not in the DB): Gate No locks to 1;
  // Vendor is left for the worker to pick (only an auto-filled one is dropped).
  void _applyNewSo() {
    setState(() {
      if (_vendorAuto) {
        _vendorController.clear();
        _vendorAuto = false;
      }
      _gateController.text = '1';
      _gateAuto = true;
    });
  }

  // If the SO already exists, fill the vendor from its record and set Gate No
  // to (max existing gate for this SO) + 1 so the pallet can't collide with an
  // existing one. If the SO doesn't exist, any previously auto-filled vendor/
  // gate are cleared.
  Future<bool> _lookupSo(String soNumber) async {
    final so = soNumber.trim();
    if (so.length < 3) return false;
    setState(() => _soLookingUp = true);
    var found = false;
    try {
      final apiKey = dotenv.env['API_KEY'] ?? '';
      final response = await http
          .post(
            Uri.parse('${widget.baseUrl}/product/scanner/'),
            headers: {
              'Content-Type': 'application/json',
              'X-Api-Key': apiKey,
            },
            body: jsonEncode({'action': 'find_so_number', 'barcode': so}),
          )
          .timeout(const Duration(seconds: 10));
      if (!mounted) return false;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['success'] == true) {
          found = true;
          final data = body['data'] as Map<String, dynamic>?;
          final vendorName = data?['vendor_name']?.toString();
          if (vendorName != null && vendorName.isNotEmpty) {
            setState(() {
              _vendorController.text = vendorName;
              _vendorAuto = true;
            });
          }
          final soId = data?['id']?.toString();
          if (soId != null) {
            final nextGate = await _nextGateForSo(soId, apiKey);
            if (mounted && nextGate != null) {
              setState(() {
                _gateController.text = nextGate.toString();
                _gateAuto = true;
              });
            }
          }
          // Vendor/gate are filled and locked — jump straight to Barcode.
          if (mounted) _licenceFocusNode.requestFocus();
        }
      }
      // SO not found → it's a new SO: lock Gate No to 1.
      if (!found) _applyNewSo();
    } catch (_) {
      // Network error — ignore; the fields stay as they are.
    } finally {
      if (mounted) setState(() => _soLookingUp = false);
    }
    return found;
  }

  // Highest gateload_number already on this SO's pallets, plus 1 (1 if none).
  Future<int?> _nextGateForSo(String soId, String apiKey) async {
    try {
      final resp = await http.get(
        Uri.parse('${widget.baseUrl}/product/scanner/sos/$soId/pallets/'),
        headers: {'X-Api-Key': apiKey},
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final list = (jsonDecode(resp.body) as List<dynamic>)
            .cast<Map<String, dynamic>>();
        int maxGate = 0;
        for (final p in list) {
          final g =
              int.tryParse((p['gateload_number'] ?? '').toString().trim());
          if (g != null && g > maxGate) maxGate = g;
        }
        return maxGate + 1;
      }
    } catch (_) {
      // ignore — leave gate for the worker to set
    }
    return null;
  }

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() {
        _imageFiles.add(image);
        _photosExpanded = true;
      });
    }
  }

  void _removeImage(XFile imageFile) {
    setState(() => _imageFiles.remove(imageFile));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final vendor = _vendorController.text.trim();
    if (vendor.isEmpty) {
      _showSnackBar('Vendor required — type or select one', isError: true);
      _vendorFocusNode.requestFocus();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final apiKey = dotenv.env['API_KEY'] ?? '';

      final response = await http
          .post(
            Uri.parse('${widget.baseUrl}/product/scanner/'),
            headers: {
              'Authorization': 'Bearer ${widget.token}',
              'Content-Type': 'application/json',
              'X-Api-Key': apiKey,
            },
            body: jsonEncode({
              'action': 'lot_inbound',
              'so_number': _soNumberController.text,
              'vendor': vendor,
              // Every vendor uses the per-pallet rule → one pallet, qty 1.
              'weight_rule': 'per_pallet',
              'date': _dateController.text,
              // Backend _lot_inbound reads `pallet_weight` and stores it
              // into the pallet.in_weight_gross column.
              'licence_number': _licenceController.text,
              'gateload_number': _gateController.text.trim(),
              'material_type': _materialTypeController.text.trim(),
              // Only send location when Zone, Row, and Column are all chosen.
              if (_locZone != null && _locRow != null && _locCol != null)
                'location': '$_locZone-$_locRow-$_locCol',
              'pallet_weight': _palletWeightController.text,
              'pallet_qty': '1',
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode != 200 && response.statusCode != 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        // Backend reports a duplicate pallet (same SO + vendor + gate) with
        // HTTP 409. Show a blocking alert instead of a transient snackbar.
        if (response.statusCode == 409 || body['error'] == 'duplicate') {
          final msg = (body['message'] ?? body['error'] ??
                  'This pallet already exists.')
              .toString();
          _showDuplicateAlert(msg);
          return;
        }
        final msg =
            body['error'] ?? 'Submission failed (${response.statusCode})';
        _showSnackBar(msg.toString(), isError: true);
        return;
      }

      final palletId = (jsonDecode(response.body)
          as Map<String, dynamic>)['data']?['pallet']?['id']?.toString();

      // Upload every photo to this pallet (multiple photos per pallet).
      if (_imageFiles.isNotEmpty && palletId != null) {
        for (final img in _imageFiles) {
          try {
            final photoReq = http.MultipartRequest(
              'POST',
              Uri.parse(
                  '${widget.baseUrl}/product/scanner/pallets/$palletId/photos/'),
            );
            photoReq.headers['X-Api-Key'] = apiKey;
            photoReq.files
                .add(await http.MultipartFile.fromPath('image', img.path));
            await photoReq.send().timeout(const Duration(seconds: 30));
          } catch (_) {}
        }
      }

      if (!mounted) return;
      _resetForm();
      _showSnackBar('Pallet logged', isError: false);
    } on TimeoutException {
      if (!mounted) return;
      _showNetworkAlert(
          'Request timed out. Check the network connection and retry.');
    } on SocketException {
      if (!mounted) return;
      _showNetworkAlert('Cannot reach the server. Check the network link.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Unexpected error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    // Keep SO number, vendor, and date so the worker can log the next pallet
    // on the same SO. Only clear the per-pallet fields.
    _licenceController.clear();
    _palletWeightController.clear();
    _materialTypeController.clear();
    // The SO now exists in the DB → lock its vendor for subsequent pallets.
    // Keep the gate sequence going — the next pallet on this SO is current + 1.
    final currentGate = int.tryParse(_gateController.text.trim());
    setState(() {
      _vendorAuto = true;
      if (currentGate != null) {
        _gateController.text = (currentGate + 1).toString();
        _gateAuto = true;
      } else {
        _gateController.clear();
        _gateAuto = false;
      }
      _locZone = null;
      _locRow = null;
      _locCol = null;
      _imageFiles = [];
      _photosExpanded = false;
    });
    _licenceFocusNode.requestFocus();
  }

  // Pull-down "clear all" — wipes every field except Date and starts fresh.
  Future<void> _clearAll() async {
    _soNumberController.clear();
    _vendorController.clear();
    _gateController.clear();
    _licenceController.clear();
    _palletWeightController.clear();
    _materialTypeController.clear();
    setState(() {
      _vendorAuto = false;
      _gateAuto = false;
      _locZone = null;
      _locRow = null;
      _locCol = null;
      _imageFiles = [];
      _detailsExpanded = false;
      _photosExpanded = false;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    _showSnackBar('Form cleared');
  }

  // ── Feedback (industrial styling) ────────────────────────────────────────────

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final accent = isError ? Ind.danger : Ind.ok;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Ind.panel,
        elevation: 8,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: accent),
        ),
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
                color: accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(color: Ind.text, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  void _showNetworkAlert(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ind.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Ind.danger),
        ),
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Ind.danger, size: 20),
            SizedBox(width: 8),
            Text('LINK ERROR',
                style: TextStyle(
                    color: Ind.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ],
        ),
        content: Text(message,
            style: const TextStyle(color: Ind.textDim, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('DISMISS',
                style: TextStyle(
                    color: Ind.amber, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showDuplicateAlert(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ind.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Ind.amber),
        ),
        title: const Row(
          children: [
            Icon(Icons.report_problem_outlined, color: Ind.amber, size: 20),
            SizedBox(width: 8),
            Text('DUPLICATE PALLET',
                style: TextStyle(
                    color: Ind.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ],
        ),
        content: Text(message,
            style: const TextStyle(color: Ind.textDim, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK',
                style: TextStyle(
                    color: Ind.amber, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Field primitives ─────────────────────────────────────────────────────────

  InputDecoration _fieldDecoration(String hint,
      {bool isRequired = false,
      double height = _fieldHeight,
      Widget? suffixIcon}) {
    OutlineInputBorder side(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          fontSize: 11, color: Ind.textDim, letterSpacing: 0.8),
      filled: true,
      fillColor: isRequired ? Ind.amberTint : Ind.inset,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      constraints: BoxConstraints(minHeight: height, maxHeight: height),
      suffixIcon: suffixIcon,
      suffixIconConstraints:
          const BoxConstraints(minWidth: 32, minHeight: 0),
      enabledBorder: side(isRequired ? Ind.amberDim : Ind.border),
      border: side(Ind.border),
      focusedBorder: side(Ind.amber, 1.6),
      errorBorder: side(Ind.danger),
      focusedErrorBorder: side(Ind.danger, 1.6),
      errorStyle: const TextStyle(fontSize: 0, height: 0),
    );
  }

  Widget _buildCompactField(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool isRequired = false,
    bool mono = false,
    double height = _fieldHeight,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
  }) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          nextFocusNode?.requestFocus();
        }
      },
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        cursorColor: Ind.amber,
        decoration:
            _fieldDecoration(hint, isRequired: isRequired, height: height),
        style: TextStyle(
          fontSize: 14,
          color: Ind.text,
          fontFamily: mono ? Ind.mono : null,
          letterSpacing: mono ? 0.5 : 0,
        ),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textInputAction:
            nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
        onFieldSubmitted: (_) => nextFocusNode?.requestFocus(),
        validator: isRequired
            ? (value) =>
                (value == null || value.isEmpty) ? 'REQUIRED' : null
            : null,
      ),
    );
  }

  // A read-only "picker" field (tap to open a sheet) styled exactly like the
  // text fields — same decoration, same forced height.
  Widget _pickerField({
    required String? value,
    required String hint,
    required VoidCallback onTap,
    bool mono = false,
    double height = _fieldHeight,
  }) {
    final hasValue = value != null && value.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: _fieldDecoration(hint, height: height),
        isEmpty: !hasValue,
        child: hasValue
            ? Text(value,
                style: TextStyle(
                    fontSize: 14,
                    color: Ind.text,
                    fontFamily: mono ? Ind.mono : null))
            : null,
      ),
    );
  }

  // Sheet picker with a NONE option. Returns the picked String, the _kNone
  // sentinel (clear the field), or null (dismissed — leave unchanged).
  static const Object _kNone = Object();

  Future<Object?> _pickOption({
    required String title,
    required List<String> options,
    required String? current,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Ind.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
                child: Row(
                  children: [
                    Container(width: 3, height: 14, color: Ind.amber),
                    const SizedBox(width: 8),
                    Text(title,
                        style: Ind.label
                            .copyWith(color: Ind.text, fontSize: 12)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Ind.textDim),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Ind.border),
              InkWell(
                onTap: () => Navigator.pop(ctx, _kNone),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.not_interested,
                          size: 16,
                          color: current == null ? Ind.amber : Ind.textDim),
                      const SizedBox(width: 8),
                      Text('NONE',
                          style: TextStyle(
                              fontFamily: Ind.mono,
                              fontSize: 13,
                              letterSpacing: 1,
                              color:
                                  current == null ? Ind.amber : Ind.textDim)),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Ind.border),
              Flexible(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: options.length,
                  itemBuilder: (c, i) {
                    final opt = options[i];
                    final selected = opt == current;
                    return InkWell(
                      onTap: () => Navigator.pop(ctx, opt),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? Ind.amber : Ind.inset,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: selected ? Ind.amber : Ind.border),
                        ),
                        child: Text(opt,
                            style: TextStyle(
                                fontFamily: Ind.mono,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: selected ? Ind.bg : Ind.text)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SO Number (terminal command line) ────────────────────────────────────────

  Widget _buildSoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 6),
          child: Text('SO NUMBER', style: Ind.label),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _soNumberController,
                focusNode: _soNumberFocusNode,
                cursorColor: Ind.amber,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) =>
                      newValue.copyWith(text: newValue.text.toUpperCase())),
                ],
                style: const TextStyle(
                  fontFamily: Ind.mono,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Ind.amber,
                  letterSpacing: 2,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.tag, size: 18, color: Ind.amber),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 36, minHeight: 0),
                  hintText: 'SCAN / TYPE',
                  hintStyle: const TextStyle(
                      fontFamily: Ind.mono,
                      fontSize: 14,
                      color: Ind.textDim,
                      letterSpacing: 1),
                  filled: true,
                  fillColor: Ind.inset,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Ind.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Ind.amber, width: 1.6),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Ind.danger),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Ind.danger, width: 1.6),
                  ),
                  errorStyle: const TextStyle(fontSize: 0, height: 0),
                  suffixIcon: _soLookingUp
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Ind.amber),
                          ),
                        )
                      : null,
                  suffixIconConstraints:
                      const BoxConstraints(minWidth: 36, minHeight: 0),
                ),
                textInputAction: TextInputAction.next,
                onChanged: _onSoChanged,
                onFieldSubmitted: (_) => _licenceFocusNode.requestFocus(),
                validator: (value) {
                  if (value == null || value.isEmpty) return '';
                  if (!RegExp(r'^[A-Z0-9]').hasMatch(value)) return '';
                  if (value.length < 3) return '';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            _squareButton(
              icon: Icons.autorenew,
              onTap: () {
                final now = DateTime.now();
                final generated =
                    'SO${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
                _soNumberController.text = generated;
                // Fresh new SO → Gate No locks to 1, vendor left to pick.
                _applyNewSo();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _squareButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Ind.panel,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Ind.border),
        ),
        child: Icon(icon, color: Ind.amber, size: 22),
      ),
    );
  }

  // ── Vendor (type-or-select combobox) ─────────────────────────────────────────

  Widget _buildVendorField() {
    if (_vendorsLoading) {
      return Container(
        height: _fieldHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Ind.inset,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Ind.border),
        ),
        child: const Row(
          children: [
            SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Ind.amber)),
            SizedBox(width: 8),
            Text('SYNC…',
                style: TextStyle(
                    fontFamily: Ind.mono, color: Ind.textDim, fontSize: 12)),
          ],
        ),
      );
    }

    if (_vendors.isEmpty) {
      return _buildCompactField(
        _vendorController,
        _vendorLoadError != null ? 'VENDOR (OFFLINE)' : 'VENDOR',
        isRequired: true,
        height: _vendorHeight,
        focusNode: _vendorFocusNode,
        nextFocusNode: _licenceFocusNode,
      );
    }

    // Read-only field that opens a vendor list sheet — same style as Gate No,
    // so there's no keyboard/overlay conflict. Locked when auto-filled from the SO.
    return TextFormField(
      controller: _vendorController,
      focusNode: _vendorFocusNode,
      readOnly: true,
      showCursor: false,
      style: const TextStyle(fontSize: 14, color: Ind.text),
      decoration: _fieldDecoration('VENDOR',
          isRequired: true,
          height: _vendorHeight,
          suffixIcon: _vendorAuto
              ? const Icon(Icons.lock_outline, size: 15, color: Ind.textDim)
              : null),
      validator: (v) => (v == null || v.trim().isEmpty) ? '' : null,
      onTap: _vendorAuto ? null : _pickVendor,
    );
  }

  // Opens the vendor list sheet and returns the picked name (or null).
  Future<String?> _showVendorSheet(String? current) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Ind.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => _vendorPickerSheet(current),
    );
  }

  Future<void> _pickVendor() async {
    final selected = await _showVendorSheet(_vendorController.text.trim());
    if (selected != null && mounted) {
      setState(() {
        _vendorController.text = selected;
        _vendorAuto = false; // manually chosen
      });
    }
  }

  Widget _vendorPickerSheet(String? current) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
              child: Row(
                children: [
                  Container(width: 3, height: 14, color: Ind.amber),
                  const SizedBox(width: 8),
                  Text('SELECT VENDOR',
                      style:
                          Ind.label.copyWith(color: Ind.text, fontSize: 12)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Ind.textDim),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Ind.border),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _vendors.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Ind.border),
                itemBuilder: (ctx, i) {
                  final name = _vendors[i]['name'] as String;
                  final selected = name == current;
                  return ListTile(
                    dense: true,
                    onTap: () => Navigator.pop(ctx, name),
                    title: Text(
                      name,
                      style: TextStyle(
                        color: selected ? Ind.amber : Ind.text,
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check, color: Ind.amber, size: 18)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Gate No — a read-only field (same TextFormField as Vendor, so the heights
  // match) that opens a 1–100 number-pad sheet. Locked when auto-filled from the SO.
  Widget _buildGateNoField() {
    return TextFormField(
      controller: _gateController,
      focusNode: _gateFocusNode,
      readOnly: true,
      showCursor: false,
      style: const TextStyle(
          fontFamily: Ind.mono, fontSize: 14, color: Ind.text),
      decoration: _fieldDecoration('GATE NO',
          isRequired: true,
          height: _gateHeight,
          suffixIcon: _gateAuto
              ? const Icon(Icons.lock_outline, size: 15, color: Ind.textDim)
              : null),
      validator: (v) => (v == null || v.trim().isEmpty) ? '' : null,
      onTap: _gateAuto ? null : _pickGateNo,
    );
  }

  Future<void> _pickGateNo() async {
    FocusManager.instance.primaryFocus?.unfocus(); // drop any keyboard first
    final current = int.tryParse(_gateController.text.trim());
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Ind.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => _gatePickerSheet(current),
    );
    if (selected != null && mounted) {
      setState(() {
        _gateController.text = selected.toString();
        _gateAuto = false; // manually chosen
      });
    }
  }

  Widget _gatePickerSheet(int? current) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
              child: Row(
                children: [
                  Container(width: 3, height: 14, color: Ind.amber),
                  const SizedBox(width: 8),
                  Text('SELECT GATE NO',
                      style:
                          Ind.label.copyWith(color: Ind.text, fontSize: 12)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Ind.textDim),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Ind.border),
            Flexible(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.5,
                ),
                itemCount: 100,
                itemBuilder: (ctx, i) {
                  final n = i + 1;
                  final selected = current == n;
                  return InkWell(
                    onTap: () => Navigator.pop(ctx, n),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? Ind.amber : Ind.inset,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: selected ? Ind.amber : Ind.border),
                      ),
                      child: Text('$n',
                          style: TextStyle(
                              fontFamily: Ind.mono,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: selected ? Ind.bg : Ind.text)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      cursorColor: Ind.amber,
      style: const TextStyle(
          fontFamily: Ind.mono, fontSize: 14, color: Ind.text, letterSpacing: 0.5),
      decoration: _fieldDecoration('DATE'),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (picked != null) {
          setState(() {
            _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
          });
        }
      },
    );
  }

  Widget _buildLocationRow() {
    Widget sep() => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: Text('·',
              style: TextStyle(color: Ind.amber, fontWeight: FontWeight.w700)),
        );
    return Row(
      children: [
        Expanded(
          child: _pickerField(
            value: _locZone,
            hint: 'ZONE',
            mono: true,
            onTap: () async {
              final r = await _pickOption(
                title: 'SELECT ZONE',
                options: List.generate(
                    26, (i) => String.fromCharCode('A'.codeUnitAt(0) + i)),
                current: _locZone,
              );
              if (r == null) return;
              setState(
                  () => _locZone = identical(r, _kNone) ? null : r as String);
            },
          ),
        ),
        sep(),
        Expanded(
          child: _pickerField(
            value: _locRow?.toString(),
            hint: 'ROW',
            mono: true,
            onTap: () async {
              final r = await _pickOption(
                title: 'SELECT ROW',
                options: List.generate(10, (i) => '${i + 1}'),
                current: _locRow?.toString(),
              );
              if (r == null) return;
              setState(() => _locRow =
                  identical(r, _kNone) ? null : int.parse(r as String));
            },
          ),
        ),
        sep(),
        Expanded(
          child: _pickerField(
            value: _locCol?.toString(),
            hint: 'COL',
            mono: true,
            onTap: () async {
              final r = await _pickOption(
                title: 'SELECT COLUMN',
                options: List.generate(200, (i) => '${i + 1}'),
                current: _locCol?.toString(),
              );
              if (r == null) return;
              setState(() => _locCol =
                  identical(r, _kNone) ? null : int.parse(r as String));
            },
          ),
        ),
      ],
    );
  }

  // ── Details (collapsible LOCATION group: date · material · location) ──────────

  String _detailsSummary() {
    final parts = <String>[_dateController.text];
    final mat = _materialTypeController.text.trim();
    if (mat.isNotEmpty) parts.add(mat);
    if (_locZone != null && _locRow != null && _locCol != null) {
      parts.add('$_locZone-$_locRow-$_locCol');
    }
    return parts.join('  ·  ');
  }

  Widget _buildDetailsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Ind.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Ind.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _detailsExpanded = !_detailsExpanded),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
              decoration: BoxDecoration(
                border: _detailsExpanded
                    ? const Border(bottom: BorderSide(color: Ind.border))
                    : null,
              ),
              child: Row(
                children: [
                  Container(width: 3, height: 12, color: Ind.amber),
                  const SizedBox(width: 8),
                  Text('LOCATION',
                      style: Ind.label.copyWith(color: Ind.text)),
                  Expanded(
                    child: _detailsExpanded
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              _detailsSummary(),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontFamily: Ind.mono,
                                  fontSize: 11,
                                  color: Ind.textDim),
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _detailsExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Ind.amber,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (_detailsExpanded)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildDateField()),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCompactField(
                            _materialTypeController, 'MATERIAL TYPE'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildLocationRow(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Photos (collapsible canvas) ──────────────────────────────────────────────

  Widget _buildPhotosPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Ind.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Ind.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _photosExpanded = !_photosExpanded),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
              decoration: BoxDecoration(
                border: _photosExpanded
                    ? const Border(bottom: BorderSide(color: Ind.border))
                    : null,
              ),
              child: Row(
                children: [
                  Container(width: 3, height: 12, color: Ind.amber),
                  const SizedBox(width: 8),
                  Text('PHOTOS', style: Ind.label.copyWith(color: Ind.text)),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        _imageFiles.length.toString().padLeft(2, '0'),
                        style: const TextStyle(
                            fontFamily: Ind.mono,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Ind.amber),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _photosExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Ind.amber,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (_photosExpanded)
            Padding(
              padding: const EdgeInsets.all(10),
              child: _imageFiles.isEmpty
                  ? const Row(
                      children: [
                        Icon(Icons.camera_alt_outlined,
                            size: 18, color: Ind.textDim),
                        SizedBox(width: 8),
                        Text('Tap PHOTO below to capture',
                            style:
                                TextStyle(color: Ind.textDim, fontSize: 12)),
                      ],
                    )
                  : _buildPhotoGrid(),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _imageFiles.length,
      itemBuilder: (context, index) {
        return _buildPhotoFrame(_imageFiles[index], index + 1);
      },
    );
  }

  Widget _buildPhotoFrame(XFile file, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Ind.inset,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Ind.border),
      ),
      padding: const EdgeInsets.all(3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(file.path),
              fit: BoxFit.cover,
              cacheWidth: 200,
              cacheHeight: 200,
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: Ind.amber,
                child: Text(
                  '$index'.padLeft(2, '0'),
                  style: const TextStyle(
                      fontFamily: Ind.mono,
                      color: Color(0xFF14181C),
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Positioned(
              right: 2,
              top: 2,
              child: InkWell(
                onTap: () => _removeImage(file),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xCC14181C),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 15, color: Ind.text),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chrome ───────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Container(
      color: Ind.panel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HazardStripe(height: 4),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  _outlineButton(
                    icon: Icons.photo_camera,
                    label: 'PHOTO',
                    onTap: _takePicture,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Ind.amber,
                          foregroundColor: const Color(0xFF14181C),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_forward, size: 20),
                            SizedBox(width: 8),
                            Text('SUBMIT PALLET',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1)),
                          ],
                        ),
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

  Widget _outlineButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Ind.amber,
          side: const BorderSide(color: Ind.border),
          backgroundColor: Ind.inset,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Ind.bg,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SafeArea(
                  bottom: false,
                  child: Form(
                  key: _formKey,
                  child: RefreshIndicator(
                  onRefresh: _clearAll,
                  color: Ind.amber,
                  backgroundColor: Ind.panel,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSoField(),
                        const SizedBox(height: 14),
                        IndPanel(
                          label: 'CONSIGNMENT',
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _buildVendorField()),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildGateNoField()),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildCompactField(
                                      _licenceController,
                                      'BARCODE',
                                      isRequired: true,
                                      mono: true,
                                      focusNode: _licenceFocusNode,
                                      nextFocusNode: _palletWeightFocusNode,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildCompactField(
                                      _palletWeightController,
                                      'WEIGHT · KG',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      inputFormatters: [
                                        // Digits with a single optional decimal
                                        // point and up to 4 decimal places.
                                        TextInputFormatter.withFunction(
                                            (oldValue, newValue) {
                                          final t = newValue.text;
                                          if (t.isEmpty) return newValue;
                                          return RegExp(r'^\d*\.?\d{0,4}$')
                                                  .hasMatch(t)
                                              ? newValue
                                              : oldValue;
                                        }),
                                      ],
                                      isRequired: true,
                                      mono: true,
                                      focusNode: _palletWeightFocusNode,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailsPanel(),
                        const SizedBox(height: 12),
                        _buildPhotosPanel(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                ),
                ),
              ),
              _buildFooter(),
            ],
          ),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: const Color(0xCC0E1216),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: Ind.panel,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Ind.amber),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: Ind.amber)),
              SizedBox(height: 16),
              Text('TRANSMITTING…',
                  style: TextStyle(
                      fontFamily: Ind.mono,
                      color: Ind.text,
                      fontSize: 12,
                      letterSpacing: 2)),
            ],
          ),
        ),
      ),
    );
  }
}
