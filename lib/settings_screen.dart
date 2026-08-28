import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  static const primary = Color(0xFF176B67);
  static const hot = Color(0xFFE85D4A);
  static const light = Color(0xFFE6F1EE);
  static const background = Color(0xFFF7F5F0);

  bool? _serviceEnabled;
  LocationPermission? _permission;
  bool _isCheckingLocation = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLocationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocationStatus();
    }
  }

  Future<void> _refreshLocationStatus() async {
    if (mounted) setState(() => _isCheckingLocation = true);
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    if (!mounted) return;
    setState(() {
      _serviceEnabled = serviceEnabled;
      _permission = permission;
      _isCheckingLocation = false;
    });
  }

  Future<void> _fixLocationAccess() async {
    if (_serviceEnabled == false) {
      await Geolocator.openLocationSettings();
      return;
    }

    final permission = _permission;
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
      await _refreshLocationStatus();
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }

    await _refreshLocationStatus();
  }

  bool get _hasLocationAccess {
    return _serviceEnabled == true &&
        (_permission == LocationPermission.whileInUse ||
            _permission == LocationPermission.always);
  }

  String get _locationStatus {
    if (_isCheckingLocation) return 'Checking location access...';
    if (_serviceEnabled == false) return 'Location services are turned off';
    if (_permission == LocationPermission.deniedForever) {
      return 'Permission is permanently denied';
    }
    if (_permission == LocationPermission.denied) {
      return 'Location permission is required';
    }
    if (_hasLocationAccess) return 'Location access is ready';
    return 'Location access is unavailable';
  }

  String get _locationAction {
    if (_serviceEnabled == false) return 'Open location settings';
    if (_permission == LocationPermission.deniedForever) {
      return 'Open app settings';
    }
    if (_permission == LocationPermission.denied) return 'Allow location';
    return 'Refresh status';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: RefreshIndicator(
          color: primary,
          onRefresh: _refreshLocationStatus,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HeatWay',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Manage access and review app information.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Location access'),
                const SizedBox(height: 10),
                _LocationStatusCard(
                  loading: _isCheckingLocation,
                  ready: _hasLocationAccess,
                  status: _locationStatus,
                  actionLabel: _locationAction,
                  onAction: _isCheckingLocation ? null : _fixLocationAccess,
                ),
                const SizedBox(height: 12),
                _Card(
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: Icons.location_on_outlined,
                        title: 'Device location settings',
                        subtitle: 'Turn GPS and location services on or off.',
                        onTap: Geolocator.openLocationSettings,
                      ),
                      const _SoftDivider(),
                      _ActionTile(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'App permission settings',
                        subtitle: 'Review HeatWay location permission.',
                        onTap: Geolocator.openAppSettings,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Service availability'),
                const SizedBox(height: 10),
                const _Card(
                  child: Column(
                    children: [
                      _InfoTile(
                        icon: Icons.public_rounded,
                        title: 'Supported region',
                        subtitle: 'United States only',
                        badge: 'U.S.',
                      ),
                      _SoftDivider(),
                      _InfoTile(
                        icon: Icons.gps_fixed_rounded,
                        title: 'Route origin',
                        subtitle: 'Your current GPS location',
                      ),
                      _SoftDivider(),
                      _InfoTile(
                        icon: Icons.pin_drop_outlined,
                        title: 'Route destination',
                        subtitle: 'Search a U.S. address or tap the map',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Data & routing'),
                const SizedBox(height: 10),
                const _Card(
                  child: Column(
                    children: [
                      _InfoTile(
                        icon: Icons.calendar_today_outlined,
                        title: 'Thermal date',
                        subtitle:
                            'Latest available day is selected automatically',
                      ),
                      _SoftDivider(),
                      _InfoTile(
                        icon: Icons.alt_route_rounded,
                        title: 'Route selection',
                        subtitle: 'Preferred route is ranked by thermal data',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionTitle('About'),
                const SizedBox(height: 10),
                const _Card(
                  child: Column(
                    children: [
                      _InfoTile(
                        icon: Icons.thermostat_rounded,
                        title: 'HeatWay',
                        subtitle: 'Find the cooler way.',
                        badge: '1.0.0',
                      ),
                      _SoftDivider(),
                      _InfoTile(
                        icon: Icons.info_outline_rounded,
                        title: 'Temperature guidance',
                        subtitle: 'For guidance only, not medical advice',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Center(
                  child: Text(
                    'HeatWay · Find the cooler way.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({
    required this.loading,
    required this.ready,
    required this.status,
    required this.actionLabel,
    required this.onAction,
  });

  final bool loading;
  final bool ready;
  final String status;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final accent =
        ready ? _SettingsScreenState.primary : _SettingsScreenState.hot;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color:
            ready
                ? _SettingsScreenState.primary
                : _SettingsScreenState.hot.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color:
                      ready
                          ? Colors.white.withValues(alpha: 0.14)
                          : Colors.white,
                  shape: BoxShape.circle,
                ),
                child:
                    loading
                        ? Padding(
                          padding: const EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accent,
                          ),
                        )
                        : Icon(
                          ready
                              ? Icons.location_on_rounded
                              : Icons.location_off_rounded,
                          color: ready ? Colors.white : accent,
                        ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready ? 'Location ready' : 'Location needs attention',
                      style: TextStyle(
                        color: ready ? Colors.white : accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status,
                      style: TextStyle(
                        color: ready ? Colors.white70 : Colors.black54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: ready ? Colors.white : accent,
                side: BorderSide(
                  color:
                      ready
                          ? Colors.white.withValues(alpha: 0.55)
                          : accent.withValues(alpha: 0.40),
                ),
              ),
              icon: const Icon(Icons.settings_rounded, size: 17),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: _SettingsScreenState.primary,
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.025),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<bool> Function() onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () => onTap(),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          _TileIcon(icon),
          const SizedBox(width: 12),
          Expanded(child: _TileText(title: title, subtitle: subtitle)),
          const Icon(
            Icons.chevron_right_rounded,
            color: _SettingsScreenState.primary,
          ),
        ],
      ),
    ),
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        _TileIcon(icon),
        const SizedBox(width: 12),
        Expanded(child: _TileText(title: title, subtitle: subtitle)),
        if (badge != null) _Badge(badge!),
      ],
    ),
  );
}

class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: const BoxDecoration(
      color: _SettingsScreenState.light,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: _SettingsScreenState.primary, size: 20),
  );
}

class _TileText extends StatelessWidget {
  const _TileText({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _SettingsScreenState.primary,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        subtitle,
        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
      ),
    ],
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: _SettingsScreenState.light,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: _SettingsScreenState.primary,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15));
}
