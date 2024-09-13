import 'package:android_tool/page/android_log/android_log_view_model.dart';
import 'package:android_tool/page/common/base_page.dart';
import 'package:android_tool/widget/pop_up_menu_button.dart';
import 'package:android_tool/widget/text_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:provider/provider.dart';
import 'package:substring_highlight/substring_highlight.dart';

import 'custom_log_view_model.dart';

class CustomLogPage extends StatefulWidget {
  final String deviceId;

  const CustomLogPage({Key? key, required this.deviceId}) : super(key: key);

  @override
  State<CustomLogPage> createState() => _CustomLogPageState();
}

class _CustomLogPageState extends BasePage<CustomLogPage, CustomLogViewModel> {
  @override
  void initState() {
    super.initState();
    viewModel.init();
  }

  @override
  Widget contentView(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: viewModel.handleKey,
      autofocus: true,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(width: 16),
              const TextView("日志："),
              const SizedBox(width: 12),
              OutlinedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(Colors.blue),
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  textStyle: WidgetStateProperty.all<TextStyle>(
                      TextStyle(color: Colors.white30)),
                  overlayColor: WidgetStateProperty.all<Color>(Colors.blue),
                  side: WidgetStateProperty.all<BorderSide>(
                      (BorderSide(color: Colors.blue))),
                ),
                onPressed: () {
                  viewModel.jsonFormat(viewModel.contentController.text);
                },
                child: Text("格式化JSON"),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(Colors.blue),
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  textStyle: WidgetStateProperty.all<TextStyle>(
                      TextStyle(color: Colors.white30)),
                  overlayColor: WidgetStateProperty.all<Color>(Colors.blue),
                  side: WidgetStateProperty.all<BorderSide>(
                      (BorderSide(color: Colors.blue))),
                ),
                onPressed: () {
                  viewModel
                      .jsonFormatNestedJson(viewModel.contentController.text);
                },
                child: Text("解析嵌套JSON字符串"),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(Colors.blue),
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  textStyle: WidgetStateProperty.all<TextStyle>(
                      TextStyle(color: Colors.white30)),
                  overlayColor: WidgetStateProperty.all<Color>(Colors.blue),
                  side: WidgetStateProperty.all<BorderSide>(
                      (BorderSide(color: Colors.blue))),
                ),
                onPressed: () {
                  viewModel.formatLog();
                },
                child: Text("格式化Android强制分段日志"),
              ),
              Container(
                height: 33,
                width: 150,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                // decoration: BoxDecoration(
                //   border: Border.all(color: Colors.grey),
                //   borderRadius: BorderRadius.circular(5),
                // ),
                child: TextField(
                  controller: viewModel.androidLogRegexController,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    hintText: "请输入过滤的正则",
                    border: OutlineInputBorder(),
                    hintStyle: TextStyle(fontSize: 14),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () {
                  viewModel.clearText();
                },
                child: const TextView("清空内容"),
              ),
              const SizedBox(width: 6),
              Consumer<CustomLogViewModel>(
                builder: (context, viewModel, child) {
                  return _resultStateText(viewModel);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 16),
              const TextView("加解密："),
              OutlinedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(Colors.red),
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  textStyle: WidgetStateProperty.all<TextStyle>(
                      TextStyle(color: Colors.white30)),
                  overlayColor: WidgetStateProperty.all<Color>(Colors.red),
                  side: WidgetStateProperty.all<BorderSide>(
                      (BorderSide(color: Colors.red))),
                ),
                onPressed: () {
                  viewModel.encrypt(viewModel.contentController.text);
                },
                child: Text("加密"),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(Colors.green),
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  textStyle: WidgetStateProperty.all<TextStyle>(
                      TextStyle(color: Colors.white30)),
                  overlayColor: WidgetStateProperty.all<Color>(Colors.green),
                  side: WidgetStateProperty.all<BorderSide>(
                      (BorderSide(color: Colors.green))),
                ),
                onPressed: () {
                  viewModel.decode(viewModel.contentController.text);
                },
                child: Text("解密"),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(Colors.green),
                  foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
                  textStyle: WidgetStateProperty.all<TextStyle>(
                      TextStyle(color: Colors.white30)),
                  overlayColor: WidgetStateProperty.all<Color>(Colors.green),
                  side: WidgetStateProperty.all<BorderSide>(
                      (BorderSide(color: Colors.green))),
                ),
                onPressed: () {
                  viewModel
                      .decodeAndJsonFormat(viewModel.contentController.text);
                },
                child: Text("解密格式化为JSON"),
              ),
              const SizedBox(width: 12),
              Container(
                height: 33,
                width: 150,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                // decoration: BoxDecoration(
                //   border: Border.all(color: Colors.grey),
                //   borderRadius: BorderRadius.circular(5),
                // ),
                child: TextField(
                  controller: viewModel.ivController,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    hintText: "请输入iv",
                    border: OutlineInputBorder(),
                    hintStyle: TextStyle(fontSize: 14),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 33,
                width: 150,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                // decoration: BoxDecoration(
                //   border: Border.all(color: Colors.grey),
                //   borderRadius: BorderRadius.circular(5),
                // ),
                child: TextField(
                  controller: viewModel.keyController,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    hintText: "请输入key",
                    border: OutlineInputBorder(),
                    hintStyle: TextStyle(fontSize: 14),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Selector<CustomLogViewModel, bool>(
            selector: (context, viewModel) => viewModel.showSearchBar,
            builder: (context, isFilter, child) {
              debugPrint('showSearchBar: $isFilter'); // 添加调试输出
              if (!isFilter) {
                return Container();
              }
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: viewModel.searchController,
                        decoration: InputDecoration(labelText: '搜索关键字...'),
                        onChanged: viewModel.searchText,
                        focusNode: viewModel.searchFocusNode,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_upward),
                      onPressed: viewModel.previousMatch,
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_downward),
                      onPressed: viewModel.nextMatch,
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: viewModel.close,
                    ),
                  ],
                ),
              );
            },
          ),
          _buildLogContentView(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Expanded _buildLogContentView() {
    return Expanded(
      child: Container(
        color: const Color(0xFFF0F0F0),
        child: Consumer<CustomLogViewModel>(
          builder: (context, viewModel, child) {
            return TextSelectionTheme(
              data: TextSelectionThemeData(
                selectionColor: Colors.yellow.withOpacity(0.5), // 选中的文本颜色设置为黄色
                cursorColor: Colors.black, // 光标颜色
              ),
              child: TextField(
                controller: viewModel.contentController,
                focusNode: viewModel.contentFocusNode,
                maxLines: null,
                // 允许多行输入
                expands: true,
                // 高度撑满父布局
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: '请输入文本...',
                  border: InputBorder.none, // 移除默认的下划线
                  contentPadding: EdgeInsets.all(18), // 内部边距
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  createViewModel() {
    return CustomLogViewModel(
      context,
      widget.deviceId,
    );
  }

  @override
  void dispose() {
    super.dispose();
    viewModel.scrollController.dispose();
  }

  Widget _resultStateText(CustomLogViewModel viewModel) {
    var errorTextStyle = TextStyle(color: Colors.red, fontSize: 16);
    var normalTextStyle = TextStyle(color: Colors.green, fontSize: 16);

    return Text(
      "${viewModel.checkStateStr}",
      style:
          viewModel.checkStateStr == "解析成功" ? normalTextStyle : errorTextStyle,
    );
  }
}
