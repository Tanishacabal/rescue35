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
  int _selectedIndex = 0;

  static const _navItems = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Dispatch'),
    _NavItem(icon: Icons.qr_code_scanner_outlined, activeIcon: Icons.qr_code_scanner_rounded, label: 'PCR'),
    _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  void _goToTab(int index) => setState(() => _selectedIndex = index);

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
    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.08),
              Colors.white,
            ],
          ),
        ),
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _DispatchTab(
              pulseController: _pulseController,
              showDispatchDetails: _showDispatchDetails,
              acceptDispatch: _acceptDispatch,
            ),
            _PcrTab(
              openEmergencyPcr: _openEmergencyPcr,
            ),
            const ProfileScreen(role: 'responder'),
          ],
        ),
      ),
      bottomNavigationBar: _FloatingNavBar(
        items: _navItems,
        selectedIndex: _selectedIndex,
        onTap: _goToTab,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // =====================================================
  // ALL FUNCTIONS
  // =====================================================
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
      location: requestData['location'] ?? scheduleData['pickUpLocation'] ?? '-',
      description: requestData['description'] ?? scheduleData['description'] ?? '-',
      destinationHospital: requestData['destinationHospital'] ??
          scheduleData['destinationHospital'] ??
          '-',
      patientName: scheduleData['patientName'] ??
          patientData['patientName'] ??
          patientData['patientname'] ??
          requestData['patientName'] ??
          'Patient',
      contactNumber: patientData['contactNumber'] ?? requestData['contactNumber'] ?? '-',
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
                      _StatusBadge(status: scheduleData['status'] ?? 'approved'),
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
                  // ✅ WALANG ACCEPT BUTTON — PCR BUTTON NA LANG
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: const Text('Open PCR Form'),
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

  Future<void> _acceptDispatch(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) async {
    final scheduleData = doc.data() as Map<String, dynamic>;
    final requestID = scheduleData['requestID']?.toString();
    String? patientName = scheduleData['patientName']?.toString();

    if ((patientName == null || patientName.isEmpty) &&
        requestID != null &&
        requestID.isNotEmpty) {
      final details = await _loadDispatchDetails(scheduleData);
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
        FirebaseFirestore.instance.collection('transport_requests').doc(requestID),
        {'status': 'in-transit'},
      );
    }

    await batch.commit();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('En Route — Dispatch accepted.')),
    );
  }

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
            'requestID': scheduleData['requestID'] ?? details?.requestData['requestID'],
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

}

// =====================================================
// HELPER CLASSES & WIDGETS
// =====================================================

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

class _NavItem {
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    // ✅ "En Route" at "Assigned" na ang display text
    final displayText = switch (status) {
      'in-transit' => 'En Route',
      'approved' => 'Assigned',
      'pending' => 'Pending',
      'completed' => 'Completed',
      _ => status,
    };

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
        displayText,
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
}

// =====================================================
// TAB 1: DISPATCH
// =====================================================

class _DispatchTab extends StatelessWidget {
  const _DispatchTab({
    required this.pulseController,
    required this.showDispatchDetails,
    required this.acceptDispatch,
  });
  final AnimationController pulseController;
  final Future<void> Function(BuildContext, QueryDocumentSnapshot) showDispatchDetails;
  final Future<void> Function(BuildContext, QueryDocumentSnapshot) acceptDispatch;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data() as Map<String, dynamic>?;
        final name = userData?['name'] ?? 'Responder';
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            _Header(name: name),
            const SizedBox(height: 20),
            _DispatchBody(
              uid: uid,
              pulseController: pulseController,
              showDispatchDetails: showDispatchDetails,
              acceptDispatch: acceptDispatch,
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const RescueLogo(size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Responder Dashboard',
                  style: TextStyle(
                    color: AppColors.textGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dark,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.10),
              foregroundColor: AppColors.primary,
            ),
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _DispatchBody extends StatelessWidget {
  const _DispatchBody({
    required this.uid,
    required this.pulseController,
    required this.showDispatchDetails,
    required this.acceptDispatch,
  });
  final String uid;
  final AnimationController pulseController;
  final Future<void> Function(BuildContext, QueryDocumentSnapshot) showDispatchDetails;
  final Future<void> Function(BuildContext, QueryDocumentSnapshot) acceptDispatch;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transport_schedules')
          .where('responderIDs', arrayContains: uid)
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

        final docs = [...?snap.data?.docs]..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            int getMillis(d) {
              final v = d['scheduleDate'];
              if (v is Timestamp) {
                return v.millisecondsSinceEpoch;
              }
              if (v is DateTime) {
                return v.millisecondsSinceEpoch;
              }
              if (v is String) {
                final parsed = DateTime.tryParse(v);
                return parsed?.millisecondsSinceEpoch ?? 0;
              }
              return 0;
            }
            return getMillis(aData).compareTo(getMillis(bData));
          });

