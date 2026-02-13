import 'package:flutter/material.dart';

/// Simple data structure to describe a seat position in a top-view grid.
class SeatPosition {
  final String id; // stable ID, e.g. "D1", "M2"
  final int row; // 0-based row index
  final int col; // 0-based column index
  final String type; // driver, front, middle, side_bench_left, side_bench_right, etc.

  const SeatPosition({
    required this.id,
    required this.row,
    required this.col,
    required this.type,
  });
}

/// Layout configuration for a specific vehicle model.
/// [rowCols] if set: each row can have different column count (real car proportions).
/// e.g. [2, 3, 2] = front row 2 seats, middle 3, rear 2. When null, [cols] used for all rows.
class SeatLayoutConfig {
  final int rows;
  final int cols;
  final List<SeatPosition> seats;
  final List<int>? rowCols;

  const SeatLayoutConfig({
    required this.rows,
    required this.cols,
    required this.seats,
    this.rowCols,
  });

  int colsForRow(int row) {
    if (rowCols != null && row < rowCols!.length) return rowCols![row];
    return cols;
  }
}

/// Cell size and margin - kept small to avoid RenderFlex overflow on narrow screens.
const double _kCellSize = 22.0;
const double _kCellMargin = 2.0;

/// Simple reusable top-view seat layout widget.
/// Uses variable columns per row when [rowCols] set, so cabin looks like real car (front 2, middle 3, rear 2).
/// Wrapped in car-shaped outline and FittedBox to avoid overflow.
class SeatLayoutView extends StatelessWidget {
  final SeatLayoutConfig layout;

  const SeatLayoutView({super.key, required this.layout});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(layout.rows, (r) {
        final colCount = layout.colsForRow(r);
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(colCount, (c) {
            final seat = layout.seats.firstWhere(
              (s) => s.row == r && s.col == c,
              orElse: () => const SeatPosition(id: '', row: -1, col: -1, type: 'empty'),
            );
            if (seat.row == -1) {
              return SizedBox(width: _kCellSize + _kCellMargin * 2, height: _kCellSize + _kCellMargin * 2);
            }
            return _buildSeatCell(seat);
          }),
        );
      }),
    );
    // Car-shaped outline: rounded rect so top-view feels like real vehicle
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: content,
    );
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: body,
      ),
    );
  }

  Widget _buildSeatCell(SeatPosition seat) {
    final color = _colorForType(seat.type);
    final icon = seat.type == 'driver' ? Icons.local_taxi : Icons.event_seat;

    return Container(
      width: _kCellSize,
      height: _kCellSize,
      margin: const EdgeInsets.all(_kCellMargin),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Icon(icon, size: 13, color: color),
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'driver':
        return Colors.orange;
      case 'front':
        return Colors.blue;
      case 'middle':
        return Colors.green;
      case 'rear':
        return Colors.teal;
      case 'side_bench_left':
      case 'side_bench_right':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

