
class Prayertime {
  final String readable;
  final String timestamp;

  Prayertime({required this.readable, required this.timestamp});

  DateTime dateTime(DateTime baseDate) {
    try {
      final cleanTime = readable.split(' ')[0];
      final parts = cleanTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
    } catch (_) {
      return baseDate;
    }
  }

  factory Prayertime.fromJson(Map<String, dynamic> json) {
    return Prayertime(readable: json['readable'], timestamp: json['timestamp']);
  }
}

class HijriDate {
  final String date;
  final int day;
  final String dayName;
  final int month;
  final String monthName;
  final String year;
  final List<String> holidays;

  HijriDate({
    required this.date,
    required this.day,
    required this.dayName,
    required this.month,
    required this.monthName,
    required this.year,
    required this.holidays,
  });

  factory HijriDate.fromJson(Map<String, dynamic> json) {
    return HijriDate(
      date: json['date'],
      day: int.tryParse(json['day'].toString()) ?? 1,
      dayName: json['weekday']['en'],
      month: json['month']['number'] is int
          ? json['month']['number']
          : int.tryParse(json['month']['number'].toString()) ?? 1,
      monthName: json['month']['en'],
      year: json['year'],
      holidays: List<String>.from(json['holidays'] ?? []),
    );
  }

  @override
  String toString() {
    return '$dayName, $monthName $year AH';
  }
}

class PrayerTimings {
  final Prayertime fajr;
  final Prayertime dhuhr;
  final Prayertime asr;
  final Prayertime maghrib;
  final Prayertime isha;
  final Prayertime sunrise;
  final Prayertime sunset;
  final HijriDate hijriDate;

  PrayerTimings({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.sunrise,
    required this.sunset,
    required this.hijriDate,
  });

  Map<String, DateTime> toDateTimeMap() {
    final now = DateTime.now();
    return {
      'Fajr': fajr.dateTime(now),
      'Dhuhr': dhuhr.dateTime(now),
      'Asr': asr.dateTime(now),
      'Maghrib': maghrib.dateTime(now),
      'Isha': isha.dateTime(now),
    };
  }

  factory PrayerTimings.fromJson(Map<String, dynamic> json) {
    final timings = json['timings'];
    final date = json['date'];

    return PrayerTimings(
      fajr: Prayertime(readable: timings['Fajr'], timestamp: timings['Fajr']),
      dhuhr: Prayertime(
        readable: timings['Dhuhr'],
        timestamp: timings['Dhuhr'],
      ),
      asr: Prayertime(readable: timings['Asr'], timestamp: timings['Asr']),
      maghrib: Prayertime(
        readable: timings['Maghrib'],
        timestamp: timings['Maghrib'],
      ),
      isha: Prayertime(readable: timings['Isha'], timestamp: timings['Isha']),
      sunrise: Prayertime(
        readable: timings['Sunrise'],
        timestamp: timings['Sunrise'],
      ),
      sunset: Prayertime(
        readable: timings['Sunset'],
        timestamp: timings['Sunset'],
      ),
      hijriDate: HijriDate.fromJson(date['hijri']),
    );
  }
}
