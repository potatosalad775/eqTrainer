import 'package:eq_trainer/shared/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.trailing
  });
  final IconData icon;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: context.colors.surfaceContainer,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          leading: FaIcon(
            icon,
            color: context.colors.onSurfaceVariant,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: context.colors.onSurfaceVariant,
            ),
          ),
          trailing: trailing,
        ),
      ),
    );
  }
}