class LiveSearchUserItemModel {
  String? face;
  String? name;
  int? uid;
  int? liveStatus;
  String? areaName;
  int? fansNum;
  int? roomid;

  LiveSearchUserItemModel({
    this.face,
    this.name,
    this.uid,
    this.liveStatus,
    this.areaName,
    this.fansNum,
    this.roomid,
  });

  factory LiveSearchUserItemModel.fromJson(Map<String, dynamic> json) =>
      LiveSearchUserItemModel(
        face: json['face'] as String?,
        name: json['name'] as String?,
        uid: switch (json['uid']) {
          final num v => v.toInt(),
          final String v => int.tryParse(v),
          _ => null,
        },
        liveStatus: json['live_status'] as int?,
        areaName: json['areaName'] as String?,
        fansNum: json['fansNum'] as int?,
        roomid: json['roomid'] as int?,
      );
}
