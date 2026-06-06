import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerTripCards extends StatelessWidget {
  const ShimmerTripCards({super.key, this.count = 3});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: List.generate(count, (_) => _buildCard()),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(160, 14),
            const SizedBox(height: 18),
            Row(children: [
              _circle(18),
              const SizedBox(width: 10),
              Expanded(child: _bar(double.infinity, 14)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              _circle(18),
              const SizedBox(width: 10),
              _bar(140, 14),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              _bar(90, 12),
              const SizedBox(width: 16),
              _bar(70, 12),
              const SizedBox(width: 16),
              _bar(60, 12),
            ]),
            const SizedBox(height: 18),
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(double width, double height) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      );

  Widget _circle(double size) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
}
