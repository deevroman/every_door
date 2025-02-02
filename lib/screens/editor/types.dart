import 'package:every_door/constants.dart';
import 'package:every_door/helpers/counter.dart';
import 'package:every_door/helpers/equirectangular.dart';
import 'package:every_door/helpers/good_tags.dart';
import 'package:every_door/providers/editor_mode.dart';
import 'package:every_door/providers/last_presets.dart';
import 'package:every_door/providers/osm_data.dart';
import 'package:every_door/providers/presets.dart';
import 'package:every_door/screens/editor.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:every_door/models/preset.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TypeChooserPage extends ConsumerStatefulWidget {
  final LatLng? location;
  final bool launchEditor;

  const TypeChooserPage({this.location, this.launchEditor = true});

  @override
  ConsumerState createState() => _TypeChooserPageState();
}

class _TypeChooserPageState extends ConsumerState<TypeChooserPage> {
  List<Preset> presets = const [];
  DateTime resultsUpdated = DateTime.now();
  final controller = TextEditingController();
  int updateMutex = 0;

  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      updatePresets('');
    });
  }

  Future<List<Preset>> _getPresetsAround(LatLng location,
      [int count = 3]) async {
    final locale = Localizations.localeOf(context);
    final editorMode = ref.read(editorModeProvider);
    var data = await ref
        .read(osmDataProvider)
        .getElements(location, kVisibilityRadius);
    data = data.where((e) {
      switch (e.kind) {
        case ElementKind.amenity:
          return editorMode == EditorMode.poi;
        case ElementKind.micro:
          return editorMode == EditorMode.micromapping;
        default:
          return false;
      }
    }).toList();
    if (data.isEmpty) return const [];

    // Sort by distance and trim.
    const distance = DistanceEquirectangular();
    data = data
        .where((element) =>
            distance(location, element.location) <= kVisibilityRadius)
        .toList();
    data.sort((a, b) => distance(location, a.location)
        .compareTo(distance(location, b.location)));
    if (data.length > 10) data = data.sublist(0, 10);

    // Get presets for all elements.
    final presetProv = ref.read(presetProvider);
    final presetsCount = Counter<Preset>();
    for (final element in data) {
      final preset = await presetProv.getPresetForTags(element.getFullTags(),
          locale: locale);
      if (preset != Preset.defaultPreset && !preset.isFixme)
        presetsCount.add(preset);
    }

    // Sort and return most common.
    return presetsCount.mostOccurentItems(count: count).toList();
  }

  /// Regular expression to match Japanese and Chinese hieroglyphs, to allow 1-char search strings for these.
  /// Taken from https://stackoverflow.com/a/43419070
  final reCJK = RegExp(
      '^[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uf900-\ufaff\uff66-\uff9f]');

  updatePresets(String substring) async {
    final mutex = DateTime.now().millisecondsSinceEpoch;
    updateMutex = mutex;

    final prov = ref.read(presetProvider);
    final locale = Localizations.localeOf(context);
    if (substring.length < 2 && !reCJK.hasMatch(substring)) {
      final editorMode = ref.read(editorModeProvider);
      final defaultList = editorMode == EditorMode.micromapping
          ? kDefaultMicroPresets
          : kDefaultPresets;
      final newPresets = await prov.getPresetsById(defaultList, locale: locale);

      // Add last presets.
      final presetsToAdd = <Preset>[];
      presetsToAdd.addAll(ref.read(lastPresetsProvider).getPresets());
      // Add presets from around.
      final presetsAround = <Preset>[];
      if (widget.location != null) {
        final presetsAroundTmp = await _getPresetsAround(widget.location!);
        for (final p in presetsAroundTmp)
          if (!presetsToAdd.contains(p)) presetsAround.add(p);
      }

      // Keep 2 or 4 (or 0) added presets.
      for (final p in presetsToAdd) newPresets.remove(p);
      if ((presetsToAdd.length + presetsAround.length) % 2 != 0) {
        if (presetsAround.isNotEmpty)
          presetsAround.removeLast();
        else if (presetsToAdd.length > 2)
          presetsToAdd.removeLast();
      }
      presetsToAdd.addAll(presetsAround);

      // Filter newPresets and check that we add no more than 4 items.
      newPresets.removeWhere((p) => !newPresets.contains(p));
      if (presetsToAdd.length + newPresets.length - defaultList.length > 4)
        presetsToAdd.removeRange(4, presetsToAdd.length);

      if (mounted && updateMutex == mutex) {
        setState(() {
          resultsUpdated = DateTime.now();
          presets = presetsToAdd + newPresets;
        });
      }
    } else {
      final editorMode = ref.read(editorModeProvider);

      final newPresets = await prov.getPresetsAutocomplete(substring,
          locale: locale,
          location: widget.location,
          nsi: editorMode == EditorMode.poi
              ? NsiQueryType.amenities
              : NsiQueryType.micromapping);

      // Add a fix me preset for entered string.
      newPresets.add(Preset.fixme(substring.trim()));

      if (mounted && updateMutex == mutex) {
        setState(() {
          resultsUpdated = DateTime.now();
          presets = newPresets;
          if (editorMode == EditorMode.poi) updateNSISubtitles(context);
        });
      }
    }
  }

  updateNSISubtitles(BuildContext context) async {
    final upd = resultsUpdated;
    final prov = ref.read(presetProvider);
    final locale = Localizations.localeOf(context);
    final updated = await prov.fillNSIPresetNames(presets, locale: locale);
    if (mounted && resultsUpdated == upd) {
      setState(() {
        presets = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Container(
          width: double.infinity,
          height: 40.0,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5.0),
          ),
          child: TextField(
            autofocus: true,
            controller: controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: loc.chooseType + '...',
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: Icon(Icons.clear),
                tooltip: loc.chooseTypeClear,
                onPressed: () {
                  controller.clear();
                  updatePresets('');
                },
              ),
            ),
            onChanged: (value) {
              updatePresets(value);
            },
          ),
        ),
      ),
      body: ResponsiveGridList(
        minItemWidth: 170.0,
        horizontalGridSpacing: 5,
        verticalGridSpacing: 5,
        rowMainAxisAlignment: MainAxisAlignment.start,
        children: [
          for (final preset in presets)
            GestureDetector(
              child: Container(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: TextStyle(fontSize: 16.0),
                    ),
                    SizedBox(height: 4.0),
                    Text(
                      preset.subtitle,
                      style: TextStyle(
                          fontSize: 14.0, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                color: !preset.isFixme
                    ? (preset.fromNSI
                        ? Colors.grey.withOpacity(0.2)
                        : kFieldColor.withOpacity(0.2))
                    : Colors.red.withOpacity(0.2),
                padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
              ),
              onTap: () {
                if (widget.launchEditor) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PoiEditorPage(
                        location: widget.location,
                        preset: preset,
                      ),
                    ),
                  );
                } else {
                  // Editing preset, return the new one.
                  Navigator.pop(context, preset);
                }
              },
            ),
        ],
      ),
    );
  }
}
