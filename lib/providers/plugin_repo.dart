// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io';

import 'package:every_door/helpers/plugin_code.dart';
import 'package:every_door/models/plugin.dart';
import 'package:every_door/plugins/_construction.dart';
import 'package:every_door/providers/plugin_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';
import 'package:every_door/helpers/yaml_map.dart';

final pluginRepositoryProvider =
    NotifierProvider<PluginRepository, List<Plugin>>(PluginRepository.new);

class PluginRepository extends Notifier<List<Plugin>> {
  static final _logger = Logger('PluginRepository');
  static const _kInstallMetadataFile = '.everydoor-install.json';
  late final Directory _pluginsDirectory;

  @override
  List<Plugin> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final docDir = await getApplicationDocumentsDirectory();
    _pluginsDirectory = Directory("${docDir.path}/plugins");

    // Create plugins dir if not exists.
    await _pluginsDirectory.create(recursive: true);

    // Read plugins list.
    final plugins = <Plugin>[];
    await for (final entry in _pluginsDirectory.list()) {
      if (entry is Directory) {
        try {
          final metadata = await readPluginData(entry);
          plugins.add(Plugin.fromData(metadata, entry,
              instanceBuilder: PluginCode.instantiatePlugin));
        } on PluginLoadException catch (e) {
          _logger.severe('Failed to load plugin metadata', e);
        }
      }
    }

    state = plugins;

