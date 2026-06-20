import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../providers/poltergeist_provider.dart';

/// Gesture interpretation modes for the remote screen.
enum SniperMode { navigate, drag, scroll }

/// Converts a tap offset (in the image widget's own coordinate space, which is
/// zoom-independent because the GestureDetector is the InteractiveViewer child)
/// into a relative (x%, y%) pair clamped to [0,1]. Pure → unit-testable.
(double, double) pctFromOffset(Offset local, Size base) {
  if (base.width <= 0 || base.height <= 0) return (0, 0);
  final x = (local.dx / base.width).clamp(0.0, 1.0);
  final y = (local.dy / base.height).clamp(0.0, 1.0);
  return (x, y);
}

class SniperViewPage extends ConsumerStatefulWidget {
  const SniperViewPage({super.key});

  @override
  ConsumerState<SniperViewPage> createState() => _SniperViewPageState();
}

class _SniperViewPageState extends ConsumerState<SniperViewPage> {
  final TransformationController _tc = TransformationController();
  SniperMode _mode = SniperMode.navigate;

  Offset? _tapDownPos;
  Offset? _doubleTapDownPos;
  Offset? _dragStart;
  Offset? _dragCurrent;
  double _scrollAccum = 0;

  // Crosshair feedback
  Offset? _marker;
  Timer? _markerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final st = ref.read(poltergeistProvider);
      if (st.screenshotBytes == null) _refresh();
    });
  }

  @override
  void dispose() {
    _markerTimer?.cancel();
    _tc.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.read(poltergeistProvider.notifier).executeAction('sys_screenshot');
  }

  void _flashMarker(Offset local) {
    setState(() => _marker = local);
    _markerTimer?.cancel();
    _markerTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _marker = null);
    });
  }

  void _send(String actionId, Map<String, dynamic> params) {
    ref.read(poltergeistProvider.notifier).executeAction(actionId, params: params);
  }

  void _click(Offset local, Size base, String actionId) {
    final (x, y) = pctFromOffset(local, base);
    _send(actionId, {'x': x, 'y': y});
    _flashMarker(local);
  }

  void _drag(Offset start, Offset end, Size base) {
    final (x, y) = pctFromOffset(start, base);
    final (x2, y2) = pctFromOffset(end, base);
    _send('mouse_drag', {'x': x, 'y': y, 'x2': x2, 'y2': y2});
  }

  void _scroll(Offset pos, double dy, Size base) {
    final (x, y) = pctFromOffset(pos, base);
    _send('mouse_scroll', {'x': x, 'y': y, 'dy': dy.round()});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(poltergeistProvider);

    ref.listen(poltergeistProvider.select((s) => s.errorMessage), (prev, next) {
      if (next != null && next != prev) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next, style: AppTextStyles.bodySmall),
            backgroundColor: AppColors.statusError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Francotirador', style: AppTextStyles.titleMedium),
        actions: [
          if (state.isExecuting)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recapturar',
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          _ModeBar(
            mode: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
          Expanded(
            child: state.screenshotBytes == null
                ? _empty()
                : _screen(state),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.screenshot_monitor_rounded,
                size: 56, color: AppColors.darkMuted),
            const SizedBox(height: 12),
            Text('Sin captura todavía',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.darkMuted)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Capturar'),
            ),
          ],
        ),
      );

  Widget _screen(PoltergeistState state) {
    final aspect = (state.screenW > 0 && state.screenH > 0)
        ? state.screenW / state.screenH
        : 16 / 9;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fit the host screen aspect into the available area (no letterbox in
        // the gesture target → localPosition maps directly to the image).
        double w = constraints.maxWidth;
        double h = w / aspect;
        if (h > constraints.maxHeight) {
          h = constraints.maxHeight;
          w = h * aspect;
        }
        final base = Size(w, h);
        final navMode = _mode == SniperMode.navigate;

        return Center(
          child: InteractiveViewer(
            transformationController: _tc,
            minScale: 1,
            maxScale: 5,
            panEnabled: navMode,
            scaleEnabled: navMode,
            child: SizedBox(
              width: w,
              height: h,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // ── Navigate-mode taps ──────────────────────────────────────
                onTapDown: navMode ? (d) => _tapDownPos = d.localPosition : null,
                onTap: navMode
                    ? () {
                        if (_tapDownPos != null) {
                          _click(_tapDownPos!, base, 'mouse_click');
                        }
                      }
                    : null,
                onDoubleTapDown:
                    navMode ? (d) => _doubleTapDownPos = d.localPosition : null,
                onDoubleTap: navMode
                    ? () {
                        if (_doubleTapDownPos != null) {
                          _click(_doubleTapDownPos!, base, 'mouse_double');
                        }
                      }
                    : null,
                onLongPressStart: navMode
                    ? (d) => _click(d.localPosition, base, 'mouse_right')
                    : null,
                // ── Drag / scroll gestures ──────────────────────────────────
                onPanStart: navMode
                    ? null
                    : (d) {
                        _dragStart = d.localPosition;
                        _dragCurrent = d.localPosition;
                        _scrollAccum = 0;
                      },
                onPanUpdate: navMode
                    ? null
                    : (d) {
                        _dragCurrent = d.localPosition;
                        if (_mode == SniperMode.scroll) {
                          _scrollAccum -= d.delta.dy; // up-swipe scrolls up
                          if (_scrollAccum.abs() >= 30) {
                            _scroll(_dragStart ?? d.localPosition,
                                _scrollAccum, base);
                            _scrollAccum = 0;
                          }
                        }
                      },
                onPanEnd: navMode
                    ? null
                    : (_) {
                        if (_mode == SniperMode.drag &&
                            _dragStart != null &&
                            _dragCurrent != null) {
                          _drag(_dragStart!, _dragCurrent!, base);
                        }
                        _dragStart = null;
                        _dragCurrent = null;
                        _scrollAccum = 0;
                      },
                child: Stack(
                  children: [
                    Image.memory(
                      state.screenshotBytes!,
                      width: w,
                      height: h,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                    ),
                    if (_marker != null)
                      Positioned(
                        left: _marker!.dx - 14,
                        top: _marker!.dy - 14,
                        child: IgnorePointer(
                          child: Icon(
                            Icons.add_circle_outline_rounded,
                            size: 28,
                            color: AppColors.darkPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModeBar extends StatelessWidget {
  final SniperMode mode;
  final ValueChanged<SniperMode> onChanged;

  const _ModeBar({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: AppColors.darkSurface,
      child: SegmentedButton<SniperMode>(
        segments: const [
          ButtonSegment(
            value: SniperMode.navigate,
            icon: Icon(Icons.touch_app_rounded, size: 18),
            label: Text('Tocar'),
          ),
          ButtonSegment(
            value: SniperMode.drag,
            icon: Icon(Icons.back_hand_rounded, size: 18),
            label: Text('Arrastrar'),
          ),
          ButtonSegment(
            value: SniperMode.scroll,
            icon: Icon(Icons.swipe_vertical_rounded, size: 18),
            label: Text('Scroll'),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) => onChanged(s.first),
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStatePropertyAll(AppTextStyles.labelSmall),
        ),
      ),
    );
  }
}
