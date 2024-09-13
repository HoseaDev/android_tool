import 'dart:io';

import 'package:android_tool/page/main/main_page.dart';
import 'package:flutter/material.dart';
import 'package:desktop_window/desktop_window.dart';
void main() {
  runApp(const MyApp());

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    WidgetsFlutterBinding.ensureInitialized();
    setWindowSize();
  }

}
void setWindowSize() async{
  await DesktopWindow.setMinWindowSize(Size(1350,800));
  await DesktopWindow.setMaxWindowSize(Size(1350,800));
  await DesktopWindow.setWindowSize(Size(1350,800));

}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AndroidADBTool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainPage(),
    );
  }
}
