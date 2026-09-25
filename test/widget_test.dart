import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pixel_ruler/main.dart';

void main() {
  testWidgets('应用可正常渲染标题与笔记输入框', (WidgetTester tester) async {
    await tester.pumpWidget(const PixelRulerApp());

    expect(find.text('像素测距仪'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('选择图片'), findsOneWidget);
  });
}