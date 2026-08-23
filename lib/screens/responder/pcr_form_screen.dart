import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../widgets/design_system.dart';
import 'dart:io';
import '../../services/ocr_service.dart';
import 'package:image_picker/image_picker.dart';

/// PCR form para sa mga NAKA-SCHEDULE na dispatch lang.
/// Kapag walang schedule (emergency/walk-in scan), gamitin ang
/// `PCRStandaloneFormScreen` sa halip nito.
class PCRFormScreen extends StatefulWidget {
  final String scheduleID;
  final Map<String, dynamic> scheduleData;
  final Map<String, dynamic> requestData;

  const PCRFormScreen({
    super.key,
    required this.scheduleID,
    required this.scheduleData,
    required this.requestData,
  });

  @override
  State<PCRFormScreen> createState() => _PCRFormScreenState();
}

class _PCRFormScreenState extends State<PCRFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ocrService = OcrService();
  File? _scannedImage;
  String _ocrText = '';
  bool _isScanning = false;
  bool _showOcrText = false;

  // ── Responder Profile ───────────────────────────────────
  final _responderNameCtrl = TextEditingController();
  final _responderIdCtrl = TextEditingController();
  bool _profileLoaded = false;

  // ── Type of Response dropdown ───────────────────────────
  String _typeOfResponse = 'Emergency';
  String? _responseSubType;
  final _otherSubTypeCtrl = TextEditingController();

  final _responseTypes = const ['Emergency', 'Trauma', 'Medical', 'Transfer', 'OB'];

  final _emergencySubTypes = const [
    'Cardiac Arrest',
    'Difficulty of Breathing',
    'Stroke / CVA',
    'Seizure',
    'Severe Allergic Reaction',
    'Poisoning / Overdose',
    'Unconscious / Unresponsive',
    'Other Emergency',
  ];

  final _traumaSubTypes = const [
    'Vehicular Accident / Collision',
    'Motorcycle Accident',
    'Fall',
    'Stabbing / Assault',
    'Gunshot Wound',
    'Burn',
    'Drowning',
    'Other Trauma',
  ];

  List<String> get _activeSubTypes {
    if (_typeOfResponse == 'Emergency') return _emergencySubTypes;
    if (_typeOfResponse == 'Trauma') return _traumaSubTypes;
    return const [];
  }

  bool get _isOtherSubType => _responseSubType?.startsWith('Other') ?? false;

  // PCR field controllers — base sa PCR_REPORT table sa ERD
  final _patientConditionCtrl = TextEditingController();
  final _presentIllnessCtrl = TextEditingController();
  final _pastMedicalHistoryCtrl = TextEditingController();
  final _painLocationCtrl = TextEditingController();
  final _bpCtrl = TextEditingController();
  final _pulseRateCtrl = TextEditingController();
  final _temperatureCtrl = TextEditingController();
  final _respiratoryRateCtrl = TextEditingController();
  final _spo2Ctrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _actionTakenCtrl = TextEditingController();

  bool _isLoading = false;

  // Read-only label ng naka-link na ambulance (galing na sa schedule).
  String _assignedVehicleLabel = '-';
  bool _loadingVehicleLabel = false;

  // Read-only label ng naka-link na driver (galing na sa schedule).
  String _assignedDriverLabel = '-';
  bool _loadingDriverLabel = false;

  @override
  void initState() {
    super.initState();
    _loadAssignedVehicleLabel();
    _loadAssignedDriverLabel();
    _loadResponderProfile();
  }

  Future<void> _loadResponderProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          _responderNameCtrl.text = data['fullName'] ?? '';
          _responderIdCtrl.text = data['responderID'] ?? uid;
          _profileLoaded = true;
        });
      } else {
        setState(() {
          _responderIdCtrl.text = uid;
          _profileLoaded = true;
        });
      }
    } catch (e) {
      setState(() => _profileLoaded = true);
    }
  }

  Future<void> _loadAssignedVehicleLabel() async {
    final vehicleID = widget.scheduleData['vehicleID']?.toString() ?? '';
    if (vehicleID.isEmpty) return;
    setState(() => _loadingVehicleLabel = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('vehicles')
          .doc(vehicleID)
          .get();
      final data = doc.data();
      if (mounted) {
        setState(() {
          _assignedVehicleLabel = data == null
              ? vehicleID
              : '${data['plateNumber'] ?? vehicleID} • ${data['vehicleType'] ?? ''}';
          _loadingVehicleLabel = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVehicleLabel = false);
    }
  }

  Future<void> _loadAssignedDriverLabel() async {
    final driverID = widget.scheduleData['driverID']?.toString() ?? '';
    if (driverID.isEmpty) {
      setState(() => _assignedDriverLabel = 'Not assigned');
      return;
    }
    setState(() => _loadingDriverLabel = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(driverID)
          .get();
      final data = doc.data();
      if (mounted) {
        setState(() {
          _assignedDriverLabel = data == null
              ? driverID
              : (data['fullName'] ?? data['name'] ?? driverID).toString();
          _loadingDriverLabel = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDriverLabel = false);
    }
  }

  // ── Scan PCR via camera ──────────────────────────────────
  Future<void> _scanPCR() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    setState(() => _isScanning = true);

    try {
      final File? imageFile = source == ImageSource.camera
          ? await _ocrService.pickImageFromCamera()
          : await _ocrService.pickImageFromGallery();

      if (imageFile == null) {
        setState(() => _isScanning = false);
        return;
      }

      final extractedText = await _ocrService.extractText(imageFile);

      setState(() {
        _scannedImage = imageFile;
        _ocrText = extractedText;
        _showOcrText = true;
        _isScanning = false;
        _fillFieldsFromOcr(extractedText);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'PCR scanned. Fields were auto-filled; review and edit if needed.',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    }
  }

  void _fillFieldsFromOcr(String text) {
    final normalized = text.replaceAll('\r', '\n');
    _setIfFound(
      _patientConditionCtrl,
      _findLabeledValue(normalized, const ['patient condition', 'condition']),
    );
    _setIfFound(
      _presentIllnessCtrl,
      _findLabeledValue(normalized, const [
        'present illness',
        'chief complaint',
        'complaint',
      ], multiLine: true),
    );
    _setIfFound(
      _pastMedicalHistoryCtrl,
      _findLabeledValue(normalized, const [
        'past medical history',
        'medical history',
        'pmh',
      ], multiLine: true),
    );
    _setIfFound(
      _painLocationCtrl,
      _findLabeledValue(normalized, const [
        'pain location',
        'location of pain',
      ]),
    );
    _setIfFound(
      _bpCtrl,
      _firstMatch(normalized, RegExp(r'\b\d{2,3}/\d{2,3}\b')),
    );
    _setIfFound(
      _pulseRateCtrl,
      _findNumberAfterLabels(normalized, const ['pulse rate', 'pulse', 'pr']),
    );
    _setIfFound(
      _temperatureCtrl,
      _findNumberAfterLabels(normalized, const ['temperature', 'temp']),
    );
    _setIfFound(
      _respiratoryRateCtrl,
      _findNumberAfterLabels(normalized, const [
        'respiratory rate',
        'respiration',
        'rr',
      ]),
    );
    _setIfFound(
      _spo2Ctrl,
      _findNumberAfterLabels(normalized, const ['spo2', 'sp02', 'oxygen']),
    );
    _setIfFound(
      _timeCtrl,
      _firstMatch(
        normalized,
        RegExp(r'\b(?:[01]?\d|2[0-3])[:.][0-5]\d(?:\s?[AaPp][Mm])?\b'),
      )?.replaceAll('.', ':'),
    );
    _setIfFound(
      _actionTakenCtrl,
      _findLabeledValue(normalized, const [
        'action taken',
        'interventions',
        'treatment',
      ], multiLine: true),
    );
  }

  void _setIfFound(TextEditingController controller, String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return;
    controller.text = clean;
  }

  String? _findLabeledValue(
    String text,
    List<String> labels, {
    bool multiLine = false,
  }) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final allLabels = const [
      'type of response',
      'response type',
      'patient condition',
      'condition',
      'present illness',
      'chief complaint',
      'past medical history',
      'medical history',
      'pain location',
      'bp',
      'pulse rate',
      'pulse',
      'temperature',
      'temp',
      'respiratory rate',
      'respiration',
      'spo2',
      'sp02',
      'time',
      'action taken',
      'interventions',
      'treatment',
    ];

    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      String? foundLabel;
      for (final label in labels) {
        if (lower.contains(label)) {
          foundLabel = label;
          break;
        }
      }
      if (foundLabel == null) continue;

      final sameLine = lines[i]
          .substring(lower.indexOf(foundLabel) + foundLabel.length)
          .replaceFirst(RegExp(r'^\s*[:\-]\s*'), '')
          .trim();
      if (sameLine.isNotEmpty) return sameLine;

      if (!multiLine && i + 1 < lines.length) return lines[i + 1];

      final collected = <String>[];
      for (var j = i + 1; j < lines.length; j++) {
        final nextLower = lines[j].toLowerCase();
        if (allLabels.any(nextLower.contains)) break;
        collected.add(lines[j]);
      }
      if (collected.isNotEmpty) return collected.join('\n');
    }
    return null;
  }

  String? _findNumberAfterLabels(String text, List<String> labels) {
    for (final label in labels) {
      final pattern = RegExp(
        '$label\\s*[:\\-]?\\s*(\\d+(?:\\.\\d+)?)',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  String? _firstMatch(String text, RegExp pattern) {
    return pattern.firstMatch(text)?.group(0);
  }

  // ── Submit PCR (scheduled dispatch) ─────────────────────
  Future<void> _submitPCR() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final db = FirebaseFirestore.instance;

      String ocrImageUrl = '';
      if (_scannedImage != null) {
        ocrImageUrl = await _ocrService.uploadImage(_scannedImage!);
      }

      final subTypeValue = _isOtherSubType
          ? _otherSubTypeCtrl.text.trim()
          : (_responseSubType ?? '');

      final typeOfResponseValue = subTypeValue.isNotEmpty
          ? '$_typeOfResponse - $subTypeValue'
          : _typeOfResponse;

      final resolvedPatientName =
          widget.requestData['patientName']?.toString() ?? 'Patient';
      final resolvedVehicleID =
          widget.scheduleData['vehicleID']?.toString() ?? '';
      final resolvedDriverID =
          widget.scheduleData['driverID']?.toString() ?? '';

      await db.collection('pcr_reports').add({
        'scheduleID': widget.scheduleID,
        'patientID': widget.requestData['patientID'] ?? '',
        'patientName': resolvedPatientName,
        'vehicleID': resolvedVehicleID,
        'driverID': resolvedDriverID,
        'driverName': _assignedDriverLabel,
        'responderID': uid,
        'typeofResponse': typeOfResponseValue,
        'responseCategory': _typeOfResponse,
        'responseSubType': subTypeValue,
        'patientCondition': _patientConditionCtrl.text.trim(),
        'presentIllness': _presentIllnessCtrl.text.trim(),
        'pastMedicalHistory': _pastMedicalHistoryCtrl.text.trim(),
        'painLocation': _painLocationCtrl.text.trim(),
        'bp': _bpCtrl.text.trim(),
        'pulseRate': int.tryParse(_pulseRateCtrl.text) ?? 0,
        'temperature': double.tryParse(_temperatureCtrl.text) ?? 0.0,
        'respiratoryRate': int.tryParse(_respiratoryRateCtrl.text) ?? 0,
        'spo2': int.tryParse(_spo2Ctrl.text) ?? 0,
        'time': _timeCtrl.text.trim(),
        'actionTaken': _actionTakenCtrl.text.trim(),
        'ocrImage': ocrImageUrl,
        'datesubmitted': FieldValue.serverTimestamp(),
        'isStandalone': false,
      });

      await db
          .collection('transport_schedules')
          .doc(widget.scheduleID)
          .update({'status': 'completed'});

      final requestID = widget.requestData['requestID']?.toString() ?? '';
      if (requestID.isNotEmpty) {
        await db.collection('transport_requests').doc(requestID).update({
          'status': 'completed',
        });
      }

      if (resolvedVehicleID.isNotEmpty) {
        await db.collection('vehicles').doc(resolvedVehicleID).update({
          'status': 'available',
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PCR submitted successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_profileLoaded) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: const Text('PCR Report Form'),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('PCR Report Form'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Responder Information'),
              const SizedBox(height: 12),
              _readOnlyInfoRow(
                'Responder Name',
                _responderNameCtrl.text.isEmpty ? _responderIdCtrl.text : _responderNameCtrl.text,
              ),
              const SizedBox(height: 8),
              _readOnlyInfoRow(
                'ID',
                _responderIdCtrl.text,
              ),
              const SizedBox(height: 24),

              _sectionHeader('Patient & Ambulance'),
              const SizedBox(height: 12),
              _readOnlyInfoRow(
                'Patient Name',
                widget.requestData['patientName']?.toString() ?? 'Patient',
              ),
              const SizedBox(height: 8),
              _readOnlyInfoRow(
                'Ambulance',
                _loadingVehicleLabel ? 'Loading...' : _assignedVehicleLabel,
              ),
              const SizedBox(height: 8),
              _readOnlyInfoRow(
                'Ambulance Driver',
                _loadingDriverLabel ? 'Loading...' : _assignedDriverLabel,
              ),
              const SizedBox(height: 24),

              _sectionHeader('Response Information'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _typeOfResponse,
                isExpanded: true,
                decoration: _dropdownDecoration('Type of Response'),
                items: _responseTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                validator: (v) => v == null ? 'Required' : null,
                onChanged: (v) {
                  setState(() {
                    _typeOfResponse = v ?? _typeOfResponse;
                    _responseSubType = null;
                    _otherSubTypeCtrl.clear();
                  });
                },
              ),
              if (_activeSubTypes.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _responseSubType,
                  isExpanded: true,
                  decoration: _dropdownDecoration('$_typeOfResponse Sub-Category'),
                  items: _activeSubTypes
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  validator: (v) => v == null ? 'Sub-category is required' : null,
                  onChanged: (v) {
                    setState(() {
                      _responseSubType = v;
                      if (v == null || !v.startsWith('Other')) {
                        _otherSubTypeCtrl.clear();
                      }
                    });
                  },
                ),
              ],
              if (_isOtherSubType) ...[
                const SizedBox(height: 12),
                _buildField(
                  _otherSubTypeCtrl,
                  'Please specify',
                  hint: 'Type of $_typeOfResponse',
                  validator: validateNonEmpty,
                ),
              ],
              const SizedBox(height: 12),
              _buildField(
                _patientConditionCtrl,
                'Patient Condition',
                hint: 'e.g. Conscious, Unconscious, Critical',
                validator: validateNonEmpty,
              ),
              const SizedBox(height: 12),
              _buildField(
                _presentIllnessCtrl,
                'Present Illness / Chief Complaint',
                maxLines: 3,
                validator: validateNonEmpty,
              ),
              const SizedBox(height: 12),
              _buildField(
                _pastMedicalHistoryCtrl,
                'Past Medical History',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _buildField(
                _painLocationCtrl,
                'Pain Location',
              ),
              const SizedBox(height: 24),

              _sectionHeader('Vital Signs'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      _bpCtrl,
                      'BP',
                      hint: '120/80',
                      validator: validateNonEmpty,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      _pulseRateCtrl,
                      'Pulse Rate',
                      hint: 'bpm',
                      inputType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      _temperatureCtrl,
                      'Temperature',
                      hint: '°C',
                      inputType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      _respiratoryRateCtrl,
                      'Respiratory Rate',
                      hint: 'breaths/min',
                      inputType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                      _spo2Ctrl,
                      'SPO2',
                      hint: '%',
                      inputType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                      _timeCtrl,
                      'Time',
                      hint: 'HH:MM',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _sectionHeader('Action Taken'),
              const SizedBox(height: 12),
              _buildField(
                _actionTakenCtrl,
                'Action Taken / Interventions',
                maxLines: 4,
                validator: validateNonEmpty,
              ),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: _isScanning ? null : _scanPCR,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isScanning
                            ? Icons.hourglass_empty
                            : Icons.camera_alt_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isScanning
                              ? 'Scanning... please wait'
                              : _scannedImage != null
                              ? 'Re-scan PCR form'
                              : 'Scan PCR form via Camera',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_isScanning)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (_ocrText.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => setState(() => _showOcrText = !_showOcrText),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD3D1C7)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'View extracted text',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textGray,
                          ),
                        ),
                        Icon(
                          _showOcrText
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: AppColors.textGray,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showOcrText) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD3D1C7)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Extracted text — copy relevant info to the fields above:',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textGray,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _ocrText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: AppColors.textDark,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],

              if (_scannedImage != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    _scannedImage!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitPCR,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Submit PCR Report',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readOnlyInfoRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD3D1C7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textGray,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD3D1C7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD3D1C7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    String? hint,
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD3D1C7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD3D1C7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  @override
  void dispose() {
    _responderNameCtrl.dispose();
    _responderIdCtrl.dispose();
    _patientConditionCtrl.dispose();
    _presentIllnessCtrl.dispose();
    _pastMedicalHistoryCtrl.dispose();
    _painLocationCtrl.dispose();
    _bpCtrl.dispose();
    _pulseRateCtrl.dispose();
    _temperatureCtrl.dispose();
    _respiratoryRateCtrl.dispose();
    _spo2Ctrl.dispose();
    _timeCtrl.dispose();
    _actionTakenCtrl.dispose();
    _otherSubTypeCtrl.dispose();
    _ocrService.dispose();
    super.dispose();
  }
}