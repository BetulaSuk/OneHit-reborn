/// User-adjustable behaviour. Kept in one object so a settings UI or a
/// config file can replace it later.
class OneHitConfig {
  const OneHitConfig({this.previewRadius = 2});

  /// Rows shown above and below the strip while hovering. 2 means at most
  /// five items are visible at once.
  final int previewRadius;
}
