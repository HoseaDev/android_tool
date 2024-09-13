import 'package:android_tool/widget/text_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 定义一个类来存储输入字段的信息
class InputField {
  final String label; // 显示在 TextField 上的标签
  final String hint; // TextField 的提示文字
  final String key; // 用来存储和返回输入的数据的键
  final String inputFormat; // 输入的格式类型，比如 "number", "text"
  //如果值为空的时候，默认hint值
  final bool defaultHintValue;

  InputField(
      {required this.label,
      required this.hint,
      required this.key,
      this.inputFormat = "text",
      this.defaultHintValue = true});
}

class InputListDialog extends StatefulWidget {
  final String? title;
  final List<InputField> inputFields; // 用来存储所有输入字段

  InputListDialog({Key? key, this.title, required this.inputFields})
      : super(key: key);

  @override
  _InputListDialogState createState() => _InputListDialogState();
}

class _InputListDialogState extends State<InputListDialog> {
  // 用于存储每个 TextField 的控制器
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // 初始化每个字段对应的 TextEditingController
    widget.inputFields.forEach((inputField) {
      _controllers[inputField.key] = TextEditingController();
    });
  }

  @override
  void dispose() {
    // 销毁所有的 TextEditingController
    _controllers.values.forEach((controller) {
      controller.dispose();
    });
    super.dispose();
  }

  // 根据 inputFormat 返回输入限制
  List<TextInputFormatter> _getInputFormatters(String inputFormat) {
    switch (inputFormat) {
      case 'number': // 只允许输入数字
        return [FilteringTextInputFormatter.digitsOnly];
      case 'text': // 允许输入所有文本
        return [FilteringTextInputFormatter.singleLineFormatter];
      default:
        return [FilteringTextInputFormatter.singleLineFormatter];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: TextView(widget.title ?? ""),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.inputFields.map((inputField) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextView(inputField.label), // 显示 label
                  TextField(
                    controller: _controllers[inputField.key],
                    decoration: InputDecoration(
                      hintText: inputField.hint, // 显示 hint
                    ),
                    inputFormatters: _getInputFormatters(
                        inputField.inputFormat), // 根据输入格式限制输入
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const TextView("确定"),
          onPressed: () {
            // 收集所有输入的数据
            Map<String, String> inputData = {};
            _controllers.forEach((key, controller) {
              // 判断输入值是否为空，如果为空且defaultHintValue为true，使用hint作为默认值
              InputField? field = widget.inputFields.firstWhere(
                      (element) => element.key == key);
              if (field != null) {
                if (controller.text.isNotEmpty) {
                  inputData[key] = controller.text;
                } else if (field.defaultHintValue) {
                  inputData[key] = field.hint; // 使用hint值作为默认值
                }else{
                  inputData[key] = controller.text;
                }
              }
            });
            // 返回输入的数据
            Navigator.of(context).pop(inputData);
          },
        ),
      ],
    );
  }
}
