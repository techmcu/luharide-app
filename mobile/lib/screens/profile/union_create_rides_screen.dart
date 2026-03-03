import 'package:flutter/material.dart';

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

  Widget _buildCreateTab(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Step 1: Default date & time',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Colors.orange[50],
            leading: const Icon(Icons.calendar_month),
            title: Text(
              _selectedDateTime == null
                  ? 'Default date & time (optional)'
                  : '${_selectedDateTime!.day.toString().padLeft(2, '0')}-'
                      '${_selectedDateTime!.month.toString().padLeft(2, '0')}-'
                      '${_selectedDateTime!.year}  '
                      '${_selectedDateTime!.hour.toString().padLeft(2, '0')}:'
                      '${_selectedDateTime!.minute.toString().padLeft(2, '0')}',
            ),
            subtitle: const Text(
              'Isko set karoge to ye time sab drivers ke liye default ban jayega. Har driver ka time aap alag bhi set kar sakte ho.',
              style: TextStyle(fontSize: 12),
            ),
            onTap: _pickDateTime,
          ),
          const SizedBox(height: 16),
          Text(
            'Step 2: Select drivers & set route / time',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_drivers.isEmpty)
            const Text(
              'No drivers in your union list yet.\nAdd drivers first from "Union Drivers".',
              style: TextStyle(fontSize: 13),
            )
          else
            ..._drivers.map((d) {
              final driver = d as Map<String, dynamic>;
              final id = driver['id']?.toString() ?? '';
              final name = (driver['name'] ?? '').toString();
              final vehicle = (driver['vehicle_number'] ?? '').toString();
              final driverDt = _driverTimes[id];
              final effectiveDt = driverDt ?? _selectedDateTime;
              final timeLabel = effectiveDt == null
                  ? 'Time not set'
                  : '${effectiveDt.day.toString().padLeft(2, '0')}-'
                      '${effectiveDt.month.toString().padLeft(2, '0')}-'
                      '${effectiveDt.year}  '
                      '${effectiveDt.hour.toString().padLeft(2, '0')}:'
                      '${effectiveDt.minute.toString().padLeft(2, '0')}';
              final routeId = _driverRouteIds[id];
              final route = _routes
                  .cast<Map<String, dynamic>>()
                  .firstWhere(
                    (r) => r['id']?.toString() == routeId,
                    orElse: () => <String, dynamic>{},
                  );
              final from = route['from_location']?.toString() ?? '';
              final to = route['to_location']?.toString() ?? '';
              final routeLabel = routeId == null || route.isEmpty
                  ? 'Route not set'
                  : '$from → $to';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        value: _selectedDriverIds.contains(id),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedDriverIds.add(id);
                            } else {
                              _selectedDriverIds.remove(id);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(name.isNotEmpty ? name : 'Driver'),
                        subtitle:
                            vehicle.isNotEmpty ? Text('Gadi: $vehicle') : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 16, right: 16, bottom: 8),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    timeLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _pickDriverDateTime(id),
                                  child: const Text(
                                    'Set time',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    routeLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _routes.isEmpty
                                      ? null
                                      : () => _pickDriverRoute(id),
                                  child: const Text(
                                    'Set route',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _createRides,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check_circle),
              label: const Text(
                'Create rides for selected drivers',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ye button ek hi baar me jitne drivers select kiye hain un sab ke liye schedule bana dega. '
            'Isi data se aage chalkar poster bhi generate ho sakta hai.',
            style: TextStyle(fontSize: 12),
          ),
        ],
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
                'No upcoming rides. Naye ride create karne ke baad yaha show honge.',
                style: TextStyle(fontSize: 13),
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
                'Gadi: $vehicle',
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
                '${vehicle.isNotEmpty ? '\nGadi: $vehicle' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (canCancel) ...[
              const SizedBox(height: 8),
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

