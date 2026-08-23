import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/design_system.dart';
import '../profile.dart';
import 'pcr_form_screen.dart';
import 'pcr_form_standalone_screen.dart';
import 'in_app_map_screen.dart';

class ResponderDashboard extends StatefulWidget {
  const ResponderDashboard({super.key});

  @override
  State<ResponderDashboard> createState() => _ResponderDashboardState();
}

class _ResponderDashboardState extends State<ResponderDashboard>
    with SingleTickerProviderStateMixin {
  static const _nativeActions = MethodChannel('rescue35/native_actions');

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return RescueGradientScaffold(
      safeArea: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.document_scanner_outlined),
          label: const Text('Scan PCR'),
          onPressed: () => _openEmergencyPcr(context),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, userSnap) {
            final userData = userSnap.data?.data() as Map<String, dynamic>?;
            final name = userData?['name'] ?? 'Responder';

            return Column(
              children: [
                _header(context, uid, name),
                Expanded(child: _dispatchBody(uid)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String uid, String name) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 18,
        20,
        18,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            Color(0xFFD62929),
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Responder Dashboard',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFE3E3),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              tooltip: 'Profile',
              icon: const Icon(Icons.person_outline_rounded, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(role: 'responder'),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await AuthService().logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dispatchBody(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transport_schedules')
          .where('responderID', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load assigned dispatches.\n${snap.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textGray),
              ),
            ),
          );
        }

        final docs = [...?snap.data?.docs]..sort(_sortSchedules);
        final assigned = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] != 'completed';
        }).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 118),
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                // Lowered from 1.28 -> 1.05 to give each card a bit more
                // vertical room. The old ratio was tight enough that a
                // 2-line label (e.g. "Assigned Dispatch") plus the icon
                // and value could exceed the cell's fixed height and
                // trigger a bottom overflow, especially with larger
                // system font scales.
                childAspectRatio: 1.05,
                children: [
                  _dashboardCard(
                    label: 'Assigned Dispatch',
                    value: '${assigned.length}',
                    icon: Icons.assignment_turned_in_outlined,
                    color: AppColors.primary,
                    onTap: assigned.isEmpty
                        ? null
                        : () => _showDispatchDetails(context, assigned.first),
                  ),
                  _dashboardCard(
                    label: 'Emergency PCR',
                    value: 'No Schedule',
                    icon: Icons.document_scanner_outlined,
                    color: AppColors.secondary,
                    onTap: () => _openEmergencyPcr(context),
                  ),
                  _dashboardCard(
                    label: 'Notifications',
                    value: assigned.isEmpty ? 'Clear' : '${assigned.length} new',
                    icon: Icons.notifications_active_outlined,
                    color: AppColors.warning,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _livePulse(),
                const SizedBox(width: 10),
                const Text(
                  'Live Dispatch',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (assigned.isEmpty)
              const GlassCard(
                radius: 16,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(
                    child: Text(
                      'No assigned dispatch yet.',
                      style: TextStyle(color: AppColors.textGray),
                    ),
                  ),
                ),
              )
            else
              ...assigned.map((doc) => _dispatchCard(context, doc)),
          ],
        );
      },
    );
  }

  Widget _dashboardCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.dark.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          // mainAxisSize.min + mainAxisAlignment.spaceBetween instead of
          // an unbounded Spacer(): this way the column only ever asks for
          // as much height as its children actually need, and any leftover
          // space is distributed rather than assumed. If content is ever
          // taller than the cell (e.g. very large accessibility font
          // scale), it will visibly compress instead of throwing a
          // "BOTTOM OVERFLOWED" render error.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              // FittedBox scales the value text down instead of letting it
              // get clipped or ellipsized — matters most for longer values
              // like "No Schedule" or "12 new" in a narrow 2-column grid.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppColors.dark,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textGray,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _livePulse() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1 + (_pulseController.value * 0.85);
        final opacity = 1 - _pulseController.value;
        return SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.26),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _dispatchCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FutureBuilder<_DispatchDetails>(
      future: _loadDispatchDetails(data),
      builder: (context, snap) {
        final details = snap.data;
        final location = details?.location ?? data['pickUpLocation'] ?? '-';
        final description = details?.description ?? '-';
        final patientName = details?.patientName ?? data['patientName'] ?? 'Patient';

        return GlassCard(
          radius: 12,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _showDispatchDetails(context, doc),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data['trackingNumber'] ?? data['requestID'] ?? doc.id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textGray,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadge(data['status'] ?? 'approved'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: AppColors.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textGray),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (data['status'] != 'in-transit') ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Accept'),
                          onPressed: () => _acceptDispatch(context, doc),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.document_scanner_outlined, size: 18),
                        label: const Text('PCR'),
                        onPressed: () => _openPcr(context, doc, details),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'in-transit' => AppColors.accent,
      'completed' => AppColors.completed,
      _ => AppColors.secondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _showDispatchDetails(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) async {
    final scheduleData = doc.data() as Map<String, dynamic>;
    final details = await _loadDispatchDetails(scheduleData);
    if (!context.mounted) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          // The sheet's content is variable-length (addresses, concern
          // text, etc.) and isScrollControlled lets it grow past a single
          // screen height. Without a scroll view here, tall content or a
          // visible keyboard has nowhere to go and overflows at the
          // bottom. Capping height at 85% of the screen + wrapping in a
          // SingleChildScrollView fixes that; the sheet now scrolls
          // instead of overflowing.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          scheduleData['trackingNumber'] ??
                              details.requestData['trackingNumber'] ??
                              doc.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.dark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusBadge(scheduleData['status'] ?? 'approved'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _detailLine('Patient', details.patientName),
                  _detailLine('Concern', details.description),
                  _detailLine('Hospital', details.destinationHospital),
                  _detailActionLine(
                    icon: Icons.phone_outlined,
                    label: 'Contact',
                    value: details.contactNumber,
                    onTap: details.contactNumber == '-'
                        ? null
                        : () => _callNumber(details.contactNumber),
                  ),
                  _detailActionLine(
                    icon: Icons.location_on_outlined,
                    label: 'Pickup',
                    value: details.location,
                    onTap: details.location == '-'
                        ? null
                        : () => _openMap(details.location),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (scheduleData['status'] != 'in-transit') ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Accept Dispatch'),
                            onPressed: () {
                              Navigator.pop(context);
                              _acceptDispatch(context, doc);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: const Text('Scan PCR'),
                          onPressed: () {
                            Navigator.pop(context);
                            _openPcr(context, doc, details);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textGray,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.dark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailActionLine({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textGray,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.dark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  Future<_DispatchDetails> _loadDispatchDetails(
    Map<String, dynamic> scheduleData,
  ) async {
    final requestID = scheduleData['requestID']?.toString();
    Map<String, dynamic> requestData = {};
    Map<String, dynamic> patientData = {};

    if (requestID != null && requestID.isNotEmpty) {
      final requestDoc = await FirebaseFirestore.instance
          .collection('transport_requests')
          .doc(requestID)
          .get();
      requestData = requestDoc.data() ?? {};

      final patientID = requestData['patientID']?.toString();
      if (patientID != null && patientID.isNotEmpty) {
        final patientDoc = await FirebaseFirestore.instance
            .collection('patients')
            .doc(patientID)
            .get();
        patientData = patientDoc.data() ?? {};
      }
    }

    return _DispatchDetails(
      requestData: requestData,
      location:
          requestData['location'] ?? scheduleData['pickUpLocation'] ?? '-',
      description:
          requestData['description'] ?? scheduleData['description'] ?? '-',
      destinationHospital:
          requestData['destinationHospital'] ??
          scheduleData['destinationHospital'] ??
          '-',
      patientName:
          scheduleData['patientName'] ??
          patientData['patientName'] ??
          patientData['patientname'] ??
          requestData['patientName'] ??
          'Patient',
      contactNumber:
          patientData['contactNumber'] ?? requestData['contactNumber'] ?? '-',
    );
  }

  Future<void> _acceptDispatch(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) async {
    final data = doc.data() as Map<String, dynamic>;
    final requestID = data['requestID']?.toString();

    // Make sure the schedule doc itself carries a 'patientName' field so
    // every screen that reads transport_schedules can show the patient's
    // name directly, without needing to join back to patients/requests.
    String? patientName = data['patientName']?.toString();
    if ((patientName == null || patientName.isEmpty) &&
        requestID != null &&
        requestID.isNotEmpty) {
      final details = await _loadDispatchDetails(data);
      patientName = details.patientName;
    }

    final batch = FirebaseFirestore.instance.batch();
    batch.update(doc.reference, {
      'status': 'in-transit',
      if (patientName != null && patientName.isNotEmpty)
        'patientName': patientName,
    });
    if (requestID != null && requestID.isNotEmpty) {
      batch.update(
        FirebaseFirestore.instance
            .collection('transport_requests')
            .doc(requestID),
        {'status': 'in-transit'},
      );
    }
    await batch.commit();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dispatch accepted.')),
    );
  }

  /// Emergency/walk-in na PCR — WALANG kinalaman sa mga naka-assign na
  /// schedule. Diretso agad papunta sa `PCRStandaloneFormScreen`, kung
  /// saan required na piliin ng responder ang Patient Name at Ambulance.
  void _openEmergencyPcr(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PCRStandaloneFormScreen()),
    );
  }

  void _openPcr(
    BuildContext context,
    QueryDocumentSnapshot doc,
    _DispatchDetails? details,
  ) {
    final scheduleData = doc.data() as Map<String, dynamic>;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PCRFormScreen(
          scheduleID: doc.id,
          scheduleData: scheduleData,
          requestData: {
            ...?details?.requestData,
            'requestID':
                scheduleData['requestID'] ?? details?.requestData['requestID'],
            'patientName': details?.patientName,
          },
        ),
      ),
    );
  }

  Future<void> _callNumber(String number) async {
    await _nativeActions.invokeMethod<void>('dial', {'number': number});
  }

  void _openMap(String address) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppMapScreen(destinationAddress: address),
      ),
    );
  }

  int _sortSchedules(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
    final aData = a.data() as Map<String, dynamic>;
    final bData = b.data() as Map<String, dynamic>;
    final aDate = _scheduleMillis(aData);
    final bDate = _scheduleMillis(bData);
    return aDate.compareTo(bDate);
  }

  int _scheduleMillis(Map<String, dynamic> data) {
    final value = data['scheduleDate'];
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}

class _DispatchDetails {
  final Map<String, dynamic> requestData;
  final String location;
  final String description;
  final String destinationHospital;
  final String patientName;
  final String contactNumber;

  const _DispatchDetails({
    required this.requestData,
    required this.location,
    required this.description,
    required this.destinationHospital,
    required this.patientName,
    required this.contactNumber,
  });
}