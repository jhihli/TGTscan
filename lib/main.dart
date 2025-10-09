import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_datawedge/flutter_datawedge.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TGT Scan',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ScanScreen(),
    );
  }
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _soNumberController = TextEditingController();
  final _weightController = TextEditingController();
  final _dateController = TextEditingController();
  final _noteController = TextEditingController();
  final List<XFile> _imageFiles = [];

  bool _isImport = true;

  late FlutterDataWedge _dataWedge;
  late StreamSubscription<ScanResult> _scanSubscription;

  @override
  void initState() {
    super.initState();
    _dataWedge = FlutterDataWedge();
    _scanSubscription = _dataWedge.onScanResult.listen((ScanResult result) {
      if (result.labelType == 'LABEL-TYPE-EAN13') {
        setState(() {
          _barcodeController.text = result.data;
        });
      } else {
        setState(() {
          _soNumberController.text = result.data;
        });
      }
    });
    _dateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _scanSubscription.cancel();
    _barcodeController.dispose();
    _soNumberController.dispose();
    _weightController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
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
      if (_imageFiles.isEmpty) {
        _showErrorDialog('Please take at least one photo before submitting.');
        return;
      }
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imagePath = '${appDir.path}/Images';
      await Directory(imagePath).create(recursive: true);

      if (_isImport) {
        List<File> savedImages = [];
        for (var imageFile in _imageFiles) {
          final String fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${_imageFiles.indexOf(imageFile)}.jpg';
          final File savedImage = await File(
            imageFile.path,
          ).copy('$imagePath/$fileName');
          savedImages.add(savedImage);
        }
        // Handle Import
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('http://192.168.0.32:8000/product/scanner/'),
        );
        request.fields['action'] = 'inbound';
        request.fields['barcode'] = _barcodeController.text;
        request.fields['so_number'] = _soNumberController.text;
        request.fields['weight'] = _weightController.text;
        request.fields['date'] = _dateController.text;
        request.fields['noted'] = _noteController.text;
        request.fields['current_status'] = '0';

        for (var savedImage in savedImages) {
          request.files.add(
            await http.MultipartFile.fromPath('photos', savedImage.path),
          );
        }

        try {
          final response = await request.send();
          final responseBody = await response.stream.bytesToString();
          if (response.statusCode == 201 || response.statusCode == 200) {
            _showSuccessDialog('Data submitted successfully');
          } else {
            _showErrorDialog('Failed to submit data: $responseBody');
          }
        } catch (e) {
          _showErrorDialog('An error occurred: $e');
        }
      } else {
        // Handle Export
        final List<File> savedImages = [];
        for (var imageFile in _imageFiles) {
          final String fileName =
              '${_soNumberController.text}_${DateTime.now().millisecondsSinceEpoch}_${_imageFiles.indexOf(imageFile)}.jpg';
          final File savedImage = await File(
            imageFile.path,
          ).copy('$imagePath/$fileName');
          savedImages.add(savedImage);
        }

        final request = http.MultipartRequest(
          'POST',
          Uri.parse('http://192.168.0.32:8000/product/scanner/'),
        );
        request.fields['action'] = 'outbound';
        request.fields['date'] = _dateController.text;
        request.fields['so_number'] = _soNumberController.text;
        request.fields['current_status'] = '1';

        for (var savedImage in savedImages) {
          request.files.add(
            await http.MultipartFile.fromPath('photos', savedImage.path),
          );
        }

        try {
          final response = await request.send();
          final responseBody = await response.stream.bytesToString();
          if (response.statusCode == 200) {
            _showSuccessDialog('Data updated successfully');
          } else if (response.statusCode == 404) {
            _showErrorDialog('The product not found.');
          } else {
            _showErrorDialog('Failed to update data: $responseBody');
          }
        } catch (e) {
          _showErrorDialog('An error occurred: $e');
        }
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
                _soNumberController.clear();
                _weightController.clear();
                _noteController.clear();
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
      appBar: AppBar(
        title: const Text(
          'TGT Scan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildModeSelector(),
                const SizedBox(height: 24),
                _buildDateField(),
                const SizedBox(height: 16),
                if (_isImport) ...[
                  _buildTextFormField(
                    _barcodeController,
                    'Barcode',
                    Icons.barcode_reader,
                  ),
                  const SizedBox(height: 16),
                ],
                _buildTextFormField(
                  _soNumberController,
                  'SO Number',
                  Icons.scanner,
                ),
                const SizedBox(height: 16),
                if (_isImport) ...[
                  _buildTextFormField(
                    _weightController,
                    'Weight',
                    Icons.line_weight,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildTextFormField(
                    _noteController,
                    'Note',
                    Icons.note,
                    isRequired: false,
                  ),
                  const SizedBox(height: 24),
                ],
                _buildImageGrid(),
                const SizedBox(height: 24),
                _buildTakePhotoButton(),
                const SizedBox(height: 24),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
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
              onTap: () => setState(() => _isImport = true),
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isImport = false),
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
                    fontWeight: FontWeight.bold,
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

  Widget _buildTextFormField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
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
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Please enter a $label';
        }
        return null;
      },
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
      icon: const Icon(Icons.camera_alt),
      label: const Text('Take Photo'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submit,
      child: const Text(
        'Submit',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
