import 'dart:io';

import 'config.dart';

/// The UI text in effect, set from the config by `applyConfig`.
Strings strings = Strings.of('');

/// Every piece of UI text, in Chinese and English side by side.
class Strings {
  const Strings._(this.zh);

  static const chinese = Strings._(true);
  static const english = Strings._(false);

  /// `zh` or `en`; anything else follows the Windows display language.
  static Strings of(String language) => switch (language) {
    'zh' => chinese,
    'en' => english,
    _ => Platform.localeName.toLowerCase().startsWith('zh') ? chinese : english,
  };

  final bool zh;

  String get code => zh ? 'zh' : 'en';

  String pick(String cn, String en) => zh ? cn : en;

  // Shared
  String get close => pick('关闭', 'Close');
  String get cancel => pick('取消', 'Cancel');
  String get ok => pick('确定', 'OK');
  String get emptyItem => pick('空白信息', 'Empty item');
  String get writeSomething => pick('写点什么', 'Write something');
  String get newItem => pick('新建信息', 'New item');
  String get decrease => pick('减少', 'Decrease');
  String get increase => pick('增加', 'Increase');
  String get pressKey => pick('按下按键…', 'Press a key…');

  // Item
  String get inlineEditHint => pick(
    'Enter 保存 · Shift+Enter 换行 · Esc 取消',
    'Enter saves · Shift+Enter new line · Esc cancels',
  );
  String get pauseCountdown => pick('暂停倒计时', 'Pause countdown');
  String get resumeCountdown => pick('继续倒计时', 'Resume countdown');
  String get countdownEnded => pick('倒计时已结束', 'Countdown ended');

  // First-run tips
  String get tipHover =>
      pick('把鼠标移上来，滚轮翻看其他信息', 'Hover here and scroll to see other items');
  String get tipEdit =>
      pick('右键一条信息即可编辑文字', 'Right-click an item to edit its text');
  String get tipTag => pick(
    '长按并拖动信息，拖到选区添加标签',
    'Long-press and drag an item onto a zone to tag it',
  );
  String get tipList =>
      pick('双击浮窗打开信息列表', 'Double-click the strip to open the list');
  String get tipImage =>
      pick('拖入图片或粘贴图片来设置图标', 'Drop or paste an image to set the icon');

  // Tags
  String get sink => pick('下沉', 'Sink');
  String get float => pick('上浮', 'Float');
  String get time => pick('时间', 'Time');
  String get detail => pick('详细', 'Detail');
  String get undetail => pick('取消详细', 'No detail');
  String get setCountdown => pick('设定倒计时', 'Set countdown');
  String get changeCountdown => pick('重新调整', 'Change countdown');

  // Time dial
  String laps(int n) => pick('$n 圈', n == 1 ? '1 lap' : '$n laps');
  String get hours => pick('小时', 'Hours');
  String get minutes => pick('分钟', 'Minutes');
  String get removeTime => pick('移除时间', 'Remove time');

  // Side editor
  String get editItem => pick('编辑信息', 'Edit item');
  String get icon => pick('图标', 'Icon');
  String get imageIcon => pick('图片图标', 'Image icon');
  String get removeImage => pick('移除图片', 'Remove image');
  String get iconHint => pick(
    '拖入图片文件或链接、或选中后粘贴图片，即可设为图标',
    'Drop an image file or link, or select the item and paste an image, to make it the icon',
  );
  String get tags => pick('标签', 'Tags');
  String get deleteItem => pick('删除这条信息', 'Delete this item');
  String get running => pick('计时中', 'Running');
  String get paused => pick('已暂停', 'Paused');
  String get sunkPaused => pick('已下沉，暂停', 'Sunk, paused');
  String get ended => pick('已结束', 'Ended');
  String get pause => pick('暂停', 'Pause');
  String get resume => pick('继续', 'Resume');
  String get adjustTime => pick('调整时间', 'Adjust time');
  String get reminderNote =>
      pick('一直计时，结束时浮出提醒', 'Always runs, and pops up when it ends');
  String get timerNote =>
      pick('只在浮窗显示时计时', 'Runs only while shown on the strip');