        final assigned = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] != 'completed';
        }).toList();

        bool isToday(Map<String, dynamic> data) {
          final value = data['scheduleDate'];
          DateTime? sd;
          if (value is Timestamp) {
            sd = value.toDate();
          } else if (value is DateTime) {
            sd = value;
          } else if (value is String) {
            sd = DateTime.tryParse(value);
          }
          if (sd == null) return false;
          final now = DateTime.now();
          return sd.year == now.year && sd.month == now.month && sd.day == now.day;
        }

        final todaySchedules = <QueryDocumentSnapshot>[];
        final otherSchedules = <QueryDocumentSnapshot>[];
        for (final doc in assigned) {
          final data = doc.data() as Map<String, dynamic>;
          if (isToday(data)) {
            todaySchedules.add(doc);
          } else {
            otherSchedules.add(doc);
          }
        }

        return Column(
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
                childAspectRatio: 1.05,
                children: [
                  _DashboardCard(
                    label: 'Assigned Dispatch',
                    value: '${assigned.length}',
                    icon: Icons.assignment_turned_in_outlined,
                    color: AppColors.primary,
                    onTap: assigned.isEmpty
                        ? null
                        : () async {
                            final first = assigned.first;
                            final data = first.data() as Map<String, dynamic>;
                            if (data['status'] != 'in-transit') {
                              await acceptDispatch(context, first);
                            }
                            if (context.mounted) {
                              await showDispatchDetails(context, first);
                            }
                          },
                  ),
                  _DashboardCard(
                    label: 'Emergency PCR',
                    value: 'Scan Now',
                    icon: Icons.document_scanner_outlined,
                    color: AppColors.secondary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PCRStandaloneFormScreen()),
                      );
                    },
                  ),
                  _DashboardCard(
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
                _LivePulse(controller: pulseController),
                const SizedBox(width: 10),
                const Text(
                  "Today's Schedule",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.dark),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (todaySchedules.isEmpty)
              const GlassCard(
                radius: 16,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(child: Text('No dispatch scheduled today.', style: TextStyle(color: AppColors.textGray))),
                ),
              )
            else
              ...todaySchedules.map((doc) => _DispatchCard(
                    doc: doc,
                    showDispatchDetails: showDispatchDetails,
                    acceptDispatch: acceptDispatch,
                  )),
            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.event_note_outlined, size: 20, color: AppColors.textGray),
                SizedBox(width: 10),
                Text('Other Schedules', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.dark)),
              ],
            ),
            const SizedBox(height: 12),
            if (otherSchedules.isEmpty)
              const GlassCard(
                radius: 16,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(child: Text('No other schedules.', style: TextStyle(color: AppColors.textGray))),
                ),
              )
            else
              ...otherSchedules.map((doc) => _DispatchCard(
                    doc: doc,
                    showDispatchDetails: showDispatchDetails,
                    acceptDispatch: acceptDispatch,
                  )),
          ],
        );
      },
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
            boxShadow: [BoxShadow(color: AppColors.dark.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(color: AppColors.dark, fontSize: 19, fontWeight: FontWeight.w900))),
              const SizedBox(height: 2),
              Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textGray, fontSize: 11.5, fontWeight: FontWeight.w800))),
            ],
          ),
        ),
      ),
    );
  }
}

class _LivePulse extends StatelessWidget {
  const _LivePulse({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1 + (controller.value * 0.85);
        final opacity = 1 - controller.value;
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
                  child: Container(width: 14, height: 14, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.26), shape: BoxShape.circle)),
                ),
              ),
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            ],
          ),
        );
      },
    );
  }
}

class _DispatchCard extends StatelessWidget {
  const _DispatchCard({
    required this.doc,
    required this.showDispatchDetails,
    required this.acceptDispatch,
  });
  final QueryDocumentSnapshot doc;
  final Future<void> Function(BuildContext, QueryDocumentSnapshot) showDispatchDetails;
  final Future<void> Function(BuildContext, QueryDocumentSnapshot) acceptDispatch;

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    return GlassCard(
      radius: 12,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        // ✅ PAG PININDOT → AUTOMATIC NA EN ROUTE AGAD!
        onTap: () async {
          if (data['status'] != 'in-transit') {
            await acceptDispatch(context, doc);
          }
          if (context.mounted) {
            await showDispatchDetails(context, doc);
          }
        },
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
                        data['patientName'] ?? 'Patient',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.dark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data['trackingNumber'] ?? data['requestID'] ?? doc.id,
                        style: const TextStyle(fontSize: 12, color: AppColors.textGray, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: data['status'] ?? 'approved'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    data['pickUpLocation'] ?? '-',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ✅ WALANG ACCEPT BUTTON — PCR BUTTON NA LANG
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.document_scanner_outlined, size: 18),
                    label: const Text('PCR / Report'),
                    onPressed: () {
                      // Punan mo na ng PCR action kung kailangan
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// TAB 2: PCR
// =====================================================

class _PcrTab extends StatelessWidget {
  const _PcrTab({required this.openEmergencyPcr});
  final void Function(BuildContext) openEmergencyPcr;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: [
        const SizedBox(height: 30),
        Center(
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.document_scanner_rounded, color: AppColors.secondary, size: 56),
              ),
              const SizedBox(height: 24),
              const Text('Patient Care Report', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.dark)),
              const SizedBox(height: 8),
              const Text('Start an emergency PCR or select from dispatch', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGray, fontSize: 13)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  label: const Text('Start Emergency PCR', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  onPressed: () => openEmergencyPcr(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =====================================================
// BOTTOM NAVIGATION BAR
// =====================================================

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.items, required this.selectedIndex, required this.onTap});
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: 70,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == selectedIndex;
            return Expanded(
              child: InkWell(
                onTap: () => onTap(index),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(selected ? item.activeIcon : item.icon, color: selected ? AppColors.primary : AppColors.textGray, size: 24),
                      const SizedBox(height: 2),
                      Text(item.label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? AppColors.primary : AppColors.textGray)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}