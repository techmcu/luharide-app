import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/union_service.dart';

class UnionCreateRidesScreen extends StatefulWidget {
  const UnionCreateRidesScreen({super.key});

  @override
  State<UnionCreateRidesScreen> createState() => _UnionCreateRidesScreenState();
}

class _UnionCreateRidesScreenState extends State<UnionCreateRidesScreen>
    with SingleTickerProviderStateMixin {
  final _service = UnionService();

  bool _loading = true;
  String? _error;

  List<dynamic> _drivers = const [];
  List<dynamic> _routes = const [];
  Set<String> _selectedDriverIds = <String>{};

  DateTime? _selectedDateTime; // global/default time
  final Map<String, DateTime?> _driverTimes = <String, DateTime?>{};
  final Map<String, String?> _driverRouteIds = <String, String?>{};

  List<dynamic> _currentSchedules = const [];
  List<dynamic> _recentSchedules = const [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final driversResult = await _service.getDrivers();
    final routesResult = await _service.getRoutes();
    final currentResult = await _service.getSchedules(scope: 'current');
    final recentResult = await _service.getSchedules(scope: 'recent');

    if (!mounted) return;

    String? error;
    if (driversResult['success'] != true) {
      error = driversResult['message']?.toString() ?? 'Failed to load drivers';
    } else if (routesResult['success'] != true) {
      error = routesResult['message']?.toString() ?? 'Failed to load routes';
    } else if (currentResult['success'] != true ||
        recentResult['success'] != true) {
      error = currentResult['message']?.toString() ??
          recentResult['message']?.toString() ??
          'Failed to load schedules';
    }

    setState(() {
      _loading = false;
      _error = error;
      if (driversResult['success'] == true) {
        _drivers = driversResult['drivers'] as List<dynamic>? ?? const [];
      }
      if (routesResult['success'] == true) {
        _routes = routesResult['routes'] as List<dynamic>? ?? const [];
        // Clean up driver route selections that no longer exist
        final routeIds = _routes
            .map((r) => (r as Map<String, dynamic>)['id']?.toString())
            .whereType<String>()
            .toSet();
        _driverRouteIds.removeWhere(
          (driverId, routeId) => routeId != null && !routeIds.contains(routeId),
        );
      } else {
        _routes = const [];
        _driverRouteIds.clear();
      }
      if (currentResult['success'] == true) {
        _currentSchedules =
            currentResult['schedules'] as List<dynamic>? ?? const [];
      }
      if (recentResult['success'] == true) {
        _recentSchedules =
            recentResult['schedules'] as List<dynamic>? ?? const [];
      }
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 0)),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (pickedTime == null) return;

    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() => _selectedDateTime = dt);
  }

  Future<void> _pickDriverDateTime(String driverId) async {
    final now = DateTime.now();
    final initial = _driverTimes[driverId] ?? _selectedDateTime ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 0)),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (pickedDate == null) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return;

    final dt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() => _driverTimes[driverId] = dt);
  }

  Future<void> _showAddRouteDialog() async {
    final fromController = TextEditingController();
    final toController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add route'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: fromController,
                      decoration: const InputDecoration(
                        labelText: 'From (e.g. Purola)',
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Enter from location';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: toController,
                      decoration: const InputDecoration(
                        labelText: 'To (e.g. Dehradun)',
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Enter to location';
                        return null;
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            StatefulBuilder(
              builder: (context, setDialogState) {
                return TextButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => submitting = true);
                          final res = await _service.addRoute(
                            fromLocation: fromController.text.trim(),
                            toLocation: toController.text.trim(),
                          );
                          setDialogState(() => submitting = false);
                          if (!mounted) return;
                          if (res['success'] == true) {
                            Navigator.pop(ctx, true);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res['message']?.toString() ??
                                      'Failed to add route',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                );
              },
            ),
          ],
        );
      },
    );

    if (result == true) {
      _loadAll();
    }
  }

  Future<void> _pickDriverRoute(String driverId) async {
    if (_routes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No routes yet. Please add a route first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Choose route for this driver',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _routes.length,
                  itemBuilder: (context, index) {
                    final route =
                        _routes[index] as Map<String, dynamic>? ?? {};
                    final id = route['id']?.toString() ?? '';
                    final from =
                        route['from_location']?.toString() ?? '';
                    final to = route['to_location']?.toString() ?? '';
                    return ListTile(
                      title: Text('$from → $to'),
                      onTap: () => Navigator.pop(ctx, id),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _driverRouteIds[driverId] = selected;
      });
    }
  }

  Future<void> _createRides() async {
    if (_selectedDriverIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one driver'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? error;
    int totalCreated = 0;

    for (final id in _selectedDriverIds) {
      final routeId = _driverRouteIds[id];
      final route = _routes
          .cast<Map<String, dynamic>>()
          .firstWhere(
            (r) => r['id']?.toString() == routeId,
            orElse: () => <String, dynamic>{},
          );

      if (routeId == null || route.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set route for all selected drivers'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final from = route['from_location']?.toString() ?? '';
      final to = route['to_location']?.toString() ?? '';

      final dt = _driverTimes[id] ?? _selectedDateTime;
      if (dt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please set time for all selected drivers (or a default time)',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final res = await _service.createSchedulesBulk(
        fromLocation: from,
        toLocation: to,
        departureTime: dt,
        unionDriverIds: [id],
      );
      if (res['success'] == true) {
        totalCreated += (res['schedules'] as List<dynamic>? ?? []).length;
      } else {
        error = res['message']?.toString() ?? 'Failed to create rides';
        break;
      }
    }

    if (!mounted) return;

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            totalCreated > 0
                ? 'Rides created for $totalCreated entries'
                : 'Rides created',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _selectedDriverIds.clear();
      _selectedDateTime = null;
      _driverTimes.clear();
      _loadAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelSchedule(String id) async {
    final res = await _service.cancelSchedule(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? ''),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ),
    );
    if (res['success'] == true) {
      _loadAll();
    }
  }

  Future<void> _sharePoster(Map<String, dynamic> schedule) async {
    final id = schedule['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final res = await _service.getSchedulePosterBytes(id);
    if (!mounted) return;

    if (res['success'] == true) {
      final bytes = (res['bytes'] as List<int>? ?? <int>[]);
      if (bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poster could not be generated'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final from = (schedule['from_location'] ?? '').toString();
      final to = (schedule['to_location'] ?? '').toString();
      final name = 'LuhaRide-${from.isNotEmpty ? from : 'from'}-${to.isNotEmpty ? to : 'to'}.pdf'
          .replaceAll(RegExp(r'[^\w\.-]+'), '-');

      final data = Uint8List.fromList(bytes);

      // Open system share sheet so user can save/share PDF locally
      final file = XFile.fromData(
        data,
        name: name,
        mimeType: 'application/pdf',
      );

      await Share.shareXFiles(
        [file],
        text: 'Taxi union ride poster from LuhaRide',
      );
    } else {
      final msg = res['message']?.toString() ?? 'Failed to download poster';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create rides & posters'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Create rides'),
            Tab(text: 'View rides'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadAll,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCreateTab(theme),
                    _buildViewTab(theme),
                  ],
                ),
    );
  }

  String _fmtDt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')} '
      '${_monthName(dt.month)} ${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  Widget _buildCreateTab(ThemeData theme) {
    final allIds = _drivers
        .map((d) => (d as Map<String, dynamic>)['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final allSelected =
        allIds.isNotEmpty && _selectedDriverIds.containsAll(allIds);

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Step 1: Default time ──────────────────────────────────────────
          _stepHeader('1', 'Set a default departure time'),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _selectedDateTime != null
                    ? const Color(0xFFE8F5E9)
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedDateTime != null
                      ? Colors.green.shade300
                      : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _selectedDateTime != null
                          ? Colors.green.withOpacity(0.15)
                          : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: _selectedDateTime != null
                          ? Colors.green.shade700
                          : Colors.orange,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedDateTime == null
                              ? 'Tap to set date & time'
                              : _fmtDt(_selectedDateTime!),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _selectedDateTime != null
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'This time will apply to all drivers by default.\nYou can override per driver below.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit_rounded,
                    color: _selectedDateTime != null
                        ? Colors.green.shade600
                        : Colors.orange,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Step 2: Select drivers ────────────────────────────────────────
          _stepHeader('2', 'Select drivers & set their route / time'),
          const SizedBox(height: 10),

          if (_drivers.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_add_rounded,
                      color: Colors.grey.shade500, size: 32),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'No drivers in your union yet.\nGo to "Drivers" and add your drivers first.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Select All / Deselect All row
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_selectedDriverIds.length} of ${_drivers.length} selected',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (allSelected) {
                        _selectedDriverIds.clear();
                      } else {
                        _selectedDriverIds = Set.from(allIds);
                      }
                    });
                  },
                  icon: Icon(
                    allSelected
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                    size: 18,
                  ),
                  label: Text(allSelected ? 'Deselect All' : 'Select All'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ..._drivers.map((d) {
              final driver = d as Map<String, dynamic>;
              final id = driver['id']?.toString() ?? '';
              final name = (driver['name'] ?? '').toString();
              final vehicle = (driver['vehicle_number'] ?? '').toString();
              final isSelected = _selectedDriverIds.contains(id);

              final driverDt = _driverTimes[id];
              final effectiveDt = driverDt ?? _selectedDateTime;
              final timeSet = effectiveDt != null;
              final timeLabel = timeSet ? _fmtDt(effectiveDt!) : 'Time not set — tap to set';
              final hasCustomTime = _driverTimes[id] != null;

              final routeId = _driverRouteIds[id];
              final route = _routes
                  .cast<Map<String, dynamic>>()
                  .firstWhere(
                    (r) => r['id']?.toString() == routeId,
                    orElse: () => <String, dynamic>{},
                  );
              final routeSet = routeId != null && route.isNotEmpty;
              final from = route['from_location']?.toString() ?? '';
              final to = route['to_location']?.toString() ?? '';
              final routeLabel = routeSet
                  ? '$from  →  $to'
                  : 'Route not set — tap to choose';

              final isReady = isSelected && timeSet && routeSet;

              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedDriverIds.remove(id);
                  } else {
                    _selectedDriverIds.add(id);
                  }
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isReady
                          ? Colors.green.shade400
                          : isSelected
                              ? Colors.orange.shade300
                              : Colors.grey.shade200,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // ── Driver header row ────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isSelected
                                  ? Colors.orange.withOpacity(0.15)
                                  : Colors.grey.shade100,
                              child: Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : 'D',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.orange.shade800
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isNotEmpty ? name : 'Driver',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (vehicle.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(
                                            Icons.directions_car_rounded,
                                            size: 13,
                                            color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          vehicle,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            // Selected / unselected indicator
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.orange
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSelected ? Icons.check_rounded : Icons.add_rounded,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade500,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Route & Time tiles ───────────────────────────────
                      if (isSelected) ...[
                        const Divider(height: 1, indent: 14, endIndent: 14),
                        // Route tile
                        _infoTile(
                          icon: Icons.route_rounded,
                          label: 'Route',
                          value: routeLabel,
                          isSet: routeSet,
                          actionLabel: routeSet ? 'Change' : 'Set Route',
                          onTap: _routes.isEmpty
                              ? () => ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'No routes yet. Add routes first.'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  )
                              : () => _pickDriverRoute(id),
                        ),
                        const Divider(height: 1, indent: 14, endIndent: 14),
                        // Time tile
                        _infoTile(
                          icon: Icons.access_time_rounded,
                          label: hasCustomTime ? 'Custom Time' : 'Time',
                          value: timeLabel,
                          isSet: timeSet,
                          actionLabel:
                              hasCustomTime ? 'Change' : (timeSet ? 'Override' : 'Set Time'),
                          onTap: () => _pickDriverDateTime(id),
                          badge: hasCustomTime ? 'Custom' : null,
                        ),
                        // Ready indicator
                        if (isReady)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.green.shade600, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Ready to create ride',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 20),

          // ── Create button ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _createRides,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 22),
              label: Text(
                _selectedDriverIds.isEmpty
                    ? 'Select drivers above to create rides'
                    : 'Create rides for ${_selectedDriverIds.length} driver${_selectedDriverIds.length > 1 ? 's' : ''}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _stepHeader(String number, String title) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF222222),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isSet,
    required String actionLabel,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: isSet ? Colors.green.shade600 : Colors.grey.shade500),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSet
                          ? const Color(0xFF222222)
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSet
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                actionLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSet ? Colors.green.shade700 : Colors.orange.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Current / upcoming rides',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_currentSchedules.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'No upcoming rides. Create rides from the "Create rides" tab.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            )
          else
            ..._currentSchedules
                .map((s) => _buildScheduleCard(s as Map<String, dynamic>, true))
                .toList(),
          const SizedBox(height: 16),
          Text(
            'Last 10 days history',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_recentSchedules.isEmpty)
            const Text(
              'No recent rides saved in last 10 days.',
              style: TextStyle(fontSize: 13),
            )
          else
            ..._recentSchedules
                .map((s) => _buildScheduleCard(s as Map<String, dynamic>, false))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> s, bool allowCancel) {
    final from = (s['from_location'] ?? '').toString();
    final to = (s['to_location'] ?? '').toString();
    final driverName = (s['driver_name'] ?? '').toString();
    final vehicle = (s['vehicle_number'] ?? '').toString();
    final status = (s['status'] ?? '').toString();
    final canCancel = s['can_cancel'] == true && allowCancel;

    DateTime? dt;
    final dtRaw = s['departure_time'];
    if (dtRaw != null) {
      dt = DateTime.tryParse(dtRaw.toString());
    }

    final dateStr = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}-'
            '${dt.month.toString().padLeft(2, '0')}-'
            '${dt.year}  '
            '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}'
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$from → $to',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'cancelled'
                        ? Colors.red[50]
                        : Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: status == 'cancelled'
                          ? Colors.red[700]
                          : Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              dateStr,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              driverName.isNotEmpty ? 'Driver: $driverName' : 'Driver: —',
              style: const TextStyle(fontSize: 13),
            ),
            if (vehicle.isNotEmpty)
              Text(
                'Vehicle: $vehicle',
                style: const TextStyle(fontSize: 13),
              ),
            const SizedBox(height: 8),
            const Text(
              'Poster preview (simple text):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                '$from → $to\n'
                'Date: $dateStr\n'
                'Driver: ${driverName.isNotEmpty ? driverName : '—'}'
                '${vehicle.isNotEmpty ? '\nVehicle: $vehicle' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sharePoster(s),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Download / share poster (PDF)'),
                  ),
                ),
              ],
            ),
            if (canCancel) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _cancelSchedule(s['id']?.toString() ?? ''),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Cancel ride',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

