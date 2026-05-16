import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

/// Custom portrait-orientation control overlay for the flick video player.
///
/// Renders a centred play/pause toggle plus a bottom bar with current
/// position, a scrubbable progress bar, total duration and a fullscreen
/// toggle. It is supplied as the `controls` of [FlickVideoWithControls]
/// wherever chat media videos are played (sender, receiver and reaction
/// bubbles). The layout adapts to small bubbles by collapsing the position
/// and duration labels and shrinking spacing.
class CustomFlickPortraitControls extends StatelessWidget {
  /// Creates the portrait control overlay.
  const CustomFlickPortraitControls({super.key});

  /// Builds the control overlay, reading the flick control and display
  /// managers from the provider scope and adapting to the available width.
  @override
  Widget build(BuildContext context) {
    FlickControlManager flickControlManager = Provider.of<FlickControlManager>(
      context,
    );
    FlickDisplayManager flickDisplayManager = Provider.of<FlickDisplayManager>(
      context,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Treat narrow bubbles as "small" to collapse non-essential labels.
        bool isSmall = constraints.maxWidth < 250;

        return Container(
          color: Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 8.w : 20.w,
            vertical: isSmall ? 8.h : 20.h,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    flickDisplayManager.handleVideoTap();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: FlickSeekVideoAction(
                    child: Center(
                      child: FlickVideoBuffer(
                        child: FlickAutoHideChild(
                          showIfVideoNotInitialized: false,
                          child: FlickPlayToggle(
                            size: isSmall ? 24.sp : 30.sp,
                            color: Colors.white,
                            padding: EdgeInsets.all(isSmall ? 8.h : 12.h),
                            decoration: const BoxDecoration(
                              color: Colors.black26,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: FlickAutoHideChild(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!isSmall)
                        FlickCurrentPosition(
                          fontSize: 12.sp,
                          color: Colors.white,
                        ),
                      Expanded(
                        child: FlickVideoProgressBar(
                          flickProgressBarSettings: FlickProgressBarSettings(
                            height: isSmall ? 3.h : 5.h,
                            handleRadius: isSmall ? 3.h : 5.h,
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmall ? 5.w : 10.w,
                            ),
                            playedColor: Colors.red,
                            bufferedColor: Colors.white38,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ),
                      if (!isSmall)
                        FlickTotalDuration(
                          fontSize: 12.sp,
                          color: Colors.white,
                        ),
                      SizedBox(width: isSmall ? 5.w : 10.w),
                      GestureDetector(
                        onTap: () {
                          flickControlManager.toggleFullscreen();
                        },
                        child: Icon(
                          flickControlManager.isFullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                          size: isSmall ? 24.h : 35.h,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom landscape-orientation (fullscreen) control overlay for the flick
/// video player.
///
/// Renders a centred play/pause toggle, an always-tappable back button that
/// exits fullscreen (or pops the route), and an auto-hiding bottom bar with
/// position, progress bar, duration and a fullscreen toggle. Supplied as the
/// fullscreen `controls` of [FlickVideoWithControls].
class CustomFlickLandscapeControls extends StatelessWidget {
  /// Creates the landscape control overlay.
  const CustomFlickLandscapeControls({super.key});

  /// Builds the fullscreen control overlay, watching the flick control and
  /// display managers so it rebuilds on playback/fullscreen state changes.
  @override
  Widget build(BuildContext context) {
    final flickControlManager = context.watch<FlickControlManager>();
    final flickDisplayManager = context.watch<FlickDisplayManager>();

    return Stack(
      children: [
        // Fullscreen tap area (play/pause + seek)
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              flickDisplayManager.handleVideoTap();
            },
            behavior: HitTestBehavior.opaque,
            child: FlickSeekVideoAction(
              child: Center(
                child: FlickVideoBuffer(
                  child: FlickAutoHideChild(
                    showIfVideoNotInitialized: false,
                    child: FlickPlayToggle(
                      size: 30.sp,
                      color: Colors.white,
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.black26,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ✅ Back button ALWAYS clickable (NOT inside FlickAutoHideChild)
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, top: 12),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (flickControlManager.isFullscreen) {
                    flickControlManager.toggleFullscreen(); // exit fullscreen
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(8.sp),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),
          ),
        ),

        // Bottom bar (can auto-hide)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: FlickAutoHideChild(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const FlickCurrentPosition(fontSize: 14, color: Colors.white),
                  Expanded(
                    child: FlickVideoProgressBar(
                      flickProgressBarSettings: FlickProgressBarSettings(
                        height: 5,
                        handleRadius: 6,
                        padding: EdgeInsets.symmetric(horizontal: 10.sp),
                        playedColor: Colors.red,
                        bufferedColor: Colors.white38,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ),
                  const FlickTotalDuration(fontSize: 14, color: Colors.white),
                  const SizedBox(width: 10),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: flickControlManager.toggleFullscreen,
                    child: Icon(
                      flickControlManager.isFullscreen
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
