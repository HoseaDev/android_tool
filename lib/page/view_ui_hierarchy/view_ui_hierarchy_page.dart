import 'dart:io';
import 'package:android_tool/page/common/base_page.dart';
import 'package:android_tool/page/view_ui_hierarchy/view_ui_hierarchy_view_model.dart';
import 'package:android_tool/widget/text_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_simple_treeview/flutter_simple_treeview.dart';
import 'package:provider/provider.dart';
import 'package:xml/xml.dart' as xml;

class ViewUIHierarchyPage extends StatefulWidget {
  final String deviceId;

  const ViewUIHierarchyPage({
    Key? key,
    required this.deviceId,
  }) : super(key: key);

  @override
  State<ViewUIHierarchyPage> createState() => _ViewUIHierarchyPageState();
}

class _ViewUIHierarchyPageState
    extends BasePage<ViewUIHierarchyPage, ViewUIHierarchyViewModel> {
  Rect? highlightedRect;
  double screenshotWidth = 0;
  double screenshotHeight = 0;
  double deviceScreenWidth = 1080; // 从 adb 获取的宽度
  double deviceScreenHeight = 2400; // 从 adb 获取的高度

  final double fixedImageWidth = 300; // 固定图片宽度
  late double fixedImageHeight; // 通过计算得到的图片高度

  // 创建两个 ScrollController，分别用于水平和垂直滚动
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    viewModel.init();
  }

  @override
  Widget contentView(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: () {
                viewModel.loadLayoutData();
              },
              child: TextView("重新加载界面"),
            ),
          ),
          Expanded(
            child: Row(
              children: <Widget>[
                Selector<ViewUIHierarchyViewModel, String>(
                  selector: (_, viewModel) => viewModel.currentScreenshotPath,
                  builder: (_, path, __) {
                    if (path.isEmpty) {
                      return Container();
                    } else {
                      return _layoutViewer(viewModel.currentScreenshotPath,
                          viewModel.currentDumpInfoPath);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  ViewUIHierarchyViewModel createViewModel() {
    return ViewUIHierarchyViewModel(context, widget.deviceId);
  }

  Widget _layoutViewer(String currentScreenshotPath, String currentDumpInfoPath) {
    // 获取图片尺寸
    if (screenshotWidth == 0 || screenshotHeight == 0) {
      _getImageSize(currentScreenshotPath);
    }

    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧显示截图
          Stack(
            children: [
              Image.file(
                File(currentScreenshotPath),
                width: fixedImageWidth, // 固定宽度300
                fit: BoxFit.contain, // 图片填充
                // 通过比例计算图片的高度
                height: fixedImageWidth * deviceScreenHeight / deviceScreenWidth,
                key: ValueKey(DateTime.now()),
              ),
              if (highlightedRect != null)
                _buildHighlightRect(), // 高亮红框部分
            ],
          ),
          // 右侧显示层次结构树，宽度固定为500，同时支持水平和垂直滚动
          SizedBox(
            width: 620, // 固定宽度
            child: Selector<ViewUIHierarchyViewModel, xml.XmlDocument?>(
              selector: (BuildContext, ViewUIHierarchyViewModel) => viewModel.layoutData,
              builder: (BuildContext context, xml.XmlDocument? value, Widget? child) {
                if (value != null) {
                  return Scrollbar(
                    controller: _verticalScrollController, // 使用垂直滚动控制器
                    thumbVisibility: true, // 滚动条可见
                    child: SingleChildScrollView(
                      controller: _horizontalScrollController, // 水平滚动控制器
                      scrollDirection: Axis.horizontal, // 水平滚动
                      child: SingleChildScrollView(
                        controller: _verticalScrollController, // 垂直滚动控制器
                        scrollDirection: Axis.vertical, // 垂直滚动
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: 300), // 保证最小宽度为300
                          child: TreeView(
                            nodes: [
                              parseXmlNode(viewModel.layoutData!.rootElement)
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // 构建红框，用于高亮显示选中的UI元素
  Widget _buildHighlightRect() {
    // 计算设备到窗口的缩放比例
    double scaleX = fixedImageWidth / deviceScreenWidth;

    // 计算显示的图片实际高度
    double displayedImageHeight = (fixedImageWidth * deviceScreenHeight) / deviceScreenWidth;

    // 修正 Y 轴的缩放比例
    double scaleY = displayedImageHeight / deviceScreenHeight;

    // 修正Y轴的偏移量，确保计算后的高度与原始设备比例一致
    double correctedTop = highlightedRect!.top * scaleY;
    debugPrint("scaleX:${scaleX}");
    debugPrint("scaleY:${scaleY}");
    debugPrint("highlightedRect!.top:${highlightedRect!.top}");
    debugPrint("correctedTop:${correctedTop}");
    // 不需要手动减去顶部按钮高度，如果Stack已经考虑了偏移
    return Positioned(
      left: highlightedRect!.left * scaleX,
      top: correctedTop, // 使用修正后的Y轴坐标
      width: highlightedRect!.width * scaleX,
      height: highlightedRect!.height * scaleY,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red, width: 2),
        ),
      ),
    );
  }


  // 递归解析 XML 布局节点
  TreeNode parseXmlNode(xml.XmlElement node) {
    String className = node.getAttribute('class') ?? 'Android布局结构';
    String contentDesc = node.getAttribute('content-desc') ?? '';
    String resourceId = node.getAttribute('resource-id') ?? '';
    String text = node.getAttribute('text') ?? '';
    Rect? bounds = parseBounds(node);
    StringBuffer sb = StringBuffer();
    // if (className.isNotEmpty) sb.write(className);
    // if (contentDesc.isNotEmpty) sb.write(contentDesc);
    // if (resourceId.isNotEmpty) sb.write(resourceId);
    // if (text.isNotEmpty) sb.write(text);
    sb.writeAll([className, contentDesc, resourceId, text], "  ");

    List<TreeNode> children = [];
    node.children.whereType<xml.XmlElement>().forEach((child) {
      children.add(parseXmlNode(child));
    });

    return TreeNode(
      content: GestureDetector(
        onTap: () {
          if (bounds != null) {
            setState(() {
              highlightedRect = bounds;
            });
          }
        },
        child: Text(sb.toString()),
      ),
      children: children,
    );
  }

  // 解析布局节点的 bounds
  Rect? parseBounds(xml.XmlElement node) {
    final boundsString = node.getAttribute('bounds');
    if (boundsString != null) {
      final matches =
      RegExp(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]').firstMatch(boundsString);
      if (matches != null) {
        final left = int.parse(matches.group(1)!);
        final top = int.parse(matches.group(2)!);
        final right = int.parse(matches.group(3)!);
        final bottom = int.parse(matches.group(4)!);
        return Rect.fromLTRB(
          left.toDouble(),
          top.toDouble(),
          right.toDouble(),
          bottom.toDouble(),
        );
      }
    }
    return null;
  }

  // 动态获取图片的尺寸
  void _getImageSize(String imagePath) {
    final image = Image.file(File(imagePath));
    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        setState(() {
          screenshotWidth = info.image.width.toDouble();
          screenshotHeight = info.image.height.toDouble();
        });
      }),
    );
  }
}
