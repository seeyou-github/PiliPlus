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
        // 注意: 服务端返回的 next_cursor 是字符串（如 "910689"），
        // 直接赋给 int? 会抛 type 'String' is not a subtype of type 'int?'，
        // 导致整个 fromJson 失败、列表一直停在 loading。这里做兼容解析。
        nextCursor: int.tryParse('${json['next_cursor']}'),
      );
}
