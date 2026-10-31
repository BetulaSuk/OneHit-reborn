import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onehit/item/info_item.dart';
import 'package:onehit/item/item_cards.dart';

void main() {
  testWidgets('inline editor: Enter commits, Esc cancels, Shift+Enter types', (
    tester,
  ) async {
    var commits = 0;
    var cancels = 0;
    final controller = TextEditingController(text: 'abc');
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: InlineEditor(
            item: InfoItem(id: 'a', text: 'abc'),
            controller: controller,
            focusNode: FocusNode(),
            onCommit: () => commits++,
            onCancel: () => cancels++,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(cancels, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(commits, 1);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(commits, 1);
  });
}
