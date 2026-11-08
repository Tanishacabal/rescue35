import 'package:flutter/material.dart';

import '../services/app_language.dart';

Future<bool> showLogoutConfirmationDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(translate(context, 'Log out?')),
      content: Text(translate(context, 'Are you sure you want to log out?')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(translate(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(translate(context, 'Log Out')),
        ),
      ],
    ),
  );
  return confirmed == true;
}
