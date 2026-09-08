import 'dart:async';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:sirr/models/prayer_time_model.dart';
import 'package:sirr/services/api_service.dart';
import 'package:sirr/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sirr/services/notification_service.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:math' as math;
import 'package:universal_html/html.dart' as html;
import 'package:sirr/services/web_permission.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Map<String, PrayerTimings> _cache = {};
  bool _isLoading = true;
  String _errorMessage = '';
  // ignore: unused_field
  String _locationName = 'Mecca, Saudi Arabia';
  Position? _currentPosition;
  
  late PageController _pageController;
  final int _initialPage = 10000;
  late Timer _timer;
  DateTime _now = DateTime.now();
  late final DateTime _referenceDate;

  @override
  void initState() {
    super.initState();
    _referenceDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _pageController = PageController(initialPage: _initialPage);
    _fetchInitialLocationAndData();
    _checkAndShowInstallPrompt();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final newNow = DateTime.now();
        setState(() {
          _now = newNow;
        });

        // Update dynamic theme based on current live prayer time
        if (_cache.isNotEmpty) {
          final todayString = DateFormat('yyyy-MM-dd').format(newNow);
          final timings = _cache[todayString];
          if (timings != null) {
            Provider.of<ThemeProvider>(context, listen: false)
                .updatePeriod(newNow, timings.toDateTimeMap(newNow));
          }
        }
        
        // Trigger web notifications if exact minute starts
        if (newNow.second == 0 && _cache.isNotEmpty) {
          final todayString = DateFormat('yyyy-MM-dd').format(newNow);
          final timings = _cache[todayString];
          if (timings != null) {
            final prayers = [
              {'name': 'Fajr', 'time': timings.fajr.dateTime(newNow)},
              {'name': 'Sunrise', 'time': timings.sunrise.dateTime(newNow)},
              {'name': 'Dhuhr', 'time': timings.dhuhr.dateTime(newNow)},
              {'name': 'Asr', 'time': timings.asr.dateTime(newNow)},
              {'name': 'Maghrib', 'time': timings.maghrib.dateTime(newNow)},
              {'name': 'Isha', 'time': timings.isha.dateTime(newNow)},
            ];
            for (var p in prayers) {
              final pt = p['time'] as DateTime;
              if (pt.hour == newNow.hour && pt.minute == newNow.minute) {
                final name = p['name'] as String;
                if (NotificationService().isNotificationEnabled(name)) {
                  NotificationService().triggerForegroundNotification('Time to Pray $name', 'It is now time for $name prayer.');
                }
              }
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _checkAndShowInstallPrompt() {
    if (!kIsWeb) return;
    
    // Use Future.delayed to ensure context is fully built and mounted before showing dialog
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      
      try {
        final bool isStandalone = html.window.matchMedia('(display-mode: standalone)').matches;
        if (isStandalone) return; // Already installed as PWA

        final userAgent = html.window.navigator.userAgent.toLowerCase();
        final isIOS = userAgent.contains('iphone') || userAgent.contains('ipad') || userAgent.contains('ipod');
        final isAndroid = userAgent.contains('android');

        if (isIOS || isAndroid) {
          _showInstallDialog(isIOS);
        }
      } catch (e) {
        debugPrint("Error checking standalone mode: $e");
      }
    });
  }

  void _showInstallDialog(bool isIOS) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Install App',
            style: GoogleFonts.amiri(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Install this app on your device for the best full-screen experience and faster access!',
                style: GoogleFonts.amiri(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              if (isIOS) ...[
                Icon(Icons.ios_share, size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  'Tap the Share button below and select\n"Add to Home Screen"',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.amiri(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ] else ...[
                Icon(Icons.install_mobile, size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  'Tap the browser menu (⋮) and select\n"Install app" or "Add to Home screen"',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.amiri(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Not Now',
                style: GoogleFonts.amiri(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  DateTime _getDateForIndex(int index) {
    final diff = index - _initialPage;
    return _referenceDate.add(Duration(days: diff));
  }

  Future<void> _fetchInitialLocationAndData() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _errorMessage = 'Location services are disabled.';
        _loadDataForDate(DateTime.now());
        return;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _errorMessage = 'Location permissions denied.';
          _loadDataForDate(DateTime.now());
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
         _errorMessage = 'Location permissions permanently denied.';
         _loadDataForDate(DateTime.now());
         return;
      }

      _currentPosition = await Geolocator.getCurrentPosition();
      
      String? cityName;
      String? countryName;

      if (kIsWeb) {
        try {
          final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=${_currentPosition!.latitude}&lon=${_currentPosition!.longitude}&zoom=10',
          );
          final response = await http.get(url, headers: {'User-Agent': 'SirrApp'});
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final address = data['address'];
            cityName = address['city'] ?? address['town'] ?? address['village'] ?? address['state'];
            countryName = address['country'];
          }
        } catch (e) {
          debugPrint("Web geocoding failed: $e");
        }
      } else {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          );
          if (placemarks.isNotEmpty) {
            cityName = placemarks.first.locality ?? placemarks.first.subAdministrativeArea;
            countryName = placemarks.first.country;
          }
        } catch (e) {
          debugPrint("Native geocoding failed: $e");
        }
      }

      if (cityName != null) {
        _locationName = "$cityName${countryName != null ? ', $countryName' : ''}";
      } else {
        _locationName = "Current Location";
      }

      await _loadDataForDate(DateTime.now());
      // Pre-load adjacent days so countdown/next-prayer cards work at day boundaries
      _loadDataForDate(DateTime.now().add(const Duration(days: 1)));
      _loadDataForDate(DateTime.now().subtract(const Duration(days: 1)));
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      _errorMessage = e.toString();
      _loadDataForDate(DateTime.now());
    }
  }

  Future<void> _loadDataForDate(DateTime date) async {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    if (_cache.containsKey(dateString)) return;

    try {
      PrayerTimings timings;
      if (_currentPosition != null) {
        timings = await ApiService().getPrayerTimingsByLocation(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          targetDate: date,
        );
      } else {
        timings = await ApiService().getPrayerTimings(
          city: 'Mecca',
          country: 'SA',
          targetDate: date,
        );
      }
      
      if (mounted) {
        setState(() {
          _cache[dateString] = timings;
          _isLoading = false;
        });
        
        // Update theme provider
        if (dateString == DateFormat('yyyy-MM-dd').format(DateTime.now())) {
           Provider.of<ThemeProvider>(context, listen: false).updatePeriod(DateTime.now(), timings.toDateTimeMap());
        }
        
        NotificationService().schedulePrayerNotifications(_cache);
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  Map<String, dynamic>? _getCurrentPrayer(PrayerTimings timings, DateTime date) {
    final pageTime = DateTime(date.year, date.month, date.day, _now.hour, _now.minute, _now.second);
    final prayers = [
      {'name': 'Fajr', 'time': timings.fajr.dateTime(date)},
      {'name': 'Dhuhr', 'time': timings.dhuhr.dateTime(date)},
      {'name': 'Asr', 'time': timings.asr.dateTime(date)},
      {'name': 'Maghrib', 'time': timings.maghrib.dateTime(date)},
      {'name': 'Isha', 'time': timings.isha.dateTime(date)},
    ];
    for (int i = prayers.length - 1; i >= 0; i--) {
      if (pageTime.isAfter(prayers[i]['time'] as DateTime)) {
        return prayers[i];
      }
    }
    
    final yesterday = date.subtract(const Duration(days: 1));
    final yesterdayString = DateFormat('yyyy-MM-dd').format(yesterday);
    if (_cache.containsKey(yesterdayString)) {
      final yesterdayTimings = _cache[yesterdayString]!;
      return {'name': 'Isha', 'time': yesterdayTimings.isha.dateTime(yesterday)};
    }
    
    return null;
  }

  Map<String, dynamic>? _getNextPrayer(PrayerTimings timings, DateTime date) {
    final pageTime = DateTime(date.year, date.month, date.day, _now.hour, _now.minute, _now.second);
    final prayers = [
      {'name': 'Fajr', 'time': timings.fajr.dateTime(date)},
      {'name': 'Dhuhr', 'time': timings.dhuhr.dateTime(date)},
      {'name': 'Asr', 'time': timings.asr.dateTime(date)},
      {'name': 'Maghrib', 'time': timings.maghrib.dateTime(date)},
      {'name': 'Isha', 'time': timings.isha.dateTime(date)},
    ];
    for (var p in prayers) {
      if (pageTime.isBefore(p['time'] as DateTime)) {
        return p;
      }
    }
    
    final tomorrow = date.add(const Duration(days: 1));
    final tomorrowString = DateFormat('yyyy-MM-dd').format(tomorrow);
    if (_cache.containsKey(tomorrowString)) {
      final tomorrowTimings = _cache[tomorrowString]!;
      return {'name': 'Fajr', 'time': tomorrowTimings.fajr.dateTime(tomorrow)};
    }
    
    return null;
  }

  Widget _buildDateHeader(int index, PrayerTimings timings, DateTime date) {
    final hijriFormatted = "${timings.hijriDate.day} ${timings.hijriDate.monthName}, ${timings.hijriDate.year}";
    final gregorianFormatted = DateFormat('EEE, d MMMM yyyy').format(date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: Theme.of(context).colorScheme.primary, size: 18),
            onPressed: () {
              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            },
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                hijriFormatted,
                style: GoogleFonts.amiri(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                gregorianFormatted,
                style: GoogleFonts.amiri(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary, size: 18),
            onPressed: () {
              _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNowPrayingCard(PrayerTimings timings, DateTime date) {
    final current = _getCurrentPrayer(timings, date);
    final next = _getNextPrayer(timings, date);
    if (current == null) return const SizedBox.shrink();
    
    final currentName = current['name'] as String;
    final currentTime = DateFormat('h:mm a').format(current['time'] as DateTime);
    final endsTime = next != null ? "ends ${DateFormat('h:mma').format(next['time'] as DateTime).toLowerCase()}" : "";
    
    String? elapsedString;
    final pageTime = DateTime(date.year, date.month, date.day, _now.hour, _now.minute, _now.second);
    final startTime = current['time'] as DateTime;
    if (pageTime.isAfter(startTime)) {
      final elapsed = pageTime.difference(startTime);
      final hours = elapsed.inHours.toString().padLeft(2, '0');
      final mins = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
      final secs = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
      elapsedString = "+ $hours:$mins:$secs since Azhaan";
    }

    final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    final label = todayString == dateString ? "NOW TIME TO PRAY" : "PRAYER ACTIVE";

    return _buildPrayingCardUI(currentName, currentTime, endsTime, label, elapsedString);
  }

  Widget _buildPrayingCardUI(String prayerName, String time, String endsLabel, String label, [String? elapsedString]) {
    final timeParts = time.split(' ');
    final timeValue = timeParts[0];
    final timePeriod = timeParts.length > 1 ? timeParts[1] : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [ BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.5), offset: Offset(0, 4)),
          BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.1), offset: Offset(0, 1), blurRadius: 0, spreadRadius: -1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.amiri(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            prayerName.toUpperCase(),
            style: GoogleFonts.amiri(
              fontSize: 44,
              height: 1.0,
              color: Theme.of(context).colorScheme.onSurface,
              shadows: [
                Shadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.2), offset: Offset(1, 1)),
                Shadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.2), offset: Offset(2, 2)),
                Shadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.2), offset: Offset(3, 3)),
                Shadow(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), offset: Offset(4, 4)),
                Shadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.6), offset: Offset(5, 5), blurRadius: 6),
              ],
            ),
          ),
          if (elapsedString != null) ...[
            const SizedBox(height: 4),
            Text(
              elapsedString,
              style: GoogleFonts.amiri(
                fontSize: 14,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: timeValue,
                      style: GoogleFonts.amiri(fontSize: 22, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
                    ),
                    TextSpan(
                      text: ' $timePeriod',
                      style: GoogleFonts.amiri(fontSize: 13, fontWeight: FontWeight.w400, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                endsLabel,
                style: GoogleFonts.amiri(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlipDigit(String char) {
    if (char == ':') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(
          ":",
          style: GoogleFonts.amiri(
            fontSize: 36,
            height: 1.0,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final transform = Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateX((1 - animation.value) * (3.14 / 2));
            return Transform(
              alignment: FractionalOffset.center,
              transform: transform,
              child: Opacity(
                opacity: animation.value,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      child: Container(
        key: ValueKey<String>(char),
        margin: const EdgeInsets.symmetric(horizontal: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [ BoxShadow(
              color: Colors.black26,
              offset: Offset(0, 3),
              blurRadius: 4,
            )
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              char,
              style: GoogleFonts.amiri(
                fontSize: 36,
                height: 1.0,
                color: Theme.of(context).colorScheme.onSurface,
                shadows: [
                  Shadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.2), offset: Offset(1, 1)),
                  Shadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.2), offset: Offset(2, 2)),
                  Shadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.2), offset: Offset(3, 3)),
                  Shadow(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), offset: Offset(4, 4)),
                  Shadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.6), offset: Offset(5, 5), blurRadius: 6),
                ],
              ),
            ),
            Positioned(
              left: -8,
              right: -8,
              child: Container(
                height: 1.5,
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownCard(PrayerTimings timings, DateTime date) {
    final next = _getNextPrayer(timings, date);
    if (next == null) return const SizedBox.shrink();

    final pageTime = DateTime(date.year, date.month, date.day, _now.hour, _now.minute, _now.second);
    final diff = (next['time'] as DateTime).difference(pageTime);
    if (diff.isNegative) return const SizedBox.shrink();

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = twoDigits(diff.inHours);
    final m = twoDigits(diff.inMinutes.remainder(60));
    final s = twoDigits(diff.inSeconds.remainder(60));
    final countdownString = "$h:$m:$s";

    final nextTimeFormatted = DateFormat('h:mm a').format(next['time'] as DateTime).toUpperCase();
    
    // progress logic
    final current = _getCurrentPrayer(timings, date);
    double pct = 0.0;
    if (current != null) {
      final totalWindow = (next['time'] as DateTime).difference(current['time'] as DateTime).inMilliseconds;
      final elapsed = pageTime.difference(current['time'] as DateTime).inMilliseconds;
      if (totalWindow > 0) {
        pct = (elapsed / totalWindow).clamp(0.0, 1.0);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [ BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.5), offset: Offset(0, 4)),
          BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.1), offset: Offset(0, 1), blurRadius: 0, spreadRadius: -1),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "TIME UNTIL ${next['name'].toString().toUpperCase()}",
                style: GoogleFonts.amiri(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                nextTimeFormatted,
                style: GoogleFonts.amiri(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: countdownString.split('').map((char) => _buildFlipDigit(char)).toList(),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 14),
            height: 5,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextPrayerDetailCard(PrayerTimings timings, DateTime date) {
    final next = _getNextPrayer(timings, date);
    if (next == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [ BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.5), offset: Offset(0, 4)),
          BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.1), offset: Offset(0, 1), blurRadius: 0, spreadRadius: -1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "NEXT PRAYER",
            style: GoogleFonts.amiri(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                next['name'].toString().toUpperCase(),
                style: GoogleFonts.amiri(
                  fontSize: 22,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: DateFormat('h:mm').format(next['time'] as DateTime),
                      style: GoogleFonts.amiri(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
                    ),
                    TextSpan(
                      text: ' ${DateFormat('a').format(next['time'] as DateTime).toLowerCase()}',
                      style: GoogleFonts.amiri(fontSize: 12, fontWeight: FontWeight.w400, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15))),
            ),
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(child: _buildSunInfo(Icons.wb_twilight, "SUNRISE", timings.sunrise.readable)),
                Container(
                  width: 1,
                  height: 40,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                ),
                Expanded(child: _buildSunInfo(Icons.wb_sunny, "MID DAY", timings.dhuhr.readable)),
                Container(
                  width: 1,
                  height: 40,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                ),
                Expanded(child: _buildSunInfo(Icons.nights_stay, "SUNSET", timings.maghrib.readable)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSunInfo(IconData icon, String label, String time) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.amiri(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time.toLowerCase(),
          style: GoogleFonts.amiri(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerList(PrayerTimings timings, DateTime date) {
    final current = _getCurrentPrayer(timings, date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [ BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.5), offset: Offset(0, 4)),
          BoxShadow(color: Theme.of(context).shadowColor.withValues(alpha: 0.1), offset: Offset(0, 1), blurRadius: 0, spreadRadius: -1),
        ],
      ),
      child: Column(
        children: [
          _buildPrayerListItem("Fajr", timings.fajr.dateTime(date), Icons.dark_mode, current != null && current['name'] == 'Fajr'),
          _buildPrayerListItem("Dhuhr", timings.dhuhr.dateTime(date), Icons.wb_sunny, current != null && current['name'] == 'Dhuhr'),
          _buildPrayerListItem("Asr", timings.asr.dateTime(date), Icons.cloud, current != null && current['name'] == 'Asr'),
          _buildPrayerListItem("Maghrib", timings.maghrib.dateTime(date), Icons.thunderstorm, current != null && current['name'] == 'Maghrib'),
          _buildPrayerListItem("Isha", timings.isha.dateTime(date), Icons.bedtime, current != null && current['name'] == 'Isha', isLast: true),
        ],
      ),
    );
  }

  Future<void> _handleNotificationToggle(String prayerName) async {
    final willEnable = !NotificationService().isNotificationEnabled(prayerName);
    await NotificationService().toggleNotification(prayerName);
    
    if (willEnable && kIsWeb && mounted) {
      try {
        final bool isStandalone = html.window.matchMedia('(display-mode: standalone)').matches;
        final userAgent = html.window.navigator.userAgent.toLowerCase();
        final isIOS = userAgent.contains('iphone') || userAgent.contains('ipad') || userAgent.contains('ipod');
        
        if (isIOS && !isStandalone) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'To get notifications on iPhone, tap Share (⎋) and select "Add to Home Screen".',
                style: GoogleFonts.amiri(),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (_) {}
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildPrayerListItem(String name, DateTime time, IconData icon, bool isActive, {bool isLast = false}) {
    if (isActive) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: Theme.of(context).colorScheme.onPrimary),
                const SizedBox(width: 10),
                Text(
                  name,
                  style: GoogleFonts.amiri(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onPrimary),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  DateFormat('h:mm a').format(time).toLowerCase(),
                  style: GoogleFonts.amiri(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onPrimary),
                ),
                GestureDetector(
                  onTap: () => _handleNotificationToggle(name),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
                      return ScaleTransition(scale: curvedAnimation, child: FadeTransition(opacity: animation, child: child));
                    },
                    child: Icon(
                      NotificationService().isNotificationEnabled(name) ? Icons.notifications_active : Icons.notifications_off,
                      key: ValueKey<bool>(NotificationService().isNotificationEnabled(name)),
                      size: 15,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(
                name,
                style: GoogleFonts.amiri(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                DateFormat('h:mm a').format(time).toLowerCase(),
                style: GoogleFonts.amiri(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              GestureDetector(
                onTap: () => _handleNotificationToggle(name),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
                    return ScaleTransition(scale: curvedAnimation, child: FadeTransition(opacity: animation, child: child));
                  },
                  child: Icon(
                    NotificationService().isNotificationEnabled(name) ? Icons.notifications_active : Icons.notifications_off,
                    key: ValueKey<bool>(NotificationService().isNotificationEnabled(name)),
                    size: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 30.0),
      child: Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final Uri url = Uri.parse('https://adilrahman.cc');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Developed by ',
                  style: GoogleFonts.amiri(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  'Adil Rahman',
                  style: GoogleFonts.amiri(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingDateOverlay() {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        if (!_pageController.position.haveDimensions) return const SizedBox.shrink();

        double page = _pageController.page!;
        double diff = (page - page.roundToDouble()).abs();

        // Fully hidden when not swiping
        if (diff < 0.01) return const SizedBox.shrink();

        // Destination is the nearest page we're heading towards
        final targetIndex = page.round();

        final targetDate = _getDateForIndex(targetIndex);
        final day = DateFormat('d').format(targetDate);
        final month = DateFormat('MMMM').format(targetDate).toUpperCase();

        // Fade in/out based on swipe progress
        double opacity = (diff < 0.5 ? diff * 2 : (1 - diff) * 2).clamp(0.0, 1.0);

        return IgnorePointer(
          child: Center(
            child: Opacity(
              opacity: opacity * 0.35,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    day,
                    style: GoogleFonts.amiri(
                      fontSize: 160,
                      color: Theme.of(context).colorScheme.primary,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    month,
                    style: GoogleFonts.amiri(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: Theme.of(context).colorScheme.primary,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLoading(bool isDesktop) {
    final cardColor = Colors.white;
    final r22 = BorderRadius.circular(22);
    final r8 = BorderRadius.circular(8);
    final r4 = BorderRadius.circular(4);

    final header = Column(
      children: [
        const SizedBox(height: 14),
        Center(child: Container(height: 16, width: 180, decoration: BoxDecoration(color: cardColor, borderRadius: r8))),
        const SizedBox(height: 4),
        Center(child: Container(height: 12, width: 140, decoration: BoxDecoration(color: cardColor, borderRadius: r4))),
        const SizedBox(height: 18),
      ],
    );

    final card1 = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(color: cardColor, borderRadius: r22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 12, width: 120, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
          const SizedBox(height: 10),
          Container(height: 40, width: 180, decoration: BoxDecoration(color: cardColor, borderRadius: r8)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(height: 18, width: 80, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
              Container(height: 12, width: 90, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
            ],
          ),
        ],
      ),
    );

    final card2 = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(color: cardColor, borderRadius: r22),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(height: 12, width: 110, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
              Container(height: 12, width: 60, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 36, width: 200, decoration: BoxDecoration(color: cardColor, borderRadius: r8)),
          const SizedBox(height: 16),
          Container(height: 5, width: double.infinity, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
        ],
      ),
    );

    final card3 = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: cardColor, borderRadius: r22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 12, width: 100, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(height: 22, width: 80, decoration: BoxDecoration(color: cardColor, borderRadius: r8)),
              Container(height: 18, width: 70, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, width: double.infinity, color: cardColor),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Column(children: [
                Container(height: 18, width: 18, decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle)),
                const SizedBox(height: 6),
                Container(height: 10, width: 50, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
                const SizedBox(height: 4),
                Container(height: 14, width: 55, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
              ])),
              Expanded(child: Column(children: [
                Container(height: 18, width: 18, decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle)),
                const SizedBox(height: 6),
                Container(height: 10, width: 50, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
                const SizedBox(height: 4),
                Container(height: 14, width: 55, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
              ])),
              Expanded(child: Column(children: [
                Container(height: 18, width: 18, decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle)),
                const SizedBox(height: 6),
                Container(height: 10, width: 50, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
                const SizedBox(height: 4),
                Container(height: 14, width: 55, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
              ])),
            ],
          ),
        ],
      ),
    );

    final card4 = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(color: cardColor, borderRadius: r22),
      child: Column(
        children: List.generate(5, (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(height: 17, width: 17, decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Container(height: 14, width: 60, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
              ]),
              Row(children: [
                Container(height: 14, width: 60, decoration: BoxDecoration(color: cardColor, borderRadius: r4)),
                const SizedBox(width: 8),
                Container(height: 15, width: 15, decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle)),
              ]),
            ],
          ),
        )),
      ),
    );

    Widget content;
    if (isDesktop) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: Column(
            children: [
              header,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [card1, const SizedBox(height: 12), card2, const SizedBox(height: 12), card3],
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    child: card4,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header, card1, const SizedBox(height: 12), card2, const SizedBox(height: 12), card3, const SizedBox(height: 12), card4
        ],
      );
    }

    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.primaryContainer,
      highlightColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 840;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(child: _buildSkeletonLoading(isDesktop)),
      );
    }

    if (_errorMessage.isNotEmpty && _cache.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: Text(_errorMessage, style: TextStyle(color: Colors.white))),
      );
    }

    final pageView = PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        final date = _getDateForIndex(index);
        _loadDataForDate(date);
        _loadDataForDate(date.add(const Duration(days: 1)));
        _loadDataForDate(date.subtract(const Duration(days: 1)));
      },
      itemBuilder: (context, index) {
        final targetDate = _getDateForIndex(index);
        final dateString = DateFormat('yyyy-MM-dd').format(targetDate);
        final timings = _cache[dateString];

        if (timings == null) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: _buildSkeletonLoading(isDesktop),
          );
        }

        Widget mainContent;
        if (isDesktop) {
          mainContent = SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Column(
                  children: [
                    _buildDateHeader(index, timings, targetDate),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildNowPrayingCard(timings, targetDate),
                              _buildCountdownCard(timings, targetDate),
                              _buildNextPrayerDetailCard(timings, targetDate),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                        Expanded(
                          child: Column(
                            children: [
                              _buildPrayerList(timings, targetDate),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          );
        } else {
          mainContent = SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              children: [
                _buildDateHeader(index, timings, targetDate),
                _buildNowPrayingCard(timings, targetDate),
                _buildCountdownCard(timings, targetDate),
                _buildNextPrayerDetailCard(timings, targetDate),
                _buildPrayerList(timings, targetDate),
                _buildFooter(),
                const SizedBox(height: 40),
              ],
            ),
          );
        }

        return mainContent;
      },
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            pageView,
            _buildFloatingDateOverlay(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.explore, color: Colors.white),
        onPressed: () async {
          if (kIsWeb) {
            await requestWebOrientationPermission();
          }
          _showCompassModal();
        },
      ),
    );
  }

  void _showCompassModal() {
    double userLat = 0.0;
    double userLon = 0.0;
    
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not available. Using default location (London).')));
      // Fallback to London coordinates so the UI still works
      userLat = 51.5074;
      userLon = -0.1278;
    } else {
      userLat = _currentPosition!.latitude;
      userLon = _currentPosition!.longitude;
    }
    
    // Kaaba / Mecca coordinates
    const double meccaLat = 21.42377783053372;
    const double meccaLon = 39.825402612333306;
    
    // Calculate Qibla Bearing
    final double lat1 = userLat * math.pi / 180.0;
    final double lat2 = meccaLat * math.pi / 180.0;
    final double lonDiff = (meccaLon - userLon) * math.pi / 180.0;
    
    final double y = math.sin(lonDiff) * math.cos(lat2);
    final double x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(lonDiff);
    
    double qiblaBearing = math.atan2(y, x) * 180.0 / math.pi;
    if (qiblaBearing < 0) {
      qiblaBearing += 360.0;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return QiblaCompassModal(
          userLat: userLat,
          userLon: userLon,
          qiblaBearing: qiblaBearing,
        );
      }
    );
  }
}

class QiblaCompassModal extends StatefulWidget {
  final double userLat;
  final double userLon;
  final double qiblaBearing;

  const QiblaCompassModal({
    super.key,
    required this.userLat,
    required this.userLon,
    required this.qiblaBearing,
  });

  @override
  State<QiblaCompassModal> createState() => _QiblaCompassModalState();
}

class _QiblaCompassModalState extends State<QiblaCompassModal> with SingleTickerProviderStateMixin {
  bool _permissionDenied = false;
  bool _noSensorDetected = false;
  Timer? _timeoutTimer;
  double _lastSmoothedAngle = 0.0;
  bool _isCalibrating = false;
  late AnimationController _calibrationController;

  @override
  void initState() {
    super.initState();
    _calibrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _initPermission();
  }

  Future<void> _initPermission() async {
    if (kIsWeb) {
      try {
        final bool isGranted = await requestWebOrientationPermission();
        if (!isGranted) {
          setState(() {
            _permissionDenied = true;
          });
          return;
        }
      } catch (e) {
        debugPrint("Error requesting orientation permission on web: $e");
      }
      
      _timeoutTimer = Timer(const Duration(seconds: 4), () {
        if (mounted && getWebCompassHeading() == null) {
          setState(() {
            _noSensorDetected = true;
          });
        }
      });
    }
  }

  Future<void> _calibrateCompass() async {
    setState(() {
      _isCalibrating = true;
      _permissionDenied = false;
      _noSensorDetected = false;
    });

    _calibrationController.forward(from: 0.0);

    if (kIsWeb) {
      await requestWebOrientationPermission();
    }

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _isCalibrating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✦ Calibrated • Pointing to Kaaba (${widget.qiblaBearing.toStringAsFixed(1)}°)',
            style: GoogleFonts.amiri(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _calibrationController.dispose();
    super.dispose();
  }

  double _calculateShortestAngle(double targetAngle, double currentAngle) {
    double diff = (targetAngle - currentAngle) % (2 * math.pi);
    if (diff < -math.pi) diff += 2 * math.pi;
    if (diff > math.pi) diff -= 2 * math.pi;
    return currentAngle + diff;
  }

  String _getCardinalDirection(double angle) {
    if (angle >= 337.5 || angle < 22.5) return 'N';
    if (angle >= 22.5 && angle < 67.5) return 'NE';
    if (angle >= 67.5 && angle < 112.5) return 'E';
    if (angle >= 112.5 && angle < 157.5) return 'SE';
    if (angle >= 157.5 && angle < 202.5) return 'S';
    if (angle >= 202.5 && angle < 247.5) return 'SW';
    if (angle >= 247.5 && angle < 292.5) return 'W';
    if (angle >= 292.5 && angle < 337.5) return 'NW';
    return '';
  }

  String _getDistanceToMecca() {
    const double meccaLat = 21.42377783053372;
    const double meccaLon = 39.825402612333306;
    const double earthRadiusKm = 6371.0;

    final double dLat = (meccaLat - widget.userLat) * math.pi / 180.0;
    final double dLon = (meccaLon - widget.userLon) * math.pi / 180.0;
    final double lat1 = widget.userLat * math.pi / 180.0;
    final double lat2 = meccaLat * math.pi / 180.0;

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final double distance = earthRadiusKm * c;

    final formatter = NumberFormat('#,###');
    return '${formatter.format(distance.round())} km to Kaaba';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final onSurfaceColor = theme.colorScheme.onSurface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.25),
            blurRadius: 25,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 42,
            height: 4.5,
            decoration: BoxDecoration(
              color: onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qibla Compass',
                      style: GoogleFonts.amiri(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: onSurfaceColor,
                      ),
                    ),
                    Text(
                      'Kaaba, Masjid al-Haram',
                      style: GoogleFonts.amiri(
                        fontSize: 13,
                        color: onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                RotationTransition(
                  turns: _calibrationController,
                  child: IconButton.filledTonal(
                    icon: Icon(Icons.refresh, color: primaryColor),
                    tooltip: 'Calibrate Compass',
                    onPressed: _calibrateCompass,
                  ),
                ),
              ],
            ),
          ),

          // Main Compass Area
          Expanded(
            child: _permissionDenied
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Compass permission denied.\nPlease enable device motion / compass access in your settings.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.amiri(fontSize: 17, color: onSurfaceColor),
                      ),
                    ),
                  )
                : _noSensorDetected
                    ? _buildStaticCompassView(onSurfaceColor, primaryColor)
                    : StreamBuilder<dynamic>(
                        stream: kIsWeb ? html.window.onDeviceOrientation : FlutterCompass.events,
                        builder: (context, snapshot) {
                          double? deviceHeading;

                          if (kIsWeb) {
                            final webHeading = getWebCompassHeading();
                            if (webHeading != null) {
                              _timeoutTimer?.cancel();
                              deviceHeading = webHeading;
                            } else {
                              final html.DeviceOrientationEvent? event = snapshot.data as html.DeviceOrientationEvent?;
                              if (event != null && event.alpha != null) {
                                _timeoutTimer?.cancel();
                                deviceHeading = (360.0 - event.alpha!.toDouble()) % 360.0;
                              }
                            }
                          } else {
                            deviceHeading = (snapshot.data as CompassEvent?)?.heading;
                          }

                          if (deviceHeading == null) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            return _buildStaticCompassView(onSurfaceColor, primaryColor);
                          }

                          // Calculate shortest rotation angle
                          final double rawRotationAngle = (widget.qiblaBearing - deviceHeading) * (math.pi / 180.0);
                          _lastSmoothedAngle = _calculateShortestAngle(rawRotationAngle, _lastSmoothedAngle);

                          double angleDiffDeg = (widget.qiblaBearing - deviceHeading) % 360.0;
                          if (angleDiffDeg > 180.0) angleDiffDeg -= 360.0;
                          if (angleDiffDeg < -180.0) angleDiffDeg += 360.0;
                          final bool isFacingKaaba = angleDiffDeg.abs() <= 5.0;

                          return _buildActiveCompassView(
                            deviceHeading: deviceHeading,
                            targetAngle: _lastSmoothedAngle,
                            isFacingKaaba: isFacingKaaba,
                            angleDiffDeg: angleDiffDeg,
                            primaryColor: primaryColor,
                            onSurfaceColor: onSurfaceColor,
                          );
                        },
                      ),
          ),

          // Bottom Details & Coordinates
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.userLat.toStringAsFixed(4)}°N  ${widget.userLon.toStringAsFixed(4)}°E',
                      style: GoogleFonts.amiri(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: onSurfaceColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getDistanceToMecca(),
                      style: GoogleFonts.amiri(
                        fontSize: 12,
                        color: onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Qibla: ${widget.qiblaBearing.toStringAsFixed(1)}°',
                    style: GoogleFonts.amiri(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCompassView({
    required double deviceHeading,
    required double targetAngle,
    required bool isFacingKaaba,
    required double angleDiffDeg,
    required Color primaryColor,
    required Color onSurfaceColor,
  }) {
    final activeColor = isFacingKaaba ? const Color(0xFF00E676) : primaryColor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Heading & Status Badge
        Text(
          '${deviceHeading.toStringAsFixed(0)}° ${_getCardinalDirection(deviceHeading)}',
          style: GoogleFonts.amiri(
            fontSize: 42,
            fontWeight: FontWeight.w300,
            color: onSurfaceColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isFacingKaaba
                ? const Color(0xFF00E676).withValues(alpha: 0.18)
                : onSurfaceColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isFacingKaaba
                  ? const Color(0xFF00E676).withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            isFacingKaaba
                ? '✦ Facing the Kaaba ✦'
                : 'Turn ${angleDiffDeg > 0 ? 'Right' : 'Left'} by ${angleDiffDeg.abs().toStringAsFixed(0)}°',
            style: GoogleFonts.amiri(
              fontSize: 14,
              fontWeight: isFacingKaaba ? FontWeight.bold : FontWeight.w500,
              color: isFacingKaaba ? const Color(0xFF00E676) : onSurfaceColor.withValues(alpha: 0.8),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Compass Rose with Smooth Dial & Kaaba Pointer
        Expanded(
          child: Center(
            child: SizedBox(
              width: 270,
              height: 270,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rotating Compass Dial
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: -deviceHeading * (math.pi / 180.0)),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    builder: (context, dialAngle, child) {
                      return Transform.rotate(
                        angle: dialAngle,
                        child: CustomPaint(
                          size: const Size(270, 270),
                          painter: CompassDialPainter(
                            primaryColor: primaryColor,
                            textColor: onSurfaceColor,
                            accentColor: activeColor,
                            qiblaBearing: widget.qiblaBearing,
                            isAligned: isFacingKaaba,
                          ),
                          child: Stack(
                            children: [
                              // North Marker
                              Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 14.0),
                                  child: Text('N', style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFFFF5252))),
                                ),
                              ),
                              // East Marker
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 14.0),
                                  child: Text('E', style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor.withValues(alpha: 0.7))),
                                ),
                              ),
                              // South Marker
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 14.0),
                                  child: Text('S', style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor.withValues(alpha: 0.7))),
                                ),
                              ),
                              // West Marker
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 14.0),
                                  child: Text('W', style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 14, color: onSurfaceColor.withValues(alpha: 0.7))),
                                ),
                              ),
                              // Kaaba Emblem on Dial Ring
                              Transform.rotate(
                                angle: widget.qiblaBearing * (math.pi / 180.0),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: isFacingKaaba ? const Color(0xFF00E676) : primaryColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isFacingKaaba ? const Color(0xFF00E676) : primaryColor).withValues(alpha: 0.5),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.mosque, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Center Qibla Pointer Needle
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: targetAngle),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    builder: (context, angle, child) {
                      return Transform.rotate(
                        angle: angle,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.navigation,
                              size: 150,
                              color: activeColor,
                            ),
                            // Center Pivot Dot
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: onSurfaceColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.colorScheme.surface, width: 3),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaticCompassView(Color onSurfaceColor, Color primaryColor) {
    final double qiblaRad = widget.qiblaBearing * (math.pi / 180.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Kaaba Bearing',
          style: GoogleFonts.amiri(fontSize: 16, color: onSurfaceColor.withValues(alpha: 0.7)),
        ),
        Text(
          '${widget.qiblaBearing.toStringAsFixed(1)}° ${_getCardinalDirection(widget.qiblaBearing)}',
          style: GoogleFonts.amiri(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(240, 240),
                painter: CompassDialPainter(
                  primaryColor: primaryColor,
                  textColor: onSurfaceColor,
                  accentColor: primaryColor,
                  qiblaBearing: widget.qiblaBearing,
                  isAligned: false,
                ),
              ),
              Transform.rotate(
                angle: qiblaRad,
                child: Icon(Icons.navigation, size: 140, color: primaryColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Rotate your device until North aligns to point directly to Kaaba.',
            textAlign: TextAlign.center,
            style: GoogleFonts.amiri(fontSize: 13, color: onSurfaceColor.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }
}

class CompassDialPainter extends CustomPainter {
  final Color primaryColor;
  final Color textColor;
  final Color accentColor;
  final double qiblaBearing;
  final bool isAligned;

  CompassDialPainter({
    required this.primaryColor,
    required this.textColor,
    required this.accentColor,
    required this.qiblaBearing,
    required this.isAligned,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer circle
    final circlePaint = Paint()
      ..color = textColor.withValues(alpha: isAligned ? 0.3 : 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius - 8, circlePaint);

    // Inner circle
    final innerCirclePaint = Paint()
      ..color = textColor.withValues(alpha: isAligned ? 0.2 : 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 30, innerCirclePaint);

    final tickPaint = Paint()..style = PaintingStyle.stroke;

    for (int i = 0; i < 360; i += 5) {
      final isMajor = i % 30 == 0;
      final isCardinal = i % 90 == 0;
      final angle = (i - 90) * math.pi / 180.0;

      final tickLength = isCardinal ? 12.0 : (isMajor ? 8.0 : 4.0);
      tickPaint.strokeWidth = isCardinal ? 2.2 : (isMajor ? 1.4 : 0.9);
      tickPaint.color = isCardinal
          ? (i == 0 ? const Color(0xFFFF5252) : primaryColor)
          : textColor.withValues(alpha: isMajor ? 0.45 : 0.15);

      final p1 = Offset(
        center.dx + (radius - 10 - tickLength) * math.cos(angle),
        center.dy + (radius - 10 - tickLength) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + (radius - 10) * math.cos(angle),
        center.dy + (radius - 10) * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CompassDialPainter oldDelegate) {
    return oldDelegate.isAligned != isAligned ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.textColor != textColor;
  }
}
