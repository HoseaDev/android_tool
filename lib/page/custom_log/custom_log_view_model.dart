import 'dart:convert';
import 'dart:io';

import 'package:android_tool/page/common/app.dart';
import 'package:android_tool/page/common/base_view_model.dart';
import 'package:android_tool/page/common/package_help_mixin.dart';
import 'package:android_tool/utils/aes_crypto.dart';
import 'package:android_tool/widget/pop_up_menu_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:json_editor_2/json_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomLogViewModel extends BaseViewModel with PackageHelpMixin {
  static const String colorLogKey = 'colorLog';
  static const String filterPackageKey = 'filterPackage';
  static const String caseSensitiveKey = 'caseSensitive';
  static const String aesIvKey = 'aesIv';
  static const String aesKeyKey = 'aesKey';
  static const String androidLogRegexKey = 'androidLogRegex';

  String deviceId;

  bool isFilterPackage = false;
  String filterContent = "";
  String checkStateStr = "";

  List<String> logList = [];

  FlutterListViewController scrollController = FlutterListViewController();

  // TextEditingController contentController = TextEditingController();
  RichTextEditingController contentController = RichTextEditingController();
  TextEditingController ivController = TextEditingController();
  TextEditingController keyController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  TextEditingController androidLogRegexController = TextEditingController();
  FocusNode searchFocusNode = FocusNode(); // 用于控制 TextField 焦点
  bool showSearchBar = false;
  int currentSearchIndex = -1;
  List<int> matchIndexes = [];
  FocusNode contentFocusNode = FocusNode();

  bool isCaseSensitive = false;

  bool isShowLast = true;

  String pid = "";

  int findIndex = -1;
  int? _lastCursorPosition;


  CustomLogViewModel(
    BuildContext context,
    this.deviceId,
  ) : super(context) {
    App().eventBus.on<DeviceIdEvent>().listen((event) async {
      logList.clear();
      deviceId = event.deviceId;
      if (deviceId.isEmpty) {
        resetPackage();
        return;
      }
      await getInstalledApp(deviceId);
    });

    SharedPreferences.getInstance().then((preferences) {
      isFilterPackage = preferences.getBool(filterPackageKey) ?? false;
      isCaseSensitive = preferences.getBool(caseSensitiveKey) ?? false;
    });
    contentFocusNode.addListener(_onFocusChange);

  }

  void _onFocusChange() {
    debugPrint("_onFocusChange:${contentFocusNode.hasFocus}");
    if(showSearchBar){
      //每一次的位置都是最后一次，不管是不是失去焦点。
      _lastCursorPosition = contentController.selection.base.offset;
    }else{
      //没有显示搜索按钮的时候，当他失去焦点的那一刻记一下位置。
      if (contentFocusNode.hasFocus) {
        if (_lastCursorPosition != null) {
          // Set the cursor position when focus is gained
          contentController.selection = TextSelection.fromPosition(
            TextPosition(offset: _lastCursorPosition!),
          );
        }
      } else {
        // Record the cursor position when focus is lost
        _lastCursorPosition = contentController.selection.base.offset;
      }
    }
  }

  void close() {
    showSearchBar = false;
    searchController.clear();
    matchIndexes.clear();
    notifyListeners();
  }

  void init() async {
    SharedPreferences.getInstance().then((preferences) {
      ivController.text = preferences.getString(aesIvKey) ?? "";
      keyController.text = preferences.getString(aesKeyKey) ?? "";
      //默认值是我们自己的正则
      androidLogRegexController.text =
          preferences.getString(androidLogRegexKey) ??
              r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}";
    });
  }

  void filter(String value) {
    filterContent = value;
    if (value.isNotEmpty) {
      logList.removeWhere((element) => !element.contains(value));
    }
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
      content = removeIfQuoted(content);
      if (!(content.startsWith("{") || content.startsWith("["))) {
        throw FormatException("字符串不是json");
      }
      var jsonObject = json.decode(content);

      // 使用 JsonEncoder 进行格式化
      var encoder = JsonEncoder.withIndent('  '); // 两个空格缩进
      String formattedJson = encoder.convert(jsonObject);
      contentController.text = formattedJson;

      checkStateStr = "解析成功";
      _lastCursorPosition = null;
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
      content = removeIfQuoted(content);
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
      _lastCursorPosition = null;
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
      StringBuffer jsonStringBuffer = StringBuffer();

      var inputContent = removeIfQuoted(contentController.text);

      // 按行处理日志
      List<String> logLines = inputContent.split('\n');


      if (androidLogRegexController.text.trim().isEmpty) {
        checkStateStr = "请输入过滤的正则";
        //保存正则到本地
        SharedPreferences.getInstance().then((preferences) {
          preferences.remove(androidLogRegexKey);
        });
        notifyListeners();
        return;
      }

      String userPattern = androidLogRegexController.text.trim();

      RegExp  regex = RegExp(userPattern);

//保存正则到本地
      SharedPreferences.getInstance().then((preferences) {
        preferences.setString(androidLogRegexKey, androidLogRegexController.text.trim());
      });


      // 如果正则表达式合法
      for (String line in logLines) {
        String trimmedLine = line.trim();
        if (regex.hasMatch(trimmedLine)) {
          continue;
        }
        jsonStringBuffer.write(trimmedLine);
      }

      // 获取完整的 JSON 字符串
      contentController.text = jsonStringBuffer.toString();
      notifyListeners();
      checkStateStr = "解析成功";
      print("解析完成");
      _lastCursorPosition = null;
    } on FormatException catch (e) {
      print("解析出错：${e.message}");
      checkStateStr = "解析失败";
    } catch (Ex) {
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
      content = removeIfQuoted(content);

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

    final decodedEncryptedText = Uri.decodeComponent(content); // 进行URL解码
    var string = AESCrypto.decrypt(ivController.text.trim(),
        keyController.text.trim(), decodedEncryptedText);
    return string;
  }

  void decodeAndJsonFormat(String content) {
    try {
      if (!checkIvOrKey()) {
        return;
      }
      content = removeIfQuoted(content);
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

  // 监听 Command + F 组合键
  void handleKey(RawKeyEvent event) {
    if (event.isMetaPressed && event.logicalKey == LogicalKeyboardKey.keyF) {
      showSearchBar = true; // 显示搜索框
      searchFocusNode.requestFocus();
      notifyListeners();
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (showSearchBar) {
        close();
      }
    }
  }

  // 搜索关键词，查找所有匹配的位置
  void searchText(String keyword) {
    String text = contentController.text.toLowerCase();
    keyword = keyword.toLowerCase();

    matchIndexes.clear();
    if (keyword.isNotEmpty) {
      int startIndex = 0;
      while (true) {
        final index = text.indexOf(keyword, startIndex);
        if (index == -1) break; // 没有更多匹配

        matchIndexes.add(index);
        startIndex = index + keyword.length; // 查找下一个匹配项
      }

      // if (_matchIndexes.isNotEmpty) {
      //   _currentSearchIndex = 0;
      //   _highlightMatch(_matchIndexes[_currentSearchIndex], keyword.length);
      // } else {
      //   _currentSearchIndex = -1;
      // }
    }
  }

  // 高亮匹配项
  void _highlightMatch(int index, int length) {
    // 设置 TextField 焦点
    // textFieldFocusNode.requestFocus();
    contentFocusNode.requestFocus();
    // 高亮选中的文本

    contentController.selection = TextSelection(
      baseOffset: index,
      extentOffset: index + length,
    );

    // 确保选中的内容自动滚动到可见区域
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelection();
    });
    notifyListeners();
  }

  // 滚动到当前选中的文本区域
  void _scrollToSelection() {
    if (contentController.selection.baseOffset != -1) {
      double offset =
          contentController.selection.baseOffset * 7.0; // 假设每个字符的宽度为7
      contentController.selection = contentController.selection.copyWith(
        baseOffset: contentController.selection.baseOffset,
        extentOffset: contentController.selection.extentOffset,
      );
    }
  }

  // 跳到下一个匹配项
  void nextMatch() {
    if (matchIndexes.isNotEmpty) {
      currentSearchIndex = (currentSearchIndex + 1) % matchIndexes.length;
      _highlightMatch(
          matchIndexes[currentSearchIndex], searchController.text.length);
    }
  }

  // 跳到上一个匹配项
  void previousMatch() {
    if (matchIndexes.isNotEmpty) {
      currentSearchIndex =
          (currentSearchIndex - 1 + matchIndexes.length) % matchIndexes.length;
      _highlightMatch(
          matchIndexes[currentSearchIndex], searchController.text.length);
    }
  }
}

String removeIfQuoted(String input) {
  // 判断字符串前后是否有引号
  input = input.trim();
  if (input.startsWith('"') && input.endsWith('"')) {
    return input.substring(1, input.length - 1);
  } else if (input.startsWith('"')) {
    return input.substring(1);
  } else if (input.endsWith('"')) {
    return input.substring(0, input.length - 1);
  }

  return input; // 否则返回原始字符串
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
