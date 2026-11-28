import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_app/views/auth/login_screen.dart';
import 'package:quiz_app/views/splash/loading_screen.dart';

void main() {
  testWidgets('Hiển thị đúng màn hình chờ LoadingScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoadingScreen(),
      ),
    );

    expect(find.text('QuizMaster'), findsOneWidget);
    expect(find.text('Học hỏi & Khám phá'), findsOneWidget);
    expect(find.text('Đang tải...'), findsOneWidget);
  });

  testWidgets('Hiển thị form LoginScreen và kiểm tra validate rỗng',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('Chào mừng trở lại!'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Đăng nhập'), findsOneWidget);

    // Bấm nút Đăng nhập khi chưa nhập dữ liệu
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pump();

    expect(
      find.text('Vui lòng nhập đầy đủ email và mật khẩu'),
      findsOneWidget,
    );
  });
}