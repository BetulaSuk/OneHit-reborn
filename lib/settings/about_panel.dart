import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/controls.dart';
import '../theme/tokens.dart';

/// Name, version, the prefix in one line, and where the data lives.
class AboutPanel extends StatelessWidget {
  const AboutPanel({
    super.key,
    required this.dataDir,
    required this.prefix,
    required this.settingsKey,
    required this.onClose,
  });

  /// Keep in step with `version` in pubspec.yaml.
  static const String version = '1.0.0';

  final String dataDir;
  final String prefix;
  final String settingsKey;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(OH.unit * 5),
      decoration: panelDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppMark(size: 48),
              const SizedBox(width: OH.unit * 3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OneHit',
                      style: panelTitle.copyWith(fontSize: OH.userSize + 5),
                    ),
                    Text('版本 $version', style: panelHint),
                  ],
                ),
              ),
              RoundIconButton(
                icon: Icons.close_rounded,
                label: '关闭',
                onTap: onClose,
              ),
            ],
          ),
          const SizedBox(height: OH.unit * 4),
          Text(
            '把此刻最重要的一条信息放在桌面最上层。悬停翻看，长按拖动加标签，双击打开列表。',
            style: panelBody.copyWith(height: 1.5),
          ),
          const SizedBox(height: OH.unit * 5),
          const PanelSection('快捷键'),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: OH.unit * 1.5,
            runSpacing: OH.unit * 1.5,
            children: [
              Text('先按', style: panelBody),
              KeyChip(label: prefix),
              Text('再按', style: panelBody),
              KeyChip(label: settingsKey),
              Text('打开设置', style: panelBody),
            ],
          ),
          const SizedBox(height: OH.unit * 5),
          const PanelSection('数据位置'),
          SelectableText(dataDir, style: panelHint),
          const SizedBox(height: OH.unit),
          Align(
            alignment: Alignment.centerLeft,
            child: QuietButton(
              label: '打开文件夹',
              icon: Icons.folder_open_outlined,
              onTap: () => Process.run('explorer', [dataDir]),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app's mark, as in its icon: three quarters of an Activity ring on a
/// near-black disc.
class AppMark extends StatelessWidget {
  const AppMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _MarkPainter());
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final stroke = s * 0.2;
    final r = s / 2 - s * 0.1 - stroke / 2;
    canvas.drawCircle(c, s / 2, Paint()..color = OH.ink);
    Paint arc(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(c, r, arc(const Color(0xFF334518)));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      1.5 * math.pi,
      false,
      arc(OH.runLap),
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) => false;
}
