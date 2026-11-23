abstract final class UpowerExclusive {
  static bool fromJson(Map<String, dynamic> json) {
    bool isTrue(Object? value) => value == true || value == 1 || value == '1';

    bool hasBadgeText(Object? value) {
      if (value is String) {
        return value.contains('充电专属');
      }
      if (value is Map) {
        return value.values.any(hasBadgeText);
      }
      if (value is Iterable) {
        return value.any(hasBadgeText);
      }
      return false;
    }

    final chargingPay = json['charging_pay'];
    return isTrue(json['is_upower_exclusive']) ||
        isTrue(json['is_upower_exclusive_video']) ||
        (chargingPay is Map && chargingPay['level'] != null) ||
        hasBadgeText(json['badge']) ||
        hasBadgeText(json['badges']) ||
        hasBadgeText(json['badge_info']) ||
        hasBadgeText(json['badge_text']) ||
        hasBadgeText(json['cover_badge']) ||
        hasBadgeText(json['cover_left_text_3']) ||
        hasBadgeText(json['cover_right_text']) ||
        hasBadgeText(json['label']) ||
        hasBadgeText(json['styles']);
  }
}
