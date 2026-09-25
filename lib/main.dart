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
      // 跟随系统明暗主题自动切换。
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
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

  /// 路径上所有像素（含端点，轴对齐直线）。
  List<_Pixel> get path {
    final List<_Pixel> out = <_Pixel>[];
    if (a.y == b.y) {
      final int x0 = math.min(a.x, b.x);
      final int x1 = math.max(a.x, b.x);
      for (int x = x0; x <= x1; x++) {
        out.add(_Pixel(x, a.y));
      }
    } else {
      final int y0 = math.min(a.y, b.y);
      final int y1 = math.max(a.y, b.y);
      for (int y = y0; y <= y1; y++) {
        out.add(_Pixel(a.x, y));
      }
    }
    return out;
  }
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
  int? _selectedMeasurementIndex;

  /// 允许缩小到的最小缩放（初始完整显示整图的缩放），禁止继续缩小。
  double _minScale = 0.1;

  /// 单个图片像素在屏幕上显示达到该逻辑像素数后解锁像素选择。
  static const double _unlockScale = 10.0;

  /// InteractiveViewer 允许的最大缩放。
  static const double _maxScale = 60.0;

  /// 允许平移出视口的最大边距（逻辑像素），禁止无限拖拽。
  static const double _boundaryMargin = 40.0;

  /// 是否正在手势缩放/拖拽（期间不强制回中，避免打架）。
  bool _interacting = false;

  /// 放大到极限时，屏幕中心像素周围绘制简方格的半径（单位：图片像素）。
  static const int _gridRadius = 30;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_centerIfAtMinScale);
  }

  @override
  void dispose() {
    _controller.removeListener(_centerIfAtMinScale);
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
      _selectedMeasurementIndex = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitImage());
  }

  /// 初始将整张图片完整居中显示在视口内，并记下允许缩小到的最小缩放。
  void _fitImage() {
    final Size? size = _viewSize;
    final ui.Image? img = _image;
    if (size == null || img == null) return;
    final double s =
        math.min(size.width / img.width, size.height / img.height);
    _minScale = s;
    _applyCenteredMatrix(s);
  }

  /// 将当前图片以缩放 [s] 居中放到视口正中。
  void _applyCenteredMatrix(double s) {
    final Size? size = _viewSize;
    final ui.Image? img = _image;
    if (size == null || img == null) return;
    final double dx = (size.width - img.width * s) / 2;
    final double dy = (size.height - img.height * s) / 2;
    _controller.value = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy);
  }

  /// 缩放到极限（最小缩放）后，强制把图片摆回屏幕中心，避免停在左上角。
  void _centerIfAtMinScale() {
    if (_interacting) return;
    final ui.Image? img = _image;
    final Size? size = _viewSize;
    if (img == null || size == null) return;
    final double scale = _controller.value.getMaxScaleOnAxis();
    if (scale > _minScale * 1.02) return;
    final t = _controller.value.storage;
    final double dx = (size.width - img.width * scale) / 2;
    final double dy = (size.height - img.height * scale) / 2;
    if ((t[12] - dx).abs() > 0.5 || (t[13] - dy).abs() > 0.5) {
      _applyCenteredMatrix(scale);
    }
  }

  void _clearAll() {
    setState(() {
      _anchor = null;
      _measurements.clear();
      _selectedMeasurementIndex = null;
    });
  }

  void _deleteMeasurement(int index) {
    setState(() {
      _measurements.removeAt(index);
      if (_selectedMeasurementIndex == index) {
        _selectedMeasurementIndex = null;
      } else if (_selectedMeasurementIndex != null &&
          _selectedMeasurementIndex! > index) {
        _selectedMeasurementIndex = _selectedMeasurementIndex! - 1;
      }
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

    setState(() => _selectedMeasurementIndex = null);

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
                  hintText: '临时笔记',
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
        } else if (scale >= _maxScale * 0.99) {
          text = '已放大到极限 · 中心 ${_gridRadius}px 范围显示像素方格';
        } else if (unlocked) {
          text = '已解锁像素选择 · 当前缩放 ${scale.toStringAsFixed(1)} px/像素';
        } else {
          text = '缩放 ${scale.toStringAsFixed(1)} px/像素 · 放大到单个像素 10px 后解锁';
        }
        final ColorScheme scheme = Theme.of(context).colorScheme;
        return Container(
          width: double.infinity,
          color: unlocked
              ? scheme.primary.withValues(alpha: 0.15)
              : scheme.onSurface.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: unlocked ? scheme.primary : scheme.onSurfaceVariant,
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
                  // 缩小极限：不允许比「整图完整显示」更小；平移极限：不允许无限拖出视口。
                  minScale: _minScale,
                  maxScale: _maxScale,
                  boundaryMargin: const EdgeInsets.all(_boundaryMargin),
                  onInteractionStart: (_) => _interacting = true,
                  onInteractionEnd: (_) {
                    _interacting = false;
                    _centerIfAtMinScale();
                  },
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
                        selectedMeasurementIndex: _selectedMeasurementIndex,
                        viewSize: Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned.fill(
              child: ValueListenableBuilder<Matrix4>(
                valueListenable: _controller,
                builder: (BuildContext context, Matrix4 m, Widget? _) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (int i = 0; i < _measurements.length; i++)
                        _buildMeasurementLabel(i, _measurements[i], m),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// 测距距离标签；点击后在旁边弹出删除选项。
  Widget _buildMeasurementLabel(int index, _Measurement mes, Matrix4 m) {
    final Offset mid = _measurementMid(m, mes);
    final bool selected = _selectedMeasurementIndex == index;

    final Widget label = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedMeasurementIndex = selected ? null : index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFC62828) : const Color(0xCC000000),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${mes.dist} px',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    final Widget content = selected
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              label,
              const SizedBox(width: 4),
              Material(
                color: const Color(0xFFC62828),
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _deleteMeasurement(index),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.delete_outline,
                        size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          )
        : label;

    return Positioned(
      left: mid.dx,
      top: mid.dy,
      child: Transform.translate(
        offset: const Offset(-20, -14),
        child: content,
      ),
    );
  }

  Offset _measurementMid(Matrix4 m, _Measurement mes) {
    final Offset p1 = _viewportOf(m, mes.a);
    final Offset p2 = _viewportOf(m, mes.b);
    return Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
  }

  Offset _viewportOf(Matrix4 m, _Pixel p) {
    final s = m.storage;
    final double cx = p.x + 0.5;
    final double cy = p.y + 0.5;
    return Offset(
      s[0] * cx + s[4] * cy + s[12],
      s[1] * cx + s[5] * cy + s[13],
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

/// 在视口坐标系中绘制：像素方格、测距高亮红框、选中点。
class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.matrix,
    required this.anchor,
    required this.measurements,
    required this.selectedMeasurementIndex,
    required this.viewSize,
  });

  final Matrix4 matrix;
  final _Pixel? anchor;
  final List<_Measurement> measurements;
  final int? selectedMeasurementIndex;
  final Size viewSize;

  /// 单个图片像素在屏幕上显示达到该逻辑像素数后解锁像素选择。
  static const double _unlockScale = 10.0;

  /// InteractiveViewer 允许的最大缩放。
  static const double _maxScale = 60.0;

  /// 放大到极限时，屏幕中心像素周围绘制简方格的半径（单位：图片像素）。
  static const int _gridRadius = 30;

  Offset _vp(_Pixel p) {
    final m = matrix.storage;
    final double cx = p.x + 0.5;
    final double cy = p.y + 0.5;
    return Offset(m[0] * cx + m[4] * cy + m[12], m[1] * cx + m[5] * cy + m[13]);
  }

  /// 以像素中心反推，得到 [x,y] 到 [x+1,y+1] 在视口中的矩形。
  Rect _pixelRect(int x, int y) {
    final Offset tl = _vp(_Pixel(x, y)) - _cellHalf();
    final Offset br = _vp(_Pixel(x, y)) + _cellHalf();
    return Rect.fromPoints(tl, br);
  }

  Offset _cellHalf() {
    final m = matrix.storage;
    // 一个图片像素的屏幕尺寸的一半。
    return Offset(m[0] / 2, m[5] / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = matrix.getMaxScaleOnAxis();
    final bool atLimit = scale >= _maxScale * 0.99;

    // 放大到极限时：屏幕中心像素半径 30px 圆形范围内画简方格。
    if (atLimit && scale >= _unlockScale) {
      final Offset centerVp = Offset(size.width / 2, size.height / 2);
      final m = matrix.storage;
      final double ix = (centerVp.dx - m[12]) / m[0];
      final double iy = (centerVp.dy - m[13]) / m[5];
      final int cx = ix.floor();
      final int cy = iy.floor();

      final Paint grid = Paint()
        ..color = const Color(0x99888888)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final int r = _gridRadius;
      for (int dy = -r; dy <= r; dy++) {
        for (int dx = -r; dx <= r; dx++) {
          if (dx * dx + dy * dy > r * r) continue;
          canvas.drawRect(_pixelRect(cx + dx, cy + dy), grid);
        }
      }
    }

    // 测距路径：每个像素画红色高亮框。
    final Paint frameSelected = Paint()
      ..color = const Color(0xFFFF1744)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final Paint frameNormal = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < measurements.length; i++) {
      final _Measurement mes = measurements[i];
      final Paint paint =
          selectedMeasurementIndex == i ? frameSelected : frameNormal;
      for (final _Pixel p in mes.path) {
        canvas.drawRect(_pixelRect(p.x, p.y), paint);
      }
    }

    // 选中点与测距端点。
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
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      oldDelegate.anchor != anchor ||
      oldDelegate.selectedMeasurementIndex != selectedMeasurementIndex ||
      oldDelegate.measurements.length != measurements.length ||
      oldDelegate.viewSize != viewSize ||
      oldDelegate.matrix != matrix;
}
