import 'dart:async';

import 'package:every_door/constants.dart';
import 'package:every_door/helpers/equirectangular.dart';
import 'package:every_door/helpers/good_tags.dart';
import 'package:every_door/models/amenity.dart';
import 'package:every_door/providers/osm_data.dart';
import 'package:every_door/screens/editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class DuplicateWarning extends ConsumerStatefulWidget {
  final OsmChange amenity;

  const DuplicateWarning({required this.amenity, Key? key}) : super(key: key);

  @override
  ConsumerState<DuplicateWarning> createState() => _DuplicateWarningState();
}

class _DuplicateWarningState extends ConsumerState<DuplicateWarning> {
  static final _logger = Logger('DuplicateWarning');
  OsmChange? possibleDuplicate;
  Timer? duplicateTimer;

  @override
  initState() {
    super.initState();
    widget.amenity.addListener(onAmenityChange);
    startDuplicateSearch();
  }

  @override
  dispose() {
    widget.amenity.removeListener(onAmenityChange);
    super.dispose();
  }

  startDuplicateSearch() {
    if (!widget.amenity.isNew || !isAmenityTags(widget.amenity.getFullTags()))
      return;
    possibleDuplicate = null;
    if (duplicateTimer != null) {
      duplicateTimer?.cancel();
      duplicateTimer = null;
    }
    duplicateTimer = Timer(Duration(seconds: 2), () async {
      final duplicate =
      await ref.read(osmDataProvider).findPossibleDuplicate(widget.amenity);
      _logger.info('Found duplicate: $duplicate');
      if (mounted) {
        setState(() {
          possibleDuplicate = duplicate;
        });
      }
    });
  }

  onAmenityChange() {
    startDuplicateSearch();
  }

  @override
  Widget build(BuildContext context) {
    const distance = DistanceEquirectangular();
    final int duplicateDistance = possibleDuplicate == null
        ? 0
        : distance(possibleDuplicate!.location, widget.amenity.location)
        .round();
    final loc = AppLocalizations.of(context)!;

    if (possibleDuplicate == null) return Container();
    return GestureDetector(
      child: Container(
        color: Colors.yellow,
        padding: EdgeInsets.symmetric(vertical: 5.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 5.0),
            Text(
              loc.editorDuplicate(duplicateDistance),
              style: kFieldTextStyle,
            ),
          ],
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PoiEditorPage(amenity: possibleDuplicate),
          ),
        );
      },
    );
  }
}
