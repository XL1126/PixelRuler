import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const PixelRulerApp());
}

class PixelRulerApp extends StatelessWidget {
  const PixelRulerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '像素测距仪',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

/// 一个图片像素的整数坐标。
class _Pixel {
  const _Pixel(this.x, this.y);
  final int x;
  final int y;
}

/// 一次完成的测距：两个轴对齐的像素点及其距离。
class _Measurement {
  _Measurement(this.a, this.b) : dist = (b.x - a.x).abs() + (b.y - a.y).abs();
  final _Pixel a;
  final _Pixel b;
  final int dist;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  final TransformationController _controller = TransformationController();
  final TextEditingController _notesController = TextEditingController();

  ui.Image? _image;
  _Pixel? _anchor;
  final List<_Measurement> _measurements = [];
  Size? _viewSize;

  /// 单个图片像素在屏幕上显示达到该逻辑像素数后解锁像素选择。
  static const double _unlockScale = 10.0;

  @override
  void dispose() {
    _controller.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _hasPoints => _anchor != null || _measurements.isNotEmpty;

  Future<void> _pickImage() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ui.Image img = await decodeImageFromList(bytes);
    if (!mounted) return;
    setState(() {
      _image = img;
      _anchor = null;
      _measurements.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitImage());
  }

  /// 初始将整张图片完整居中显示在视口内。
  void _fitImage() {
    final Size? size = _viewSize;
    final ui.Image? img = _image;
    if (size == null || img == null) return;
    final double s =
        math.min(size.width / img.width, size.height / img.height);
    final double dx = (size.width - img.width * s) / 2;
    final double dy = (size.height - img.height * s) / 2;
    _controller.value = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy);
  }

  void _clearAll() {
    setState(() {
      _anchor = null;
      _measurements.clear();
    });
  }

  /// 视口坐标 -> 图片坐标（假设矩阵仅含平移 + 缩放，无旋转）。
  Offset _toImage(Offset vp) {
    final m = _controller.value.storage;
    final double sx = m[0];
    final double sy = m[5];
    return Offset((vp.dx - m[12]) / sx, (vp.dy - m[13]) / sy);
  }

  void _handleTap(Offset vp) {
    final ui.Image? img = _image;
    if (img == null) return;
    final double scale = _controller.value.getMaxScaleOnAxis();
    if (scale < _unlockScale) return;

    final Offset p = _toImage(vp);
    final int x = p.dx.floor();
    final int y = p.dy.floor();
    if (x < 0 || y < 0 || x >= img.width || y >= img.height) return;

    if (_anchor == null) {
      setState(() => _anchor = _Pixel(x, y));
    } else {
      final _Pixel a = _anchor!;
      final _Pixel b = _Pixel(x, y);
      final int dx = (b.x - a.x).abs();
      final int dy = (b.y - a.y).abs();
      // 只允许同行或同列（轴对齐），禁止斜向与重复点击同一点。
      if ((dx > 0) ^ (dy > 0)) {
        setState(() {
          _measurements.add(_Measurement(a, b));
          _anchor = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('像素测距仪'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _image == null ? null : _pickImage,
            icon: const Icon(Icons.photo_library),
            tooltip: '重新选择图片',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  hintText: '临时笔记（无任何功能）',
                  prefixIcon: Icon(Icons.edit_note),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            _buildStatusBar(),
            Expanded(child: _buildViewer()),
          ],
        ),
      ),
      floatingActionButton: _hasPoints
          ? FloatingActionButton.extended(
              onPressed: _clearAll,
              icon: const Icon(Icons.layers_clear),
              label: const Text('清除'),
            )
          : null,
    );
  }

  Widget _buildStatusBar() {
    return ValueListenableBuilder<Matrix4>(
      valueListenable: _controller,
      builder: (BuildContext context, Matrix4 m, Widget? _) {
        final double scale = m.getMaxScaleOnAxis();
        final bool unlocked = scale >= _unlockScale;
        final String text;
        if (_image == null) {
          text = '请先选择一张图片';
        } else if (unlocked) {
          text = '已解锁像素选择 · 当前缩放 ${scale.toStringAsFixed(1)} px/像素';
        } else {
          text = '缩放 ${scale.toStringAsFixed(1)} px/像素 · 放大到单个像素 10px 后解锁';
        }
        return Container(
          width: double.infinity,
          color: unlocked
              ? Colors.green.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.15),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: unlocked ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ),
        );
      },
    );
  }

