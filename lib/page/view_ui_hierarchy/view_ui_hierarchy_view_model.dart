import 'dart:io';

import 'package:android_tool/page/feature_page/feature_view_model.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart' as xml;

class ViewUIHierarchyViewModel extends FeatureViewModel {
  String currentScreenshotPath = "";
  String currentDumpInfoPath = "";
  xml.XmlDocument? layoutData;

  ViewUIHierarchyViewModel(
    BuildContext context,
    String deviceId,
  ) : super(context, deviceId);

  Future<void> getScreenshot() async {
    PaintingBinding.instance?.imageCache?.clear();
    var directory = await getTemporaryDirectory();
    var path = p.join(directory.path, "screenshot_${DateTime.now()}.png");

    await execAdb([
      '-s',
      deviceId,
      'shell',
      'screencap',
      '-p',
      '/sdcard/screenshot.png',
    ]);
    var result = await execAdb([
      '-s',
      deviceId,
      'pull',
      '/sdcard/screenshot.png',
      path,
    ]);
    await execAdb([
      '-s',
      deviceId,
      'shell',
      'rm',
      '-rf',
      '/sdcard/screenshot.png',
    ]);

    if (result != null && result.exitCode == 0) {
      debugPrint("currentScreenshotPath:${path}");
      currentScreenshotPath = path;

      notifyListeners();
    }
  }

  Future<void> getJumpInfo() async {
    var directory = await getTemporaryDirectory();
    var path = directory.path + "/window_dump.xml";
    //UI hierchary dumped to: /sdcard/window_dump.xml
    await execAdb([
      '-s',
      deviceId,
      'shell',
      'uiautomator',
      'dump',
    ]);
    //把window_dump.xml取下来
    var result = await execAdb([
      '-s',
      deviceId,
      'pull',
      '/sdcard/window_dump.xml',
      path,
    ]);
    //删除手机上的window_dump.xml 文件
    await execAdb([
      '-s',
      deviceId,
      'shell',
      'rm',
      '-rf',
      '/sdcard/window_dump.xml',
    ]);
    debugPrint("result:${result?.exitCode}");
    if (result != null && result.exitCode == 0) {
      debugPrint("currentDumpInfoPath:${path}");
      currentDumpInfoPath = path;
      notifyListeners();
    }
  }

  Future<void> loadLayoutData() async {
    await getScreenshot();
    await getJumpInfo();
    debugPrint("viewModel.currentDumpInfoPath:${currentDumpInfoPath}");
    if (currentDumpInfoPath.isNotEmpty) {
      final layoutFile = File(currentDumpInfoPath);
      final xmlString = await layoutFile.readAsString();
      layoutData = xml.XmlDocument.parse(xmlString);
      notifyListeners();
    }
  }
}
