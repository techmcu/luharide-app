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

  // Prevent spamming cancel endpoint (avoid rapid duplicate requests).
  final Set<String> _cancelLoadingIds = <String>{};

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
    final toController   = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickAddRouteSheet(
        formKey: formKey,
        fromCtrl: fromController,
        toCtrl: toController,
        onSave: (submitting) async {
          if (!formKey.currentState!.validate()) return;
          submitting(true);
          final res = await _service.addRoute(
            fromLocation: fromController.text.trim(),
            toLocation: toController.text.trim(),
          );
          submitting(false);
          if (!mounted) return;
          if (res['success'] == true) {
            Navigator.pop(ctx);
            _loadAll();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Route saved'),
                ]),
                backgroundColor: const Color(0xFF43A047),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(res['message']?.toString() ?? 'Failed to add route'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        },
      ),
    );
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.route_rounded, color: _orange, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Choose Route',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _routes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final route = _routes[index] as Map<String, dynamic>? ?? {};
                      final id   = route['id']?.toString() ?? '';
                      final from = route['from_location']?.toString() ?? '';
                      final to   = route['to_location']?.toString() ?? '';
                      return InkWell(
                        onTap: () => Navigator.pop(ctx, id),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 10, height: 10,
                                decoration: const BoxDecoration(
                                  color: _orange, shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$from  →  $to',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 14, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
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
    final List<String> createdIds = [];

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
      final to   = route['to_location']?.toString() ?? '';
      final dt   = _driverTimes[id] ?? _selectedDateTime;

      if (dt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please set time for all selected drivers'),
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
        final schedules = res['schedules'] as List<dynamic>? ?? [];
        for (final s in schedules) {
          final sid = (s as Map<String, dynamic>)['id']?.toString();
          if (sid != null) createdIds.add(sid);
        }
      } else {
        error = res['message']?.toString() ?? 'Failed to create rides';
        break;
      }
    }

    if (!mounted) return;

    if (error == null) {
      _selectedDriverIds.clear();
      _selectedDateTime = null;
      _driverTimes.clear();
      _loadAll();

      // Auto-download combined poster for all created rides
      if (createdIds.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text('${createdIds.length} rides created — generating poster...'),
            ]),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        await _downloadCombinedPoster(createdIds);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadCombinedPoster(List<String> ids) async {
    if (!mounted) return;
    final res = await _service.getCombinedPosterBytes(ids);
    if (!mounted) return;

    if (res['success'] == true) {
      final bytes  = (res['bytes'] as List<int>? ?? <int>[]);
      if (bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poster could not be generated'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      await Share.shareXFiles(
        [XFile.fromData(Uint8List.fromList(bytes),
            name: 'luharide-daily-schedule.pdf',
            mimeType: 'application/pdf')],
        text: 'Daily taxi schedule — powered by LuhaRide',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message']?.toString() ?? 'Failed to generate poster'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelSchedule(String id) async {
    if (id.isEmpty) return;
    if (_cancelLoadingIds.contains(id)) return;

    setState(() => _cancelLoadingIds.add(id));
    final res = await _service.cancelSchedule(id);
    if (!mounted) return;

    setState(() => _cancelLoadingIds.remove(id));
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

  static const _orange = Color(0xFFFF6B00);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Schedules & posters',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline_rounded, size: 18), text: 'Create'),
            Tab(icon: Icon(Icons.list_alt_rounded, size: 18), text: 'View rides'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadAll,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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
          // ── Step 1: Select drivers ────────────────────────────────────────
          _stepHeader('1', 'Select drivers & set their route / time'),
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
    final totalUpcoming = _currentSchedules.length;
    final totalHistory  = _recentSchedules.length;

    // Collect IDs for combined poster
    final upcomingIds = _currentSchedules
        .map((s) => (s as Map<String, dynamic>)['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    return RefreshIndicator(
      color: _orange,
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ── Download full poster button ───────────────────────────────────
          if (upcomingIds.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _downloadCombinedPoster(upcomingIds),
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                label: Text(
                  'Download Full Daily Poster  (${upcomingIds.length} rides)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Upcoming rides section ────────────────────────────────────────
          _sectionHeader(
            icon: Icons.upcoming_rounded,
            color: _orange,
            title: 'Upcoming',
            count: totalUpcoming,
          ),
          const SizedBox(height: 10),
          if (_currentSchedules.isEmpty)
            _emptySection(
              icon: Icons.directions_bus_outlined,
              message: 'No upcoming rides.\nAdd from the Create tab.',
            )
          else
            ..._currentSchedules
                .map((s) => _buildScheduleCard(s as Map<String, dynamic>, true))
                .toList(),

          const SizedBox(height: 20),

          // ── History section ───────────────────────────────────────────────
          _sectionHeader(
            icon: Icons.history_rounded,
            color: const Color(0xFF3949AB),
            title: 'Last 10 Days History',
            count: totalHistory,
          ),
          const SizedBox(height: 10),
          if (_recentSchedules.isEmpty)
            _emptySection(
              icon: Icons.history_outlined,
              message: 'No rides in the last 10 days.',
            )
          else
            ..._recentSchedules
                .map((s) => _buildScheduleCard(s as Map<String, dynamic>, false))
                .toList(),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required Color color,
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
      ],
    );
  }

  Widget _emptySection({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> s, bool allowCancel) {
    final from       = (s['from_location'] ?? '').toString();
    final to         = (s['to_location'] ?? '').toString();
    final driverName = (s['driver_name'] ?? '').toString();
    final vehicle    = (s['vehicle_number'] ?? '').toString();
    final status     = (s['status'] ?? '').toString();
    final canCancel  = s['can_cancel'] == true && allowCancel;
    final scheduleId = s['id']?.toString() ?? '';
    final isCancelling = scheduleId.isNotEmpty && _cancelLoadingIds.contains(scheduleId);

    DateTime? dt;
    final dtRaw = s['departure_time'];
    if (dtRaw != null) dt = DateTime.tryParse(dtRaw.toString());

    final dateStr = dt != null
        ? '${_fmtDt(dt)}'
        : '—';

    // Status color
    Color statusColor;
    Color statusBg;
    IconData statusIcon;
    switch (status) {
      case 'cancelled':
        statusColor = Colors.red.shade700;
        statusBg    = Colors.red.shade50;
        statusIcon  = Icons.cancel_rounded;
        break;
      case 'completed':
        statusColor = const Color(0xFF3949AB);
        statusBg    = const Color(0xFFE8EAF6);
        statusIcon  = Icons.check_circle_rounded;
        break;
      default:
        statusColor = const Color(0xFF2E7D32);
        statusBg    = const Color(0xFFE8F5E9);
        statusIcon  = Icons.schedule_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header strip ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.directions_bus_rounded, color: _orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        from.isNotEmpty && to.isNotEmpty ? '$from  →  $to' : '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.isEmpty ? 'ACTIVE' : status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Driver info row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                if (driverName.isNotEmpty) ...[
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        driverName[0].toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E88E5),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driverName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (vehicle.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.directions_car_rounded,
                                  size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                vehicle,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      'Driver not assigned',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                    ),
                  ),
              ],
            ),
          ),

          // Cancel is disabled as requested.
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ── Quick Add Route Sheet (used inside Create Rides tab) ──────────────────────

class _QuickAddRouteSheet extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fromCtrl, toCtrl;
  final void Function(Future<void> Function(bool)) onSave;

  const _QuickAddRouteSheet({
    required this.formKey,
    required this.fromCtrl,
    required this.toCtrl,
    required this.onSave,
  });

  @override
  State<_QuickAddRouteSheet> createState() => _QuickAddRouteSheetState();
}

class _QuickAddRouteSheetState extends State<_QuickAddRouteSheet> {
  bool _submitting = false;
  static const _orange = Color(0xFFFF6B00);
  static const _blue   = Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 8,
        left: 20,
        right: 20,
      ),
      child: Form(
        key: widget.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_road_rounded, color: _orange, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Add Route',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('Save route to use when creating rides',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: widget.fromCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDeco('From (e.g. Purola)', Icons.trip_origin_rounded, _orange),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? 'Enter departure location' : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.arrow_downward_rounded, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('to', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                  ),
                ],
              ),
            ),
            TextFormField(
              controller: widget.toCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDeco('To (e.g. Dehradun)', Icons.location_on_rounded, _blue),
              validator: (v) =>
                  (v?.trim() ?? '').isEmpty ? 'Enter destination' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () {
                        widget.onSave(
                          (val) async { if (mounted) setState(() => _submitting = val); },
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Save Route',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, Color accent) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18, color: accent),
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    );
  }
}
