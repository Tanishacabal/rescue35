import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../constants/app_colors.dart';
import '../../widgets/design_system.dart';
import '../profile.dart';

class MyRequestsScreen extends StatelessWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return RescueGradientScaffold(
      child: Column(
        children: [
          const _ScreenHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transport_requests')
                  .where('userID', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _EmptyState(
                    icon: Icons.error_outline_rounded,
                    iconColor: AppColors.pending,
                    title: 'Something went wrong',
                    subtitle: 'Unable to load requests right now.\n${snap.error}',
                  );
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No requests yet',
                    subtitle: 'Your transport requests will show up here once you\nsubmit one.',
                  );
                }
                final docs = [...snap.data!.docs]
                  ..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aDate = aData['requestDate'] as Timestamp?;
                    final bDate = bData['requestDate'] as Timestamp?;
                    return (bDate?.millisecondsSinceEpoch ?? 0).compareTo(
                      aDate?.millisecondsSinceEpoch ?? 0,
                    );
                  });

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    return _RequestCard(doc: docs[i]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Requests',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.dark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Track the status of your transport requests',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textGray,
                    fontWeight: FontWeight.w600,
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
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProfileScreen(role: 'citizen'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.textGray;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGray, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Request card
// ---------------------------------------------------------------------------

/// Renders one transport request card. Patient details (name, age, sex,
/// contact number, barangay) live in a separate `patients` collection —
/// the transport_requests doc only stores a `patientID` reference — so
/// this widget fetches that patient doc once and merges it in before
/// displaying the card.
class _RequestCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _RequestCard({required this.doc});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  late Future<DocumentSnapshot<Map<String, dynamic>>?> _patientFuture;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _patientFuture = _loadPatient();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadPatient() {
    final data = widget.doc.data() as Map<String, dynamic>;
    final patientID = (data['patientID'] ?? '').toString();
    if (patientID.isEmpty) return Future.value(null);
    return FirebaseFirestore.instance
        .collection('patients')
        .doc(patientID)
        .get();
  }

  /// The database stores names as "LASTNAME, FIRSTNAME MI." for consistency.
  /// For display in the UI, convert that back into a natural
  /// "Firstname Mi. Lastname" reading order (title case).
  String _displayName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return 'Patient';

    if (!trimmed.contains(',')) {
      // Not in "LAST, FIRST MI." format — just title-case whatever is there.
      return trimmed.split(RegExp(r'\s+')).map(_titleCase).join(' ');
    }

    final parts = trimmed.split(',');
    final last = _titleCase(parts[0].trim());
    final rest = parts.length > 1 ? parts[1].trim() : '';
    final restTokens =
        rest.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    if (restTokens.isEmpty) return last;

    final lastToken = restTokens.last;
    final isMi = lastToken.replaceAll('.', '').length == 1;

    if (isMi && restTokens.length > 1) {
      final first =
          restTokens.sublist(0, restTokens.length - 1).map(_titleCase).join(' ');
      final mi = '${lastToken.replaceAll('.', '').toUpperCase()}.';
      return '$first $mi $last';
    }

    final first = restTokens.map(_titleCase).join(' ');
    return '$first $last';
  }

  String _titleCase(String word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      future: _patientFuture,
      builder: (context, patientSnap) {
        final requestData = widget.doc.data() as Map<String, dynamic>;
        final patientData = patientSnap.data?.data() ?? const {};
        final patientLoading =
            patientSnap.connectionState == ConnectionState.waiting;

        final status = (requestData['status'] ?? 'pending').toString();
        final color = _statusColor(status);

        final rawPatientName = (patientData['patientname'] ??
                requestData['patientName'] ??
                requestData['patientname'] ??
                '')
            .toString();
        final patientName = patientLoading ? 'Loading…' : _displayName(rawPatientName);

        final location = (requestData['location'] ?? '-').toString();
        final date = (requestData['requestDate'] as Timestamp?)
                ?.toDate()
                .toString()
                .substring(0, 16) ??
            '-';

        final age = (patientData['age'] ?? '').toString();
        final sex = (patientData['sex'] ?? '').toString();
        final contactNumber =
            (patientData['contactNumber'] ?? '-').toString();
        final barangay = (patientData['barangay'] ?? '-').toString();
        final hospital = (requestData['destinationHospital'] ?? '-').toString();
        final scheduleDate = requestData['scheduleDate'] as Timestamp?;
        final scheduleDateStr = scheduleDate != null
            ? scheduleDate.toDate().toString().substring(0, 10)
            : '-';
        final scheduleTime = (requestData['scheduleTime'] ?? '-').toString();
        final notes = (requestData['additionalNotes'] ?? '').toString().trim();
        final description = (requestData['description'] ?? '-').toString();

        return GlassCard(
          radius: 20,
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              // Colored top accent to make status scannable at a glance.
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.route_outlined, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patientName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.dark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                (requestData['trackingNumber'] ?? widget.doc.id).toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textGray,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusBadge(status: status, color: color),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 17, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$description\nSubmitted: $date',
                      style: const TextStyle(color: AppColors.textGray, height: 1.4, fontSize: 12.5),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Text(
                              _expanded ? 'Hide details' : 'View details',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: _expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.primary, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 220),
                      crossFadeState:
                          _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                      firstChild: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 22),
                          _DetailRow(
                            icon: Icons.badge_outlined,
                            label: 'Patient',
                            value: [
                              age.isEmpty ? null : '$age yrs old',
                              sex.isEmpty ? null : sex,
                            ].whereType<String>().join(' · '),
                          ),
                          _DetailRow(
                            icon: Icons.phone_outlined,
                            label: 'Contact',
                            value: contactNumber,
                          ),
                          _DetailRow(
                            icon: Icons.map_outlined,
                            label: 'Barangay',
                            value: barangay,
                          ),
                          _DetailRow(
                            icon: Icons.local_hospital_outlined,
                            label: 'Destination',
                            value: hospital,
                          ),
                          _DetailRow(
                            icon: Icons.event_outlined,
                            label: 'Schedule',
                            value: '$scheduleDateStr · $scheduleTime',
                          ),
                          if (notes.isNotEmpty)
                            _DetailRow(
                              icon: Icons.note_alt_outlined,
                              label: 'Notes',
                              value: notes,
                              isLast: true,
                            ),
                        ],
                      ),
                      secondChild: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Color _statusColor(String status) => switch (status) {
        'approved' => AppColors.secondary,
        'in-transit' => AppColors.accent,
        'completed' => AppColors.completed,
        _ => AppColors.pending,
      };
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.secondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textGray,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}