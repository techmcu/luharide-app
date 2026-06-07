import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/trip_service.dart';

class LocationPickerScreen extends StatefulWidget {
  final String title;
  final String initialValue;
  final TripService tripService;

  const LocationPickerScreen({
    super.key,
    required this.title,
    this.initialValue = '',
    required this.tripService,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<String> _apiSuggestions = [];
  List<String> _recentLocations = [];
  bool _isLoading = false;
  bool _hasFetched = false;

  static const _kBlue = Color(0xFF2563EB);
  static const _recentKey = 'luha_recent_locations';
  static const _maxRecent = 8;

  static const _popularLocations = [
    'Dehradun', 'Haridwar', 'Rishikesh', 'Mussoorie', 'Nainital',
    'Haldwani', 'Roorkee', 'Rudrapur', 'Kashipur', 'Kotdwar',
    'Almora', 'Pithoragarh', 'Uttarkashi', 'Tehri', 'Pauri',
    'Srinagar Garhwal', 'Ranikhet', 'Bhimtal', 'Joshimath', 'Ramnagar',
    'Purola', 'Vikasnagar', 'Herbertpur', 'Laksar', 'Doiwala',
  ];

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue;
    if (widget.initialValue.isNotEmpty) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.initialValue.length,
      );
    }
    _loadRecentLocations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList(_recentKey) ?? [];
    if (mounted) setState(() => _recentLocations = recent);
  }

  Future<void> _saveRecentLocation(String location) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList(_recentKey) ?? [];
    recent.removeWhere((l) => l.toLowerCase() == location.toLowerCase());
    recent.insert(0, location);
    if (recent.length > _maxRecent) recent.removeRange(_maxRecent, recent.length);
    await prefs.setStringList(_recentKey, recent);
  }

  void _onTextChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() { _apiSuggestions = []; _hasFetched = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _fetchSuggestions);
  }

  List<String> _rankLocations(List<String> locations, String query) {
    final q = query.toLowerCase();
    final filtered = locations.where((l) => l.toLowerCase().contains(q)).toList();
    filtered.sort((a, b) {
      final al = a.toLowerCase();
      final bl = b.toLowerCase();
      final aExact = al == q;
      final bExact = bl == q;
      if (aExact != bExact) return aExact ? -1 : 1;
      final aStarts = al.startsWith(q);
      final bStarts = bl.startsWith(q);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      final aWord = al.split(RegExp(r'\s+')).any((w) => w.startsWith(q));
      final bWord = bl.split(RegExp(r'\s+')).any((w) => w.startsWith(q));
      if (aWord != bWord) return aWord ? -1 : 1;
      return al.compareTo(bl);
    });
    return filtered;
  }

  Future<void> _fetchSuggestions() async {
    final query = _controller.text.trim();
    if (query.length < 2) return;
    if (mounted) setState(() => _isLoading = true);
    try {
      final results = await widget.tripService.getLocationSuggestions(query);
      if (!mounted) return;
      setState(() {
        _apiSuggestions = results;
        _isLoading = false;
        _hasFetched = true;
      });
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasFetched = true; });
    }
  }

  void _selectLocation(String location) {
    _saveRecentLocation(location);
    Navigator.pop(context, location);
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final qLower = query.toLowerCase();
    final hasQuery = query.length >= 2;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: _kBlue,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.words,
              onChanged: _onTextChanged,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Type location name...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.7)),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.white.withValues(alpha: 0.7)),
                        onPressed: () {
                          _controller.clear();
                          setState(() { _apiSuggestions = []; _hasFetched = false; });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(minHeight: 2, color: _kBlue),
          Expanded(
            child: hasQuery
                ? _buildSearchResults(query, qLower)
                : _buildIdleState(),
          ),
        ],
      ),
    );
  }

  /// No query typed — show recent searches + popular locations
  Widget _buildIdleState() {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        if (_recentLocations.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.history_rounded,
            iconColor: Colors.grey[500]!,
            label: 'Recent Searches',
          ),
          ..._recentLocations.map((loc) => _LocationTile(
                location: loc,
                icon: Icons.history_rounded,
                iconBgColor: Colors.grey.withValues(alpha: 0.08),
                iconColor: Colors.grey[500]!,
                onTap: () => _selectLocation(loc),
              )),
          Divider(height: 24, indent: 16, endIndent: 16, color: Colors.grey[100]),
        ],
        _SectionHeader(
          icon: Icons.star_rounded,
          iconColor: Colors.orange[400]!,
          label: 'Popular Locations',
        ),
        ..._popularLocations.map((loc) => _LocationTile(
              location: loc,
              icon: Icons.star_outline_rounded,
              iconBgColor: Colors.orange.withValues(alpha: 0.1),
              iconColor: Colors.orange[400]!,
              onTap: () => _selectLocation(loc),
            )),
      ],
    );
  }

  /// Query typed — show API suggestions (or instant local matches while loading)
  Widget _buildSearchResults(String query, String qLower) {
    List<String> displayList;
    if (_hasFetched) {
      displayList = _apiSuggestions;
    } else {
      displayList = _rankLocations(
        [..._recentLocations, ..._popularLocations],
        query,
      );
      // deduplicate
      final seen = <String>{};
      displayList = displayList.where((l) => seen.add(l.toLowerCase())).toList();
    }

    if (displayList.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No locations found for "$query"',
              style: TextStyle(fontSize: 15, color: Colors.grey[400]),
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different spelling',
              style: TextStyle(fontSize: 13, color: Colors.grey[350]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (displayList.isNotEmpty)
          _SectionHeader(
            icon: Icons.location_on_outlined,
            iconColor: Colors.grey[500]!,
            label: '${displayList.length} result${displayList.length == 1 ? '' : 's'}',
          ),
        Expanded(
          child: ListView.separated(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            itemCount: displayList.length,
            separatorBuilder: (_, __) => Divider(height: 1, indent: 56, color: Colors.grey[100]),
            itemBuilder: (context, index) {
              final loc = displayList[index];
              return _LocationTile(
                location: loc,
                icon: Icons.location_on_outlined,
                iconBgColor: _kBlue.withValues(alpha: 0.08),
                iconColor: _kBlue,
                onTap: () => _selectLocation(loc),
                highlightQuery: qLower,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.label,
  });
  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.location,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.onTap,
    this.highlightQuery,
  });
  final String location;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final VoidCallback onTap;
  final String? highlightQuery;

  static const _kBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: iconBgColor,
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: highlightQuery != null
          ? _buildHighlightedText(location, highlightQuery!)
          : Text(location, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text('Uttarakhand', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
      trailing: Icon(Icons.north_west_rounded, size: 16, color: Colors.grey[300]),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    final idx = text.toLowerCase().indexOf(query);
    if (idx < 0) {
      return Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[800]),
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: const TextStyle(fontWeight: FontWeight.w700, color: _kBlue),
          ),
          if (idx + query.length < text.length) TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
    );
  }
}
