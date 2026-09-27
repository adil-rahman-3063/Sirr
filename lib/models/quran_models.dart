class SurahModel {
  final int number;
  final String name;
  final String englishName;
  final String englishNameTranslation;
  final int numberOfAyahs;
  final String revelationType;

  SurahModel({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.numberOfAyahs,
    required this.revelationType,
  });

  factory SurahModel.fromJson(Map<String, dynamic> json) {
    return SurahModel(
      number: json['number'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      englishNameTranslation: json['englishNameTranslation'] as String? ?? '',
      numberOfAyahs: json['numberOfAyahs'] as int? ?? 0,
      revelationType: json['revelationType'] as String? ?? 'Meccan',
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'name': name,
    'englishName': englishName,
    'englishNameTranslation': englishNameTranslation,
    'numberOfAyahs': numberOfAyahs,
    'revelationType': revelationType,
  };
}

class AyahModel {
  final int number;
  final String text;
  final int numberInSurah;
  final int juz;
  final int page;
  final int ruku;
  final int hizbQuarter;
  final bool sajda;

  AyahModel({
    required this.number,
    required this.text,
    required this.numberInSurah,
    required this.juz,
    required this.page,
    required this.ruku,
    required this.hizbQuarter,
    required this.sajda,
  });

  factory AyahModel.fromJson(Map<String, dynamic> json) {
    bool isSajda = false;
    if (json['sajda'] is bool) {
      isSajda = json['sajda'] as bool;
    } else if (json['sajda'] is Map) {
      isSajda = true;
    }

    return AyahModel(
      number: json['number'] as int? ?? 0,
      text: json['text'] as String? ?? '',
      numberInSurah: json['numberInSurah'] as int? ?? 0,
      juz: json['juz'] as int? ?? 1,
      page: json['page'] as int? ?? 1,
      ruku: json['ruku'] as int? ?? 1,
      hizbQuarter: json['hizbQuarter'] as int? ?? 1,
      sajda: isSajda,
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'text': text,
    'numberInSurah': numberInSurah,
    'juz': juz,
    'page': page,
    'ruku': ruku,
    'hizbQuarter': hizbQuarter,
    'sajda': sajda,
  };
}

class SurahDetailModel {
  final int number;
  final String name;
  final String englishName;
  final String englishNameTranslation;
  final String revelationType;
  final int numberOfAyahs;
  final List<AyahModel> ayahs;

  SurahDetailModel({
    required this.number,
    required this.name,
    required this.englishName,
    required this.englishNameTranslation,
    required this.revelationType,
    required this.numberOfAyahs,
    required this.ayahs,
  });

  factory SurahDetailModel.fromJson(Map<String, dynamic> json) {
    final rawAyahs = json['ayahs'] as List<dynamic>? ?? [];
    return SurahDetailModel(
      number: json['number'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      englishNameTranslation: json['englishNameTranslation'] as String? ?? '',
      revelationType: json['revelationType'] as String? ?? 'Meccan',
      numberOfAyahs: json['numberOfAyahs'] as int? ?? rawAyahs.length,
      ayahs: rawAyahs.map((a) => AyahModel.fromJson(a as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'name': name,
    'englishName': englishName,
    'englishNameTranslation': englishNameTranslation,
    'revelationType': revelationType,
    'numberOfAyahs': numberOfAyahs,
    'ayahs': ayahs.map((a) => a.toJson()).toList(),
  };
}

class LastReadModel {
  final int surahNumber;
  final String surahArabicName;
  final String surahEnglishName;
  final int ayahNumberInSurah;
  final int timestamp;

  LastReadModel({
    required this.surahNumber,
    required this.surahArabicName,
    required this.surahEnglishName,
    required this.ayahNumberInSurah,
    required this.timestamp,
  });

  factory LastReadModel.fromJson(Map<String, dynamic> json) {
    return LastReadModel(
      surahNumber: json['surahNumber'] as int? ?? 1,
      surahArabicName: json['surahArabicName'] as String? ?? 'الفاتحة',
      surahEnglishName: json['surahEnglishName'] as String? ?? 'Al-Fatiha',
      ayahNumberInSurah: json['ayahNumberInSurah'] as int? ?? 1,
      timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
    'surahNumber': surahNumber,
    'surahArabicName': surahArabicName,
    'surahEnglishName': surahEnglishName,
    'ayahNumberInSurah': ayahNumberInSurah,
    'timestamp': timestamp,
  };
}

class JuzSurahRef {
  final int surahNumber;
  final String surahArabicName;
  final String surahEnglishName;
  final int startAyah;
  final int endAyah;

  const JuzSurahRef({
    required this.surahNumber,
    required this.surahArabicName,
    required this.surahEnglishName,
    required this.startAyah,
    required this.endAyah,
  });
}

class JuzMetadata {
  final int number;
  final String arabicName;
  final String startSurahName;
  final int startSurahNumber;
  final int startAyah;
  final List<JuzSurahRef> surahs;

  const JuzMetadata({
    required this.number,
    required this.arabicName,
    required this.startSurahName,
    required this.startSurahNumber,
    required this.startAyah,
    this.surahs = const [],
  });
}
