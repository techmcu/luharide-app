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

  /// Display line for dropdown: "Name (X seater)"
  String get dropdownLabel => '$name ($capacity seater)';
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

/// One option for driver verification dropdown: id + display name + capacity + layout.
class VehicleDropdownOption {
  final String id;
  final String displayName;
  final int capacity;
  final SeatLayoutConfig layout;

  const VehicleDropdownOption({
    required this.id,
    required this.displayName,
    required this.capacity,
    required this.layout,
  });

  /// Required so Flutter DropdownButtonFormField can compare selected value with items list.
  @override
  bool operator ==(Object other) => other is VehicleDropdownOption && other.id == id;

  @override
  int get hashCode => id.hashCode;

  /// Short subtitle for two-line dropdown (capacity only — name is on first line).
  String get capacitySubtitle => '$capacity seats (RTO style)';
}

/// All layouts: RHD (driver right in top-view). rowCols = real car proportions (front 2, middle 3, rear 2 etc).
class VehicleCatalog {
  static final List<VehicleBrandConfig> brands = [
    _tata(),
    _mahindra(),
    _marutiSuzuki(),
    _toyota(),
    _kia(),
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

  /// Tempo Traveller / bus: RHD top view — front row [passenger, driver], then rows of 3 (or 2).
  static SeatLayoutConfig _tempoLayout(int totalSeats) {
    final seats = <SeatPosition>[];
    final rowCols = <int>[2]; // row 0: passenger, driver
    seats.add(const SeatPosition(id: 'F1', row: 0, col: 0, type: 'front'));
    seats.add(const SeatPosition(id: 'D1', row: 0, col: 1, type: 'driver'));
    int remaining = totalSeats - 2;
    int row = 1;
    while (remaining > 0) {
      final inRow = remaining >= 3 ? 3 : remaining;
      rowCols.add(inRow);
      for (int c = 0; c < inRow; c++) {
        final type = row >= 4 ? 'rear' : 'middle';
        seats.add(SeatPosition(id: 'S${seats.length + 1}', row: row, col: c, type: type));
      }
      remaining -= inRow;
      row++;
    }
    final cols = rowCols.reduce((a, b) => a > b ? a : b);
    return SeatLayoutConfig(rows: row, cols: cols, rowCols: rowCols, seats: seats);
  }

  static final _layoutTempo12 = _tempoLayout(12);
  static final _layoutTempo16 = _tempoLayout(16);
  static final _layoutTempo18 = _tempoLayout(18);
  static final _layoutTempo20 = _tempoLayout(20);
  static final _layoutTempo24 = _tempoLayout(24);
  static final _layoutTempo26 = _tempoLayout(26);
  static final _layoutTempo30 = _tempoLayout(30);
  static final _layoutTempo32 = _tempoLayout(32);

  /// Get a generic seat layout for a given total seat count.
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
      case 12:
        return _layoutTempo12;
      case 16:
        return _layoutTempo16;
      case 18:
        return _layoutTempo18;
      case 20:
        return _layoutTempo20;
      case 24:
        return _layoutTempo24;
      case 26:
        return _layoutTempo26;
      case 30:
        return _layoutTempo30;
      case 32:
        return _layoutTempo32;
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
        const VehicleModelConfig(id: 'tata_punch', name: 'Punch', bodyType: 'SUV', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'tata_tiago', name: 'Tiago', bodyType: 'Hatchback', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'tata_nexon', name: 'Nexon', bodyType: 'SUV', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'tata_harrier', name: 'Harrier', bodyType: 'SUV', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'tata_safari', name: 'Safari', bodyType: 'SUV', capacity: 7, layout: _layout7),
        const VehicleModelConfig(id: 'tata_sumo', name: 'Sumo', bodyType: 'SUV', capacity: 9, layout: _layout9Sumo),
      ],
    );
  }

  static VehicleBrandConfig _mahindra() {
    return VehicleBrandConfig(
      id: 'mahindra',
      name: 'Mahindra',
      models: [
        const VehicleModelConfig(
          id: 'mahindra_bolero_jeep',
          name: 'Bolero Jeep · 10 seat (Hill)',
          bodyType: 'Jeep',
          capacity: 10,
          layout: _layoutJeep10,
        ),
        const VehicleModelConfig(id: 'mahindra_bolero_suv', name: 'Bolero 7-Seater', bodyType: 'SUV', capacity: 7, layout: _layout7),
        const VehicleModelConfig(id: 'mahindra_bolero_ne', name: 'Bolero Neo', bodyType: 'SUV', capacity: 7, layout: _layout7),
        const VehicleModelConfig(id: 'mahindra_thar', name: 'Thar', bodyType: 'SUV', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'mahindra_xuv300', name: 'XUV300', bodyType: 'SUV', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'mahindra_xuv700', name: 'XUV700', bodyType: 'SUV', capacity: 7, layout: _layout7),
        const VehicleModelConfig(id: 'mahindra_scorpio', name: 'Scorpio', bodyType: 'SUV', capacity: 7, layout: _layout7),
        const VehicleModelConfig(id: 'mahindra_scorpio_n', name: 'Scorpio N', bodyType: 'SUV', capacity: 7, layout: _layout7),
        const VehicleModelConfig(id: 'mahindra_marazzo', name: 'Marazzo', bodyType: 'MPV', capacity: 8, layout: _layout8),
      ],
    );
  }

  static VehicleBrandConfig _marutiSuzuki() {
    return VehicleBrandConfig(
      id: 'maruti',
      name: 'Maruti Suzuki',
      models: [
        const VehicleModelConfig(id: 'maruti_alto', name: 'Alto', bodyType: 'Hatchback', capacity: 4, layout: _layout4),
        const VehicleModelConfig(id: 'maruti_alto_k10', name: 'Alto K10', bodyType: 'Hatchback', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'maruti_wagon_r', name: 'Wagon R', bodyType: 'Hatchback', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'maruti_swift', name: 'Swift', bodyType: 'Hatchback', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'maruti_dzire', name: 'Dzire', bodyType: 'Sedan', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'maruti_swift_dzire', name: 'Swift Dzire', bodyType: 'Sedan', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'maruti_brezza', name: 'Brezza', bodyType: 'SUV', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'maruti_ertiga', name: 'Ertiga', bodyType: 'MPV', capacity: 7, layout: _layout7),
        const VehicleModelConfig(id: 'maruti_ertiga_tour', name: 'Ertiga Tour', bodyType: 'MPV', capacity: 7, layout: _layout7),
        const VehicleModelConfig(id: 'maruti_eeco', name: 'Eeco', bodyType: 'Van', capacity: 7, layout: _layout7),
        const VehicleModelConfig(id: 'maruti_eeco_8', name: 'Eeco (8-seater)', bodyType: 'Van', capacity: 8, layout: _layout8),
        const VehicleModelConfig(id: 'maruti_omni', name: 'Omni', bodyType: 'Van', capacity: 8, layout: _layout8),
      ],
    );
  }

  static VehicleBrandConfig _toyota() {
    return VehicleBrandConfig(
      id: 'toyota',
      name: 'Toyota',
      models: [
        const VehicleModelConfig(id: 'toyota_glanza', name: 'Glanza', bodyType: 'Hatchback', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'toyota_urban_cruiser', name: 'Urban Cruiser', bodyType: 'SUV', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'toyota_innova_crysta', name: 'Innova Crysta', bodyType: 'MPV', capacity: 7, layout: _layout7),
        const VehicleModelConfig(id: 'toyota_innova_hycross', name: 'Innova Hycross', bodyType: 'MPV', capacity: 7, layout: _layout7),
        const VehicleModelConfig(id: 'toyota_innova_touring', name: 'Innova Touring Sport', bodyType: 'MPV', capacity: 8, layout: _layout8),
        const VehicleModelConfig(id: 'toyota_fortuner', name: 'Fortuner', bodyType: 'SUV', capacity: 7, layout: _layout7),
      ],
    );
  }

  static VehicleBrandConfig _kia() {
    return VehicleBrandConfig(
      id: 'kia',
      name: 'Kia',
      models: [
        const VehicleModelConfig(id: 'kia_seltos', name: 'Seltos', bodyType: 'SUV', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'kia_sonet', name: 'Sonet', bodyType: 'SUV', capacity: 5, layout: _layout5),
        const VehicleModelConfig(id: 'kia_carens', name: 'Carens', bodyType: 'MPV', capacity: 7, layout: _layout7),
        const VehicleModelConfig(id: 'kia_carnival', name: 'Carnival', bodyType: 'MPV', capacity: 7, layout: _layout7),
      ],
    );
  }

  /// Tempo Traveller / bus options (RTO-style seat counts)
  static List<VehicleDropdownOption> _tempoOptions() {
    return [
      VehicleDropdownOption(id: 'tempo_10', displayName: 'Tempo 10 seat', capacity: 10, layout: _layoutJeep10),
      VehicleDropdownOption(id: 'tempo_12', displayName: 'Tempo 12 seat', capacity: 12, layout: _layoutTempo12),
      VehicleDropdownOption(id: 'tempo_16', displayName: 'Tempo 16 seat', capacity: 16, layout: _layoutTempo16),
      VehicleDropdownOption(id: 'tempo_18', displayName: 'Tempo 18 seat', capacity: 18, layout: _layoutTempo18),
      VehicleDropdownOption(id: 'tempo_20', displayName: 'Tempo 20 seat', capacity: 20, layout: _layoutTempo20),
      VehicleDropdownOption(id: 'tempo_24', displayName: 'Tempo 24 seat', capacity: 24, layout: _layoutTempo24),
      VehicleDropdownOption(id: 'tempo_26', displayName: 'Tempo 26 seat', capacity: 26, layout: _layoutTempo26),
      VehicleDropdownOption(id: 'tempo_30', displayName: 'Tempo 30 seat', capacity: 30, layout: _layoutTempo30),
      VehicleDropdownOption(id: 'tempo_32', displayName: 'Tempo 32 seat', capacity: 32, layout: _layoutTempo32),
    ];
  }

  /// Single list for driver verification dropdown: "Kaunsi gadi hai aapko?"
  /// Cars + Tempo. Each option has fixed layout; selecting one fixes seat count & layout for trips.
  static List<VehicleDropdownOption> get allVehicleOptionsForDropdown {
    final list = <VehicleDropdownOption>[];
    for (final brand in brands) {
      for (final model in brand.models) {
        // One clean line: brand + model (capacity is subtitle in UI — avoids huge strings)
        list.add(VehicleDropdownOption(
          id: model.id,
          displayName: '${brand.name} · ${model.name}',
          capacity: model.capacity,
          layout: model.layout,
        ));
      }
    }
    list.addAll(_tempoOptions());
    list.sort((a, b) {
      final byName = a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      if (byName != 0) return byName;
      return a.capacity.compareTo(b.capacity);
    });
    return list;
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
    // Tempo / bus options (id like tempo_12, tempo_16)
    for (final opt in _tempoOptions()) {
      if (opt.id == id) {
        return VehicleModelConfig(id: opt.id, name: opt.displayName, bodyType: 'Tempo', capacity: opt.capacity, layout: opt.layout);
      }
    }
    return null;
  }
}
