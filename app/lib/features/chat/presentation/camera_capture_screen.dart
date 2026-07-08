import 'dart:developer';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../helpers/toast.dart';
import '../../../theme/app_theme.dart';

/// Index of the first camera facing the opposite way to the one at
/// [currentIndex], or `-1` when the device exposes no camera on the other side.
///
/// The flip button picks the next lens by [CameraLensDirection] rather than
/// cycling the list with `(i + 1) % n`, because phones commonly expose
/// auxiliary back lenses (wide / tele / depth). A blind index step can land on
/// another back camera that never opens — which is what wedged the
/// front-camera switch. Extracted as a pure function so it is unit-testable
/// without booting real camera hardware.
int oppositeLensCameraIndex(List<CameraDescription> cameras, int currentIndex) {
  final current = cameras[currentIndex].lensDirection;
  return cameras.indexWhere((c) => c.lensDirection != current);
}

/// What [CameraCaptureScreen] returns: the captured file and its media kind.
class CameraCaptureResult {
  /// Creates a result for a captured [file] of the given [mediaType].
  const CameraCaptureResult(this.file, this.mediaType);

  /// The captured photo or video.
  final XFile file;

  /// `'image'` or `'video'`.
  final String mediaType;
}

/// A full-screen, WhatsApp-style camera with a Photo/Video mode toggle.
///
/// Opened from the media picker's **Camera** option. Owns its own
/// [CameraController] (independent of the patent silent-recorder) and pops a
/// [CameraCaptureResult] when the user captures. In Photo mode a tap takes a
/// photo; in Video mode a tap starts recording and the next tap stops it.
class CameraCaptureScreen extends StatefulWidget {
  /// Creates the camera capture screen.
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _isVideoMode = false;
  bool _isRecording = false;
  bool _initializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initController(_cameraIndex);
    }
  }

  Future<void> _setup() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _error = 'No camera available';
          _initializing = false;
        });
        return;
      }
      await _initController(_cameraIndex);
    } catch (e) {
      setState(() {
        _error = 'Camera unavailable';
        _initializing = false;
      });
    }
  }

  Future<void> _initController(int index) async {
    // Release the current camera BEFORE opening the next one. Most devices
    // (especially Android) can't hold two camera sessions open at once, so
    // initializing the new controller while the old one still owns the
    // hardware hangs the switch — this is why the front-camera flip got stuck.
    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final camera = _cameras[index];
    log(
      'camera_capture: init ${camera.lensDirection} '
      '(index $index of ${_cameras.length})',
    );
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
    );
    _controller = controller;
    try {
      // Some devices hang instead of throwing when a lens can't open at this
      // resolution — cap the wait so we surface an error rather than spin.
      await controller.initialize().timeout(const Duration(seconds: 8));
      if (mounted) setState(() => _initializing = false);
    } catch (e) {
      log('camera_capture: init failed for ${camera.lensDirection}: $e');
      if (mounted) {
        setState(() {
          _error = 'Camera unavailable';
          _initializing = false;
        });
      }
    }
  }

  Future<void> _flipCamera() async {
    // Ignore taps while a switch is already in flight, else two concurrent
    // _initController calls race over the camera hardware.
    if (_cameras.length < 2 || _isRecording || _initializing) return;
    final next = oppositeLensCameraIndex(_cameras, _cameraIndex);
    if (next < 0) return;
    _cameraIndex = next;
    setState(() => _initializing = true);
    await _initController(_cameraIndex);
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      if (_isVideoMode) {
        if (_isRecording) {
          final file = await c.stopVideoRecording();
          if (!mounted) return;
          Navigator.of(context).pop(CameraCaptureResult(file, 'video'));
        } else {
          await c.startVideoRecording();
          setState(() => _isRecording = true);
        }
      } else {
        final file = await c.takePicture();
        if (!mounted) return;
        Navigator.of(context).pop(CameraCaptureResult(file, 'image'));
      }
    } catch (e) {
      ToastUtil.showErrorMessage('Capture failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _preview(c)),
          // Close.
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          // Controls.
          if (_error == null)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 24.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isRecording) _modeToggle(),
                      SizedBox(height: 20.h),
                      _bottomRow(),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _preview(CameraController? c) {
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }
    if (_initializing || c == null || !c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    // Cover-fit the preview so it fills the screen without distortion.
    final size = c.value.previewSize!;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.height,
        height: size.width,
        child: CameraPreview(c),
      ),
    );
  }

  Widget _modeToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _modeLabel('Photo', selected: !_isVideoMode, videoMode: false),
        SizedBox(width: 28.w),
        _modeLabel('Video', selected: _isVideoMode, videoMode: true),
      ],
    );
  }

  Widget _modeLabel(
    String text, {
    required bool selected,
    required bool videoMode,
  }) {
    return GestureDetector(
      onTap:
          _isRecording ? null : () => setState(() => _isVideoMode = videoMode),
      behavior: HitTestBehavior.opaque,
      child: Text(
        text,
        style: TextStyle(
          color: selected ? context.reacti.brandFill : Colors.white70,
          fontSize: 15.sp,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _bottomRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w),
      child: Row(
        children: [
          const Spacer(),
          _shutter(),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  _cameras.length > 1 && !_isRecording
                      ? IconButton(
                        icon: const Icon(
                          Icons.flip_camera_ios_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: _flipCamera,
                      )
                      : const SizedBox(width: 30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shutter() {
    final recording = _isRecording;
    return GestureDetector(
      onTap: _capture,
      child: Container(
        width: 72.w,
        height: 72.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4.w),
        ),
        child: Center(
          child: Container(
            width: recording ? 28.w : 56.w,
            height: recording ? 28.w : 56.w,
            decoration: BoxDecoration(
              color: recording ? Colors.red : Colors.white,
              shape: recording ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: recording ? BorderRadius.circular(6.r) : null,
            ),
          ),
        ),
      ),
    );
  }
}
