import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/police_station_service.dart';
import '../../core/theme/app_theme.dart';
import '../../services/location_service.dart';
import '../../widgets/safe_button.dart';
import '../../widgets/safe_card.dart';
import '../../widgets/status_badge.dart';

class NearbyPoliceScreen extends StatefulWidget {
  const NearbyPoliceScreen({super.key});

  @override
  State<NearbyPoliceScreen> createState() => _NearbyPoliceScreenState();
}

class _NearbyPoliceScreenState extends State<NearbyPoliceScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Position? _currentPosition;
  List<PoliceStation> _stations = [];

  @override
  void initState() {
    super.initState();
    _loadNearbyStations();
  }

  Future<void> _loadNearbyStations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Location access is required to discover nearby police stations. Please ensure GPS is enabled and permission is granted.';
        });
        return;
      }

      _currentPosition = pos;

      final results = await PoliceStationService.fetchNearbyStations(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      if (!mounted) return;
      setState(() {
        _stations = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to reach the mapping service. Please check your internet connection or open external maps.';
      });
    }
  }

  Future<void> _openDirections(PoliceStation station) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${station.latitude},${station.longitude}',
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open map application.')),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _callStation(PoliceStation station) async {
    final number = station.phone ?? '112';
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _call112Emergency() async {
    final uri = Uri.parse('tel:112');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } catch (_) {}
  }

  Future<void> _openExternalMapsSearch() async {
    if (_currentPosition != null) {
      final uri = Uri.parse(
        'https://www.google.com/maps/search/police+station/@${_currentPosition!.latitude},${_currentPosition!.longitude},14z',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      final uri = Uri.parse('https://www.google.com/maps/search/police+station+near+me');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Nearby Police Stations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Stations',
            onPressed: _isLoading ? null : _loadNearbyStations,
          ),
        ],
      ),
      body: Column(
        children: [
          // Clear Safety & Non-Automated Alert Notice
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDarkElevated : AppTheme.infoLightBlue,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.borderDark : AppTheme.infoBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppTheme.infoBlue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informational Directory Only',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Viewing stations does not dispatch an automated alert to police. In an immediate emergency, call 112 directly.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content Area
          Expanded(
            child: _buildContent(context, isDark),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SafeButton(
            text: 'Call 112 Emergency Police',
            icon: Icons.emergency,
            type: SafeButtonType.danger,
            onPressed: _call112Emergency,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.brandPrimary),
            const SizedBox(height: 16),
            Text(
              'Locating verified police stations...',
              style: TextStyle(
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off_outlined, size: 52, color: AppTheme.warningAmber),
              const SizedBox(height: 14),
              Text(
                'Location or Service Unavailable',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SafeButton(
                text: 'Retry Discovery',
                icon: Icons.refresh,
                onPressed: _loadNearbyStations,
              ),
              const SizedBox(height: 10),
              SafeButton(
                text: 'Search on Google Maps',
                icon: Icons.map_outlined,
                type: SafeButtonType.outline,
                onPressed: _openExternalMapsSearch,
              ),
            ],
          ),
        ),
      );
    }

    if (_stations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_police_outlined, size: 48, color: AppTheme.textTertiaryFor(context)),
              const SizedBox(height: 12),
              Text(
                'No police stations cataloged within 8 km',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Open external maps to search across a wider radius, or dial 112 immediately.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SafeButton(
                text: 'Search Wider on Maps',
                icon: Icons.open_in_new,
                type: SafeButtonType.outline,
                onPressed: _openExternalMapsSearch,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      itemCount: _stations.length,
      itemBuilder: (context, index) {
        final station = _stations[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SafeCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF312E81) : AppTheme.brandPrimaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_police,
                        color: isDark ? const Color(0xFF818CF8) : AppTheme.brandPrimary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          StatusBadge(
                            label: station.formattedDistance,
                            type: StatusBadgeType.info,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (station.address != null && station.address!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_outlined, size: 16, color: AppTheme.textTertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          station.address!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.directions, size: 18),
                        label: const Text('Directions', style: TextStyle(fontSize: 12.5)),
                        onPressed: () => _openDirections(station),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.safeGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.phone, size: 18),
                        label: Text(
                          station.phone != null ? 'Call Station' : 'Call 112',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _callStation(station),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
