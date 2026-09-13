part of re_editor;

final kIsMacOS = defaultTargetPlatform == TargetPlatform.macOS;
final kIsAndroid = defaultTargetPlatform == TargetPlatform.android;
final kIsIOS = defaultTargetPlatform == TargetPlatform.iOS;

/// ohos 平台判定：flutter_ohos fork 的 defaultTargetPlatform 返回
/// TargetPlatform.ohos（标准枚举之外的值）。re_editor 的 IME 前缀退格
/// （usePrefix）与移动选择手柄都依赖 kIsAndroid/kIsIOS，ohos 上均为
/// false，导致软键盘在空行无法退格、长按无选择手柄。一并按移动端处理。
final bool kIsOhosMobileLike =
    !kIsWeb && defaultTargetPlatform == TargetPlatform.ohos;
