import 'dart:convert';
import 'dart:io';

import 'package:android_tool/page/common/app.dart';
import 'package:android_tool/page/common/base_view_model.dart';
import 'package:android_tool/page/common/package_help_mixin.dart';
import 'package:android_tool/utils/aes_crypto.dart';
import 'package:android_tool/widget/pop_up_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomLogViewModel extends BaseViewModel with PackageHelpMixin {
  static const String colorLogKey = 'colorLog';
  static const String filterPackageKey = 'filterPackage';
  static const String caseSensitiveKey = 'caseSensitive';
  static const String aesIvKey = 'aesIv';
  static const String aesKeyKey = 'aesKey';

  String deviceId;

  bool isFilterPackage = false;
  String filterContent = "";
  String checkStateStr = "";

  List<String> logList = [];

  FlutterListViewController scrollController = FlutterListViewController();

  TextEditingController contentController = TextEditingController();
  TextEditingController ivController = TextEditingController();
  TextEditingController keyController = TextEditingController();

  bool isCaseSensitive = false;

  bool isShowLast = true;

  String pid = "";

  int findIndex = -1;

  Process? _process;

  List<FilterLevel> filterLevel = [
    FilterLevel("Verbose", "*:V"),
    FilterLevel("Debug", "*:D"),
    FilterLevel("Info", "*:I"),
    FilterLevel("Warn", "*:W"),
    FilterLevel("Error", "*:E"),
  ];
  PopUpMenuButtonViewModel<FilterLevel> filterLevelViewModel =
      PopUpMenuButtonViewModel();

  CustomLogViewModel(
    BuildContext context,
    this.deviceId,
  ) : super(context) {
    App().eventBus.on<DeviceIdEvent>().listen((event) async {
      logList.clear();
      deviceId = event.deviceId;
      kill();
      if (deviceId.isEmpty) {
        resetPackage();
        return;
      }
      await getInstalledApp(deviceId);
      listenerLog();
    });
    App().eventBus.on<AdbPathEvent>().listen((event) {
      logList.clear();
      adbPath = event.path;
      kill();
      listenerLog();
    });
    SharedPreferences.getInstance().then((preferences) {
      isFilterPackage = preferences.getBool(filterPackageKey) ?? false;
      isCaseSensitive = preferences.getBool(caseSensitiveKey) ?? false;
    });

    filterLevelViewModel.list = filterLevel;
    filterLevelViewModel.selectValue = filterLevel.first;
    filterLevelViewModel.addListener(() {
      kill();
      listenerLog();
    });
  }

  void init() async {
    SharedPreferences.getInstance().then((preferences) {
      ivController.text = preferences.getString(aesIvKey) ?? "";
      keyController.text = preferences.getString(aesKeyKey) ?? "";
    });

  }

  void selectPackageName(BuildContext context) async {
    var package = await showPackageSelect(context, deviceId);
    if (packageName == package || package.isEmpty) {
      return;
    }

    packageName = package;
    if (isFilterPackage) {
      logList.clear();
      pid = await getPid();
      kill();
      listenerLog();
      notifyListeners();
    }
  }

  void listenerLog() {
    String level = filterLevelViewModel.selectValue?.value ?? "";
    var list = ["-s", deviceId, "logcat", "$level"];
    if (isFilterPackage) {
      list.add("--pid=$pid");
    }
    execAdb(list, onProcess: (process) {
      _process = process;
      process.stdout.transform(const Utf8Decoder()).listen((line) {
        if (filterContent.isNotEmpty
            ? line.toLowerCase().contains(filterContent.toLowerCase())
            : true) {
          if (logList.length > 1000) {
            logList.removeAt(0);
          }
          logList.add(line);
          notifyListeners();
          if (isShowLast) {
            scrollController.jumpTo(
              scrollController.position.maxScrollExtent,
            );
          }
        }
      });
    });
  }

  void filter(String value) {
    filterContent = value;
    if (value.isNotEmpty) {
      logList.removeWhere((element) => !element.contains(value));
    }
    notifyListeners();
  }

  Color getLogColor(String log) {
    var split = log.split(" ");
    split.removeWhere((element) => element.isEmpty);
    String type = "";
    if (split.length > 4) {
      type = split[4];
    }
    switch (type) {
      case "V":
        break;
      case "D":
        return const Color(0xFF017F14);
      case "I":
        return const Color(0xFF0585C1);
      case "W":
        return const Color(0xFFBBBB23);
      case "E":
        return const Color(0xFFFF0006);
      case "F":
      default:
        break;
    }
    return const Color(0xFF383838);
  }

  /// 根据包名获取进程应用进程id
  Future<String> getPid() async {
    var result = await execAdb([
      "-s",
      deviceId,
      "shell",
      "ps | grep ${packageName} | awk '{print \$2}'"
    ]);
    if (result == null) {
      return "";
    }
    return result.stdout.toString().trim();
  }

  void kill() {
    _process?.kill();
    shell.kill();
  }

  Future<void> setFilterPackage(bool value) async {
    isFilterPackage = value;
    SharedPreferences.getInstance().then((preferences) {
      preferences.setBool(filterPackageKey, value);
    });
    if (value) {
      pid = await getPid();
      logList.removeWhere((element) => !element.contains(pid));
    }
    kill();
    listenerLog();
    notifyListeners();
  }

  void setCaseSensitive(bool bool) {
    isCaseSensitive = bool;
    SharedPreferences.getInstance().then((preferences) {
      preferences.setBool(caseSensitiveKey, bool);
    });
    notifyListeners();
  }

  void jsonFormat(String content) {
    try {
      if (!(content.startsWith("{") || content.startsWith("["))) {
        throw FormatException("字符串不是json");
      }
      var jsonObject = json.decode(content);

      // 使用 JsonEncoder 进行格式化
      var encoder = JsonEncoder.withIndent('  '); // 两个空格缩进
      String formattedJson = encoder.convert(jsonObject);
      contentController.text = formattedJson;
      checkStateStr = "解析成功";
      print("解析完成");
    } on FormatException catch (e) {
      print("解析出错：${e.message}");
      content = "?";
      checkStateStr = "解析失败";
    } catch (e) {
      print("其他异常");
    } finally {
      notifyListeners();
    }
  }

  void jsonFormatNestedJson(String content) {
    try {
      if (!(content.startsWith("{") || content.startsWith("["))) {
        throw FormatException("字符串不是json");
      }
      var jsonObject = parseNestedJson2(content);

      // 使用 JsonEncoder 进行格式化
      var encoder = JsonEncoder.withIndent('  '); // 两个空格缩进
      String formattedJson = encoder.convert(jsonObject);
      contentController.text = formattedJson;
      checkStateStr = "解析成功";
      print("解析完成");
    } on FormatException catch (e) {
      print("解析出错：${e.message}");
      content = "?";
      checkStateStr = "解析失败";
    } catch (e) {
      print("其他异常");
    } finally {
      notifyListeners();
    }
  }

  void formatLog() {
    try {
      // 创建一个StringBuffer来累积JSON字符串
      // 用于保存提取出的 JSON 字符串
      // 用于保存提取出的 JSON 字符串
      StringBuffer jsonStringBuffer = StringBuffer();

      var inputContent = contentController.text;
      // 按行处理日志
      List<String> logLines = inputContent.split('\n');
// 正则表达式，用于匹配类似于 '2024-08-28 09:26:11.956 27561-6780 okgo com.sczhuoshi.appzzb I ' 的行
      final regex =
          RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3} \d+-\d+ .+ I');

      for (String line in logLines) {
        String trimmedLine = line.trim();
        if (regex.hasMatch(trimmedLine)) {
          continue;
        }
        jsonStringBuffer.write(trimmedLine);
      }

      // 获取完整的 JSON 字符串
      String jsonString = jsonStringBuffer.toString();

      var jsonObject = json.decode(jsonString);
      // 将解析后的 Map 再次转换为格式化的 JSON 字符串
      String formattedJson = JsonEncoder.withIndent('  ').convert(jsonObject);
      contentController.text = formattedJson;
      notifyListeners();
      checkStateStr = "解析成功";
      print("解析完成");
    } on FormatException catch (e) {
      print("解析出错：${e.message}");
      checkStateStr = "解析失败";
    } catch (Ex) {
      // print("e:${e.m}")
      print("其他异常");
    } finally {
      notifyListeners();
    }
  }

  bool checkIvOrKey() {
    if (ivController.text.trim().isEmpty) {
      checkStateStr = "请输入iv";
      notifyListeners();
      return false;
    }
    if (keyController.text.trim().isEmpty) {
      checkStateStr = "请输入key";
      notifyListeners();
      return false;
    }

    SharedPreferences.getInstance().then((preferences) {
      preferences.setString(aesIvKey, ivController.text);
      preferences.setString(aesKeyKey, keyController.text);
    });
    return true;
  }

  void decode(String content) {
    try {
      if (!checkIvOrKey()) {
        return;
      }


      String str = _doDecode(content);
      contentController.text = str;
      checkStateStr = "解析成功";
    } catch (e) {
      print("解密出错");
      checkStateStr = "解密出错";
      debugPrintStack();
    } finally {
      notifyListeners();
    }
  }

  void encrypt(String content) {
    try {
      if (!checkIvOrKey()) {
        return;
      }


      var str = AESCrypto.encrypt(
          ivController.text.trim(), keyController.text.trim(), content.trim());
      contentController.text = str;
      notifyListeners();
    } catch (e) {
      print("加密出错");
      checkStateStr = "加密出错";
      print(e);
      debugPrintStack();
    } finally {
      notifyListeners();
    }
  }

  String _doDecode(String content) {
    // var string = AESCrypto.decrypt(
    //     keyController.text.trim(), keyController.text.trim(), content.trim());

    var string = AESCrypto.decrypt(
        ivController.text.trim(), keyController.text.trim(), content.trim());
    return string;
  }

  void decodeAndJsonFormat(String content) {
    try {
      if (!checkIvOrKey()) {
        return;
      }

      var string = _doDecode(content);
      jsonFormat(string);
    } catch (e) {
      print("加密出错");
      checkStateStr = "解密出错";
    } finally {
      notifyListeners();
    }
  }

  void copyLog(String log) {
    Clipboard.setData(ClipboardData(text: log));
  }

  void clearText() {
    contentController.text = "";
    checkStateStr = "";
    notifyListeners();
  }
}

