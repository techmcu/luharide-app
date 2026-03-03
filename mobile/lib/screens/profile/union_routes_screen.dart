import 'package:flutter/material.dart';

import '../../services/union_service.dart';

class UnionRoutesScreen extends StatefulWidget {
  const UnionRoutesScreen({super.key});

  @override
  State<UnionRoutesScreen> createState() => _UnionRoutesScreenState();
}

class _UnionRoutesScreenState extends State<UnionRoutesScreen> {
  final _service = UnionService();
  bool _loading = true;
  String? _error;
  List<dynamic> _routes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _service.getRoutes();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result['success'] == true) {
        _routes = result['routes'] as List<dynamic>? ?? const [];
      } else {
        _error = result['message']?.toString() ?? 'Failed to load routes';
      }
    });
  }

  Future<void> _showAddRouteDialog() async {
    final fromController = TextEditingController();
    final toController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    final ok = await showDialog<bool>(
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

    if (ok == true) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preset routes'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRouteDialog,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_road),
        label: const Text('Add route'),
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
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _routes.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No preset routes added yet.\nUse the Add route button to store common routes like\n"Purola → Dehradun", "Dehradun → Purola".',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _routes.length,
                        itemBuilder: (context, index) {
                          final r =
                              _routes[index] as Map<String, dynamic>? ?? {};
                          final from =
                              r['from_location']?.toString() ?? '';
                          final to = r['to_location']?.toString() ?? '';
                          final createdAt = r['created_at']?.toString() ?? '';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.alt_route),
                              title: Text('$from → $to'),
                              subtitle: createdAt.isNotEmpty
                                  ? Text(
                                      'Added: $createdAt',
                                      style: const TextStyle(fontSize: 11),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

