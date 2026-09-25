<div align="center">

# 📐 PixelRuler

### 像素测距仪

**在图片上精确测量像素距离的 Flutter 工具**

![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-5.0%2B-3DDC84?logo=android&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow)

[功能](#-核心功能) · [使用](#-使用方法) · [构建](#-构建) · [技术](#-技术要点)

</div>

---

## 🎯 核心功能

<table>
<tr>
<td width="50%" valign="top">

### 🔍 像素级选点
- 单指拖动缩放，**单像素 ≥ 10px** 后解锁选点
- 只允许**水平 / 垂直**轴对齐测距，杜绝斜向误差
- 起点选中后自动高亮整行、整列辅助线

</td>
<td width="50%" valign="top">

### 📏 距离测量
- 测距路径以**红色像素框**高亮，边界对齐真实像素
- 距离标签实时显示像素数
- 点击标签可**单独删除**任意一条测距

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🔎 极限放大辅助
- 放大到极限后，屏幕中心 **30px** 半径圆形范围显示像素方格
- 同色像素不再难以分辨
- 关闭插值采样，放大后边缘始终锐利

</td>
<td width="50%" valign="top">

### 🖼️ 视口控制
- 图片缩小极限 = 整图完整显示，禁止无限缩小
- 平移带有边界约束，不会拖出视口
- 缩小到极限后自动**居中**到屏幕中央

</td>
</tr>
<tr>
<td width="50%" valign="top">

### 🌗 系统主题
- 自动跟随系统明暗主题切换
- Material 3 配色，深浅色均清晰易读

</td>
<td width="50%" valign="top">

### 📝 临时笔记
- 顶部笔记框随手记录测量备注
- 不打断测距流程

</td>
</tr>
</table>

---

## 🚀 使用方法

| 步骤 | 操作 | 说明 |
|:---:|------|------|
| 1 | 选择图片 | 点击「选择图片」从相册导入 |
| 2 | 放大定位 | 双指缩放到单像素 10px 以上 |
| 3 | 选起点 | 点击目标像素，出现十字辅助 |
| 4 | 选终点 | 同行或同列再点一下，完成测距 |
| 5 | 微调 | 点击距离标签可选中，再点 🗑 删除该条 |

<details>
<summary><b>💡 小技巧</b></summary>

- 斜向点击会被忽略——测距必须水平或垂直
- 再次点击标签可取消选中
- 右下角「清除」一次重置所有测距
- 极限放大时，中心圆环内会画出像素方格，方便数格子

</details>

---

## 🔨 构建

```bash
# 获取依赖
flutter pub get

# 构建 Release APK（推荐在纯英文、C 盘路径下）
flutter build apk --release
```

> **Windows 构建注意**
> - 项目路径不能包含中文（Dart AOT 会失败）
> - 建议与 Pub Cache 同盘符（C:），避免 Kotlin 增量编译报 `different roots`
> - 产物路径：`build/app/outputs/flutter-apk/app-release.apk`

---

## 🧱 技术要点

```text
Flutter / Dart 3.13
├── InteractiveViewer     手势缩放与平移（min/max/boundary 可控）
├── TransformationController
│                         矩阵驱动视口 ↔ 图片坐标换算
├── CustomPaint
│   ├── 像素红框高亮       测距路径逐像素描边
│   ├── 极限放大方格       中心 30px 圆域网格
│   └── 灰色遮罩           起点十字辅助线
└── ImagePicker           相册选图
```

- **FilterQuality.none**：放大后不插值，保留真实像素色块
- **坐标体系**：视口坐标 → 图片整数像素，距离为曼哈顿距离（轴对齐）
- **主题**：`ThemeMode.system` 自动适配系统明暗

---

## 📦 仓库

<table>
<tr>
<td>仓库名</td>
<td><a href="https://github.com/XL1126/PixelRuler"><b>PixelRuler</b></a></td>
</tr>
<tr>
<td>包名</td>
<td><code>pixel_ruler</code></td>
</tr>
<tr>
<td>平台</td>
<td>Android（Flutter 可扩展至 iOS / 桌面）</td>
</tr>
</table>

---

<div align="center">
<sub>PixelRuler · 让像素距离一目了然</sub>
</div>
