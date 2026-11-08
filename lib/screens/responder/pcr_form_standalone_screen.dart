import 'package:flutter/material.dart' hide Text;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../services/app_language.dart';
import '../../widgets/localized_text.dart' show Text;
import 'dart:io';
import '../../services/ocr_service.dart';
import '../../services/activity_log_service.dart';
import 'package:image_picker/image_picker.dart';

/// PCR form para sa EMERGENCY / WALK-IN na sitwasyon — WALANG naka-link
/// na transport schedule. Dito nagpapakita ng Patient Name field at
/// Ambulance dropdown (kailangan piliin ng responder), kumpara sa
/// `PCRFormScreen` na read-only na lang dahil galing na sa schedule.
///
/// Halimbawa ng paggamit — button na "Emergency PCR (No Schedule)":
///
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (_) => const PCRStandaloneFormScreen()),
/// );
/// ```
class PCRStandaloneFormScreen extends StatefulWidget {
  const PCRStandaloneFormScreen({super.key});

  @override
  State<PCRStandaloneFormScreen> createState() =>
      _PCRStandaloneFormScreenState();
}

class _PCRStandaloneFormScreenState extends State<PCRStandaloneFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ocrService = OcrService();
  File? _scannedImage;
  String _ocrText = '';
  bool _isScanning = false;
  bool _showOcrText = false;

  // ── Type of Response dropdown ───────────────────────────
  String _typeOfResponse = 'Emergency';
  String? _responseSubType;
  final _otherSubTypeCtrl = TextEditingController();

  final _responseTypes = const [
    'Emergency',
    'Trauma',
    'Medical',
    'Transfer',
    'OB',
  ];

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
  final _patientNameCtrl = TextEditingController();
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

  // Listahan ng available vehicles para sa dropdown.
  List<Map<String, dynamic>> _vehicleOptions = [];
  String? _selectedVehicleID;
  bool _loadingVehicles = false;

  // Listahan ng ambulance drivers para sa dropdown.
  List<Map<String, dynamic>> _driverOptions = [];
  String? _selectedDriverID;
  bool _loadingDrivers = false;
  bool _driverLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadVehicleOptions();
    _loadDriverOptions();
  }

  Future<void> _loadVehicleOptions() async {
    if (!mounted) return;
    setState(() => _loadingVehicles = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('vehicles')
          .get();
      final options = snap.docs
          .where((doc) => (doc.data())['status'] == 'available')
          .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'label':
                  '${data['plateNumber'] ?? doc.id} • ${data['vehicleType'] ?? ''}',
            };
          })
          .toList();
      if (mounted) {
        setState(() {
          _vehicleOptions = options;
          _loadingVehicles = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVehicles = false);
    }
  }

  Future<void> _loadDriverOptions() async {
    if (!mounted) return;
    setState(() => _loadingDrivers = true);
    try {
      // Driver accounts can use different role spellings depending on where
      // the account was created, so filter the users collection locally.
      final snap = await FirebaseFirestore.instance
          .collection('responders')
          .get();
      final options = snap.docs
          .where((doc) {
            final data = doc.data();
            final role = data['role']?.toString().toLowerCase().replaceAll(
              '-',
              '_',
            );
            final userType = data['userType']
                ?.toString()
                .toLowerCase()
                .replaceAll('-', '_');
            final responderType = data['responderType']
                ?.toString()
                .toLowerCase()
                .replaceAll('-', '_');
            return {
                  'driver',
                  'ambulance_driver',
                  'ambulancedriver',
                  'driver_responder',
                }.contains(role) ||
                {
                  'driver',
                  'ambulance_driver',
                  'ambulancedriver',
                }.contains(userType) ||
                {
                  'driver',
                  'ambulance_driver',
                  'ambulancedriver',
                }.contains(responderType);
          })
          .map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'label':
                  (data['responder_name'] ??
                          data['name'] ??
                          data['fullName'] ??
                          doc.id)
                      .toString(),
            };
          })
          .toList();
      if (mounted) {
        setState(() {
          _driverOptions = options;
          _loadingDrivers = false;
          _driverLoadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingDrivers = false;
          _driverLoadFailed = true;
        });
      }
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

  // ── OCR autofill ─────────────────────────────────────────
  void _fillFieldsFromOcr(String text) {
    final normalized = text.replaceAll('\r', '\n');

    _setIfFound(
      _patientConditionCtrl,
      _findLabeledValue(normalized, const ['patient condition']) ??
          _firstMatch(
            normalized,
            RegExp(
              r'\b(?:unconscious|conscious|unresponsive)\b',
              caseSensitive: false,
            ),
          ),
    );

    _setIfFound(
      _presentIllnessCtrl,
      _findLabeledValue(normalized, const [
        'history of present illness',
        'present illness',
        'chief complaint',
        'complaint',
      ], multiLine: true),
    );

    _setIfFound(
      _pastMedicalHistoryCtrl,
      _findLabeledValue(normalized, const [
        'past medical history',
        'past health history',
        'medical history',
        'pmh',
      ], multiLine: true),
    );

    _setIfFound(
      _painLocationCtrl,
      _findLabeledValue(normalized, const [
        'pain location',
        'location of pain',
        'locations',
      ])?.replaceFirst(
        RegExp(r'^\(\+\)\s*pain\s*[-:]?\s*', caseSensitive: false),
        '',
      ),
    );

    _fillVitalsFromOcr(normalized);

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

    _setIfFound(_actionTakenCtrl, _findActionTaken(normalized));
  }

  /// Vital signs (Patient No. 1). Hindi umaasa sa labels dahil hiwalay
  /// ang labels at values sa OCR. Gumagamit ng normal range bilang anchor,
  /// at ng pagkakasunod ng mga numero pagkatapos ng BP bilang fallback.
  void _fillVitalsFromOcr(String text) {
    final t = text.replaceAll(RegExp(r'[–—]'), '-');

    // BP: unang xxx/xx na hindi 120/80 (normal range)
    String? bp;
    var bpEnd = -1;
    for (final m in RegExp(
      r'(?<!\d)(\d{2,3})\s*/\s*(\d{2,3})(?!\d)',
    ).allMatches(t)) {
      final sys = int.parse(m.group(1)!);
      final dia = int.parse(m.group(2)!);
      if (sys == 120 && dia == 80) continue;
      if (sys < 60 || sys > 260 || dia < 30 || dia > 160 || sys <= dia) {
        continue;
      }
      bp = '$sys/$dia';
      bpEnd = m.end;
      break;
    }

    String? pick(String pattern) =>
        RegExp(pattern).firstMatch(t)?.group(1)?.replaceAll(',', '.');

    var pr = pick(r'60\s*-\s*100\s*\)?\s*(\d{2,3})(?!\d)');
    var bt = pick(r'(?<!\d)37(?:\.0)?\s*\)?\s*(\d{2}(?:[.,]\d)?)(?!\d)');
    var rr = pick(r'12\s*-\s*20\s*\)?\s*(\d{1,2})(?!\d)');

    // Fallback: mga numero na kasunod ng BP, in order: PR, BT, RR
    if ((pr == null || bt == null || rr == null) && bpEnd >= 0) {
      final rest = t
          .substring(bpEnd)
          .replaceAll(RegExp(r'\([^)]*\)'), ' ')
          .replaceAll(RegExp(r'\d+\s*-\s*\d+'), ' ')
          // Idugtong ang numerong hinati ng OCR (hal. "9 2" -> "92")
          .replaceAllMapped(
            RegExp(r'(?<![\d.])(\d)\s+(\d)(?![\d.])'),
            (m) => '${m.group(1)}${m.group(2)}',
          );
      final nums = RegExp(r'(?<![\d.])\d{1,3}(?:[.,]\d)?(?!\d)')
          .allMatches(rest)
          .map((m) => m.group(0)!.replaceAll(',', '.'))
          .take(12)
          .toList();
      bool isInt(String n) => !n.contains('.');
      var idx = 0;
      String? next(bool Function(String) ok) {
        while (idx < nums.length) {
          final n = nums[idx++];
          if (ok(n)) return n;
        }
        return null;
      }

      // PR at RR: buong numero lang (walang decimal). BT: may decimal.
      pr ??= next((n) {
        final v = double.parse(n);
        return isInt(n) && v >= 30 && v <= 220;
      });
      bt ??= next((n) {
        final v = double.parse(n);
        return !isInt(n) && v >= 34 && v <= 42;
      });
      rr ??= next((n) {
        final v = double.parse(n);
        return isInt(n) && v >= 6 && v <= 60;
      });
    }

    if (bt != null) {
      final v = double.tryParse(bt);
      if (v == null || v < 34 || v > 42) bt = null;
    }

    // Last resort para sa temperature: kahit anong xx.x sa 34–42 (hal. 36.8)
    if (bt == null) {
      final m = RegExp(
        r'(?<!\d)(3[4-9]|4[0-2])\s*[.,]\s*(\d)(?!\d)',
      ).firstMatch(t);
      if (m != null) bt = '${m.group(1)}.${m.group(2)}';
    }

    _setIfFound(_bpCtrl, bp);
    _setIfFound(_pulseRateCtrl, pr);
    _setIfFound(_temperatureCtrl, bt);
    _setIfFound(_respiratoryRateCtrl, rr);
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
      'history of present illness',
      'present illness',
      'chief complaint',
      'past medical history',
      'past health history',
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
      'action/',
      'interventions',
      'treatment',
      'responders',
      'endorsement',
      'address',
      'ambulance unit',
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

      // Tinatanggal din ang "/s:" sa "Chief Complaint/s:"
      final sameLine = lines[i]
          .substring(lower.indexOf(foundLabel) + foundLabel.length)
          .replaceFirst(RegExp(r'^\s*(?:/\s*s)?\s*[:\-]\s*'), '')
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

  // Regex para makilala ang label ng vital sign sa isang linya
  static final _vitalLabelPattern = RegExp(
    r'(?<![a-z])(bp|pr|bt|rr|temp|pulse|spo2)(?![a-z])',
    caseSensitive: false,
  );

  // Tinatanggal ang units/normal range na nasa ( ) at ang ranges (hal. 60-100)
  String _cleanVitalText(String s) => s
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'\d+\s*[-–]\s*\d+'), ' ');

  /// Kinukuha ang value ng Patient No. 1 sa vital signs table.
  String? _findVital(
    String text,
    List<String> labels,
    RegExp valuePattern, {
    bool preferSecondIfNoParens = false,
  }) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      for (final label in labels) {
        final m = RegExp(
          '(?<![a-z])${RegExp.escape(label)}(?![a-z])',
        ).firstMatch(lower);
        if (m == null) continue;

        final rest = lines[i].substring(m.end);
        final cleaned = _cleanVitalText(rest);
        final matches = valuePattern.allMatches(cleaned).toList();

        if (matches.isNotEmpty) {
          // Kung walang ( ) at may 2 values, ang una ay normal range
          if (preferSecondIfNoParens &&
              !rest.contains('(') &&
              matches.length >= 2) {
            return matches[1].group(0);
          }
          return matches.first.group(0);
        }

        // Fallback: baka nasa susunod na linya ang value (column-by-column OCR)
        for (var j = i + 1; j < lines.length && j <= i + 3; j++) {
          if (_vitalLabelPattern.hasMatch(lines[j].toLowerCase())) break;
          final next = valuePattern.firstMatch(_cleanVitalText(lines[j]));
          if (next != null) return next.group(0);
        }
      }
    }
    return null;
  }

  /// Hinahanap ang value sa tabi ng standard normal range ng form
  /// (hal. "(120/80) 130/90"), kahit hiwalay ang labels sa values sa OCR.
  String? _normalRangeValue(String text, String pattern) {
    return RegExp(pattern).firstMatch(text)?.group(1)?.replaceAll(' ', '');
  }

  // Linya ng vital signs table (header, labels, numbers) na hindi dapat
  // mapasama sa Action Taken.
  bool _isVitalNoise(String line) {
    final stripped = line
        .toLowerCase()
        .replaceAll(
          RegExp(
            r'\b(vital|signs?|normal|patient|no|nol|noi|bp|pr|bt|rr|mmhg|bpm|cpm)\b',
          ),
          '',
        )
        .replaceAll(RegExp(r'[\d\s()/.\-–:°c,]'), '');
    return stripped.isEmpty;
  }

  /// Kinukuha ang "ACTION/'S TAKEN:" hanggang bago ang RESPONDERS,
  /// nilalaktawan ang mga linya ng vital signs table.
  /// Action Taken: una, hinahanap ang mga linyang nagsisimula sa karaniwang
  /// action verbs (Assessed, Controlled, Monitored, Transported...), kahit
  /// saan sa scan lumabas. Kung wala, gamitin ang "ACTION/'S TAKEN" label.
  String? _findActionTaken(String text) {
    final verbRe = RegExp(
      r'^[\W\d]*(?:assess|control|monitor|administ|appl(?:y|ied)|transport|'
      r'load|perform|gave|given|immobili|clean|dress|splint|check|provid|'
      r'initiat|secur|bandag|insert|obtain|elevat|stabili|extric|ventilat|'
      r'suction|oxygen|cpr|c-collar|cervical)',
      caseSensitive: false,
    );
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.length > 6)
        .toList();
    final actions = lines.where((l) => verbRe.hasMatch(l)).toList();
    if (actions.isNotEmpty) return actions.join('\n');
    return _findActionTakenByLabel(text);
  }

  String? _findActionTakenByLabel(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final labelRe = RegExp(r"action\W*s?\W*taken", caseSensitive: false);
    final stopRe = RegExp(
      r'responders|endorsement|received by|waiver|verified and checked',
      caseSensitive: false,
    );

    for (var i = 0; i < lines.length; i++) {
      final m = labelRe.firstMatch(lines[i]);
      if (m == null) continue;

      final collected = <String>[];
      final sameLine = lines[i]
          .substring(m.end)
          .replaceFirst(RegExp(r'^\s*[:\-]\s*'), '')
          .trim();
      if (sameLine.isNotEmpty && !_isVitalNoise(sameLine)) {
        collected.add(sameLine);
      }

      for (var j = i + 1; j < lines.length; j++) {
        if (stopRe.hasMatch(lines[j])) break;
        if (_isVitalNoise(lines[j])) continue;
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

  // ── Submit PCR (emergency / walang schedule) ────────────
  Future<void> _submitPCR() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedVehicleID == null || _selectedVehicleID!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an ambulance.')),
      );
      return;
    }

    if (_selectedDriverID == null || _selectedDriverID!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an ambulance driver.')),
      );
      return;
    }

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

      final driverLabel =
          _driverOptions.firstWhere(
                (d) => d['id'] == _selectedDriverID,
                orElse: () => const {'label': ''},
              )['label']
              as String;

      final pcrReport = await db.collection('pcr_reports').add({
        'scheduleID': '',
        'patientID': '',
        'patientName': _patientNameCtrl.text.trim(),
        'vehicleID': _selectedVehicleID,
        'driverID': _selectedDriverID,
        'driverName': driverLabel,
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
        'isStandalone': true,
      });

      await ActivityLogService.log(
        action: 'emergency_pcr_report_submitted',
        description:
            'Submitted an emergency PCR report for ${_patientNameCtrl.text.trim()}.',
        entityType: 'pcr_report',
        entityId: pcrReport.id,
        metadata: {
          'vehicleID': _selectedVehicleID,
          'driverID': _selectedDriverID,
        },
      );

      // Walang schedule/request na i-a-update dito — bagong emergency case ito.

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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Emergency PCR Report'),
        actions: const [AppLanguageSwitcher(compact: true)],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader('Patient & Ambulance'),
              const SizedBox(height: 12),
              _buildField(
                _patientNameCtrl,
                'Patient Name',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedVehicleID,
                isExpanded: true,
                decoration: _dropdownDecoration(
                  _loadingVehicles ? 'Loading ambulances...' : 'Ambulance',
                ),
                items: _vehicleOptions
                    .map(
                      (v) => DropdownMenuItem<String>(
                        value: v['id'] as String,
                        child: Text(v['label'] as String),
                      ),
                    )
                    .toList(),
                validator: (v) => v == null ? 'Pumili ng ambulance' : null,
                onChanged: (v) => setState(() => _selectedVehicleID = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedDriverID,
                isExpanded: true,
                decoration: _dropdownDecoration(
                  _loadingDrivers
                      ? 'Loading drivers...'
                      : _driverLoadFailed
                      ? 'Unable to load drivers'
                      : _driverOptions.isEmpty
                      ? 'No drivers available'
                      : 'Ambulance Driver',
                ),
                items: _driverOptions
                    .map(
                      (d) => DropdownMenuItem<String>(
                        value: d['id'] as String,
                        child: Text(d['label'] as String),
                      ),
                    )
                    .toList(),
                validator: (v) => v == null ? 'Pumili ng driver' : null,
                onChanged: _driverOptions.isEmpty
                    ? null
                    : (v) => setState(() => _selectedDriverID = v),
              ),
              if (_driverLoadFailed) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _loadingDrivers ? null : _loadDriverOptions,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry loading drivers'),
                  ),
                ),
              ],
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
                  decoration: _dropdownDecoration(
                    '$_typeOfResponse Sub-Category',
                  ),
                  items: _activeSubTypes
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  validator: (v) =>
                      v == null ? 'Piliin ang sub-category' : null,
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
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],
              const SizedBox(height: 12),
              _buildField(
                _patientConditionCtrl,
                'Patient Condition',
                hint: 'e.g. Conscious, Unconscious, Critical',
              ),
              const SizedBox(height: 12),
              _buildField(
                _presentIllnessCtrl,
                'Present Illness / Chief Complaint',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              _buildField(
                _pastMedicalHistoryCtrl,
                'Past Medical History',
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _buildField(_painLocationCtrl, 'Pain Location'),
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
                      validator: (v) => v!.isEmpty ? 'Required' : null,
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
                    child: _buildField(_timeCtrl, 'Time', hint: 'HH:MM'),
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
                validator: (v) => v!.isEmpty ? 'Required' : null,
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
    _patientNameCtrl.dispose();
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