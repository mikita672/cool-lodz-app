import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../achievements/badges_view.dart';
import '../leaderboard/ranking_view.dart';
import 'quest_view.dart';

/// Sections of the Quest tab: Quest (S10), Odznaki (S12), Ranking (S13).
enum QuestSection { quest, badges, ranking }

/// Quest tab: a segmented switch between S10, S12 and S13.
class QuestTabScreen extends StatefulWidget {
  const QuestTabScreen({super.key, this.initial = QuestSection.quest});

  final QuestSection initial;

  @override
  State<QuestTabScreen> createState() => _QuestTabScreenState();
}

class _QuestTabScreenState extends State<QuestTabScreen> {
  late QuestSection _section = widget.initial;

  @override
  void didUpdateWidget(QuestTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial) _section = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navQuest)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.screenPadding,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<QuestSection>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: QuestSection.quest,
                    label: Text(l10n.questSegmentQuest),
                  ),
                  ButtonSegment(
                    value: QuestSection.badges,
                    label: Text(l10n.questSegmentBadges),
                  ),
                  ButtonSegment(
                    value: QuestSection.ranking,
                    label: Text(l10n.questSegmentRanking),
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (s) => setState(() => _section = s.first),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.s8),
          Expanded(
            child: switch (_section) {
              QuestSection.quest => const QuestView(),
              QuestSection.badges => const BadgesView(),
              QuestSection.ranking => const RankingView(),
            },
          ),
        ],
      ),
    );
  }
}
