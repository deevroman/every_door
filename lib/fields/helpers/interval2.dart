import 'package:every_door/fields/helpers/hours_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ClockIntervalField extends StatelessWidget {
  final HoursInterval interval;
  final Function(HoursInterval) onChange;
  final bool isBreak;
  final bool isCollectionTimes;

  const ClockIntervalField({
    required this.interval,
    required this.onChange,
    this.isBreak = false,
    this.isCollectionTimes = false,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (isCollectionTimes) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        // TODO: actually there can be many times, so this needs to be an array... It's complicated.
        child: ClockEditor(
          interval: interval,
          onChange: onChange,
          title: 'Collection',
          type: ClockEditorType.single,
        ),
      );
    } else if (!isBreak) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 14.0),
        child: Row(
          children: [
            Expanded(
              child: ClockEditor(
                interval: interval,
                onChange: onChange,
                title: loc.fieldHoursOpens,
                type: ClockEditorType.first,
              ),
            ),
            Expanded(
              child: ClockEditor(
                interval: interval,
                onChange: onChange,
                title: loc.fieldHoursCloses,
                type: ClockEditorType.second,
              ),
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        child: ClockEditor(
          interval: interval,
          onChange: onChange,
          title: loc.fieldHoursBreak,
          type: ClockEditorType.both,
        ),
      );
    }
  }
}

enum ClockEditorType { first, second, both, single }

class ClockEditor extends StatefulWidget {
  final HoursInterval interval;
  final String title;
  final ClockEditorType type;
  final Function(HoursInterval) onChange;

  const ClockEditor({
    required this.interval,
    required this.onChange,
    required this.title,
    required this.type,
  });

  @override
  State<ClockEditor> createState() => _ClockEditorState();

  static Future<String?> _showTimePickerIntl(
      BuildContext context, String initialHours,
      {String? confirmText, String? helpText}) async {
    TimeOfDay start;
    final parts = initialHours.split(':');
    if (parts.length != 2)
      start = TimeOfDay(hour: 9, minute: 0);
    else
      start = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: start,
      helpText: helpText,
      confirmText: confirmText,
      builder: (BuildContext context, Widget? child) {
        // Force 24-hour clock.
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    return time == null
        ? null
        : '${time.hour.toString().padLeft(2, "0")}:${time.minute.toString().padLeft(2, "0")}';
  }

  static Future<HoursInterval?> showIntervalEditor(
      BuildContext context, HoursInterval interval,
      [bool onlySecond = false]) async {
    final loc = AppLocalizations.of(context)!;
    String start = interval.start;
    if (!onlySecond) {
      final result = await _showTimePickerIntl(context, start,
          confirmText: MaterialLocalizations.of(context).continueButtonLabel,
          helpText: loc.fieldHoursOpens);
      if (result == null) return null;
      start = result;
    }
    final end = await _showTimePickerIntl(context, interval.end,
        helpText: loc.fieldHoursCloses);
    if (end == null) return null;
    return HoursInterval(start, end);
  }
}

class _ClockEditorState extends State<ClockEditor> {
  @override
  Widget build(BuildContext context) {
    String time;
    if (widget.type == ClockEditorType.both) {
      time = widget.interval.toString();
    } else {
      time = widget.type == ClockEditorType.second
          ? widget.interval.end
          : widget.interval.start;
    }
    final double baseSize = widget.type == ClockEditorType.both ? 14.0 : 18.0;

    return GestureDetector(
      onTap: () async {
        final result = await ClockEditor.showIntervalEditor(
            context, widget.interval, widget.type == ClockEditorType.second);
        if (result != null && result != widget.interval) {
          widget.onChange(result);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(fontSize: baseSize, color: Colors.grey),
          ),
          Text(
            time,
            style: TextStyle(fontSize: baseSize * 2),
          ),
        ],
      ),
    );
  }
}