dynamic parseNestedJson2(dynamic jsonContent) {
  if (jsonContent is String) {
    try {
      // 尝试将字符串解析为 JSON 对象
      final parsed = jsonDecode(jsonContent);

      // 递归地解析嵌套的 JSON 对象
      return parseNestedJson2(parsed);
    } catch (e) {
      // 如果解析失败，保持原样返回字符串
      return jsonContent;
    }
  } else if (jsonContent is Map<String, dynamic>) {
    // 如果是 Map，递归解析其中的每个值
    return jsonContent
        .map((key, value) => MapEntry(key, parseNestedJson2(value)));
  } else if (jsonContent is List) {
    // 如果是 List，递归解析列表中的每个元素
    return jsonContent.map(parseNestedJson2).toList();
  }

  // 如果既不是字符串，也不是 Map 或 List，则返回原始值
  return jsonContent;
}

Map<String, dynamic> parseNestedJson1(String jsonString) {
  // 将最外层的 JSON 字符串解析为 Map
  Map<String, dynamic> decodedJson = jsonDecode(jsonString);

  // 遍历 Map 的每个键值对
  decodedJson.forEach((key, value) {
    if (value is String) {
      try {
        // 尝试解析字符串值为嵌套的 JSON 对象
        var nestedJson = jsonDecode(value);
        if (nestedJson is Map || nestedJson is List) {
          // 如果成功解析，替换原字符串值
          decodedJson[key] = nestedJson;
        }
      } catch (e) {
        // 如果解析失败，保持原字符串值
      }
    }
  });

  return decodedJson;
}

class FilterLevel extends PopUpMenuItem {
  String name;
  String value;

  FilterLevel(this.name, this.value) : super(name);
}
