import 'dart:async' show Timer;
import 'dart:io' show Platform;

import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/desktop/tray_controller.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:nativeapi/nativeapi.dart' as nativeapi;
import 'package:window_manager/window_manager.dart';

class WindowController {
  WindowController._();
  static WindowController get instance => _instance;
  static final WindowController _instance = WindowController._();

  int? _windowId;
  nativeapi.Window? _window;
  nativeapi.Window? get window => _window;

  double? _opacity;

  final _setting = GStorage.setting;

  /// 窗口是否处于最大化：只用于判断「当前尺寸要不要记成 windowSize」，不落盘
  bool _isMaximized = false;

  /// 最小化 / 全屏时系统也会触发尺寸变化，这些状态不写入窗口大小
  bool _isMinimized = false;
  bool _isFullScreen = false;

  Timer? _moveTimer;
  Timer? _resizeTimer;
  static const _kDuration = Duration(milliseconds: 200);

  late bool minimizeOnExit = Pref.minimizeOnExit;
  late bool pauseOnMinimize = Pref.pauseOnMinimize;
  late bool isPlaying = false;

  void init() {
    assert(_window == null);

    final window = WindowManager.instance.getCurrent();
    if (window == null) return;
    _window = window;
    _windowId = window.addListener(_windowListener);
    _isMaximized = window.isMaximized;
  }

  void _windowListener(WindowEvent event) {
    switch (event) {
      case WindowFocusedEvent():
        // https://github.com/leanflutter/window_manager/issues/571
        _setOpacityOnWindows(1.0);
        // 兜底：能获得焦点说明窗口已不处于最小化状态
        _isMinimized = false;
        break;
      case WindowBlurredEvent():
        break;
      case WindowMinimizedEvent():
        _isMinimized = true;
        break;
      case WindowMaximizedEvent():
        _isMaximized = true;
        _isMinimized = false;
        break;
      case WindowRestoredEvent():
        _isMaximized = false;
        _isMinimized = false;
        break;
      case WindowMovedEvent():
        _moveTimer?.cancel();
        _moveTimer = Timer(_kDuration, onWindowMoved);
        break;
      case WindowResizedEvent():
        _resizeTimer?.cancel();
        _resizeTimer = Timer(_kDuration, onWindowResized);
        break;
      case WindowCreatedEvent():
        break;
      case WindowClosedEvent():
        break;
      case WindowEnteredFullScreenEvent():
        _isFullScreen = true;
        break;
      case WindowExitedFullScreenEvent():
        _isFullScreen = false;
        break;
      case WindowCloseRequestedEvent():
        event.request.cancel();
        if (TrayController.instance.showTrayIcon && minimizeOnExit) {
          _hide();
        } else {
          onClose();
        }
        break;
      case WindowPropertyChangedEvent():
        break;
      case WindowOcclusionChangedEvent():
        break;
      case nativeapi.WindowDockedEvent():
        break;
      case nativeapi.WindowUndockedEvent():
        break;
    }
  }

  void onWindowMoved() {
    final window = _window;
    if (window == null) return;
    // 只同步画中画窗口的位置，不把窗口位置写进配置
    // （拖动窗口属于高频操作，落盘会不断触发设置变更与自动备份）
    PlPlayerController.instance?.updatePipBounds(window);
  }

  void onWindowResized() {
    final window = _window;
    if (window == null) return;
    if (PlPlayerController.instance?.updatePipBounds(window) ?? false) {
      return;
    }
    // 最大化 / 最小化 / 全屏由系统改变尺寸，不记录；
    // 只有用户手动拖动边框调整大小才写入
    if (_isMaximized || _isMinimized || _isFullScreen || window.isMaximized) {
      return;
    }
    final bounds = window.bounds;
    _setting.put(SettingBoxKey.windowSize, [bounds.width, bounds.height]);
  }

  void _playIfNeeded() {
    if (pauseOnMinimize && isPlaying) {
      PlPlayerController.instance?.play();
    }
  }

  void _pauseIfNeeded() {
    if (pauseOnMinimize) {
      if (PlPlayerController.instance case final player?) {
        if (isPlaying = player.playerStatus.isPlaying) {
          player.pause();
        }
      } else {
        isPlaying = false;
      }
    }
  }

  Future<void> onClose() async {
    await GStorage.compact();
    await GStorage.close();
    TrayController.instance.dispose();
    DeviceUtils.exitApp();
  }

  void _setOpacityOnWindows(double opacity) {
    if (Platform.isWindows && _opacity != opacity) {
      _opacity = opacity;
      _window?.opacity = opacity;
    }
  }

  void _hide() {
    _pauseIfNeeded();
    // https://github.com/leanflutter/window_manager/issues/571
    _setOpacityOnWindows(0.0);
    _window?.hide();
  }

  void show() {
    _window
      ?..focus()
      ..show();
    _playIfNeeded();
  }

  void toggleVisibility() {
    final window = _window;
    if (window == null) return;
    window.isVisible ? _hide() : show();
  }

  void dispose() {
    _moveTimer?.cancel();
    _resizeTimer?.cancel();
    _window?.removeListener(_windowId!);
    _window = null;
  }
}
