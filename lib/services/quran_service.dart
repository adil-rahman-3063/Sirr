import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sirr/models/quran_models.dart';

class QuranService {
  static final QuranService _instance = QuranService._internal();
  factory QuranService() => _instance;
  QuranService._internal();

  static const String _baseUrl = 'https://api.alquran.cloud/v1';
  static const String _surahsCacheKey = 'cached_quran_surahs_list_v1';
  static const String _lastReadCacheKey = 'quran_last_read_v1';

  List<SurahModel>? _cachedSurahs;
  final Map<int, SurahDetailModel> _cachedSurahDetails = {};

  /// 30 Canonical Juz (Para) Index Data with Full Contained Surahs
  final List<JuzMetadata> allJuzList = const [
    JuzMetadata(
      number: 1,
      arabicName: 'الم',
      startSurahName: 'Al-Faatiha',
      startSurahNumber: 1,
      startAyah: 1,
      surahs: [
        JuzSurahRef(surahNumber: 1, surahArabicName: 'الفاتحة', surahEnglishName: 'Al-Faatiha', startAyah: 1, endAyah: 7),
        JuzSurahRef(surahNumber: 2, surahArabicName: 'البقرة', surahEnglishName: 'Al-Baqara', startAyah: 1, endAyah: 141),
      ],
    ),
    JuzMetadata(
      number: 2,
      arabicName: 'سَيَقُولُ',
      startSurahName: 'Al-Baqara',
      startSurahNumber: 2,
      startAyah: 142,
      surahs: [
        JuzSurahRef(surahNumber: 2, surahArabicName: 'البقرة', surahEnglishName: 'Al-Baqara', startAyah: 142, endAyah: 252),
      ],
    ),
    JuzMetadata(
      number: 3,
      arabicName: 'تِلْكَ الرُّسُلُ',
      startSurahName: 'Al-Baqara',
      startSurahNumber: 2,
      startAyah: 253,
      surahs: [
        JuzSurahRef(surahNumber: 2, surahArabicName: 'البقرة', surahEnglishName: 'Al-Baqara', startAyah: 253, endAyah: 286),
        JuzSurahRef(surahNumber: 3, surahArabicName: 'آل عمران', surahEnglishName: 'Aal-i-Imraan', startAyah: 1, endAyah: 92),
      ],
    ),
    JuzMetadata(
      number: 4,
      arabicName: 'لَنْ تَنَالُوا',
      startSurahName: 'Aal-i-Imraan',
      startSurahNumber: 3,
      startAyah: 93,
      surahs: [
        JuzSurahRef(surahNumber: 3, surahArabicName: 'آل عمران', surahEnglishName: 'Aal-i-Imraan', startAyah: 93, endAyah: 200),
        JuzSurahRef(surahNumber: 4, surahArabicName: 'النساء', surahEnglishName: 'An-Nisaa', startAyah: 1, endAyah: 23),
      ],
    ),
    JuzMetadata(
      number: 5,
      arabicName: 'وَالْمُحْصَنَاتُ',
      startSurahName: 'An-Nisaa',
      startSurahNumber: 4,
      startAyah: 24,
      surahs: [
        JuzSurahRef(surahNumber: 4, surahArabicName: 'النساء', surahEnglishName: 'An-Nisaa', startAyah: 24, endAyah: 147),
      ],
    ),
    JuzMetadata(
      number: 6,
      arabicName: 'لَا يُحِبُّ اللَّهُ',
      startSurahName: 'An-Nisaa',
      startSurahNumber: 4,
      startAyah: 148,
      surahs: [
        JuzSurahRef(surahNumber: 4, surahArabicName: 'النساء', surahEnglishName: 'An-Nisaa', startAyah: 148, endAyah: 176),
        JuzSurahRef(surahNumber: 5, surahArabicName: 'المائدة', surahEnglishName: 'Al-Maaida', startAyah: 1, endAyah: 81),
      ],
    ),
    JuzMetadata(
      number: 7,
      arabicName: 'وَإِذَا سَمِعُوا',
      startSurahName: 'Al-Maaida',
      startSurahNumber: 5,
      startAyah: 82,
      surahs: [
        JuzSurahRef(surahNumber: 5, surahArabicName: 'المائدة', surahEnglishName: 'Al-Maaida', startAyah: 82, endAyah: 120),
        JuzSurahRef(surahNumber: 6, surahArabicName: 'الأنعام', surahEnglishName: 'Al-An\'aam', startAyah: 1, endAyah: 110),
      ],
    ),
    JuzMetadata(
      number: 8,
      arabicName: 'وَلَوْ أَنَّنَا',
      startSurahName: 'Al-An\'aam',
      startSurahNumber: 6,
      startAyah: 111,
      surahs: [
        JuzSurahRef(surahNumber: 6, surahArabicName: 'الأنعام', surahEnglishName: 'Al-An\'aam', startAyah: 111, endAyah: 165),
        JuzSurahRef(surahNumber: 7, surahArabicName: 'الأعراف', surahEnglishName: 'Al-A\'raaf', startAyah: 1, endAyah: 87),
      ],
    ),
    JuzMetadata(
      number: 9,
      arabicName: 'قَالَ الْمَلَأُ',
      startSurahName: 'Al-A\'raaf',
      startSurahNumber: 7,
      startAyah: 88,
      surahs: [
        JuzSurahRef(surahNumber: 7, surahArabicName: 'الأعراف', surahEnglishName: 'Al-A\'raaf', startAyah: 88, endAyah: 206),
        JuzSurahRef(surahNumber: 8, surahArabicName: 'الأنفال', surahEnglishName: 'Al-Anfaal', startAyah: 1, endAyah: 40),
      ],
    ),
    JuzMetadata(
      number: 10,
      arabicName: 'وَاعْلَمُوا',
      startSurahName: 'Al-Anfaal',
      startSurahNumber: 8,
      startAyah: 41,
      surahs: [
        JuzSurahRef(surahNumber: 8, surahArabicName: 'الأنفال', surahEnglishName: 'Al-Anfaal', startAyah: 41, endAyah: 75),
        JuzSurahRef(surahNumber: 9, surahArabicName: 'التوبة', surahEnglishName: 'At-Tawba', startAyah: 1, endAyah: 92),
      ],
    ),
    JuzMetadata(
      number: 11,
      arabicName: 'يَعْتَذِرُونَ',
      startSurahName: 'At-Tawba',
      startSurahNumber: 9,
      startAyah: 93,
      surahs: [
        JuzSurahRef(surahNumber: 9, surahArabicName: 'التوبة', surahEnglishName: 'At-Tawba', startAyah: 93, endAyah: 129),
        JuzSurahRef(surahNumber: 10, surahArabicName: 'يونس', surahEnglishName: 'Yunus', startAyah: 1, endAyah: 109),
        JuzSurahRef(surahNumber: 11, surahArabicName: 'هود', surahEnglishName: 'Hud', startAyah: 1, endAyah: 5),
      ],
    ),
    JuzMetadata(
      number: 12,
      arabicName: 'وَمَا مِنْ دَابَّةٍ',
      startSurahName: 'Hud',
      startSurahNumber: 11,
      startAyah: 6,
      surahs: [
        JuzSurahRef(surahNumber: 11, surahArabicName: 'هود', surahEnglishName: 'Hud', startAyah: 6, endAyah: 123),
        JuzSurahRef(surahNumber: 12, surahArabicName: 'يوسف', surahEnglishName: 'Yusuf', startAyah: 1, endAyah: 52),
      ],
    ),
    JuzMetadata(
      number: 13,
      arabicName: 'وَمَا أُبَرِّئُ',
      startSurahName: 'Yusuf',
      startSurahNumber: 12,
      startAyah: 53,
      surahs: [
        JuzSurahRef(surahNumber: 12, surahArabicName: 'يوسف', surahEnglishName: 'Yusuf', startAyah: 53, endAyah: 111),
        JuzSurahRef(surahNumber: 13, surahArabicName: 'الرعد', surahEnglishName: 'Ar-Ra\'d', startAyah: 1, endAyah: 43),
        JuzSurahRef(surahNumber: 14, surahArabicName: 'إبراهيم', surahEnglishName: 'Ibrahim', startAyah: 1, endAyah: 52),
      ],
    ),
    JuzMetadata(
      number: 14,
      arabicName: 'رُبَمَا',
      startSurahName: 'Al-Hijr',
      startSurahNumber: 15,
      startAyah: 1,
      surahs: [
        JuzSurahRef(surahNumber: 15, surahArabicName: 'الحجر', surahEnglishName: 'Al-Hijr', startAyah: 1, endAyah: 99),
        JuzSurahRef(surahNumber: 16, surahArabicName: 'النحل', surahEnglishName: 'An-Nahl', startAyah: 1, endAyah: 128),
      ],
    ),
    JuzMetadata(
      number: 15,
      arabicName: 'سُبْحَانَ الَّذِي',
      startSurahName: 'Al-Israa',
      startSurahNumber: 17,
      startAyah: 1,
      surahs: [
        JuzSurahRef(surahNumber: 17, surahArabicName: 'الإسراء', surahEnglishName: 'Al-Israa', startAyah: 1, endAyah: 111),
        JuzSurahRef(surahNumber: 18, surahArabicName: 'الكهف', surahEnglishName: 'Al-Kahf', startAyah: 1, endAyah: 74),
      ],
    ),
    JuzMetadata(
      number: 16,
      arabicName: 'قَالَ أَلَمْ',
      startSurahName: 'Al-Kahf',
      startSurahNumber: 18,
      startAyah: 75,
      surahs: [
        JuzSurahRef(surahNumber: 18, surahArabicName: 'الكهف', surahEnglishName: 'Al-Kahf', startAyah: 75, endAyah: 110),
        JuzSurahRef(surahNumber: 19, surahArabicName: 'مريم', surahEnglishName: 'Maryam', startAyah: 1, endAyah: 98),
        JuzSurahRef(surahNumber: 20, surahArabicName: 'طه', surahEnglishName: 'Taa-Haa', startAyah: 1, endAyah: 135),
      ],
    ),
    JuzMetadata(
      number: 17,
      arabicName: 'اقْتَرَبَ',
      startSurahName: 'Al-Anbiyaa',
      startSurahNumber: 21,
      startAyah: 1,
      surahs: [
        JuzSurahRef(surahNumber: 21, surahArabicName: 'الأنبياء', surahEnglishName: 'Al-Anbiyaa', startAyah: 1, endAyah: 112),
        JuzSurahRef(surahNumber: 22, surahArabicName: 'الحج', surahEnglishName: 'Al-Hajj', startAyah: 1, endAyah: 78),
      ],
    ),
    JuzMetadata(
      number: 18,
      arabicName: 'قَدْ أَفْلَحَ',
      startSurahName: 'Al-Muminoon',
      startSurahNumber: 23,
      startAyah: 1,
      surahs: [
        JuzSurahRef(surahNumber: 23, surahArabicName: 'المؤمنون', surahEnglishName: 'Al-Muminoon', startAyah: 1, endAyah: 118),
        JuzSurahRef(surahNumber: 24, surahArabicName: 'النور', surahEnglishName: 'An-Noor', startAyah: 1, endAyah: 64),
        JuzSurahRef(surahNumber: 25, surahArabicName: 'الفرقان', surahEnglishName: 'Al-Furqaan', startAyah: 1, endAyah: 20),
      ],
    ),
    JuzMetadata(
      number: 19,
      arabicName: 'وَقَالَ الَّذِينَ',
      startSurahName: 'Al-Furqaan',
      startSurahNumber: 25,
      startAyah: 21,
      surahs: [
        JuzSurahRef(surahNumber: 25, surahArabicName: 'الفرقان', surahEnglishName: 'Al-Furqaan', startAyah: 21, endAyah: 77),
        JuzSurahRef(surahNumber: 26, surahArabicName: 'الشعراء', surahEnglishName: 'Ash-Shu\'araa', startAyah: 1, endAyah: 227),
        JuzSurahRef(surahNumber: 27, surahArabicName: 'النمل', surahEnglishName: 'An-Naml', startAyah: 1, endAyah: 55),
      ],
    ),
    JuzMetadata(
      number: 20,
      arabicName: 'أَمَّنْ خَلَقَ',
      startSurahName: 'An-Naml',
      startSurahNumber: 27,
      startAyah: 56,
      surahs: [
        JuzSurahRef(surahNumber: 27, surahArabicName: 'النمل', surahEnglishName: 'An-Naml', startAyah: 56, endAyah: 93),
        JuzSurahRef(surahNumber: 28, surahArabicName: 'القصص', surahEnglishName: 'Al-Qasas', startAyah: 1, endAyah: 88),
        JuzSurahRef(surahNumber: 29, surahArabicName: 'العنكبوت', surahEnglishName: 'Al-Ankaboot', startAyah: 1, endAyah: 45),
      ],
    ),
    JuzMetadata(
      number: 21,
      arabicName: 'اتْلُ مَا أُوحِيَ',
      startSurahName: 'Al-Ankaboot',
      startSurahNumber: 29,
      startAyah: 46,
      surahs: [
        JuzSurahRef(surahNumber: 29, surahArabicName: 'العنكبوت', surahEnglishName: 'Al-Ankaboot', startAyah: 46, endAyah: 69),
        JuzSurahRef(surahNumber: 30, surahArabicName: 'الروم', surahEnglishName: 'Ar-Room', startAyah: 1, endAyah: 60),
        JuzSurahRef(surahNumber: 31, surahArabicName: 'لقمان', surahEnglishName: 'Luqman', startAyah: 1, endAyah: 34),
        JuzSurahRef(surahNumber: 32, surahArabicName: 'السجدة', surahEnglishName: 'As-Sajda', startAyah: 1, endAyah: 30),
        JuzSurahRef(surahNumber: 33, surahArabicName: 'الأحزاب', surahEnglishName: 'Al-Ahzaab', startAyah: 1, endAyah: 30),
      ],
    ),
    JuzMetadata(
      number: 22,
      arabicName: 'وَمَنْ يَقْنُتْ',
      startSurahName: 'Al-Ahzaab',
      startSurahNumber: 33,
      startAyah: 31,
      surahs: [
        JuzSurahRef(surahNumber: 33, surahArabicName: 'الأحزاب', surahEnglishName: 'Al-Ahzaab', startAyah: 31, endAyah: 73),
        JuzSurahRef(surahNumber: 34, surahArabicName: 'سبأ', surahEnglishName: 'Saba', startAyah: 1, endAyah: 54),
        JuzSurahRef(surahNumber: 35, surahArabicName: 'فاطر', surahEnglishName: 'Faatir', startAyah: 1, endAyah: 45),
        JuzSurahRef(surahNumber: 36, surahArabicName: 'يس', surahEnglishName: 'Yaseen', startAyah: 1, endAyah: 27),
      ],
    ),
    JuzMetadata(
      number: 23,
      arabicName: 'وَمَا لِيَ',
      startSurahName: 'Yaseen',
      startSurahNumber: 36,
      startAyah: 28,
      surahs: [
        JuzSurahRef(surahNumber: 36, surahArabicName: 'يس', surahEnglishName: 'Yaseen', startAyah: 28, endAyah: 83),
        JuzSurahRef(surahNumber: 37, surahArabicName: 'الصافات', surahEnglishName: 'As-Saaffaat', startAyah: 1, endAyah: 182),
        JuzSurahRef(surahNumber: 38, surahArabicName: 'ص', surahEnglishName: 'Saad', startAyah: 1, endAyah: 88),
        JuzSurahRef(surahNumber: 39, surahArabicName: 'الزمر', surahEnglishName: 'Az-Zumar', startAyah: 1, endAyah: 31),
      ],
    ),
    JuzMetadata(
      number: 24,
      arabicName: 'فَمَنْ أَظْلَمُ',
      startSurahName: 'Az-Zumar',
      startSurahNumber: 39,
      startAyah: 32,
      surahs: [
        JuzSurahRef(surahNumber: 39, surahArabicName: 'الزمر', surahEnglishName: 'Az-Zumar', startAyah: 32, endAyah: 75),
        JuzSurahRef(surahNumber: 40, surahArabicName: 'غافر', surahEnglishName: 'Ghafir', startAyah: 1, endAyah: 85),
        JuzSurahRef(surahNumber: 41, surahArabicName: 'فصلت', surahEnglishName: 'Fussilat', startAyah: 1, endAyah: 46),
      ],
    ),
    JuzMetadata(
      number: 25,
      arabicName: 'إِلَيْهِ يُرَدُّ',
      startSurahName: 'Fussilat',
      startSurahNumber: 41,
      startAyah: 47,
      surahs: [
        JuzSurahRef(surahNumber: 41, surahArabicName: 'فصلت', surahEnglishName: 'Fussilat', startAyah: 47, endAyah: 54),
        JuzSurahRef(surahNumber: 42, surahArabicName: 'الشورى', surahEnglishName: 'Ash-Shura', startAyah: 1, endAyah: 53),
        JuzSurahRef(surahNumber: 43, surahArabicName: 'الزخرف', surahEnglishName: 'Az-Zukhruf', startAyah: 1, endAyah: 89),
        JuzSurahRef(surahNumber: 44, surahArabicName: 'الدخان', surahEnglishName: 'Ad-Dukhan', startAyah: 1, endAyah: 59),
        JuzSurahRef(surahNumber: 45, surahArabicName: 'الجاثية', surahEnglishName: 'Al-Jathiya', startAyah: 1, endAyah: 37),
      ],
    ),
    JuzMetadata(
      number: 26,
      arabicName: 'حم',
      startSurahName: 'Al-Ahqaf',
      startSurahNumber: 46,
      startAyah: 1,
      surahs: [
        JuzSurahRef(surahNumber: 46, surahArabicName: 'الأحقاف', surahEnglishName: 'Al-Ahqaf', startAyah: 1, endAyah: 35),
        JuzSurahRef(surahNumber: 47, surahArabicName: 'محمد', surahEnglishName: 'Muhammad', startAyah: 1, endAyah: 38),
        JuzSurahRef(surahNumber: 48, surahArabicName: 'الفتح', surahEnglishName: 'Al-Fath', startAyah: 1, endAyah: 29),
        JuzSurahRef(surahNumber: 49, surahArabicName: 'الحجرات', surahEnglishName: 'Al-Hujuraat', startAyah: 1, endAyah: 18),
        JuzSurahRef(surahNumber: 50, surahArabicName: 'ق', surahEnglishName: 'Qaaf', startAyah: 1, endAyah: 45),
        JuzSurahRef(surahNumber: 51, surahArabicName: 'الذاريات', surahEnglishName: 'Adh-Dhaariyat', startAyah: 1, endAyah: 30),
      ],
    ),
    JuzMetadata(
      number: 27,
      arabicName: 'قَالَ فَمَا خَطْبُكُمْ',
      startSurahName: 'Adh-Dhaariyat',
      startSurahNumber: 51,
      startAyah: 31,
      surahs: [
        JuzSurahRef(surahNumber: 51, surahArabicName: 'الذاريات', surahEnglishName: 'Adh-Dhaariyat', startAyah: 31, endAyah: 60),
        JuzSurahRef(surahNumber: 52, surahArabicName: 'الطور', surahEnglishName: 'At-Toor', startAyah: 1, endAyah: 49),
        JuzSurahRef(surahNumber: 53, surahArabicName: 'النجم', surahEnglishName: 'An-Najm', startAyah: 1, endAyah: 62),
        JuzSurahRef(surahNumber: 54, surahArabicName: 'القمر', surahEnglishName: 'Al-Qamar', startAyah: 1, endAyah: 55),
        JuzSurahRef(surahNumber: 55, surahArabicName: 'الرحمن', surahEnglishName: 'Ar-Rahman', startAyah: 1, endAyah: 78),
        JuzSurahRef(surahNumber: 56, surahArabicName: 'الواقعة', surahEnglishName: 'Al-Waaqia', startAyah: 1, endAyah: 96),
        JuzSurahRef(surahNumber: 57, surahArabicName: 'الحديد', surahEnglishName: 'Al-Hadid', startAyah: 1, endAyah: 29),
      ],
    ),
    JuzMetadata(
      number: 28,
      arabicName: 'قَدْ سَمِعَ اللَّهُ',
      startSurahName: 'Al-Mujaadila',
      startSurahNumber: 58,
      startAyah: 1,
      surahs: [
        JuzSurahRef(surahNumber: 58, surahArabicName: 'المجادلة', surahEnglishName: 'Al-Mujaadila', startAyah: 1, endAyah: 22),
        JuzSurahRef(surahNumber: 59, surahArabicName: 'الحشر', surahEnglishName: 'Al-Hashr', startAyah: 1, endAyah: 24),
        JuzSurahRef(surahNumber: 60, surahArabicName: 'الممتحنة', surahEnglishName: 'Al-Mumtahana', startAyah: 1, endAyah: 13),
        JuzSurahRef(surahNumber: 61, surahArabicName: 'الصف', surahEnglishName: 'As-Saff', startAyah: 1, endAyah: 14),
        JuzSurahRef(surahNumber: 62, surahArabicName: 'الجمعة', surahEnglishName: 'Al-Jumu\'a', startAyah: 1, endAyah: 11),
        JuzSurahRef(surahNumber: 63, surahArabicName: 'المنافقون', surahEnglishName: 'Al-Munaafiqoon', startAyah: 1, endAyah: 11),
        JuzSurahRef(surahNumber: 64, surahArabicName: 'التغابن', surahEnglishName: 'At-Taghaabun', startAyah: 1, endAyah: 18),
        JuzSurahRef(surahNumber: 65, surahArabicName: 'الطلاق', surahEnglishName: 'At-Talaaq', startAyah: 1, endAyah: 12),
        JuzSurahRef(surahNumber: 66, surahArabicName: 'التحريم', surahEnglishName: 'At-Tahrim', startAyah: 1, endAyah: 12),
      ],
    ),
    JuzMetadata(
      number: 29,
      arabicName: 'تَبَارَكَ الَّذِي',
      startSurahName: 'Al-Mulk',
      startSurahNumber: 67,
      startAyah: 1,
      surahs: [
        JuzSurahRef(surahNumber: 67, surahArabicName: 'الملك', surahEnglishName: 'Al-Mulk', startAyah: 1, endAyah: 30),
        JuzSurahRef(surahNumber: 68, surahArabicName: 'القلم', surahEnglishName: 'Al-Qalam', startAyah: 1, endAyah: 52),
        JuzSurahRef(surahNumber: 69, surahArabicName: 'الحاقة', surahEnglishName: 'Al-Haaqqa', startAyah: 1, endAyah: 52),
        JuzSurahRef(surahNumber: 70, surahArabicName: 'المعارج', surahEnglishName: 'Al-Ma\'aarij', startAyah: 1, endAyah: 44),
        JuzSurahRef(surahNumber: 71, surahArabicName: 'نوح', surahEnglishName: 'Nooh', startAyah: 1, endAyah: 28),
        JuzSurahRef(surahNumber: 72, surahArabicName: 'الجن', surahEnglishName: 'Al-Jinn', startAyah: 1, endAyah: 28),
        JuzSurahRef(surahNumber: 73, surahArabicName: 'المزمل', surahEnglishName: 'Al-Muzzammil', startAyah: 1, endAyah: 20),
        JuzSurahRef(surahNumber: 74, surahArabicName: 'المدثر', surahEnglishName: 'Al-Muddaththir', startAyah: 1, endAyah: 56),
        JuzSurahRef(surahNumber: 75, surahArabicName: 'القيامة', surahEnglishName: 'Al-Qiyaama', startAyah: 1, endAyah: 40),
        JuzSurahRef(surahNumber: 76, surahArabicName: 'الإنسان', surahEnglishName: 'Al-Insaan', startAyah: 1, endAyah: 31),
        JuzSurahRef(surahNumber: 77, surahArabicName: 'المرسلات', surahEnglishName: 'Al-Mursalaat', startAyah: 1, endAyah: 50),
      ],
    ),
    JuzMetadata(
      number: 30,
      arabicName: 'عَمَّ يَتَسَاءَلُونَ',
      startSurahName: 'An-Naba',
      startSurahNumber: 78,
      startAyah: 1,
      surahs: [
        JuzSurahRef(surahNumber: 78, surahArabicName: 'النبأ', surahEnglishName: 'An-Naba', startAyah: 1, endAyah: 40),
        JuzSurahRef(surahNumber: 79, surahArabicName: 'النازعات', surahEnglishName: 'An-Naazi\'aat', startAyah: 1, endAyah: 46),
        JuzSurahRef(surahNumber: 80, surahArabicName: 'عبس', surahEnglishName: 'Abasa', startAyah: 1, endAyah: 42),
        JuzSurahRef(surahNumber: 81, surahArabicName: 'التكوير', surahEnglishName: 'At-Takwir', startAyah: 1, endAyah: 29),
        JuzSurahRef(surahNumber: 82, surahArabicName: 'الانفطار', surahEnglishName: 'Al-Infitaar', startAyah: 1, endAyah: 19),
        JuzSurahRef(surahNumber: 83, surahArabicName: 'المطففين', surahEnglishName: 'Al-Mutaffifin', startAyah: 1, endAyah: 36),
        JuzSurahRef(surahNumber: 84, surahArabicName: 'الانشقاق', surahEnglishName: 'Al-Inshiqaaq', startAyah: 1, endAyah: 25),
        JuzSurahRef(surahNumber: 85, surahArabicName: 'البروج', surahEnglishName: 'Al-Burooj', startAyah: 1, endAyah: 22),
        JuzSurahRef(surahNumber: 86, surahArabicName: 'الطارق', surahEnglishName: 'At-Taariq', startAyah: 1, endAyah: 17),
        JuzSurahRef(surahNumber: 87, surahArabicName: 'الأعلى', surahEnglishName: 'Al-A\'laa', startAyah: 1, endAyah: 19),
        JuzSurahRef(surahNumber: 88, surahArabicName: 'الغاشية', surahEnglishName: 'Al-Ghaashiya', startAyah: 1, endAyah: 26),
        JuzSurahRef(surahNumber: 89, surahArabicName: 'الفجر', surahEnglishName: 'Al-Fajr', startAyah: 1, endAyah: 30),
        JuzSurahRef(surahNumber: 90, surahArabicName: 'البلد', surahEnglishName: 'Al-Balad', startAyah: 1, endAyah: 20),
        JuzSurahRef(surahNumber: 91, surahArabicName: 'الشمس', surahEnglishName: 'Ash-Shams', startAyah: 1, endAyah: 15),
        JuzSurahRef(surahNumber: 92, surahArabicName: 'الليل', surahEnglishName: 'Al-Layl', startAyah: 1, endAyah: 21),
        JuzSurahRef(surahNumber: 93, surahArabicName: 'الضحى', surahEnglishName: 'Ad-Dhuhaa', startAyah: 1, endAyah: 11),
        JuzSurahRef(surahNumber: 94, surahArabicName: 'الشرح', surahEnglishName: 'Ash-Sharh', startAyah: 1, endAyah: 8),
        JuzSurahRef(surahNumber: 95, surahArabicName: 'التين', surahEnglishName: 'At-Teen', startAyah: 1, endAyah: 8),
        JuzSurahRef(surahNumber: 96, surahArabicName: 'العلق', surahEnglishName: 'Al-Alaq', startAyah: 1, endAyah: 19),
        JuzSurahRef(surahNumber: 97, surahArabicName: 'القدر', surahEnglishName: 'Al-Qadr', startAyah: 1, endAyah: 5),
        JuzSurahRef(surahNumber: 98, surahArabicName: 'البينة', surahEnglishName: 'Al-Bayyina', startAyah: 1, endAyah: 8),
        JuzSurahRef(surahNumber: 99, surahArabicName: 'الزلزلة', surahEnglishName: 'Az-Zalzala', startAyah: 1, endAyah: 8),
        JuzSurahRef(surahNumber: 100, surahArabicName: 'العاديات', surahEnglishName: 'Al-Aadiyaat', startAyah: 1, endAyah: 11),
        JuzSurahRef(surahNumber: 101, surahArabicName: 'القارعة', surahEnglishName: 'Al-Qaari\'a', startAyah: 1, endAyah: 11),
        JuzSurahRef(surahNumber: 102, surahArabicName: 'التكاثر', surahEnglishName: 'At-Takaathur', startAyah: 1, endAyah: 8),
        JuzSurahRef(surahNumber: 103, surahArabicName: 'العصر', surahEnglishName: 'Al-Asr', startAyah: 1, endAyah: 3),
        JuzSurahRef(surahNumber: 104, surahArabicName: 'الهمزة', surahEnglishName: 'Al-Humaza', startAyah: 1, endAyah: 9),
        JuzSurahRef(surahNumber: 105, surahArabicName: 'الفيل', surahEnglishName: 'Al-Feel', startAyah: 1, endAyah: 5),
        JuzSurahRef(surahNumber: 106, surahArabicName: 'قريش', surahEnglishName: 'Quraysh', startAyah: 1, endAyah: 4),
        JuzSurahRef(surahNumber: 107, surahArabicName: 'الماعون', surahEnglishName: 'Al-Maa\'oon', startAyah: 1, endAyah: 7),
        JuzSurahRef(surahNumber: 108, surahArabicName: 'الكوثر', surahEnglishName: 'Al-Kawthar', startAyah: 1, endAyah: 3),
        JuzSurahRef(surahNumber: 109, surahArabicName: 'الكافرون', surahEnglishName: 'Al-Kaafiroon', startAyah: 1, endAyah: 6),
        JuzSurahRef(surahNumber: 110, surahArabicName: 'النصر', surahEnglishName: 'An-Nasr', startAyah: 1, endAyah: 3),
        JuzSurahRef(surahNumber: 111, surahArabicName: 'المسد', surahEnglishName: 'Al-Masad', startAyah: 1, endAyah: 5),
        JuzSurahRef(surahNumber: 112, surahArabicName: 'الإخلاص', surahEnglishName: 'Al-Ikhlaas', startAyah: 1, endAyah: 4),
        JuzSurahRef(surahNumber: 113, surahArabicName: 'الفلق', surahEnglishName: 'Al-Falaq', startAyah: 1, endAyah: 5),
        JuzSurahRef(surahNumber: 114, surahArabicName: 'الناس', surahEnglishName: 'An-Naas', startAyah: 1, endAyah: 6),
      ],
    ),
  ];

