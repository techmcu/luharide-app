import 'seat_layout.dart';

class VehicleModelConfig {
  final String id;
  final String name;
  final String bodyType;
  final int capacity;
  final SeatLayoutConfig layout;

  const VehicleModelConfig({
    required this.id,
    required this.name,
    required this.bodyType,
    required this.capacity,
    required this.layout,
  });
}

class VehicleBrandConfig {
  final String id;
  final String name;
  final List<VehicleModelConfig> models;

  const VehicleBrandConfig({
    required this.id,
    required this.name,
    required this.models,
  });
}

/// All layouts: RHD (driver right in top-view). rowCols = real car proportions (front 2, middle 3, rear 2 etc).
class VehicleCatalog {
  static final List<VehicleBrandConfig> brands = [
    _tata(),
    _mahindra(),
    _marutiSuzuki(),
    _toyota(),
  ];

  // —— 4-seater: [2,2] ——
  static const _layout4 = SeatLayoutConfig(
    rows: 2,
    cols: 2,
    rowCols: [2, 2],
    seats: [
      SeatPosition(id: 'F1', row: 0, col: 0, type: 'front'),
      SeatPosition(id: 'D1', row: 0, col: 1, type: 'driver'),
      SeatPosition(id: 'R1', row: 1, col: 0, type: 'rear'),
      SeatPosition(id: 'R2', row: 1, col: 1, type: 'rear'),
    ],
  );

  // —— 5-seater: [2,3] front pair + rear bench ——
  static const _layout5 = SeatLayoutConfig(
    rows: 2,
    cols: 3,
    rowCols: [2, 3],
    seats: [
      SeatPosition(id: 'F1', row: 0, col: 0, type: 'front'),
      SeatPosition(id: 'D1', row: 0, col: 1, type: 'driver'),
      SeatPosition(id: 'R1', row: 1, col: 0, type: 'rear'),
      SeatPosition(id: 'R2', row: 1, col: 1, type: 'rear'),
      SeatPosition(id: 'R3', row: 1, col: 2, type: 'rear'),
    ],
  );

  // —— 7-seater: [2,3,2] like Ertiga/Innova ——
  static const _layout7 = SeatLayoutConfig(
    rows: 3,
    cols: 3,
    rowCols: [2, 3, 2],
    seats: [
      SeatPosition(id: 'F1', row: 0, col: 0, type: 'front'),
      SeatPosition(id: 'D1', row: 0, col: 1, type: 'driver'),
      SeatPosition(id: 'M1', row: 1, col: 0, type: 'middle'),
      SeatPosition(id: 'M2', row: 1, col: 1, type: 'middle'),
      SeatPosition(id: 'M3', row: 1, col: 2, type: 'middle'),
      SeatPosition(id: 'R1', row: 2, col: 0, type: 'rear'),
      SeatPosition(id: 'R2', row: 2, col: 1, type: 'rear'),
    ],
  );

  // —— 8-seater: [2,3,3] ——
  static const _layout8 = SeatLayoutConfig(
    rows: 3,
    cols: 3,
    rowCols: [2, 3, 3],
    seats: [
      SeatPosition(id: 'F1', row: 0, col: 0, type: 'front'),
      SeatPosition(id: 'D1', row: 0, col: 1, type: 'driver'),
      SeatPosition(id: 'M1', row: 1, col: 0, type: 'middle'),
      SeatPosition(id: 'M2', row: 1, col: 1, type: 'middle'),
      SeatPosition(id: 'M3', row: 1, col: 2, type: 'middle'),
      SeatPosition(id: 'R1', row: 2, col: 0, type: 'rear'),
      SeatPosition(id: 'R2', row: 2, col: 1, type: 'rear'),
      SeatPosition(id: 'R3', row: 2, col: 2, type: 'rear'),
    ],
  );

  // —— 9-seater Sumo: [2,3,3,2] ——
  static const _layout9Sumo = SeatLayoutConfig(
    rows: 4,
    cols: 3,
    rowCols: [2, 3, 3, 2],
    seats: [
      SeatPosition(id: 'F1', row: 0, col: 0, type: 'front'),
      SeatPosition(id: 'D1', row: 0, col: 1, type: 'driver'),
      SeatPosition(id: 'M1', row: 1, col: 0, type: 'middle'),
      SeatPosition(id: 'M2', row: 1, col: 1, type: 'middle'),
      SeatPosition(id: 'M3', row: 1, col: 2, type: 'middle'),
      SeatPosition(id: 'R1', row: 2, col: 0, type: 'rear'),
      SeatPosition(id: 'R2', row: 2, col: 1, type: 'rear'),
      SeatPosition(id: 'R3', row: 2, col: 2, type: 'rear'),
      SeatPosition(id: 'B1', row: 3, col: 0, type: 'rear'),
      SeatPosition(id: 'B2', row: 3, col: 1, type: 'rear'),
    ],
  );