  // List
  String get allItems => pick('全部信息', 'All items');
  String get shrink =>
      pick('缩回浮窗（双击标题栏）', 'Back to the strip (double-click the header)');

  // Shortcuts
  String get pressAKey => pick('按一个键', 'Press a key');
  String command(Command c) => switch (c) {
    Command.toggle => pick('显示或隐藏浮窗', 'Show or hide OneHit'),
    Command.list => pick('打开或关闭列表', 'Open or close the list'),
    Command.create => pick('新建信息', 'New item'),
    Command.edit => pick('编辑当前信息', 'Edit the pinned item'),
    Command.paste => pick('剪贴板存为新信息', 'Clipboard as a new item'),
    Command.time => pick('给当前信息定时', 'Time the pinned item'),
    Command.pause => pick('暂停或继续计时', 'Pause or resume'),
    Command.next => pick('下一条信息', 'Next item'),
    Command.previous => pick('上一条信息', 'Previous item'),
    Command.settings => pick('打开设置', 'Open settings'),
  };

  // Tray
  String get settingsMenu => pick('设置…', 'Settings…');
  String get aboutMenu => pick('关于 OneHit', 'About OneHit');
  String get hide => pick('隐藏浮窗', 'Hide OneHit');
  String get show => pick('显示浮窗', 'Show OneHit');
  String get quit => pick('退出', 'Quit');

  // About
  String version(String v) => pick('版本 $v', 'Version $v');
  String get aboutBlurb => pick(
    '把此刻最重要的一条信息放在桌面最上层。悬停翻看，长按拖动加标签，双击打开列表。',
    'Keeps the one thing that matters right now on top of the desktop. Hover to browse, long-press and drag to tag, double-click for the list.',
  );
  String get shortcuts => pick('快捷键', 'Shortcuts');
  String get pressFirst => pick('先按', 'Press');
  String get thenPress => pick('再按', 'then');
  String get toOpenSettings => pick('打开设置', 'for settings');
  String get dataFolder => pick('数据位置', 'Data folder');
  String get openFolder => pick('打开文件夹', 'Open folder');

  // Settings
  String get settings => pick('设置', 'Settings');
  String get language => pick('语言', 'Language');
  String get display => pick('显示屏', 'Display');
  String monitor(String n) => pick('显示器 $n', 'Monitor $n');
  String get primary => pick('主屏', 'primary');
  String get prefix => pick('前缀键', 'Prefix');
  String get prefixNeedsModifier => pick(
    '前缀键要带上 Ctrl、Alt、Shift 或 Win',
    'The prefix needs Ctrl, Alt, Shift or Win',
  );
  String get recordPrefix =>
      pick('按下新的组合键，Esc 取消', 'Press the new combination, Esc cancels');
  String get prefixHow =>
      pick('先按前缀键，再按下面的一个键', 'Press the prefix, then one of the keys below');
  String get prefixTaken => pick(
    '这个组合键被其他程序占用了，换一个吧',
    'Another app holds this combination; record a different one',
  );
  String get text => pick('文字', 'Text');
  String get font => pick('字体', 'Font');
  String get fontSize => pick('字号', 'Size');
  String get fontSample => pick('字体预览 Aa 123', 'Font preview Aa 123');
  String defaultFont(String face) => pick('默认（$face）', 'Default ($face)');
  String get defaultShort => pick('默认', 'Default');
  String get searchFonts => pick('搜索字体', 'Search fonts');
  String get loadingFonts => pick('正在读取字体…', 'Loading fonts…');
  String get window => pick('浮窗', 'Floating window');
  String get onHover => pick('悬停时显示', 'Shown on hover');
  String eachWay(int n) => pick('前后各 $n 条', '$n each way');
  String get detailHeight => pick('详细信息高度', 'Detail card height');
  String get startWithWindows => pick('开机时启动', 'Start with Windows');
}
