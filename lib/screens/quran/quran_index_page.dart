import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sirr/models/quran_models.dart';
import 'package:sirr/screens/quran/surah_reader_page.dart';
import 'package:sirr/services/quran_service.dart';

class QuranIndexPage extends StatefulWidget {
  const QuranIndexPage({super.key});

  @override
  State<QuranIndexPage> createState() => _QuranIndexPageState();
}

class _QuranIndexPageState extends State<QuranIndexPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<SurahModel> _allSurahs = [];
  List<SurahModel> _filteredSurahs = [];
  LastReadModel? _lastRead;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSearchOpen = false;
  final Set<int> _expandedJuzNumbers = {1};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final surahsFuture = QuranService().getSurahs(forceRefresh: forceRefresh);
    final lastReadFuture = QuranService().getLastRead();

    final results = await Future.wait([surahsFuture, lastReadFuture]);
    final surahs = results[0] as List<SurahModel>;
    final lastRead = results[1] as LastReadModel?;

    if (mounted) {
      setState(() {
        _allSurahs = surahs;
        _filteredSurahs = QuranService().filterSurahs(surahs, _searchController.text);
        _lastRead = lastRead;
        _isLoading = false;
        if (surahs.isEmpty) {
          _errorMessage = 'تعذر تحميل فهرس القرآن. يرجى التحقق من الاتصال بالإنترنت.';
        }
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _filteredSurahs = QuranService().filterSurahs(_allSurahs, _searchController.text);
    });
  }

  void _openSurah(int surahNumber, {String? surahName, String? englishName, int? targetAyah}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SurahReaderPage(
          surahNumber: surahNumber,
          initialSurahName: surahName,
          initialEnglishName: englishName,
          targetAyahNumber: targetAyah,
        ),
      ),
    );

    final updatedLastRead = await QuranService().getLastRead();
    if (mounted) {
      setState(() {
        _lastRead = updatedLastRead;
      });
    }
  }

  void _openLastRead() {
    if (_lastRead != null) {
      _openSurah(
        _lastRead!.surahNumber,
        surahName: _lastRead!.surahArabicName,
        englishName: _lastRead!.surahEnglishName,
        targetAyah: _lastRead!.ayahNumberInSurah,
      );
    } else {
      _openSurah(1, surahName: 'الفاتحة', englishName: 'Al-Faatiha');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryColor,
          onRefresh: () => _loadData(forceRefresh: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(theme),
              if (_isSearchOpen) _buildSearchBar(theme),
              _buildTabSelector(theme),
              Expanded(
                child: _isLoading
                    ? _buildSkeletonList(theme)
                    : _errorMessage != null
                        ? _buildErrorView(theme)
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildSurahsList(theme),
                              _buildJuzList(theme),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: theme.colorScheme.onSurface),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _lastRead != null ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                    tooltip: 'آخر قراءة',
                    onPressed: _openLastRead,
                  ),
                  IconButton(
                    icon: Icon(
                      _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                      color: theme.colorScheme.onSurface,
                      size: 24,
                    ),
                    tooltip: 'بحث',
                    onPressed: () {
                      setState(() {
                        _isSearchOpen = !_isSearchOpen;
                        if (!_isSearchOpen) {
                          _searchController.clear();
                        }
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'الْقُرْآنُ الْكَرِيمُ',
              textAlign: TextAlign.center,
              style: GoogleFonts.amiri(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.1),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'ابحث برقم أو اسم السورة (مثال: الكهف، يس، 36)...',
            hintStyle: GoogleFonts.amiri(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary, size: 22),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector(ThemeData theme) {
    final isSurahSelected = _tabController.index == 0;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                _tabController.animateTo(0);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSurahSelected ? theme.colorScheme.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSurahSelected
                      ? [
                          BoxShadow(
                            color: theme.shadowColor.withValues(alpha: 0.15),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'السُّوَر (Surah)',
                  style: GoogleFonts.amiri(
                    fontSize: 16,
                    fontWeight: isSurahSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSurahSelected ? primaryColor : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _tabController.animateTo(1);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: !isSurahSelected ? theme.colorScheme.primaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: !isSurahSelected
                      ? [
                          BoxShadow(
                            color: theme.shadowColor.withValues(alpha: 0.15),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  'الأَجْزَاء (Juz)',
                  style: GoogleFonts.amiri(
                    fontSize: 16,
                    fontWeight: !isSurahSelected ? FontWeight.bold : FontWeight.w500,
                    color: !isSurahSelected ? primaryColor : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahsList(ThemeData theme) {
    if (_filteredSurahs.isEmpty) {
      return Center(
        child: Text(
          'لا توجد نتائج بحث مطابقة',
          style: GoogleFonts.amiri(
            fontSize: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: _filteredSurahs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final surah = _filteredSurahs[index];
        return _buildSurahRow(surah, theme);
      },
    );
  }

  Widget _buildSurahRow(SurahModel surah, ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;
    final isMeccan = surah.revelationType.toLowerCase() == 'meccan';
    final revelationText = isMeccan ? 'Mekah' : 'Madinah';
    final countText = "${surah.numberOfAyahs} Ayat";
    final meaningText = surah.englishNameTranslation;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.15),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openSurah(
            surah.number,
            surahName: surah.name,
            englishName: surah.englishName,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "${surah.number}",
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah.englishName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$revelationText - $meaningText - $countText",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  surah.name,
                  style: GoogleFonts.amiri(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleJuzExpansion(int juzNumber) {
    setState(() {
      if (_expandedJuzNumbers.contains(juzNumber)) {
        _expandedJuzNumbers.remove(juzNumber);
      } else {
        _expandedJuzNumbers.add(juzNumber);
      }
    });
  }

  Widget _buildJuzList(ThemeData theme) {
    final query = _searchController.text.trim().toLowerCase();
    List<JuzMetadata> juzList = QuranService().allJuzList;
    if (query.isNotEmpty) {
      juzList = juzList.where((juz) {
        if (juz.number.toString() == query) return true;
        if (juz.arabicName.contains(query)) return true;
        if (juz.startSurahName.toLowerCase().contains(query)) return true;
        return juz.surahs.any((s) =>
            s.surahEnglishName.toLowerCase().contains(query) ||
            s.surahArabicName.contains(query) ||
            s.surahNumber.toString() == query);
      }).toList();
    }

    if (juzList.isEmpty) {
      return Center(
        child: Text(
          'لا توجد أجزاء مطابقة للبحث',
          style: GoogleFonts.amiri(
            fontSize: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: juzList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final juz = juzList[index];
        final isExpanded = query.isNotEmpty || _expandedJuzNumbers.contains(juz.number);
        return _buildJuzRow(juz, theme, isExpanded);
      },
    );
  }

  Widget _buildJuzRow(JuzMetadata juz, ThemeData theme, bool isExpanded) {
    final primaryColor = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.15),
            offset: const Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          // Juz Main Header Card (Tapping expands/collapses)
          InkWell(
            onTap: () => _toggleJuzExpansion(juz.number),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Juz Number Badge
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "${juz.number}",
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Juz Title and Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "الجزء ${juz.number} • ${juz.arabicName}",
                          style: GoogleFonts.amiri(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "يبدأ من: ${juz.startSurahName} (الآية ${juz.startAyah})",
                          style: GoogleFonts.amiri(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Surah Count Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${juz.surahs.length} ${juz.surahs.length == 1 ? 'سورة' : 'سور'}",
                      style: GoogleFonts.amiri(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Expand / Collapse Chevron Arrow
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Contained Surahs List
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: juz.surahs.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 12,
                    thickness: 0.6,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                  ),
                  itemBuilder: (context, sIndex) {
                    final surahRef = juz.surahs[sIndex];
                    return InkWell(
                      onTap: () => _openSurah(
                        surahRef.surahNumber,
                        surahName: surahRef.surahArabicName,
                        englishName: surahRef.surahEnglishName,
                        targetAyah: surahRef.startAyah,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            // Contained Surah Number Badge
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "${surahRef.surahNumber}",
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Surah English Name & Verse Range
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    surahRef.surahEnglishName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    "الآيات ${surahRef.startAyah} - ${surahRef.endAyah}",
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Arabic Calligraphy Name
                            Text(
                              "سورة ${surahRef.surahArabicName}",
                              style: GoogleFonts.amiri(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.primaryContainer,
      highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: 8,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => Container(
          height: 66,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 50, color: Colors.orangeAccent),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'حدث خطأ في التحميل',
              textAlign: TextAlign.center,
              style: GoogleFonts.amiri(fontSize: 16, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _loadData(forceRefresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: Text('إعادة المحاولة', style: GoogleFonts.amiri(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