    _installFromAssets();
    _installConstruction();
  }

  Future<void> deletePlugin(String id) async {
    final plugin = state.where((p) => p.id == id).firstOrNull;
    if (plugin == null) return;

    ref.read(pluginManagerProvider.notifier).setStateAndSave(plugin, false);
    state = state.where((p) => p.id != id).toList();
    final pluginDir = _getPluginDirectory(id);
    if (await pluginDir.exists()) {
      await pluginDir.delete(recursive: true);
    }
  }

  Future<void> _installFromAssets() async {
    ByteData pluginFile;
    try {
      pluginFile = await rootBundle.load('assets/plugin.edp');
    } on FlutterError {
      // No plugin packaged.
      return;
    }

    final tmpDir = await getTemporaryDirectory();
    final File tmpPath = File('${tmpDir.path}/bundled_plugin.zip');
    await tmpPath.writeAsBytes(pluginFile.buffer.asUint8List(), flush: true);

    try {
      await install(tmpPath);
    } on PluginLoadException catch (e) {
      _logger.warning('Failed to install a bundled plugin', e);
    } finally {
      try {
        await tmpPath.delete();
      } on Exception {
        // it's fine if we leave it.
      }
    }
  }

  Future<void> _installConstruction() async {
    if (!PluginUnderConstruction.kEnabled) return;
    // So that the state is initialized.
    await Future.delayed(Duration(milliseconds: 500));

    final data = PluginUnderConstruction.getMetadata();
    final pluginDir = _getPluginDirectory(data['id']);
    final plugin = Plugin(
      id: data['id'],
      data: data,
      directory: pluginDir,
      instanceBuilder: (_) async => PluginUnderConstruction(),
    );

    await deletePlugin(data['id']);
    state = state.followedBy([plugin]).toList();

    await ref
        .read(pluginManagerProvider.notifier)
        .setStateAndSave(plugin, true);
  }

  Directory _getPluginDirectory(String id) {
    return Directory("${_pluginsDirectory.path}/$id");
  }

  Future<Map<String, dynamic>> _readInstallMetadata(Directory path) async {
    final file = File('${path.path}/$_kInstallMetadataFile');
    if (!await file.exists()) return {};

    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return {};
      final installedSource = data['installed_source'];
      if (installedSource is String && installedSource.isNotEmpty) {
        return {
          'installed_source': installedSource,
          if (data['installed_at'] is String &&
              DateTime.tryParse(data['installed_at']) != null)
            'installed_at': data['installed_at'],
          if (data['installed_archive_sha256'] is String &&
              RegExp(r'^[0-9a-f]{64}$')
                  .hasMatch(data['installed_archive_sha256']))
            'installed_archive_sha256': data['installed_archive_sha256'],
        };
      }
    } on Exception catch (e, st) {
      _logger.warning(
          'Failed to parse install metadata for plugin in ${path.path}', e, st);
    }

    return {};
  }

  Future<void> _writeInstallMetadata(Directory path,
      {Uri? installedSource, Map<String, dynamic>? installMetadata}) async {
    final file = File('${path.path}/$_kInstallMetadataFile');
    final payload = <String, dynamic>{
      if (installedSource != null)
        'installed_source': installedSource.toString(),
      if (installMetadata != null) ...installMetadata,
    };

    if (payload.isEmpty) {
      if (await file.exists()) {
        try {
          await file.delete();
        } on Exception {
          // Ignore file cleanup issues.
        }
      }
      return;
    }

    await file.writeAsString(
      jsonEncode(payload),
      flush: true,
    );
  }

  /// Reads the YAML file bundled with the plugin, and returns
  /// the plugin identifier, and the rest of the metadata.
  Future<PluginData> readPluginData(Directory path) async {
    // Read the metadata.
    final metadataFile = File("${path.path}/plugin.yaml");
    if (!await metadataFile.exists()) {
      throw PluginLoadException("No ${path.path}/plugin.yaml found");
    }

    // Parse the metadata.yaml file.
    final metadataContents = await metadataFile.readAsString();
    final yamlData = loadYamlNode(metadataContents);
    if (yamlData is! YamlMap) {
      throw PluginLoadException('Metadata should contain a map.');
    }
    final Map<String, dynamic> metadata = yamlData.toMap();
    metadata.addAll(await _readInstallMetadata(path));
    if (!metadata.containsKey('installed_at')) {
      try {
        metadata['installed_at'] =
            (await metadataFile.stat()).modified.toUtc().toIso8601String();
      } on Exception {
        // No fallback timestamp.
      }
    }

    // Check for required fields.
    final String? pluginId = metadata['id'];
    if (pluginId == null) {
      throw PluginLoadException("Missing plugin id in metadata");
    }

    // Validate the plugin id.
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]+$').hasMatch(pluginId)) {
      throw PluginLoadException("Plugin id \"$pluginId\" has bad characters.");
    }

    return PluginData(pluginId, metadata);
  }

  /// Unpacks the provided archive at [file] into a temporary directory,
  /// and returns the directory. The caller is responsible for deleting
  /// the directory afterwards. Calling [installFromTmpDir] also works.
  /// The installation process is split in two parts, so that you could
  /// call [readPluginData] in between and decide whether you want to continue.
  ///
  /// May throw [PluginLoadException] when file operations go wrong.
  Future<Directory> unpackAndDelete(File file) async {
    if (!await file.exists()) {
      throw PluginLoadException("File is missing: ${file.path}");
    }

    // Unpack the file.
    final tmpDir = await getTemporaryDirectory();
    final tmpPluginDir = await tmpDir.createTemp("plugin");
    try {
      await ZipFile.extractToDirectory(
        zipFile: file,
        destinationDir: tmpPluginDir,
      );
    } on PlatformException catch (e) {
      tmpPluginDir.delete(recursive: true);
      throw PluginLoadException("Failed to unpack ${file.path}", e);
    }

    // Delete the temporary file if possible.
    if (await file.exists()) {
      try {
        await file.delete();
      } on FileSystemException {
        // Does not matter.
      }
    }

    return tmpPluginDir;
  }

  /// Installs the plugin from the temporary directory. Removes
  /// the directory after either error or success. Will throw
  /// exceptions when either file operations fail, or plugin
  /// cannot be enabled because of internal errors.
  Future<Plugin> installFromTmpDir(Directory tmpPluginDir,
      {Uri? installedSource, Map<String, dynamic>? installMetadata}) async {
    try {
      // Read the metadata.
      final tmpPlugin = await readPluginData(tmpPluginDir);

      // If this plugin was installed, remove it.
      await deletePlugin(tmpPlugin.id);

      // Create the plugin directory and move files there.
      final pluginDir = _getPluginDirectory(tmpPlugin.id);
      await tmpPluginDir.rename(pluginDir.path);
      await _writeInstallMetadata(pluginDir,
          installedSource: installedSource, installMetadata: installMetadata);

      final data = await readPluginData(pluginDir);
      final plugin = Plugin.fromData(data, pluginDir,
          instanceBuilder: PluginCode.instantiatePlugin);

      // Add the plugin record to the list.
      state = state.followedBy([plugin]).toList();

      await ref
          .read(pluginManagerProvider.notifier)
          .setStateAndSave(plugin, true);

      return plugin;
    } finally {
      // delete the directory and exit
      try {
        await tmpPluginDir.delete(recursive: true);
      } on Exception {
        // Oh well, let the trash rest there.
      }
    }
  }

  /// Unpacks the file and installs a plugin from it.
  Future<void> install(File file,
      {Uri? installedSource, Map<String, dynamic>? installMetadata}) async {
    final tmpPluginDir = await unpackAndDelete(file);
    await installFromTmpDir(tmpPluginDir,
        installedSource: installedSource, installMetadata: installMetadata);
  }
}
