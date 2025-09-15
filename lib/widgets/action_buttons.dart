import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onToggle;
  final VoidCallback? onViewAll;
  final bool isNearbyMode;
  final bool isLoading;
  final bool isViewAllLoading;
  final int nearbyCount;

  const ActionButtons({
    super.key,
    required this.onToggle,
    this.onViewAll,
    required this.isNearbyMode,
    required this.isLoading,
    this.isViewAllLoading = false,
    this.nearbyCount = 0,
  });

  static const Color pccBlue = Color(0xFF0255C2);

  @override
  Widget build(BuildContext context) {
    final glowingButton = ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: pccBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0, // 🔹 removed shadow
      ),
      onPressed: isLoading ? null : onToggle,
      icon: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.near_me),
      label: Text(
        isNearbyMode ? "Nearby ($nearbyCount)" : "Find Nearby",
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );

    if (!isNearbyMode) {
      return SizedBox(width: double.infinity, child: glowingButton);
    }

    return Row(
      children: [
        Expanded(flex: 9, child: glowingButton),
        const SizedBox(width: 12),
        if (onViewAll != null)
          Expanded(
            flex: 1,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: pccBlue.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.all(0),
                elevation: 0, // 🔹 no shadow here either
              ),
              onPressed: isViewAllLoading ? null : onViewAll,
              child: isViewAllLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(pccBlue),
                      ),
                    )
                  : const Icon(Icons.list, color: pccBlue),
            ),
          ),
      ],
    );
  }
}