  // —— Jeep / hill taxi: [3,3,2,2] front 3 + middle 3 + two rear bench rows ——
  static const _layoutJeep10 = SeatLayoutConfig(
    rows: 4,
    cols: 3,
    rowCols: [3, 3, 2, 2],
    seats: [
      SeatPosition(id: 'F1', row: 0, col: 0, type: 'front'),
      SeatPosition(id: 'F2', row: 0, col: 1, type: 'front'),
      SeatPosition(id: 'D1', row: 0, col: 2, type: 'driver'),
      SeatPosition(id: 'M1', row: 1, col: 0, type: 'middle'),
      SeatPosition(id: 'M2', row: 1, col: 1, type: 'middle'),
      SeatPosition(id: 'M3', row: 1, col: 2, type: 'middle'),
      SeatPosition(id: 'B1L', row: 2, col: 0, type: 'side_bench_left'),
      SeatPosition(id: 'B1R', row: 2, col: 1, type: 'side_bench_right'),
      SeatPosition(id: 'B2L', row: 3, col: 0, type: 'side_bench_left'),
      SeatPosition(id: 'B2R', row: 3, col: 1, type: 'side_bench_right'),
    ],
  );

  /// Get a generic seat layout for a given total seat count.
  /// This is used for passenger seat selection so that the seat map
  /// matches the same top-view style used during driver verification.
  static SeatLayoutConfig layoutForCapacity(int totalSeats) {
    switch (totalSeats) {
      case 4:
        return _layout4;
      case 5:
        return _layout5;
      case 7:
        return _layout7;
      case 8:
        return _layout8;
      case 9:
        return _layout9Sumo;
      case 10:
        return _layoutJeep10;
      default:
        // Fallback: simple car/bus style grid (similar to old seat selection)
        final seatsPerRow = totalSeats <= 7 ? 2 : 3;
        final rows = (totalSeats / seatsPerRow).ceil();
        final seats = <SeatPosition>[];
        var index = 0;
        for (var r = 0; r < rows; r++) {
          for (var c = 0; c < seatsPerRow; c++) {
            if (index >= totalSeats) break;
            final type = r == 0
                ? (index == 0 ? 'front' : 'driver')
                : (r == rows - 1 ? 'rear' : 'middle');
            seats.add(SeatPosition(
              id: 'S${index + 1}',
              row: r,
              col: c,
              type: type,
            ));
            index++;
          }
        }
        return SeatLayoutConfig(
          rows: rows,
          cols: seatsPerRow,
          seats: seats,
        );
    }
  }

  static VehicleBrandConfig _tata() {
    return VehicleBrandConfig(
      id: 'tata',
      name: 'Tata',
      models: [
        VehicleModelConfig(id: 'tata_punch', name: 'Punch', bodyType: 'SUV', capacity: 5, layout: _layout5),
        VehicleModelConfig(id: 'tata_tiago', name: 'Tiago', bodyType: 'Hatchback', capacity: 5, layout: _layout5),
        VehicleModelConfig(id: 'tata_nexon', name: 'Nexon', bodyType: 'SUV', capacity: 5, layout: _layout5),
        VehicleModelConfig(id: 'tata_harrier', name: 'Harrier', bodyType: 'SUV', capacity: 5, layout: _layout5),
        VehicleModelConfig(id: 'tata_safari', name: 'Safari', bodyType: 'SUV', capacity: 7, layout: _layout7),
        VehicleModelConfig(id: 'tata_sumo', name: 'Sumo', bodyType: 'SUV', capacity: 9, layout: _layout9Sumo),
      ],
    );
  }

