import 'package:flutter/material.dart';

/// A RefreshIndicator wrapper that shows a hint when user pulls down.
/// Use this instead of RefreshIndicator to get the pull-down hint.
class RefreshIndicatorWithHint extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? color;
  final Color? backgroundColor;
  final double displacement;
  final double edgeOffset;

  const RefreshIndicatorWithHint({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
    this.backgroundColor,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
  });

  @override
  State<RefreshIndicatorWithHint> createState() =>
      _RefreshIndicatorWithHintState();
}

class _RefreshIndicatorWithHintState extends State<RefreshIndicatorWithHint> {
  double _dragOffset = 0.0;
  double _startY = 0.0;
  bool _isDragging = false;
  bool _isAtTop = true;
  bool _isRefreshing = false;
  static const double _maxPullDistance = 120.0;
  static const double _showHintThreshold = 20.0;

  void _onPointerDown(PointerDownEvent event) {
    _startY = event.position.dy;
    _isDragging = true;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_isDragging || _isRefreshing || !_isAtTop) return;

    final delta = event.position.dy - _startY;
    if (delta > 0) {
      // Pulling down
      setState(() {
        _dragOffset = delta.clamp(0.0, _maxPullDistance);
      });
    } else if (_dragOffset > 0) {
      // Moving back up
      setState(() {
        _dragOffset = (_dragOffset + delta).clamp(0.0, _maxPullDistance);
      });
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _isDragging = false;
    if (_dragOffset > 0) {
      setState(() {
        _dragOffset = 0;
      });
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _isDragging = false;
    if (_dragOffset > 0) {
      setState(() {
        _dragOffset = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          // Track if we're at the top of the scroll view
          if (notification is ScrollUpdateNotification) {
            final atTop = notification.metrics.pixels <= 0;
            if (atTop != _isAtTop) {
              setState(() {
                _isAtTop = atTop;
                if (!atTop) _dragOffset = 0;
              });
            }
          }
          return false;
        },
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _isRefreshing = true;
                  _dragOffset = 0;
                });
                try {
                  await widget.onRefresh();
                } finally {
                  if (mounted) {
                    setState(() {
                      _isRefreshing = false;
                    });
                  }
                }
              },
              color: widget.color,
              backgroundColor: widget.backgroundColor,
              displacement: widget.displacement,
              edgeOffset: widget.edgeOffset,
              child: widget.child,
            ),
            // Pull-down hint overlay
            if (_dragOffset > _showHintThreshold && !_isRefreshing)
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity:
                      ((_dragOffset - _showHintThreshold) /
                              (_maxPullDistance - _showHintThreshold))
                          .clamp(0.0, 1.0),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _dragOffset > _maxPullDistance * 0.7
                                ? Icons.refresh_rounded
                                : Icons.arrow_downward_rounded,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _dragOffset > _maxPullDistance * 0.7
                                ? 'Release to refresh'
                                : 'Pull to refresh',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Legacy widget - kept for backward compatibility but now just returns empty
/// Use RefreshIndicatorWithHint instead to wrap your RefreshIndicator
class PullToRefreshHint extends StatelessWidget {
  const PullToRefreshHint({super.key});

  @override
  Widget build(BuildContext context) {
    // Return empty - the hint is now part of RefreshIndicatorWithHint
    return const SizedBox.shrink();
  }
}

