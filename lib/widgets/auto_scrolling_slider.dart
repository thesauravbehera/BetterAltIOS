import 'dart:async';
import 'package:flutter/material.dart';

class AutoScrollingSlider extends StatefulWidget {
  final List<String> imagePaths;
  const AutoScrollingSlider({super.key, required this.imagePaths});

  @override
  State<AutoScrollingSlider> createState() => _AutoScrollingSliderState();
}

class _AutoScrollingSliderState extends State<AutoScrollingSlider> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  bool _isUserScrolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScroll();
    });
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!_isUserScrolling && _scrollController.hasClients) {
        final double currentPosition = _scrollController.position.pixels;
        // Move slightly to the right infinitely since ListView builder is unbounded
        _scrollController.jumpTo(currentPosition + 1.5);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190, // slightly taller to accommodate the shadow
      child: Listener(
        onPointerDown: (_) => setState(() => _isUserScrolling = true),
        onPointerUp: (_) => setState(() => _isUserScrolling = false),
        onPointerCancel: (_) => setState(() => _isUserScrolling = false),
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(), // Allows user to manually swipe
          itemBuilder: (context, index) {
            final imagePath = widget.imagePaths[index % widget.imagePaths.length];
            return GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.all(16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        InteractiveViewer(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(imagePath, fit: BoxFit.contain),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 30),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(imagePath, fit: BoxFit.contain),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
