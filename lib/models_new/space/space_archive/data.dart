import 'package:PiliPlus/models_new/space/space_archive/episodic_button.dart';
import 'package:PiliPlus/models_new/space/space_archive/item.dart';

class SpaceArchiveData {
  EpisodicButton? episodicButton;
  int? count;
  List<SpaceArchiveItem>? item;
  bool? hasNext;
  bool? hasPrev;
  int? next;
  int? nextCursor;

  SpaceArchiveData({
    this.episodicButton,
    this.count,
    this.item,
    this.hasNext,
    this.hasPrev,
    this.next,
    this.nextCursor,
  });

  factory SpaceArchiveData.fromJson(Map<String, dynamic> json) =>
      SpaceArchiveData(
        episodicButton: json['episodic_button'] == null
            ? null
            : EpisodicButton.fromJson(
                json['episodic_button'] as Map<String, dynamic>,
              ),
        count: json['count'] as int?,
        item: (json['item'] as List<dynamic>?)
            ?.map((e) => SpaceArchiveItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasNext: json['has_next'] as bool?,
        hasPrev: json['has_prev'] as bool?,
        next: json['next'],
        nextCursor: json['next_cursor'],
      );
}
