// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'dart:io';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:every_door/fields/helpers/qr_code.dart';
import 'package:every_door/generated/l10n/app_localizations.dart'
    show AppLocalizations;
import 'package:every_door/models/plugin.dart';
import 'package:every_door/providers/edpr.dart';
import 'package:every_door/providers/plugin_repo.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:every_door/screens/settings/install_plugin.dart';
import 'package:every_door/screens/settings/log.dart';
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
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final repo = container.read(pluginRepositoryProvider.notifier);

  try {
    container.invalidate(edprProvider);
    final remoteList = await container.read(edprProvider.future);
    final remoteById = Map<String, RemotePlugin>.fromEntries(
      remoteList.map((p) => MapEntry(p.id, p)),
    );
    final installed = Map<String, Plugin>.fromEntries(
        container.read(pluginRepositoryProvider).map((p) => MapEntry(p.id, p)));

    int updated = 0;
    int checked = 0;
    final List<String> errors = [];

    for (final plugin in installed.values) {
      final remote = remoteById[plugin.id];
      Uri? sourceUrl = remote?.url;
      if (sourceUrl == null && plugin.url != null) {
        try {
          sourceUrl = PluginUriData(plugin.url!).url;
        } on ArgumentError {
          sourceUrl = null;
        } catch (_) {
          sourceUrl = null;
        }
      }
      if (sourceUrl == null) continue;

      checked += 1;
      File? archiveFile;
      try {
        final download = await _downloadPluginArchive(sourceUrl);
        archiveFile = download.file;
        final archiveSha256 = download.sha256hex;
        final bool shaDiffers = plugin.installedArchiveSha256 == null ||
            plugin.installedArchiveSha256 != archiveSha256;

        // Hash check is primary. Remote metadata is a fallback signal.
        final bool shouldInstall = shaDiffers ||
            (remote != null && _isUpdateCandidate(remote, plugin));
        if (!shouldInstall) continue;

        final pluginDir = await repo.unpackAndDelete(archiveFile);
        archiveFile = null;
        final tmpData = await repo.readPluginData(pluginDir);
        final expectedId = remote?.id ?? plugin.id;
        if (tmpData.id != expectedId && expectedId != 'my') {
          throw Exception(
              'The URL implies plugin id "$expectedId", but it actually is "${tmpData.id}"');
        }
        final bundledUrl = tmpData.url;
        if (bundledUrl != null && bundledUrl != sourceUrl) {
          throw Exception(
              'The plugin supplies URL different from $sourceUrl: $bundledUrl');
        }
        if (!(tmpData.apiVersion?.matches(kApiVersion) ?? true)) {
          throw Exception(
              'The plugin API version (${tmpData.apiVersion}) does not match the current version ($kApiVersion).');
        }

        await repo.installFromTmpDir(
          pluginDir,
          installedSource: sourceUrl,
          installMetadata: {
            'installed_at': DateTime.now().toUtc().toIso8601String(),
            'installed_archive_sha256': archiveSha256,
          },
        );
        updated += 1;
      } catch (e) {
        errors.add('${plugin.id}: $e');
      } finally {
        if (archiveFile != null && await archiveFile.exists()) {
          try {
            await archiveFile.delete();
          } on Exception {
            // Ignore temporary file cleanup failures.
          }
        }
      }
    }

    if (!context.mounted) return;
    if (errors.isNotEmpty) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
              'Updated $updated plugins, ${errors.length} failed. See logs for details.'),
        ),
      );
      return;
    }
    if (updated == 0) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(checked == 0
              ? 'No installed plugins with update URLs.'
              : 'No plugin updates available.'),
        ),
      );
      return;
    }
    messenger?.showSnackBar(
      SnackBar(content: Text('Updated $updated plugins.')),
    );
  } catch (e) {
    if (!context.mounted) return;
    messenger?.showSnackBar(
      SnackBar(content: Text('Failed to check plugin updates: $e')),
    );
  }
}

bool _isUpdateCandidate(RemotePlugin remote, Plugin installed) {
  if (remote.version.fresherThan(installed.version)) return true;
  if (remote.url != null &&
      installed.url != null &&
      remote.url.toString() != installed.url.toString()) {
    return true;
  }
  if (installed.installedAt != null &&
      remote.updated.toUtc().isAfter(installed.installedAt!.toUtc())) {
    return true;
  }
  return false;
}

Future<({File file, String sha256hex})> _downloadPluginArchive(Uri url) async {
  final tmpDir = await getTemporaryDirectory();
  final tmpPath = File(
      '${tmpDir.path}/plugin_check_${DateTime.now().microsecondsSinceEpoch}.zip');
  if (await tmpPath.exists()) await tmpPath.delete();

  final client = http.Client();
  try {
    final request = http.Request('GET', url);
    final response = await client.send(request);
    if (response.statusCode != 200) {
      throw Exception('Could not download plugin, code ${response.statusCode}');
    }
    final fileSize = ((response.contentLength ?? 0) / 1024 / 1024).round();
    if (fileSize > 100) {
      throw Exception(
          'Would not download a file bigger than 100 MB (got $fileSize MB)');
    }
    await for (final chunk in response.stream) {
      await tmpPath.writeAsBytes(chunk, mode: FileMode.append);
    }

    final archiveSha256 =
        sha256.convert(await tmpPath.readAsBytes()).toString();
    return (file: tmpPath, sha256hex: archiveSha256);
  } finally {
    client.close();
  }
}