  static VehicleBrandConfig _mahindra() {
    return VehicleBrandConfig(
      id: 'mahindra',
      name: 'Mahindra',
      models: [
        VehicleModelConfig(id: 'mahindra_bolero_jeep', name: 'Bolero / Commander Jeep (Hill Taxi)', bodyType: 'Jeep', capacity: 10, layout: _layoutJeep10),
        VehicleModelConfig(id: 'mahindra_bolero_suv', name: 'Bolero 7-Seater', bodyType: 'SUV', capacity: 7, layout: _layout7),
        VehicleModelConfig(id: 'mahindra_bolero_ne', name: 'Bolero Neo', bodyType: 'SUV', capacity: 7, layout: _layout7),
        VehicleModelConfig(id: 'mahindra_thar', name: 'Thar', bodyType: 'SUV', capacity: 5, layout: _layout5),
        VehicleModelConfig(id: 'mahindra_xuv300', name: 'XUV300', bodyType: 'SUV', capacity: 5, layout: _layout5),
        VehicleModelConfig(id: 'mahindra_xuv700', name: 'XUV700', bodyType: 'SUV', capacity: 7, layout: _layout7),
        VehicleModelConfig(id: 'mahindra_scorpio', name: 'Scorpio', bodyType: 'SUV', capacity: 7, layout: _layout7),
        VehicleModelConfig(id: 'mahindra_scorpio_n', name: 'Scorpio N', bodyType: 'SUV', capacity: 7, layout: _layout7),
        VehicleModelConfig(id: 'mahindra_marazzo', name: 'Marazzo', bodyType: 'MPV', capacity: 8, layout: _layout8),
      ],
    );
  }

  static VehicleBrandConfig _marutiSuzuki() {
    return VehicleBrandConfig(
      id: 'maruti',
      name: 'Maruti Suzuki',
      models: [
        VehicleModelConfig(id: 'maruti_alto', name: 'Alto', bodyType: 'Hatchback', capacity: 4, layout: _layout4),
        VehicleModelConfig(id: 'maruti_alto_k10', name: 'Alto K10', bodyType: 'Hatchback', capacity: 5, layout: _layout5),
        VehicleModelConfig(id: 'maruti_wagon_r', name: 'Wagon R', bodyType: 'Hatchback', capacity: 5, layout: _layout5),
        VehicleModelConfig(id: 'maruti_swift', name: 'Swift', bodyType: 'Hatchback', capacity: 5, layout: _layout5),
        VehicleModelConfig(id: 'maruti_dzire', name: 'Dzire', bodyType: 'Sedan', capacity: 5, layout: _layout5),
        VehicleModelConfig(id: 'maruti_swift_dzire', name: 'Swift Dzire', bodyType: 'Sedan', capacity: 5, layout: _layout5),
        VehicleModelConfig(id: 'maruti_brezza', name: 'Brezza', bodyType: 'SUV', capacity: 5, layout: _layout5),
        VehicleModelConfig(id: 'maruti_ertiga', name: 'Ertiga', bodyType: 'MPV', capacity: 7, layout: _layout7),
        VehicleModelConfig(id: 'maruti_ertiga_tour', name: 'Ertiga Tour', bodyType: 'MPV', capacity: 7, layout: _layout7),
        VehicleModelConfig(id: 'maruti_eeco', name: 'Eeco', bodyType: 'Van', capacity: 7, layout: _layout7),
        VehicleModelConfig(id: 'maruti_eeco_8', name: 'Eeco (8-seater)', bodyType: 'Van', capacity: 8, layout: _layout8),
        VehicleModelConfig(id: 'maruti_omni', name: 'Omni', bodyType: 'Van', capacity: 8, layout: _layout8),
      ],
    );
  }

  static VehicleBrandConfig _toyota() {
    return VehicleBrandConfig(
      id: 'toyota',
      name: 'Toyota',
      models: [
        VehicleModelConfig(id: 'toyota_glanza', name: 'Glanza', bodyType: 'Hatchback', capacity: 5, layout: _layout5),
        VehicleModelConfig(id: 'toyota_urban_cruiser', name: 'Urban Cruiser', bodyType: 'SUV', capacity: 5, layout: _layout5),
        VehicleModelConfig(id: 'toyota_innova_crysta', name: 'Innova Crysta', bodyType: 'MPV', capacity: 7, layout: _layout7),
        VehicleModelConfig(id: 'toyota_innova_hycross', name: 'Innova Hycross', bodyType: 'MPV', capacity: 7, layout: _layout7),
        VehicleModelConfig(id: 'toyota_innova_touring', name: 'Innova Touring Sport', bodyType: 'MPV', capacity: 8, layout: _layout8),
        VehicleModelConfig(id: 'toyota_fortuner', name: 'Fortuner', bodyType: 'SUV', capacity: 7, layout: _layout7),
      ],
    );
  }

  static VehicleBrandConfig? findBrandById(String id) {
    try {
      return brands.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  static VehicleModelConfig? findModelById(String id) {
    for (final brand in brands) {
      try {
        return brand.models.firstWhere((m) => m.id == id);
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}
