import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Text;

import '../../constants/app_colors.dart';
import '../../services/app_language.dart';
import '../../widgets/localized_text.dart' show Text;

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view notifications.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: Text(translate(context, 'Notifications')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: const [AppLanguageSwitcher()],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _NotificationState(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load your account',
              message: 'Please check your connection and try again.',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final isResponder = snapshot.data?.data()?['role'] == 'responder';
          final requests = isResponder
              ? FirebaseFirestore.instance
                    .collection('transport_requests')
                    .where('status', isEqualTo: 'pending')
              : FirebaseFirestore.instance
                    .collection('transport_requests')
                    .where('userID', isEqualTo: user.uid);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: requests.snapshots(),
            builder: (context, requestSnapshot) {
              if (requestSnapshot.hasError) {
                return _NotificationState(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to load request alerts',
                  message: 'Firestore error: ${requestSnapshot.error}',
                );
              }
              if (requestSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('notifications')
                    .orderBy('createdAt', descending: true)
                    .limit(100)
                    .snapshots(),
                builder: (context, notificationSnapshot) {
                  final entries = <_AlertEntry>[];
                  final notifiedRequestIds = <String>{};

                  for (final notification
                      in notificationSnapshot.data?.docs ?? []) {
                    final data = notification.data();
                    final requestId = data['requestId']?.toString();
                    if (requestId != null) notifiedRequestIds.add(requestId);
                    entries.add(
                      _AlertEntry(
                        title: (data['title'] ?? 'RESCUE 35 update').toString(),
                        body: (data['body'] ?? '').toString(),
                        date: _asDate(data['createdAt']),
                        isRead: data['isRead'] == true,
                        reference: notification.reference,
                      ),
                    );
                  }

                  for (final request in requestSnapshot.data?.docs ?? []) {
                    if (notifiedRequestIds.contains(request.id)) continue;
                    final data = request.data();
                    final trackingNumber =
                        (data['trackingNumber'] ?? request.id).toString();
                    final status = _displayStatus(data['status']?.toString());
                    entries.add(
                      _AlertEntry(
                        title: isResponder
                              ? translate(context, 'New transport request')
                              : '${translate(context, 'Request')} $status',
                        body: isResponder
                            ? '${translate(context, 'Request')} $trackingNumber ${translate(context, 'is waiting for a responder.')}'
                            : '${translate(context, 'Your transport request')} $trackingNumber ${translate(context, 'is')} $status.',
                        date: _asDate(data['requestDate']),
                        isRead: true,
                      ),
                    );
                  }

                  entries.sort((a, b) {
                    return (b.date?.millisecondsSinceEpoch ?? 0).compareTo(
                      a.date?.millisecondsSinceEpoch ?? 0,
                    );
                  });

                  final notificationError = notificationSnapshot.hasError;
                  if (entries.isEmpty && !notificationError) {
                    return const _NotificationState(
                      icon: Icons.notifications_none_rounded,
                      title: "You're all caught up",
                      message: 'Updates about requests will appear here.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: entries.length + (notificationError ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (notificationError && index == 0) {
                        return const _NotificationWarning(
                          message:
                              'Notification history is unavailable. Showing '
                              'current request alerts instead.',
                        );
                      }

                      final entry =
                          entries[index - (notificationError ? 1 : 0)];
                      return _AlertCard(
                        entry: entry,
                        dateText: entry.date == null
                            ? null
                            : _formatDate(entry.date!),
                        onTap: entry.reference == null
                            ? null
                            : () => _markRead(context, entry.reference!),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _displayStatus(String? status) {
    if (status == null || status.isEmpty) return 'updated';
    return status
        .replaceAll('-', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  Future<void> _markRead(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    try {
      await reference.update({'isRead': true});
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to mark notification as read: ${error.message ?? error.code}',
          ),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day/${local.year} • $hour:$minute $period';
  }
}

class _AlertEntry {
  const _AlertEntry({
    required this.title,
    required this.body,
    required this.date,
    required this.isRead,
    this.reference,
  });

  final String title;
  final String body;
  final DateTime? date;
  final bool isRead;
  final DocumentReference<Map<String, dynamic>>? reference;
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.entry, required this.dateText, this.onTap});

  final _AlertEntry entry;
  final String? dateText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: entry.isRead ? Colors.white : const Color(0xFFF0F5FF),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            style: const TextStyle(
                              color: AppColors.dark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!entry.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      entry.body,
                      style: const TextStyle(
                        color: AppColors.textGray,
                        height: 1.35,
                      ),
                    ),
                    if (dateText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        dateText!,
                        style: const TextStyle(
                          color: AppColors.textGray,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationWarning extends StatelessWidget {
  const _NotificationWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pending.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.dark, fontSize: 12),
      ),
    );
  }
}

class _NotificationState extends StatelessWidget {
  const _NotificationState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 48),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.dark,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textGray),
            ),
          ],
        ),
      ),
    );
  }
}
