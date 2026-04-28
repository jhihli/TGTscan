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
  final TextEditingController _noteController = TextEditingController();

  final FocusNode _soNumberFocusNode = FocusNode();
  final FocusNode _vendorFocusNode = FocusNode();
  final FocusNode _noteFocusNode = FocusNode();

  // Per-pallet row controllers — all lists share the same index per row
  List<TextEditingController> _licenceControllers = [TextEditingController()];
  List<TextEditingController> _payloadControllers = [TextEditingController()];
  List<TextEditingController> _palletWeightControllers = [TextEditingController()];
  List<TextEditingController> _palletQtyControllers = [TextEditingController()];
  List<TextEditingController> _boardQtyControllers = [TextEditingController()];

  List<FocusNode> _licenceFocusNodes = [FocusNode()];
  List<FocusNode> _payloadFocusNodes = [FocusNode()];
  List<FocusNode> _palletWeightFocusNodes = [FocusNode()];
  List<FocusNode> _palletQtyFocusNodes = [FocusNode()];
  List<FocusNode> _boardQtyFocusNodes = [FocusNode()];

  // 'per_pallet' → Pallet Qty locked to 1; 'aggregated' → editable
  String _weightRule = 'per_pallet';
  bool get _isPerPallet => _weightRule == 'per_pallet';

  List<Map<String, dynamic>> _vendors = [];
  String? _selectedVendorName;
  bool _vendorsLoading = false;
  String? _vendorLoadError;

  List<XFile> _imageFiles = [];
  bool _isLoading = false;

  late FlutterDataWedge _dataWedge;
  late StreamSubscription<ScanResult> _scanSubscription;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadVendors();

    _dataWedge = FlutterDataWedge();
    _scanSubscription = _dataWedge.onScanResult.listen((ScanResult result) {
      if (_soNumberFocusNode.hasFocus) {
        setState(() => _soNumberController.text = result.data.toUpperCase());
        _vendorFocusNode.requestFocus();
        return;
      }
      final licenceIdx = _licenceFocusNodes.indexWhere((fn) => fn.hasFocus);
      if (licenceIdx != -1) {
        setState(() => _licenceControllers[licenceIdx].text = result.data);
        _payloadFocusNodes[licenceIdx].requestFocus();
        return;
      }
      final payloadIdx = _payloadFocusNodes.indexWhere((fn) => fn.hasFocus);
      if (payloadIdx != -1) {
        setState(() => _payloadControllers[payloadIdx].text = result.data);
        _palletWeightFocusNodes[payloadIdx].requestFocus();
        return;
      }
      final weightIdx = _palletWeightFocusNodes.indexWhere((fn) => fn.hasFocus);
      if (weightIdx != -1) {
        setState(() => _palletWeightControllers[weightIdx].text = result.data);
        if (_isPerPallet) {
          _boardQtyFocusNodes[weightIdx].requestFocus();
        } else {
          _palletQtyFocusNodes[weightIdx].requestFocus();
        }
        return;
      }
      final qtyIdx = _palletQtyFocusNodes.indexWhere((fn) => fn.hasFocus);
      if (qtyIdx != -1) {
        setState(() => _palletQtyControllers[qtyIdx].text = result.data);
        _boardQtyFocusNodes[qtyIdx].requestFocus();
        return;
      }
      final boardQtyIdx = _boardQtyFocusNodes.indexWhere((fn) => fn.hasFocus);
      if (boardQtyIdx != -1) {
        setState(() => _boardQtyControllers[boardQtyIdx].text = result.data);
        final isLast = boardQtyIdx == _licenceControllers.length - 1;
        (isLast ? _noteFocusNode : _licenceFocusNodes[boardQtyIdx + 1]).requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _scanSubscription.cancel();
    _soNumberController.dispose();
    _vendorController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    _soNumberFocusNode.dispose();
    _vendorFocusNode.dispose();
    _noteFocusNode.dispose();
    for (final c in _licenceControllers) { c.dispose(); }
    for (final c in _payloadControllers) { c.dispose(); }
    for (final c in _palletWeightControllers) { c.dispose(); }
    for (final c in _palletQtyControllers) { c.dispose(); }
    for (final c in _boardQtyControllers) { c.dispose(); }
    for (final fn in _licenceFocusNodes) { fn.dispose(); }
    for (final fn in _payloadFocusNodes) { fn.dispose(); }
    for (final fn in _palletWeightFocusNodes) { fn.dispose(); }
    for (final fn in _palletQtyFocusNodes) { fn.dispose(); }
    for (final fn in _boardQtyFocusNodes) { fn.dispose(); }
    super.dispose();
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

  Future<void> _loadVendors() async {
    setState(() { _vendorsLoading = true; _vendorLoadError = null; });
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
        if (mounted) setState(() => _vendorLoadError = 'HTTP ${response.statusCode}');
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _vendorLoadError = 'Timed out — tap Retry');
      }
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final apiKey = dotenv.env['API_KEY'] ?? '';
      String? soId;

      for (int i = 0; i < _palletWeightControllers.length; i++) {
        final palletQty = _isPerPallet ? '1' : _palletQtyControllers[i].text;
        final boardQtyRaw = _boardQtyControllers[i].text.trim();

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
                'vendor': _vendors.isNotEmpty
                    ? (_selectedVendorName ?? '')
                    : _vendorController.text.trim(),
                'weight_rule': _weightRule,
                'date': _dateController.text,
                'licence_number': _licenceControllers[i].text,
                'payload_number': _payloadControllers[i].text,
                'pallet_weight': _palletWeightControllers[i].text,
                'pallet_qty': palletQty,
                'board_qty': boardQtyRaw.isEmpty ? null : int.tryParse(boardQtyRaw),
                'noted': _noteController.text,
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (!mounted) return;

        if (response.statusCode != 200 && response.statusCode != 201) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final msg = body['error'] ?? 'Submission failed (${response.statusCode})';
          _showSnackBar('Row ${i + 1}: ${msg.toString()}', isError: true);
          return;
        }

        soId ??= (jsonDecode(response.body) as Map<String, dynamic>)['data']?['so']?['id']?.toString();
      }

      if (_imageFiles.isNotEmpty && soId != null) {
        for (final img in _imageFiles) {
          try {
            final photoReq = http.MultipartRequest(
              'POST',
              Uri.parse('${widget.baseUrl}/product/scanner/sos/$soId/photos/'),
            );
            photoReq.headers['X-Api-Key'] = apiKey;
            photoReq.files.add(await http.MultipartFile.fromPath('image', img.path));
            await photoReq.send().timeout(const Duration(seconds: 30));
          } catch (_) {}
        }
      }

      if (!mounted) return;
      _resetForm();
      _showSnackBar('Lot submitted successfully');
    } on TimeoutException {
      if (!mounted) return;
      _showNetworkAlert('Request timed out. Please check your network connection and try again.');
    } on SocketException {
      if (!mounted) return;
      _showNetworkAlert('Cannot reach the server. Please check your network connection.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('An unexpected error occurred: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _addPalletRow() {
    setState(() {
      _licenceControllers.add(TextEditingController());
      _payloadControllers.add(TextEditingController());
      _palletWeightControllers.add(TextEditingController());
      _palletQtyControllers.add(TextEditingController());
      _boardQtyControllers.add(TextEditingController());
      _licenceFocusNodes.add(FocusNode());
      _payloadFocusNodes.add(FocusNode());
      _palletWeightFocusNodes.add(FocusNode());
      _palletQtyFocusNodes.add(FocusNode());
      _boardQtyFocusNodes.add(FocusNode());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _licenceFocusNodes.last.requestFocus();
    });
  }

  void _removePalletRow(int index) {
    if (_palletWeightControllers.length <= 1) return;
    setState(() {
      _licenceControllers[index].dispose();
      _payloadControllers[index].dispose();
      _palletWeightControllers[index].dispose();
      _palletQtyControllers[index].dispose();
      _boardQtyControllers[index].dispose();
      _licenceFocusNodes[index].dispose();
      _payloadFocusNodes[index].dispose();
      _palletWeightFocusNodes[index].dispose();
      _palletQtyFocusNodes[index].dispose();
      _boardQtyFocusNodes[index].dispose();
      _licenceControllers.removeAt(index);
      _payloadControllers.removeAt(index);
      _palletWeightControllers.removeAt(index);
      _palletQtyControllers.removeAt(index);
      _boardQtyControllers.removeAt(index);
      _licenceFocusNodes.removeAt(index);
      _payloadFocusNodes.removeAt(index);
      _palletWeightFocusNodes.removeAt(index);
      _palletQtyFocusNodes.removeAt(index);
      _boardQtyFocusNodes.removeAt(index);
    });
  }

  void _resetForm() {
    _soNumberController.clear();
    _vendorController.clear();
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _noteController.clear();
    setState(() {
      for (var i = 1; i < _palletWeightControllers.length; i++) {
        _licenceControllers[i].dispose();
        _payloadControllers[i].dispose();
        _palletWeightControllers[i].dispose();
        _palletQtyControllers[i].dispose();
        _boardQtyControllers[i].dispose();
        _licenceFocusNodes[i].dispose();
        _payloadFocusNodes[i].dispose();
        _palletWeightFocusNodes[i].dispose();
        _palletQtyFocusNodes[i].dispose();
        _boardQtyFocusNodes[i].dispose();
      }
      _licenceControllers = [TextEditingController()];
      _payloadControllers = [TextEditingController()];
      _palletWeightControllers = [TextEditingController()];
      _palletQtyControllers = [TextEditingController()];
      _boardQtyControllers = [TextEditingController()];
      _licenceFocusNodes = [FocusNode()];
      _payloadFocusNodes = [FocusNode()];
      _palletWeightFocusNodes = [FocusNode()];
      _palletQtyFocusNodes = [FocusNode()];
      _boardQtyFocusNodes = [FocusNode()];
      _imageFiles = [];
      _weightRule = 'per_pallet';
      _selectedVendorName = null;
    });
    _soNumberFocusNode.requestFocus();
  }

  // ── Field builders ──────────────────────────────────────────────────────────

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool isRequired = true,
    int? maxDigits,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    double labelFontSize = 13,
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
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: labelFontSize, color: Colors.grey),
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
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return 'Please enter $label';
          }
          if (maxDigits != null && value != null) {
            final digitCount = value.replaceAll('.', '').length;
            if (digitCount > maxDigits) return '$label too large?';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildVendorField() {
    if (_vendorsLoading) {
      return Container(
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
            Text('Loading vendors…',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    if (_vendors.isEmpty) {
      if (_vendorLoadError != null) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: Colors.red[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vendor load failed: $_vendorLoadError',
                  style: TextStyle(fontSize: 12, color: Colors.red[700]),
                ),
              ),
              TextButton(
                onPressed: _loadVendors,
                child: const Text('Retry', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      }
      return _buildTextField(
        _vendorController,
        'Vendor',
        Icons.business,
        focusNode: _vendorFocusNode,
        nextFocusNode: _licenceFocusNodes[0],
      );
    }

    return DropdownButtonFormField<String>(
      key: ValueKey(_selectedVendorName),
      initialValue: _selectedVendorName,
      focusNode: _vendorFocusNode,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Vendor',
        labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        prefixIcon: const Icon(Icons.business, size: 18),
        filled: true,
        fillColor: const Color(0xFFFFF8E7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      hint: const Text('Select vendor',
          style: TextStyle(fontSize: 14, color: Colors.grey)),
      items: _vendors.map((v) {
        final name = v['name'] as String;
        final rule = (v['default_weight_rule'] as String?) ?? 'per_pallet';
        final ruleLabel = rule == 'per_pallet' ? 'Per Pallet' : 'Aggregated';
        final ruleColor = rule == 'per_pallet' ? Colors.blue : Colors.orange;
        return DropdownMenuItem<String>(
          value: name,
          child: Row(
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontSize: 14))),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: ruleColor.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ruleColor.shade200),
                ),
                child: Text(
                  ruleLabel,
                  style: TextStyle(fontSize: 11, color: ruleColor.shade700),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value == null) return;
        final vendor = _vendors.firstWhere((v) => v['name'] == value);
        setState(() {
          _selectedVendorName = value;
          _weightRule =
              (vendor['default_weight_rule'] as String?) ?? 'per_pallet';
        });
        _licenceFocusNodes[0].requestFocus();
      },
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Please select a vendor' : null,
    );
  }

  Widget _buildCompactField(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool isRequired = false,
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
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          filled: true,
          fillColor: isRequired ? const Color(0xFFFFF8E7) : Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textInputAction:
            nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
        onFieldSubmitted: (_) => nextFocusNode?.requestFocus(),
        validator: isRequired
            ? (value) =>
                (value == null || value.isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _buildReadOnlyCompactField(String value) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 13, color: Colors.black54),
    );
  }

  Widget _buildWeightRuleToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.rule, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          const Text('Weight Rule',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const Spacer(),
          _weightRuleChip('per_pallet', 'Per Pallet'),
          const SizedBox(width: 8),
          _weightRuleChip('aggregated', 'Aggregated'),
        ],
      ),
    );
  }

  Widget _weightRuleChip(String value, String label) {
    final selected = _weightRule == value;
    return GestureDetector(
      onTap: () => setState(() => _weightRule = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.blue : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _dateController,
      decoration: InputDecoration(
        labelText: 'Date',
        labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        prefixIcon: const Icon(Icons.calendar_today, size: 18),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
      style: const TextStyle(fontSize: 14),
      readOnly: true,
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

  Widget _buildPalletRows() {
    final count = _palletWeightControllers.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section header with + Add outside
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Text(
                'PALLETS · $count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _addPalletRow,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+ Add',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // One card per pallet row — swipe right to reveal Remove
        ...List.generate(count, (i) {
          final isLast = i == count - 1;
          final nextRowFirstFocus =
              isLast ? _noteFocusNode : _licenceFocusNodes[i + 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Dismissible(
              key: ObjectKey(_licenceControllers[i]),
              direction: DismissDirection.startToEnd,
              confirmDismiss: (_) async => count > 1,
              onDismissed: (_) => _removePalletRow(i),
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.white, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'Remove',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    // Row 1: Licence | Payload
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactField(
                            _licenceControllers[i],
                            'Licence',
                            focusNode: _licenceFocusNodes[i],
                            nextFocusNode: _payloadFocusNodes[i],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildCompactField(
                            _payloadControllers[i],
                            'Payload',
                            focusNode: _payloadFocusNodes[i],
                            nextFocusNode: _palletWeightFocusNodes[i],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Row 2: Weight | Qty | Boards qty
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildCompactField(
                            _palletWeightControllers[i],
                            'Weight',
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'))
                            ],
                            isRequired: true,
                            focusNode: _palletWeightFocusNodes[i],
                            nextFocusNode: _isPerPallet
                                ? _boardQtyFocusNodes[i]
                                : _palletQtyFocusNodes[i],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 3,
                          child: _isPerPallet
                              ? _buildReadOnlyCompactField('1')
                              : _buildCompactField(
                                  _palletQtyControllers[i],
                                  'Qty',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly
                                  ],
                                  isRequired: true,
                                  focusNode: _palletQtyFocusNodes[i],
                                  nextFocusNode: _boardQtyFocusNodes[i],
                                ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 3,
                          child: _buildCompactField(
                            _boardQtyControllers[i],
                            'Boards qty',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            focusNode: _boardQtyFocusNodes[i],
                            nextFocusNode: nextRowFirstFocus,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
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
            Text('No photos taken yet',
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // SO Number + Generate button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _soNumberController,
                          focusNode: _soNumberFocusNode,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            TextInputFormatter.withFunction((oldValue, newValue) =>
                                newValue.copyWith(
                                    text: newValue.text.toUpperCase())),
                          ],
                          decoration: InputDecoration(
                            labelText: 'SO Number',
                            labelStyle:
                                const TextStyle(fontSize: 13, color: Colors.grey),
                            prefixIcon: const Icon(Icons.scanner, size: 18),
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
                          onFieldSubmitted: (_) => _vendorFocusNode.requestFocus(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter SO Number';
                            }
                            if (!RegExp(r'^[A-Z0-9]').hasMatch(value)) {
                              return 'SO Number must start with a letter or number';
                            }
                            if (value.length < 3) {
                              return 'SO Number must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            final now = DateTime.now();
                            final generated =
                                'SO${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
                            setState(() => _soNumberController.text = generated);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: const Color(0xFF4A90D9),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Icon(Icons.autorenew, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Vendor dropdown (falls back to text field when load fails)
                  _buildVendorField(),
                  const SizedBox(height: 8),

                  // Weight Rule toggle
                  _buildWeightRuleToggle(),
                  const SizedBox(height: 8),

                  // Pallet rows (each card: Licence+Payload / Weight+Qty+Boards)
                  _buildPalletRows(),

                  // Date + Note side by side
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildDateField()),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          _noteController,
                          'Note',
                          Icons.note,
                          isRequired: false,
                          focusNode: _noteFocusNode,
                        ),
                      ),
                    ],
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
