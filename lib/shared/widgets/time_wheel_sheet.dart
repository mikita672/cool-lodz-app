import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/api/live/weather.dart';
import '../../l10n/app_localizations.dart';
import 'weather_icon.dart';

/// Minutes on the wheel go in these steps.
const timeWheelMinuteStep = 5;

/// Picks a day and a time like an alarm clock: day chips, hour and minute
/// wheels, and the weather of the chosen time with an hourly strip (when
/// [forecast] is known). Returns local time, or null when dismissed.
Future<DateTime?> showTimeWheelSheet(
  BuildContext context, {
  required String title,
  required DateTime initial,
  required DateTime now,
  int days = 8,
  WeatherForecast? forecast,
  String? note,
}) => showModalBottomSheet<DateTime>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => TimeWheelSheet(
    title: title,
    initial: initial,
    now: now,
    days: days,
    forecast: forecast,
    note: note,
  ),
);

/// «Dziś», «Jutro» or «pt 24.10» for the day [index] days after today.
String dayLabel(int index, DateTime day, AppLocalizations l10n) =>
    switch (index) {
      0 => l10n.timeToday,
      1 => l10n.timeTomorrow,
      _ => DateFormat('EEE d.MM', 'pl').format(day),
    };

class TimeWheelSheet extends StatefulWidget {
  const TimeWheelSheet({
    super.key,
    required this.title,
    required this.initial,
    required this.now,
    this.days = 8,
    this.forecast,
    this.note,
  });

  final String title;
  final DateTime initial;
  final DateTime now;

  /// Today and the following days on offer.
  final int days;
  final WeatherForecast? forecast;
  final String? note;

  @override
  State<TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<TimeWheelSheet> {
  static const _itemExtent = 48.0;
  static const _minutes = 60 ~/ timeWheelMinuteStep;

  late int _day;
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hours;
  late final FixedExtentScrollController _mins;
  late final ScrollController _strip;

  DateTime get _today => DateUtils.dateOnly(widget.now);

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _day = DateUtils.dateOnly(
      initial,
    ).difference(_today).inDays.clamp(0, widget.days - 1);
    _hour = initial.hour;
    _minute = initial.minute - initial.minute % timeWheelMinuteStep;
    _hours = FixedExtentScrollController(initialItem: _hour);
    _mins = FixedExtentScrollController(
      initialItem: _minute ~/ timeWheelMinuteStep,
    );
    // The strip starts a little before the chosen hour (60 px per hour).
    _strip = ScrollController(
      initialScrollOffset: (_hour * 60.0 - 120).clamp(0, double.infinity),
    );
  }

  @override
  void dispose() {
    _hours.dispose();
    _mins.dispose();
    _strip.dispose();
    super.dispose();
  }

  DateTime _dayAt(int index) => DateUtils.addDaysToDate(_today, index);

  DateTime get _selected {
    final d = _dayAt(_day);
    return DateTime(d.year, d.month, d.day, _hour, _minute);
  }

  /// Moves the hour wheel to [hour] (the hourly strip), keeping the loop.
  void _jumpToHour(int hour) {
    final current = _hours.selectedItem;
    final delta = ((hour - current) % 24 + 36) % 24 - 12;
    _hours.animateToItem(
      current + delta,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    if (_mins.selectedItem % _minutes != 0) {
      _mins.animateToItem(
        _mins.selectedItem - _mins.selectedItem % _minutes,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
    setState(() {
      _hour = hour;
      _minute = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final forecast = widget.forecast;
    final selected = _selected;
    final hourWeather = forecast?.at(selected);
    final day = _dayAt(_day);
    // Hour h shows the forecast entry covering h:30.
    final strip = [
      if (forecast != null)
        for (var h = 0; h < 24; h++)
          if (forecast.at(DateTime(day.year, day.month, day.day, h, 30))
              case final w?)
            (h, w),
    ];

    Widget wheel({
      required Key key,
      required FixedExtentScrollController controller,
      required int count,
      required String Function(int) label,
      required ValueChanged<int> onChanged,
    }) => SizedBox(
      width: 88,
      height: _itemExtent * 3.4,
      child: CupertinoPicker(
        key: key,
        scrollController: controller,
        itemExtent: _itemExtent,
        looping: true,
        useMagnifier: true,
        magnification: 1.15,
        selectionOverlay: const SizedBox.shrink(),
        onSelectedItemChanged: (i) => onChanged(i % count),
        children: [
          for (var i = 0; i < count; i++)
            Center(
              child: Text(
                label(i),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          0,
          AppSizes.screenPadding,
          AppSizes.screenPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppTextStyles.titleM),
            if (widget.note case final note?) ...[
              const SizedBox(height: AppSizes.s4),
              Text(note, style: AppTextStyles.bodyS),
            ],
            const SizedBox(height: AppSizes.s12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < widget.days; i++) ...[
                    ChoiceChip(
                      key: Key('time-wheel-day-$i'),
                      label: Text(dayLabel(i, _dayAt(i), l10n)),
                      selected: i == _day,
                      onSelected: (_) => setState(() => _day = i),
                    ),
                    const SizedBox(width: AppSizes.s8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSizes.s8),
            Stack(
              alignment: Alignment.center,
              children: [
                // The band of the chosen time, as on an alarm clock.
                Container(
                  height: _itemExtent,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSizes.radiusCard),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    wheel(
                      key: const Key('time-wheel-hour'),
                      controller: _hours,
                      count: 24,
                      label: (i) => '$i'.padLeft(2, '0'),
                      onChanged: (h) => setState(() => _hour = h),
                    ),
                    Text(':', style: theme.textTheme.headlineMedium),
                    wheel(
                      key: const Key('time-wheel-minute'),
                      controller: _mins,
                      count: _minutes,
                      label: (i) =>
                          '${i * timeWheelMinuteStep}'.padLeft(2, '0'),
                      onChanged: (m) =>
                          setState(() => _minute = m * timeWheelMinuteStep),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSizes.s12),
            if (hourWeather != null)
              WeatherSummary(hour: hourWeather, instant: selected)
            else if (forecast != null)
              Text(l10n.weatherNoForecast, style: AppTextStyles.bodyS),
            if (strip.isNotEmpty) ...[
              const SizedBox(height: AppSizes.s12),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  key: const Key('time-wheel-strip'),
                  scrollDirection: Axis.horizontal,
                  controller: _strip,
                  itemCount: strip.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (context, i) {
                    final (h, w) = strip[i];
                    final at = DateTime(day.year, day.month, day.day, h, 30);
                    final on = h == _hour;
                    return SizedBox(
                      width: 56,
                      child: Material(
                        color: on
                            ? AppColors.primaryContainer
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusChip,
                        ),
                        child: InkWell(
                          key: Key('time-wheel-strip-$h'),
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusChip,
                          ),
                          onTap: () => _jumpToHour(h),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$h:00', style: theme.textTheme.labelSmall),
                              const SizedBox(height: 2),
                              WeatherIcon(hour: w, instant: at),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (w.temperature case final t?)
                                    Text(
                                      '${t.round()}°',
                                      style: theme.textTheme.labelMedium,
                                    ),
                                  if (weatherTags(w).contains(WeatherTag.windy))
                                    const Icon(
                                      Icons.air_rounded,
                                      size: 12,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: AppSizes.s16),
            FilledButton(
              key: const Key('time-wheel-done'),
              onPressed: () => Navigator.of(context).pop(selected),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
              ),
              child: Text(l10n.timeSet),
            ),
          ],
        ),
      ),
    );
  }
}
