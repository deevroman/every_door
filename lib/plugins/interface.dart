// Copyright 2022-2025 Ilya Zverev
// This file is a part of Every Door, distributed under GPL v3 or later version.
// Refer to LICENSE file and https://www.gnu.org/licenses/gpl-3.0.html for details.
import 'dart:io' show Directory, File;
import 'dart:convert' show json, utf8;

import 'package:eval_annotation/eval_annotation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:every_door/helpers/auth/controller.dart';
import 'package:every_door/helpers/auth/provider.dart';
import 'package:every_door/models/field.dart';
import 'package:every_door/models/imagery.dart';
import 'package:every_door/models/plugin.dart';
import 'package:every_door/plugins/events.dart';
import 'package:every_door/plugins/ext_overlay.dart';
import 'package:every_door/plugins/preferences.dart';
import 'package:every_door/plugins/providers.dart';
import 'package:every_door/providers/add_presets.dart';
import 'package:every_door/providers/editor_buttons.dart';
import 'package:every_door/providers/editor_mode.dart';
import 'package:every_door/providers/auth.dart';
import 'package:every_door/providers/overlays.dart';
import 'package:every_door/screens/modes/definitions/base.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';

/// This class is used by plugins to interact with the app.
/// It might be rebuilt often, and contains references to Riverpod
/// ref and BuildContext (if applicable). And also a ton of convenience
/// methods.
@Bind()
class EveryDoorApp {
  static final _imagePicker = ImagePicker();

  final Ref _ref;
  final Function()? _onRepaint;

  final Plugin plugin;
  final PluginPreferences preferences;
  final PluginProviders providers;
  final PluginEvents events;
  final Logger logger;

  EveryDoorApp({required this.plugin, required Ref ref, Function()? onRepaint})
      : _ref = ref,
        _onRepaint = onRepaint,
        preferences = PluginPreferences(plugin.id, ref),
        providers = PluginProviders(ref),
        events = PluginEvents(plugin.id, ref),
        logger = Logger("Plugin/${plugin.id}");

  // Future<Database> get database => _ref.read(pluginDatabaseProvider).database;

  /// When available, initiates the screen repaint. Useful for updating the
  /// plugin settings screen.
  void repaint() => _onRepaint?.call();

  /// Get the bundled in [Ref] object. Is not available to plugins, which we
  /// are trying to shield from Riverpod (which MAY be a bad idea though).
  Ref get ref => _ref;

  /// Adds an overlay layer. You only need to specify the [Imagery.id]
  /// and [Imagery.buildLayer], but also set the [Imagery.overlay] to true.
  /// For plugins, it would make sense to either use the metadata static file,
  /// or to instantiate [ExtOverlay].
  ///
  /// Unlike the specific mode-bound overlays, those appear everywhere, even
  /// in map-opening fields. If you want to add an overlay just to the main
  /// map, see [PluginEvents.onModeCreated] and [BaseModeDefinition.addOverlay].
  void addOverlay(Imagery imagery) {
    if (!imagery.overlay) {
      throw ArgumentError("Imagery should be an overlay");
    }
    _ref
        .read(overlayImageryProvider.notifier)
        .addLayer(imagery.id, imagery, pluginId: plugin.id);
  }

  /// Adds an editor mode. Cannot replace existing ones, use [removeMode]
  /// for that.
  void addMode(BaseModeDefinition mode) {
    try {
      _ref.read(editorModeProvider.notifier).register(mode);
    } on ArgumentError {
      logger.severe("Failed to add mode ${mode.name}");
    }
  }

  /// Removes the mode. Can remove both a pre-defined mode (like "notes"),
  /// and a plugin-added one.
  void removeMode(String name) {
    _ref.read(editorModeProvider.notifier).unregister(name);
  }

  /// Do something with every mode installed. Useful for dynamically adding
  /// and removing buttons and layers, for example.
  void eachMode(Function(BaseModeDefinition) callback) {
    _ref.read(editorModeProvider.notifier).modes().forEach(callback);
  }

  /// Adds an authentication provider. It is not currently possible
  /// to override an [AuthController]. It is also not possible to
  /// replace the generic providers such as "osm", or use providers
  /// defined in other plugins (because of the mandatory prefix).
  void addAuthProvider(String name, AuthProvider provider) {
    if (provider.title == null) {
      throw ArgumentError("Title is required for a provider");
    }
    _ref
        .read(authProvider.notifier)
        .update(AuthController('${plugin.id}#$name', provider));
  }

  /// Returns a controller for an authentication provider. Use "osm"
  /// to get OSM request headers.
  AuthController auth(String name) =>
      _ref.read(authProvider)['${plugin.id}#$name'] ??
      _ref.read(authProvider)[name]!;

