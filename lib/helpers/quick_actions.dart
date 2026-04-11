// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:every_door/fields/helpers/qr_code.dart';
import 'package:every_door/generated/l10n/app_localizations.dart'
    show AppLocalizations;
import 'package:every_door/providers/edpr.dart';
import 'package:every_door/screens/settings/install_plugin.dart';
import 'package:every_door/screens/settings/log.dart';
import 'package:every_door/screens/settings/plugin_repo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> openSystemLog(BuildContext context) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => LogDisplayPage()),
  );
}

Future<void> installPluginFromQrCode(BuildContext context) async {
  final loc = AppLocalizations.of(context)!;
  final nav = Navigator.of(context);

  Uri? detected;
  if (QrCodeScanner.kEnabled) {
    detected = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QrCodeScanner(resolveRedirects: false),
      ),
    );
  } else {
    final List<String>? answer = await showTextInputDialog(
      context: context,
      title: loc.pluginsUrl,
      textFields: [
        DialogTextField(
          keyboardType: TextInputType.url,
          autocorrect: false,
        )
      ],
    );
    if (answer != null && answer.isNotEmpty && answer.first.isNotEmpty) {
      detected = Uri.tryParse(answer.first);
    }
  }

  if (detected != null && nav.mounted) {
    nav.push(
      MaterialPageRoute(builder: (_) => InstallPluginPage(detected!)),
    );
  }
}

Future<void> checkPluginUpdates(BuildContext context) async {
  ProviderScope.containerOf(context).invalidate(edprProvider);
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PluginRepositoryPage(updatesOnly: true),
    ),
  );
}