  Widget _buildViewer() {
    final ui.Image? img = _image;
    if (img == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_search, size: 72, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('请选择一张图片开始像素测距'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('选择图片'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        final double imgW = img.width.toDouble();
        final double imgH = img.height.toDouble();

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (TapUpDetails d) => _handleTap(d.localPosition),
                child: InteractiveViewer(
                  transformationController: _controller,
                  constrained: false,
                  minScale: 0.01,
                  maxScale: 60,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  child: SizedBox(
                    width: imgW,
                    height: imgH,
                    child: Stack(
                      children: [
                        RawImage(
                          image: img,
                          width: imgW,
                          height: imgH,
                          fit: BoxFit.fill,
                          // 关闭插值采样，放大后显示为锐利的像素色块而非模糊过渡。
                          filterQuality: FilterQuality.none,
                        ),
                        CustomPaint(
                          size: Size(imgW, imgH),
                          painter: _GrayOverlayPainter(
                            anchor: _anchor,
                            imgW: img.width,
                            imgH: img.height,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<Matrix4>(
                  valueListenable: _controller,
                  builder: (BuildContext context, Matrix4 m, Widget? _) {
                    return CustomPaint(
                      painter: _OverlayPainter(
                        matrix: m,
                        anchor: _anchor,
                        measurements: _measurements,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 在选中第一个像素后，将十字（其所在行与列）之外的区域覆盖为灰色。
class _GrayOverlayPainter extends CustomPainter {
  _GrayOverlayPainter({
    required this.anchor,
    required this.imgW,
    required this.imgH,
  });

  final _Pixel? anchor;
  final int imgW;
  final int imgH;

  @override
  void paint(Canvas canvas, Size size) {
    final _Pixel? a = anchor;
    if (a == null) return;
    final Paint grey = Paint()..color = const Color(0xAA000000);
    final double x = a.x.toDouble();
    final double y = a.y.toDouble();
    final double w = imgW.toDouble();
    final double h = imgH.toDouble();
    // 四个灰色象限，仅保留十字（整行 y 与整列 x）不被覆盖。
    canvas.drawRect(Rect.fromLTRB(0, 0, x, y), grey);
    canvas.drawRect(Rect.fromLTRB(x + 1, 0, w, y), grey);
    canvas.drawRect(Rect.fromLTRB(0, y + 1, x, h), grey);
    canvas.drawRect(Rect.fromLTRB(x + 1, y + 1, w, h), grey);
  }

  @override
  bool shouldRepaint(covariant _GrayOverlayPainter oldDelegate) =>
      oldDelegate.anchor != anchor ||
      oldDelegate.imgW != imgW ||
      oldDelegate.imgH != imgH;
}

/// 在视口坐标系中绘制选中点、测距线段与距离文字。
class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.matrix,
    required this.anchor,
    required this.measurements,
  });

  final Matrix4 matrix;
  final _Pixel? anchor;
  final List<_Measurement> measurements;

  Offset _vp(_Pixel p) {
    final m = matrix.storage;
    final double cx = p.x + 0.5;
    final double cy = p.y + 0.5;
    return Offset(m[0] * cx + m[4] * cy + m[12], m[1] * cx + m[5] * cy + m[13]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final _Measurement mes in measurements) {
      final Offset p1 = _vp(mes.a);
      final Offset p2 = _vp(mes.b);
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = const Color(0xFFFF5252)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );

      const TextStyle labelStyle = TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      );
      final TextPainter tp = TextPainter(
        text: TextSpan(text: '${mes.dist} px', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final Offset mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      final Rect rect = Rect.fromCenter(
        center: mid,
        width: tp.width + 12,
        height: tp.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = const Color(0xCC000000),
      );
      tp.paint(canvas, rect.topLeft + const Offset(6, 3));
    }

    final List<_Pixel> points = <_Pixel>[];
    if (anchor != null) {
      points.add(anchor!);
    }
    for (final _Measurement mes in measurements) {
      points.add(mes.a);
      points.add(mes.b);
    }

    final Paint dot = Paint()..color = const Color(0xFFFF1744);
    final Paint ring = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final _Pixel p in points) {
      final Offset c = _vp(p);
      canvas.drawCircle(c, 6, dot);
      canvas.drawCircle(c, 6, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) => true;
}