  /// Adds a handler for a new (or existing) field type.
  /// Use [PresetFieldContext] constructor to get commonly used
  /// values from the data.
  void registerFieldType(String fieldType, FieldBuilder builder) {
    _ref
        .read(pluginPresetsProvider)
        .registerFieldType(fieldType, plugin, builder);
  }

  /// Adds a field for an identifier, that is not described as a structure.
  /// That means, it has a key, a label, and everything else already baked-in.
  void registerField(String fieldId, PresetField field) {
    _ref
        .read(pluginPresetsProvider)
        .registerPresetField(fieldId, plugin, field);
  }

  /// Adds a button to the editor pane. Buttons modify some [OsmChange]
  /// object property that is not intuitive to modify with a field.
  void addEditorButton(EditorButton button) {
    _ref.read(editorButtonsProvider.notifier).add(plugin.id, button);
  }

  /// Opens gallery picker on the host side and returns selected file path.
  /// This is eval-safe and avoids direct MethodChannel usage in plugins.
  Future<String> pickImageFromGallery() async {
    const String fn = 'pickImageFromGallery';
    void info(String message) {
      final line = '[$fn] $message';
      logger.info(line);
      print(line);
    }

    void warn(String message) {
      final line = '[$fn] $message';
      logger.warning(line);
      print(line);
    }

    try {
      info('opening file picker');
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>[
          'jpg',
          'jpeg',
          'heic',
          'heif',
        ],
        allowMultiple: false,
        withData: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final PlatformFile file = result.files.first;
        final String? path = file.path;
        if (path != null && path.isNotEmpty) {
          info('file picker path: $path');
          final f = File(path);
          if (await f.exists()) {
            info('file path exists');
            return path;
          }
        }
      } else {
        info('file picker cancelled by user');
        return "";
      }
    } catch (error) {
      warn('file picker error: $error');
    }

    info('fallback to gallery picker');
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: true,
    );
    if (picked == null) {
      info('picker cancelled by user');
      return "";
    }

    final String originalPath = picked.path;
    info('picker returned path: $originalPath');
    if (originalPath.isNotEmpty) {
      final file = File(originalPath);
      if (await file.exists()) {
        info('path exists, using original file');
        return originalPath;
      }
    }

    final String tempPath =
        '${Directory.systemTemp.path}/every_door_pick_${DateTime.now().microsecondsSinceEpoch}.jpg';
    try {
      await picked.saveTo(tempPath);
      info('copied picked file to: $tempPath');
      return tempPath;
    } catch (error) {
      warn('failed to copy file, using original path: $error');
      return originalPath;
    }
  }

  /// Sends a multipart request through host runtime to avoid dart_eval
  /// limitations around binary multipart assembly.
  /// [headers] and [fields] are string maps.
  /// Return value is a JSON envelope:
  /// {"statusCode": int, "body": String}
  Future<String> uploadMultipartRequest(
    String endpoint,
    String filePath,
    String uploadPath,
    Map<String, String> headers,
    Map<String, String> fields,
  ) async {
    const String fn = 'uploadMultipartRequest';
    void info(String message) {
      final line = '[$fn] $message';
      logger.info(line);
      print(line);
    }

    void warn(String message) {
      final line = '[$fn] $message';
      logger.warning(line);
      print(line);
    }

    try {
      if (uploadPath.isEmpty) {
        warn('upload path is empty');
        return '{"statusCode":0,"body":""}';
      }

      const String resolvedFileField = 'file';
      final String normalizedPath = filePath.replaceAll('\\', '/');
      final List<String> pathParts = normalizedPath.split('/');
      final String resolvedFileName =
          pathParts.isEmpty || pathParts.last.trim().isEmpty
              ? 'upload.jpg'
              : pathParts.last.trim();

      final Uri uploadUri = Uri.https(endpoint, uploadPath);
      info('upload uri: $uploadUri');
      final request = http.MultipartRequest('POST', uploadUri);
      request.headers.addAll(headers);
      request.fields.addAll(fields);
      info('upload headers: ${request.headers}');
      info('upload fields: ${request.fields}');
      request.files.add(
        await http.MultipartFile.fromPath(
          resolvedFileField,
          filePath,
          filename: resolvedFileName,
        ),
      );

      final streamed = await request.send();
      final http.Response uploadResp = await http.Response.fromStream(streamed);
      final String bodyText = utf8.decode(uploadResp.bodyBytes);
      final String envelope = json.encode(<String, dynamic>{
        'statusCode': uploadResp.statusCode,
        'body': bodyText,
      });

      if (uploadResp.statusCode < 200 || uploadResp.statusCode >= 300) {
        warn('upload file failed: ${uploadResp.statusCode}; body=$bodyText');
        return envelope;
      }

      info('file upload done');
      return envelope;
    } catch (error, stackTrace) {
      warn('upload exception: $error');
      warn('$stackTrace');
      return '{"statusCode":0,"body":""}';
    }
  }
}
