import 'dart:async';
import 'package:flutter/material.dart';

class ActionButtons extends StatefulWidget {
  final VoidCallback onToggleNearby; // when switching to Nearby
  final VoidCallback onToggleAll; // when switching to All
  final bool isNearbyMode; // true = showing Nearby, false = showing All
  final bool isLoading;
  final int nearbyCount;

  const ActionButtons({
    super.key,
    required this.onToggleNearby,
    required this.onToggleAll,
    required this.isNearbyMode,
    required this.isLoading,
    this.nearbyCount = 0,
  });

  static const Color pccBlue = Color(0xFF0255C2);

  @override
  State<ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<ActionButtons> {
  bool _showHint = false; // controls label swap
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startHintCycle();
  }

  @override
  void didUpdateWidget(ActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isNearbyMode != widget.isNearbyMode) {
      // restart timer when state changes
      _timer?.cancel();
      _showHint = false;
      _startHintCycle();
    }
  }

  void _startHintCycle() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() {
          _showHint = !_showHint;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _safeCall(BuildContext context, VoidCallback? callback, String failMessage) {
    if (callback == null) return;
    try {
      callback();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failMessage),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonLabel = widget.isNearbyMode
        ? (_showHint ? "Click to view all list" : "Nearby (${widget.nearbyCount})")
        : (_showHint ? "Click to view Nearby Branches" : "All Branches (35)");

    final glowingButton = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: ActionButtons.pccBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      onPressed: widget.isLoading
          ? null
          : () {
              if (widget.isNearbyMode) {
                _safeCall(context, widget.onToggleAll, "Failed to load all branches");
              } else {
                _safeCall(context, widget.onToggleNearby, "Failed to find nearby branches");
              }
            },
      icon: widget.isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(widget.isNearbyMode ? Icons.near_me : Icons.list),
      label: Text(
        buttonLabel,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );

    return SizedBox(width: double.infinity, child: glowingButton);
  }
}