  /// Fetch list of all 114 Surahs
  Future<List<SurahModel>> getSurahs({bool forceRefresh = false}) async {
    if (_cachedSurahs != null && !forceRefresh) {
      return _cachedSurahs!;
    }

    final prefs = await SharedPreferences.getInstance();
    
    // Check SharedPreferences cache first
    if (!forceRefresh) {
      final cachedJson = prefs.getString(_surahsCacheKey);
      if (cachedJson != null) {
        try {
          final List<dynamic> list = json.decode(cachedJson);
          _cachedSurahs = list.map((item) => SurahModel.fromJson(item as Map<String, dynamic>)).toList();
          return _cachedSurahs!;
        } catch (e) {
          debugPrint('[QuranService] Cache parse error: $e');
        }
      }
    }

    // Fetch from Al-Quran Cloud API
    try {
      final response = await http.get(Uri.parse('$_baseUrl/surah')).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] is List) {
          final List<dynamic> list = data['data'];
          final surahs = list.map((item) => SurahModel.fromJson(item as Map<String, dynamic>)).toList();
          _cachedSurahs = surahs;
          await prefs.setString(_surahsCacheKey, json.encode(list));
          return surahs;
        }
      }
    } catch (e) {
      debugPrint('[QuranService] Network fetch error: $e');
    }

    // Return empty or previous cache if network failed
    return _cachedSurahs ?? [];
  }

  /// Fetch full Surah with Arabic Uthmani text
  Future<SurahDetailModel?> getSurahDetail(int surahNumber, {bool forceRefresh = false}) async {
    if (_cachedSurahDetails.containsKey(surahNumber) && !forceRefresh) {
      return _cachedSurahDetails[surahNumber];
    }

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cached_surah_detail_${surahNumber}_v1';

    // Try local storage cache
    if (!forceRefresh) {
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        try {
          final Map<String, dynamic> map = json.decode(cachedJson);
          final detail = SurahDetailModel.fromJson(map);
          _cachedSurahDetails[surahNumber] = detail;
          return detail;
        } catch (e) {
          debugPrint('[QuranService] Surah $surahNumber cache parse error: $e');
        }
      }
    }

    // Fetch from Al-Quran Cloud API (Uthmani edition)
    try {
      final url = Uri.parse('$_baseUrl/surah/$surahNumber/quran-uthmani');
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['data'] != null) {
          final detail = SurahDetailModel.fromJson(data['data'] as Map<String, dynamic>);
          _cachedSurahDetails[surahNumber] = detail;
          await prefs.setString(cacheKey, json.encode(detail.toJson()));
          return detail;
        }
      }
    } catch (e) {
      debugPrint('[QuranService] Error fetching surah $surahNumber: $e');
    }

    return null;
  }

  /// Get Last Read Bookmark
  Future<LastReadModel?> getLastRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_lastReadCacheKey);
      if (jsonString != null) {
        return LastReadModel.fromJson(json.decode(jsonString));
      }
    } catch (e) {
      debugPrint('[QuranService] Error loading last read: $e');
    }
    return null;
  }

  /// Save Last Read Bookmark
  Future<void> saveLastRead(LastReadModel lastRead) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastReadCacheKey, json.encode(lastRead.toJson()));
    } catch (e) {
      debugPrint('[QuranService] Error saving last read: $e');
    }
  }

  /// Fast Search Filter (matches Arabic name, English transliteration, Translation, or Surah Number)
  List<SurahModel> filterSurahs(List<SurahModel> allSurahs, String query) {
    if (query.trim().isEmpty) return allSurahs;

    final q = query.trim().toLowerCase();
    final normalizedQ = _normalizeArabic(q);

    return allSurahs.where((surah) {
      // Number match
      if (surah.number.toString() == q) return true;

      // English Name match (e.g. "Al-Faatiha", "Baqarah")
      if (surah.englishName.toLowerCase().contains(q)) return true;
      if (surah.englishNameTranslation.toLowerCase().contains(q)) return true;

      // Arabic Name match (normalized)
      final normalizedSurahName = _normalizeArabic(surah.name);
      if (normalizedSurahName.contains(normalizedQ) || surah.name.contains(query.trim())) {
        return true;
      }

      return false;
    }).toList();
  }

  /// Helper to normalize Arabic diacritics / tashkeel for forgiving search
  String _normalizeArabic(String text) {
    var s = text;
    // Remove Arabic diacritics
    s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]'), '');
    // Normalize Alefs
    s = s.replaceAll(RegExp(r'[إأآا]'), 'ا');
    // Normalize Yaa
    s = s.replaceAll('ى', 'ي');
    // Normalize Taa Marbuta
    s = s.replaceAll('ة', 'ه');
    return s.toLowerCase();
  }
}
