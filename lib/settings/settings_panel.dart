import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../item/info_item.dart';
import '../item/info_item_view.dart';
import '../item/item_store.dart';
import '../shell/keys.dart';
import '../shell/native.dart';
import '../theme/controls.dart';
import '../theme/tokens.dart';

/// Everything the user can change, applied as it changes: the display, the
/// prefix key and the keys after it, the font, and the minimal window.
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.config,
    required this.native,
    required this.store,
    required this.prefixFree,
    required this.onRecordPrefix,
    required this.onClose,
  });

  static const double width = 400;

  final ConfigStore config;
  final NativeBridge native;
  final ItemStore store;

  /// False when another app holds the prefix key.
  final bool prefixFree;

  /// True while a new prefix is being recorded: the current one has to let
  /// go of the keys meanwhile.
  final ValueChanged<bool> onRecordPrefix;
  final VoidCallback onClose;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  static const _prefix = 'prefix';

  List<DisplayInfo> _displays = const [];
  bool _autostart = false;

  /// Loaded when the font list first opens.
  List<FontName>? _fonts;
  bool _picking = false;
  String _query = '';

  /// [_prefix], a [Command], or null.
  Object? _recording;
  String? _recordHint;

  final _keys = FocusNode();
  final _search = TextEditingController();

  OneHitConfig get _c => widget.config.value;

  static final _sample = InfoItem(
    id: 'sample',
    text: '字体预览 Aa 123',
    icon: 'notes',
  );

  @override
  void initState() {
    super.initState();
    widget.config.addListener(_changed);
    widget.native.displays().then((d) {
      if (mounted) setState(() => _displays = d);
    });
    widget.native.autostart().then((on) {
      if (mounted) setState(() => _autostart = on);
    });
  }

  @override
  void dispose() {
    widget.config.removeListener(_changed);
    if (_recording == _prefix) widget.onRecordPrefix(false);
    _keys.dispose();
    _search.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  void _set(OneHitConfig next) => widget.config.update(next);

  // Recording keys ---------------------------------------------------------

  void _record(Object target) {
    if (_recording == _prefix) widget.onRecordPrefix(false);
    setState(() {
      _recording = target;
      _recordHint = null;
    });
    if (target == _prefix) widget.onRecordPrefix(true);
    _keys.requestFocus();
  }

  void _stopRecording() {
    if (_recording == _prefix) widget.onRecordPrefix(false);
    setState(() {
      _recording = null;
      _recordHint = null;
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    final target = _recording;
    if (target == null) return KeyEventResult.ignored;
    if (e is! KeyDownEvent) return KeyEventResult.handled;
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      _stopRecording();
    } else if (target == _prefix) {
      final chord = Chord.pressed(e.logicalKey);
      if (chord != null) {
        _set(_c.copyWith(prefix: '$chord'));
        _stopRecording();
      } else if (keyNameOfEvent(e.logicalKey) != null) {
        setState(() => _recordHint = '前缀键要带上 Ctrl、Alt、Shift 或 Win');
      }
    } else if (target is Command) {
      final name = keyNameOfEvent(e.logicalKey);
      if (name != null) {
        _set(_c.bind(target, name));
        _stopRecording();
      }
    }
    return KeyEventResult.handled;
  }

  // Other settings -----------------------------------------------------------

  bool _showsOn(DisplayInfo d) =>
      _c.display == d.id ||
      (d.primary && !_displays.any((x) => x.id == _c.display));

  Future<void> _toggleAutostart() async {
    await widget.native.setAutostart(!_autostart);
    final on = await widget.native.autostart();
    if (mounted) setState(() => _autostart = on);
  }

  Future<void> _togglePicker() async {
    setState(() => _picking = !_picking);
    if (_fonts != null) return;
    final seen = <String>{};
    final fonts = [
      for (final f in await widget.native.fonts())
        if (seen.add(f.family)) f,
    ]..sort((a, b) => a.name.compareTo(b.name));
    if (mounted) setState(() => _fonts = fonts);
  }

  // Build --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final prefix = Chord.parse(c.prefix)!;
    final recordingPrefix = _recording == _prefix;
    final prefixNote = recordingPrefix
        ? (_recordHint ?? '按下新的组合键，Esc 取消')
        : widget.prefixFree
        ? '先按前缀键，再按下面的一个键'
        : '这个组合键被其他程序占用了，换一个吧';

    return Focus(
      focusNode: _keys,
      onKeyEvent: _onKey,
      child: Container(
        width: SettingsPanel.width,
        decoration: panelDecoration,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(OH.unit * 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '设置',
                      style: panelTitle.copyWith(fontSize: OH.userSize + 3),
                    ),
                  ),
                  RoundIconButton(
                    icon: Icons.close_rounded,
                    label: '关闭',
                    onTap: widget.onClose,
                  ),
                ],
              ),
              const SizedBox(height: OH.unit * 4),
              const PanelSection('显示屏'),
              Wrap(
                spacing: OH.unit * 2,
                runSpacing: OH.unit * 2,
                children: [
                  for (final d in _displays)
                    PillToggle(
                      label: [
                        '显示器 ${d.number}',
                        '${d.width}×${d.height}',
                        if (d.primary) '主屏',
                      ].join(' · '),
                      icon: Icons.desktop_windows_outlined,
                      on: _showsOn(d),
                      onTap: () =>
                          _set(c.copyWith(display: d.primary ? '' : d.id)),
                    ),
                ],
              ),
              const SizedBox(height: OH.unit * 6),
              const PanelSection('快捷键'),
              _Row(
                label: '前缀键',
                child: KeyChip(
                  label: prefix.label,
                  recording: recordingPrefix,
                  onTap: () => _record(_prefix),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: OH.unit * 2),
                child: Text(
                  prefixNote,
                  style: panelHint.copyWith(
                    color: widget.prefixFree || recordingPrefix
                        ? OH.inkSoft
                        : OH.endRing,
                  ),
                ),
              ),
              for (final command in Command.values)
                _Row(
                  label: command.label,
                  child: KeyChip(
                    label: keyLabel(c.keyFor(command)),
                    recording: _recording == command,
                    onTap: () => _record(command),
                  ),
                ),
              const SizedBox(height: OH.unit * 6),
              const PanelSection('文字'),
              _Row(
                label: '字体',
                child: _FontChip(
                  family: c.fontFamily,
                  open: _picking,
                  onTap: _togglePicker,
                ),
              ),
              if (_picking) _fontList(c),
              _Row(
                label: '字号',
                child: PillStepper(
                  label: '${c.fontSize.round()}',
                  canDown: c.fontSize > 12,
                  canUp: c.fontSize < 20,
                  onStep: (d) => _set(c.copyWith(fontSize: c.fontSize + d)),
                ),
              ),
              const SizedBox(height: OH.unit * 3),
              Center(
                child: InfoItemView(
                  item: widget.store.pinned ?? _sample,
                  now: widget.store.now,
                  lifted: false,
                ),
              ),
              const SizedBox(height: OH.unit * 6),
              const PanelSection('浮窗'),
              _Row(
                label: '悬停时显示',
                child: PillStepper(
                  label: '前后各 ${c.previewRadius} 条',
                  canDown: c.previewRadius > 0,
                  canUp: c.previewRadius < 6,
                  onStep: (d) =>
                      _set(c.copyWith(previewRadius: c.previewRadius + d)),
                ),
              ),
              _Row(
                label: '详细信息高度',
                child: PillStepper(
                  label: '${c.detailHeight.round()}',
                  canDown: c.detailHeight > 60,
                  canUp: c.detailHeight < 600,
                  onStep: (d) => _set(
                    c.copyWith(
                      detailHeight: (c.detailHeight + 20 * d).clamp(60, 600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: OH.unit * 3),
              Align(
                alignment: Alignment.centerLeft,
                child: PillToggle(
                  label: '开机时启动',
                  icon: Icons.power_settings_new_rounded,
                  on: _autostart,
                  onTap: _toggleAutostart,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fontList(OneHitConfig c) {
    final fonts = _fonts;
    final q = _query.trim().toLowerCase();
    final options = <FontName>[
      (family: '', name: '默认（${OH.face}）'),
      for (final f in fonts ?? const <FontName>[])
        if (q.isEmpty ||
            f.name.toLowerCase().contains(q) ||
            f.family.toLowerCase().contains(q))
          f,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: OH.unit * 2),
      padding: const EdgeInsets.all(OH.unit * 2),
      decoration: BoxDecoration(
        color: OH.discFill,
        borderRadius: BorderRadius.circular(OH.unit * 3),
      ),
      child: Column(
        children: [
          TextField(
            controller: _search,
            autofocus: true,
            style: panelBody,
            cursorColor: OH.ink,
            onChanged: (t) => setState(() => _query = t),
            decoration: InputDecoration(
              isDense: true,
              hintText: '搜索字体',
              hintStyle: panelBody.copyWith(color: OH.inkSoft),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 18,
                color: OH.inkSoft,
              ),
              filled: true,
              fillColor: OH.ground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(OH.unit * 2),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: OH.unit * 2),
          SizedBox(
            height: 216,
            child: fonts == null
                ? Center(child: Text('正在读取字体…', style: panelHint))
                : ListView.builder(
                    itemCount: options.length,
                    itemExtent: 36,
                    itemBuilder: (context, i) {
                      final f = options[i];
                      final on = f.family == c.fontFamily;
                      return InkWell(
                        onTap: () => _set(c.copyWith(fontFamily: f.family)),
                        borderRadius: BorderRadius.circular(OH.unit * 2),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: OH.unit * 3,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  f.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: panelBody.copyWith(
                                    fontFamily: f.family.isEmpty
                                        ? OH.face
                                        : f.family,
                                  ),
                                ),
                              ),
                              if (on)
                                const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: OH.ink,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// A label on the left, its control on the right.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: OH.unit),
    child: Row(
      children: [
        Expanded(child: Text(label, style: panelBody)),
        child,
      ],
    ),
  );
}

/// The current font, written in itself.
class _FontChip extends StatelessWidget {
  const _FontChip({
    required this.family,
    required this.open,
    required this.onTap,
  });

  final String family;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 32,
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.only(left: OH.unit * 3, right: OH.unit * 2),
          decoration: BoxDecoration(
            color: OH.discFill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  family.isEmpty ? '默认' : family,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: panelBody,
                ),
              ),
              const SizedBox(width: OH.unit),
              Icon(
                open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 18,
                color: OH.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
