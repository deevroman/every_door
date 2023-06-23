import 'dart:async';

import 'package:every_door/constants.dart';
import 'package:every_door/helpers/tile_layers.dart';
import 'package:every_door/providers/editor_mode.dart';
import 'package:every_door/providers/editor_settings.dart';
import 'package:every_door/providers/location.dart';
import 'package:every_door/screens/settings.dart';
import 'package:every_door/widgets/loc_marker.dart';
import 'package:every_door/widgets/status_pane.dart';
import 'package:every_door/widgets/track_button.dart';
import 'package:every_door/widgets/zoom_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NavigationPane extends ConsumerStatefulWidget {
  const NavigationPane({Key? key}) : super(key: key);

  @override
  ConsumerState<NavigationPane> createState() => _NavigationPaneState();
}

class _NavigationPaneState extends ConsumerState<NavigationPane> {
  late LatLng center;
  final controller = MapController();
  late final StreamSubscription<MapEvent> mapSub;

  @override
  void initState() {
    super.initState();
    center = ref.read(effectiveLocationProvider);
    mapSub = controller.mapEventStream.listen(onMapEvent);
  }

  onMapEvent(MapEvent event) {
    bool fromController = event.source == MapEventSource.mapController;
    if (event is MapEventWithMove) {
      center = event.center;
      if (!fromController) {
        ref.read(zoomProvider.notifier).state = event.zoom;
        if (event.zoom > kEditMinZoom) {
          // Switch navigation mode off
          ref.read(navigationModeProvider.notifier).state = false;
        }
      }
    } else if (event is MapEventMoveEnd) {
      if (!fromController) {
        ref.read(effectiveLocationProvider.notifier).set(event.center);
      }
    } else if (event is MapEventRotateEnd) {
      if (!fromController) {
        double rotation = controller.rotation;
        while (rotation > 200) rotation -= 360;
        while (rotation < -200) rotation += 360;
        if (rotation.abs() < kRotationThreshold) {
          ref.read(rotationProvider.notifier).state = 0.0;
          controller.rotate(0.0);
        } else {
          ref.read(rotationProvider.notifier).state = rotation;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final leftHand = ref.watch(editorSettingsProvider).leftHand;
    final loc = AppLocalizations.of(context)!;
    EdgeInsets safePadding = MediaQuery.of(context).padding;

    // Rotate the map according to the global rotation value.
    ref.listen(rotationProvider, (_, double newValue) {
      if ((newValue - controller.rotation).abs() >= 1.0)
        controller.rotate(newValue);
    });

    ref.listen(effectiveLocationProvider, (_, LatLng next) {
      controller.move(next, controller.zoom);
      setState(() {
        center = next;
      });
    });

    return Stack(
      children: [
        FlutterMap(
          mapController: controller,
          options: MapOptions(
            center: center,
            zoom: kEditMinZoom,
            minZoom: 4.0,
            maxZoom: kEditMinZoom + 1.0,
            interactiveFlags: InteractiveFlag.drag |
                InteractiveFlag.pinchZoom |
                InteractiveFlag.pinchMove,
            plugins: [
              ZoomButtonsPlugin(),
              OverlayButtonPlugin(),
            ],
          ),
          layers: [
            // Settings button
            OverlayButtonOptions(
              alignment: leftHand ? Alignment.topRight : Alignment.topLeft,
              padding: EdgeInsets.symmetric(
                horizontal: 0.0,
                vertical: 10.0,
              ),
              icon: Icons.menu,
              tooltip: loc.mapSettings,
              safeRight: true,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );
              },
            ),
            ZoomButtonsOptions(
              alignment:
                  leftHand ? Alignment.bottomLeft : Alignment.bottomRight,
              padding: EdgeInsets.symmetric(
                horizontal:
                    0.0 + (leftHand ? safePadding.left : safePadding.right),
                vertical: 20.0,
              ),
            ),
          ],
          nonRotatedChildren: [
            buildAttributionWidget(kOSMImagery),
          ],
          children: [
            TileLayerWidget(
              options: buildTileLayerOptions(kOSMImagery),
            ),
            LocationMarkerWidget(),
          ],
        ),
        ApiStatusPane(),
      ],
    );
  }
}
