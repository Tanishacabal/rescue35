import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../constants/app_colors.dart';
import '../../widgets/design_system.dart';

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

String sanitizeInput(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[<>]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

String? validateNonEmpty(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'This field is required';
  if (text.length < 3) return 'Please provide more detail';
  if (text.length > 500) return 'Text is too long (max 500 characters)';
  return null;
}

String? validateName(String? value, {String label = 'Name'}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return '$label is required';
  if (text.length < 2) return 'Minimum 2 characters';
  if (text.length > 50) return '$label is too long';
  if (!RegExp(r"^[a-zA-Z\s.'-]+$").hasMatch(text)) return 'Letters only';
  return null;
}

String? validateMiddleInitial(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  return RegExp(r'^[A-Z]$').hasMatch(text) ? null : '1 letter';
}

String? validateAddress(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Address is required';
  if (text.length < 5) return 'Please enter a complete address';
  if (text.length > 200) return 'Address is too long';
  return null;
}

String? validateAge(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return 'Age is required';
  final age = int.tryParse(text);
  if (age == null) return 'Enter a valid whole number';
  if (age <= 0 || age > 120) return 'Enter a valid age (1-120)';
  return null;
}

String? validatePhilippineMobile(String? value) {
  final text = (value ?? '').trim().replaceAll(RegExp(r'[\s-]'), '');
  if (text.isEmpty) return 'Phone number is required';
  final local = RegExp(r'^09\d{9}$');
  final intl = RegExp(r'^\+639\d{9}$');
  if (!local.hasMatch(text) && !intl.hasMatch(text)) {
    return 'Enter a valid PH mobile number (e.g. 09171234567)';
  }
  return null;
}

class _SearchResult {
  final String displayName;
  final LatLng point;
  const _SearchResult({required this.displayName, required this.point});
}

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _defaultCenter = LatLng(18.2333, 121.6667);

  final _mapController = MapController();
  final _searchCtrl = TextEditingController();

  LatLng? _picked;
  bool _isSearching = false;
  bool _isLocating = false;
  List<_SearchResult> _results = [];
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialLocation;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final text = query.trim();
    if (text.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(text)}'
        '&format=json&limit=6&countrycodes=ph'
        '&viewbox=121.3,18.6,122.1,17.8&bounded=0',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'rescue35-flutter-app'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _results = data.map((item) {
            return _SearchResult(
              displayName: item['display_name'] as String,
              point: LatLng(
                double.parse(item['lat'] as String),
                double.parse(item['lon'] as String),
              ),
            );
          }).toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectResult(_SearchResult result) {
    setState(() {
      _picked = result.point;
      _results = [];
      _searchCtrl.text = result.displayName;
    });
    _mapController.move(result.point, 16);
    FocusScope.of(context).unfocus();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError =
            'Naka-off ang Location services. I-on muna sa settings ng device.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationError =
              'Hindi pinayagan ang location access. Kailangan ito para makuha ang kasalukuyang lokasyon.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationError =
            'Permanenteng naka-deny ang location permission. Paki-enable sa App Settings.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _picked = point;
        _searchCtrl.text =
            '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
        _results = [];
      });
      _mapController.move(point, 16);
    } catch (e) {
      setState(() => _locationError = 'Hindi makuha ang lokasyon: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tap to Select Pickup Location')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialLocation ?? _defaultCenter,
              initialZoom: 14,
              onTap: (tapPosition, point) {
                setState(() {
                  _picked = point;
                  _results = [];
                });
                FocusScope.of(context).unfocus();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.yourapp.rescue',
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.location_pin,
                        color: AppColors.primary,
                        size: 44,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(14),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Maghanap ng lugar o address',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : (_searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _results = []);
                                  },
                                )
                              : null),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (_searchCtrl.text == value) _search(value);
                      });
                    },
                    onSubmitted: _search,
                  ),
                ),
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _results.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, i) {
                        final result = _results[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined,
                              color: AppColors.secondary),
                          title: Text(
                            result.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () => _selectResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 110,
            child: FloatingActionButton.small(
              heroTag: 'current_location',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              onPressed: _isLocating ? null : _useCurrentLocation,
              child: _isLocating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              children: [
                if (_locationError != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _locationError!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
                else if (_picked == null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                        'Maghanap, tap sa mapa, o gamitin ang current location'),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _picked == null ? null : () => Navigator.pop(context, _picked),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Use This Location'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _userLastNameCtrl = TextEditingController();
  final _userFirstNameCtrl = TextEditingController();
  final _userMiCtrl = TextEditingController();
  final _userPhoneCtrl = TextEditingController();
  final _userAddressCtrl = TextEditingController();

  final _patientLastNameCtrl = TextEditingController();
  final _patientFirstNameCtrl = TextEditingController();
  final _patientMiCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _pickupCtrl = TextEditingController();
  final _concernCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  int _step = 0;
  bool _isLoading = false;
  DateTime? _selectedDate;
  String? _selectedTime;
  TimeOfDay? _selectedTimeOfDay;
  LatLng? _pickupLatLng;
  String _sex = 'Male';
  String _barangay = 'Centro';
  String _hospital = 'Lal-lo District Hospital';
  bool _profileLoaded = false;

  final List<TimeOfDay> _availableTimeSlots = const [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 10, minute: 0),
    TimeOfDay(hour: 13, minute: 0),
    TimeOfDay(hour: 15, minute: 0),
  ];

  final _hospitals = const [
    'Lal-lo District Hospital',
    'Cagayan Valley Medical Center',
    'St. Paul Hospital Tuguegarao',
    'Alcala Medicare Community Hospital',
  ];

  final _barangays = const [
    'Abagao',
    'Alaguia',
    'Bagumbayan',
    'Bangag',
    'Bical',
    'Bicud',
    'Binag',
    'Cabayabasan',
    'Cagoran',
    'Cambong',
    'Catayauan',
    'Catugan',
    'Centro',
    'Cullit',
    'Dagupan',
    'Dalaya',
    'Fabrica',
    'Fusina',
    'Lalafugan',
    'Logac',
    'Magallungon',
    'Magapit',
    'Malanao',
    'Maxingal',
    'Naguilian',
    'Paranum',
    'Rosario',
    'San Antonio',
    'San Jose',
    'San Juan',
    'San Lorenzo',
    'San Mariano',
    'Santa Maria',
    'Tucalana',
  ];

  String get _userFullName => _composeName(
        _userLastNameCtrl.text,
        _userFirstNameCtrl.text,
        _userMiCtrl.text,
      );

  String get _patientFullName => _composeName(
        _patientLastNameCtrl.text,
        _patientFirstNameCtrl.text,
        _patientMiCtrl.text,
      );

  String _composeName(String last, String first, String mi) {
    final l = sanitizeInput(last).trim();
    final f = sanitizeInput(first).trim();
    final m = sanitizeInput(mi).trim();
    final miPart = m.isEmpty ? '' : ' ${m.replaceAll('.', '')}.';
    return '$l, $f$miPart';
  }

  void _splitFullNameInto(
    String fullName,
    TextEditingController lastCtrl,
    TextEditingController firstCtrl,
    TextEditingController miCtrl,
  ) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return;

    if (trimmed.contains(',')) {
      final parts = trimmed.split(',');
      lastCtrl.text = parts[0].trim().toUpperCase();
      final rest = parts.length > 1 ? parts[1].trim() : '';
      final restTokens =
          rest.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      if (restTokens.isNotEmpty) {
        final last = restTokens.last;
        final isMi = last.replaceAll('.', '').length == 1;
        if (isMi && restTokens.length > 1) {
          miCtrl.text = last.replaceAll('.', '').toUpperCase();
          firstCtrl.text =
              restTokens.sublist(0, restTokens.length - 1).join(' ').toUpperCase();
        } else {
          firstCtrl.text = restTokens.join(' ').toUpperCase();
        }
      }
    } else {
      final tokens =
          trimmed.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      if (tokens.length == 1) {
        firstCtrl.text = tokens[0].toUpperCase();
      } else {
        lastCtrl.text = tokens.last.toUpperCase();
        firstCtrl.text = tokens.sublist(0, tokens.length - 1).join(' ').toUpperCase();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          _splitFullNameInto(
            data['fullName'] ?? '',
            _userLastNameCtrl,
            _userFirstNameCtrl,
            _userMiCtrl,
          );
          _userPhoneCtrl.text = data['phoneNumber'] ?? '';
          _userAddressCtrl.text = data['address'] ?? '';
          _profileLoaded = true;
        });
      } else {
        setState(() => _profileLoaded = true);
      }
    } catch (e) {
      setState(() => _profileLoaded = true);
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTimeOfDay ?? _availableTimeSlots.first,
      helpText: 'Select Pickup Time',
    );
    if (picked == null) return;

    final isAvailable = _availableTimeSlots.any(
      (slot) => slot.hour == picked.hour && slot.minute == picked.minute,
    );

    if (!isAvailable) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.error_outline_rounded,
              color: AppColors.secondary, size: 40),
          title: const Text('Time Not Available'),
          content: Text(
            'Hindi available ang napiling oras. Pumili sa mga sumusunod:\n\n'
            '${_availableTimeSlots.map(_formatTimeOfDay).join('  •  ')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _selectedTimeOfDay = picked;
      _selectedTime = _formatTimeOfDay(picked);
    });
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialLocation: _pickupLatLng),
      ),
    );
    if (result != null) {
      setState(() {
        _pickupLatLng = result;
        _pickupCtrl.text =
            '${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) return;
    if (_pickupLatLng == null) {
      _snack('Please select a pickup location on the map.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final db = FirebaseFirestore.instance;
      final tracking = 'R35-${DateTime.now().millisecondsSinceEpoch}';

      final patientRef = await db.collection('patients').add({
        'userID': uid,
        'patientname': _patientFullName,
        'age': int.tryParse(_ageCtrl.text) ?? 0,
        'sex': _sex,
        'contactNumber': sanitizeInput(_contactCtrl.text),
        'barangay': _barangay,
        'address': sanitizeInput(_addressCtrl.text),
      });

      await db.collection('transport_requests').add({
        'userID': uid,
        'patientID': patientRef.id,
        'trackingNumber': tracking,
        'location': sanitizeInput(_pickupCtrl.text),
        'pickupLat': _pickupLatLng!.latitude,
        'pickupLng': _pickupLatLng!.longitude,
        'destinationHospital': _hospital,
        'description': sanitizeInput(_concernCtrl.text),
        'additionalNotes': sanitizeInput(_notesCtrl.text),
        'scheduleDate': Timestamp.fromDate(_selectedDate!),
        'scheduleTime': _selectedTime,
        'requestDate': FieldValue.serverTimestamp(),
        'status': 'pending',
        'timeline': ['Requested'],
      });

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.completed,
            size: 46,
          ),
          title: const Text('Request Submitted'),
          content: Text(
            'Tracking Number\n$tracking',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RescueGradientScaffold(
      child: Column(
        children: [
          AppBar(
            title: const Text('Request Medical Transport'),
            elevation: 0,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: !_profileLoaded
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _progress(),
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: [
                            _profileStep(),
                            _dateStep(),
                            _timeStep(),
                            _patientStep(),
                            _transportStep(),
                            _confirmStep(),
                          ][_step],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            if (_step > 0)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => setState(() => _step -= 1),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  label: const Text('Back'),
                                ),
                              ),
                            if (_step > 0) const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: PrimaryButton(
                                label: _step == 5 ? 'Submit Request' : 'Continue',
                                icon: _step == 5
                                    ? Icons.send_rounded
                                    : Icons.arrow_forward_rounded,
                                loading: _isLoading,
                                onPressed: _step == 5 ? _submit : _next,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _next() {
    if (_step == 0) {
      if (!_formKey.currentState!.validate()) return;
    } else if (_step == 1 && _selectedDate == null) {
      _snack('Select an available future date.');
      return;
    } else if (_step == 2 && _selectedTime == null) {
      _snack('Select an available time slot.');
      return;
    } else if ((_step == 3 || _step == 4) && !_formKey.currentState!.validate()) {
      return;
    } else if (_step == 4 && _pickupLatLng == null) {
      _snack('Please select a pickup location on the map.');
      return;
    }
    setState(() => _step += 1);
  }

  Widget _progress() {
    final labels = ['Profile', 'Date', 'Time', 'Patient', 'Transport', 'Confirm'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= _step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 6),
            height: 7,
            decoration: BoxDecoration(
              color: active ? AppColors.secondary : AppColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }

  Widget _profileStep() {
    return GlassCard(
      key: const ValueKey('profile'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(Icons.person_outline, 'Your Profile Information'),
          const SizedBox(height: 8),
          const Text(
            'Please confirm your contact information',
            style: TextStyle(color: AppColors.textGray, fontSize: 12),
          ),
          const SizedBox(height: 16),
          _nameRow(_userLastNameCtrl, _userFirstNameCtrl, _userMiCtrl),
          _gap(),
          _field(
            _userPhoneCtrl,
            'Phone Number',
            Icons.phone_outlined,
            inputType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              LengthLimitingTextInputFormatter(13),
            ],
            validator: validatePhilippineMobile,
          ),
          _gap(),
          _field(
            _userAddressCtrl,
            'Address',
            Icons.home_outlined,
            maxLines: 2,
            inputFormatters: [LengthLimitingTextInputFormatter(200)],
            validator: validateAddress,
          ),
        ],
      ),
    );
  }

  Widget _dateStep() {
    final today = DateTime.now();
    return GlassCard(
      key: const ValueKey('date'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(Icons.calendar_month_outlined, 'Select Schedule Date'),
          CalendarDatePicker(
            initialDate: _selectedDate ?? today.add(const Duration(days: 1)),
            firstDate: today,
            lastDate: today.add(const Duration(days: 60)),
            onDateChanged: (date) => setState(() => _selectedDate = date),
          ),
          const SizedBox(height: 8),
          const Text(
            'Past dates and fully booked LGU schedules are disabled during final admin configuration.',
            style: TextStyle(color: AppColors.textGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _timeStep() {
    return GlassCard(
      key: const ValueKey('time'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(Icons.schedule_outlined, 'Select Pickup Time'),
          InkWell(
            onTap: _pickTime,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    _selectedTime ?? 'Tap to select a time',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _selectedTime == null
                          ? AppColors.textGray
                          : AppColors.dark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Available slots: ${_availableTimeSlots.map(_formatTimeOfDay).join(', ')}',
            style: const TextStyle(color: AppColors.textGray, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _patientStep() {
    return GlassCard(
      key: const ValueKey('patient'),
      child: Column(
        children: [
          _title(Icons.personal_injury_outlined, 'Patient Information'),
          _nameRow(_patientLastNameCtrl, _patientFirstNameCtrl, _patientMiCtrl),
          _gap(),
          Row(
            children: [
              Expanded(
                child: _field(
                  _ageCtrl,
                  'Age',
                  Icons.cake_outlined,
                  inputType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  validator: validateAge,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sex,
                  isExpanded: true,
                  decoration:
                      rescueInputDecoration('Sex', Icons.wc_outlined),
                  items: const ['Male', 'Female']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _sex = v ?? _sex),
                  validator: (v) => v == null ? 'Sex is required' : null,
                ),
              ),
            ],
          ),
          _gap(),
          _field(
            _contactCtrl,
            'Contact Number',
            Icons.phone_outlined,
            inputType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              LengthLimitingTextInputFormatter(13),
            ],
            validator: validatePhilippineMobile,
          ),
          _gap(),
          DropdownButtonFormField<String>(
            initialValue: _barangay,
            decoration:
                rescueInputDecoration('Barangay', Icons.location_city_outlined),
            items: _barangays
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) => setState(() => _barangay = v ?? _barangay),
            validator: (v) => v == null ? 'Barangay is required' : null,
          ),
          _gap(),
          _field(
            _addressCtrl,
            'House / Street Address',
            Icons.home_outlined,
            maxLines: 2,
            inputFormatters: [LengthLimitingTextInputFormatter(200)],
            validator: validateAddress,
          ),
        ],
      ),
    );
  }

  Widget _transportStep() {
    return GlassCard(
      key: const ValueKey('transport'),
      child: Column(
        children: [
          _title(Icons.local_hospital_outlined, 'Transport Details'),
          TextFormField(
            controller: _pickupCtrl,
            readOnly: true,
            onTap: _pickLocation,
            decoration: rescueInputDecoration(
              'Pickup Location',
              Icons.pin_drop_outlined,
              hint: 'Tap to select on map',
            ).copyWith(
              suffixIcon: const Icon(Icons.map_outlined),
            ),
            validator: (v) => _pickupLatLng == null
                ? 'Please select a pickup location on the map'
                : null,
          ),
          _gap(),
          DropdownButtonFormField<String>(
            initialValue: _hospital,
            isExpanded: true,
            decoration: rescueInputDecoration(
              'Destination Hospital',
              Icons.local_hospital_outlined,
            ),
            items: _hospitals
                .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                .toList(),
            onChanged: (v) => setState(() => _hospital = v ?? _hospital),
            validator: (v) => v == null ? 'Hospital is required' : null,
          ),
          _gap(),
          _field(
            _concernCtrl,
            'Medical Concern',
            Icons.medical_information_outlined,
            maxLines: 3,
            inputFormatters: [LengthLimitingTextInputFormatter(500)],
            validator: validateNonEmpty,
          ),
          _gap(),
          _field(
            _notesCtrl,
            'Additional Notes',
            Icons.note_alt_outlined,
            maxLines: 2,
            inputFormatters: [LengthLimitingTextInputFormatter(500)],
            required: false,
            validator: (v) {
              final text = (v ?? '').trim();
              if (text.isEmpty) return null;
              return text.length < 3 ? 'Please provide more detail' : null;
            },
          ),
        ],
      ),
    );
  }

  Widget _confirmStep() {
    return GlassCard(
      key: const ValueKey('confirm'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(Icons.fact_check_outlined, 'Confirm Request'),
          const Divider(height: 16),
          const Text(
            'Your Information',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          _gap(),
          _summary('Your Name', _userFullName),
          _summary('Your Phone', _userPhoneCtrl.text),
          _summary('Your Address', _userAddressCtrl.text),
          const SizedBox(height: 16),
          const Divider(height: 16),
          const Text(
            'Patient Details',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          _gap(),
          _summary('Patient Name', _patientFullName),
          _summary('Age', _ageCtrl.text),
          _summary('Sex', _sex),
          _summary('Phone', _contactCtrl.text),
          _summary('Barangay', _barangay),
          _summary('Address', _addressCtrl.text),
          const SizedBox(height: 16),
          const Divider(height: 16),
          const Text(
            'Transport Details',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          _gap(),
          _summary('Date', _selectedDate?.toString().substring(0, 10) ?? '-'),
          _summary('Time', _selectedTime ?? '-'),
          _summary('Pickup', _pickupCtrl.text),
          _summary('Hospital', _hospital),
          _summary('Concern', _concernCtrl.text),
          if (_notesCtrl.text.trim().isNotEmpty)
            _summary('Notes', _notesCtrl.text),
        ],
      ),
    );
  }

  Widget _title(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameRow(
    TextEditingController lastCtrl,
    TextEditingController firstCtrl,
    TextEditingController miCtrl,
  ) {
    return Column(
      children: [
        _field(
          lastCtrl,
          'Last Name',
          Icons.person_outline,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            _UpperCaseTextFormatter(),
            LengthLimitingTextInputFormatter(50),
          ],
          validator: (v) => validateName(v, label: 'Last name'),
        ),
        const SizedBox(height: 10),
        _field(
          firstCtrl,
          'First Name',
          Icons.person_outline,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            _UpperCaseTextFormatter(),
            LengthLimitingTextInputFormatter(50),
          ],
          validator: (v) => validateName(v, label: 'First name'),
        ),
        const SizedBox(height: 10),
        _field(
          miCtrl,
          'Middle Initial',
          Icons.short_text_rounded,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            _UpperCaseTextFormatter(),
            LengthLimitingTextInputFormatter(1),
          ],
          required: false,
          validator: validateMiddleInitial,
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? hint,
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    bool required = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: inputType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      decoration: rescueInputDecoration(
        label,
        icon,
        hint: hint,
        required: required,
      ),
      validator: validator,
    );
  }

  Widget _summary(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textGray,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(child: Text(value.trim().isEmpty ? '-' : value.trim())),
        ],
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _gap() => const SizedBox(height: 12);

  @override
  void dispose() {
    _userLastNameCtrl.dispose();
    _userFirstNameCtrl.dispose();
    _userMiCtrl.dispose();
    _userPhoneCtrl.dispose();
    _userAddressCtrl.dispose();
    _patientLastNameCtrl.dispose();
    _patientFirstNameCtrl.dispose();
    _patientMiCtrl.dispose();
    _ageCtrl.dispose();
    _contactCtrl.dispose();
    _addressCtrl.dispose();
    _pickupCtrl.dispose();
    _concernCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }
}