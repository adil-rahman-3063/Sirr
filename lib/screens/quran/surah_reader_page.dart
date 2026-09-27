import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sirr/models/quran_models.dart';
import 'package:sirr/services/quran_service.dart';
import 'package:sirr/widgets/glass_snack_bar.dart';

class SurahReaderPage extends StatefulWidget {
  final int surahNumber;
  final String? initialSurahName;
  final String? initialEnglishName;
  final int? targetAyahNumber;

  const SurahReaderPage({
    super.key,
    required this.surahNumber,
    this.initialSurahName,
    this.initialEnglishName,
    this.targetAyahNumber,
  });

  @override
  State<SurahReaderPage> createState() => _SurahReaderPageState();
}

class _SurahReaderPageState extends State<SurahReaderPage> {
  late int _currentSurahNumber;
  late PageController _pageController;
  List<SurahModel> _allSurahs = [];
  double _arabicFontSize = 26.0;
  int? _bookmarkedAyahNumber;
  final ScrollController _pillsScrollController = ScrollController();
  final Map<int, GlobalKey<_SurahPageViewItemState>> _pageKeys = {};

  static const String _bismillahText = "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ";

  @override
  void initState() {
    super.initState();
    _currentSurahNumber = widget.surahNumber.clamp(1, 114);
    _pageController = PageController(initialPage: _currentSurahNumber - 1);
    _loadAllSurahsList();
    _checkBookmarkForSurah(_currentSurahNumber);
    _prefetchAdjacentSurahs(_currentSurahNumber);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pillsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSurahsList() async {
    try {
      final surahs = await QuranService().getSurahs();
      if (mounted) {
        setState(() {
          _allSurahs = surahs;
        });
        _autoScrollSurahPill();
      }
    } catch (e) {
      debugPrint('[SurahReader] Failed loading surahs list: $e');
    }
  }

  void _prefetchAdjacentSurahs(int centerSurah) {
    try {
      if (centerSurah > 1) {
        QuranService().getSurahDetail(centerSurah - 1);
      }
      if (centerSurah < 114) {
        QuranService().getSurahDetail(centerSurah + 1);
      }
    } catch (_) {}
  }

  Future<void> _checkBookmarkForSurah(int surahNum) async {
    try {
      final lastRead = await QuranService().getLastRead();
      if (mounted) {
        setState(() {
          if (lastRead != null && lastRead.surahNumber == surahNum) {
            _bookmarkedAyahNumber = lastRead.ayahNumberInSurah;
          } else {
            _bookmarkedAyahNumber = null;
          }
        });
      }
    } catch (_) {}
  }

  void _autoScrollSurahPill() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pillsScrollController.hasClients) {
        final targetOffset = (_currentSurahNumber - 1) * 110.0;
        _pillsScrollController.animateTo(
          targetOffset.clamp(0.0, _pillsScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _onPageChanged(int index) {
    final newSurahNumber = (index + 1).clamp(1, 114);
    setState(() {
      _currentSurahNumber = newSurahNumber;
    });
    _checkBookmarkForSurah(newSurahNumber);
    _autoScrollSurahPill();
    _prefetchAdjacentSurahs(newSurahNumber);

    // Auto-save last read when turning to a new Surah
    if (_allSurahs.isNotEmpty && newSurahNumber <= _allSurahs.length) {
      final surah = _allSurahs[newSurahNumber - 1];
      QuranService().saveLastRead(
        LastReadModel(
          surahNumber: surah.number,
          surahArabicName: surah.name,
          surahEnglishName: surah.englishName,
          ayahNumberInSurah: 1,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  void _switchSurah(int newSurahNumber) {
    if (newSurahNumber >= 1 && newSurahNumber <= 114 && newSurahNumber != _currentSurahNumber) {
      final diff = (newSurahNumber - _currentSurahNumber).abs();
      if (diff > 1) {
        _pageController.jumpToPage(newSurahNumber - 1);
      } else {
        _pageController.animateToPage(
          newSurahNumber - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _scrollToCurrentBookmark() {
    if (_bookmarkedAyahNumber != null) {
      _pageKeys[_currentSurahNumber]?.currentState?.scrollToAyah(_bookmarkedAyahNumber!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(theme),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: 114,
                pageSnapping: true,
                physics: const PageScrollPhysics(),
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final surahNum = index + 1;
                  _pageKeys[surahNum] ??= GlobalKey<_SurahPageViewItemState>();

                  return _buildPageFadeWrapper(
                    index: index,
                    child: _SurahPageViewItem(
                      key: _pageKeys[surahNum],
                      surahNumber: surahNum,
                      arabicFontSize: _arabicFontSize,
                      targetAyahNumber: surahNum == widget.surahNumber ? widget.targetAyahNumber : null,
                      bookmarkedAyahNumber: _currentSurahNumber == surahNum ? _bookmarkedAyahNumber : null,
                      onBookmarkChanged: (ayahNum) {
                        setState(() {
                          _bookmarkedAyahNumber = ayahNum;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// High-Performance Smooth Fade Transition (Rock-Solid in Place, No Crash, No Floating Drift)
  Widget _buildPageFadeWrapper({
    required int index,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: _pageController,
      child: child,
      builder: (context, staticChild) {
        double page = (_currentSurahNumber - 1).toDouble();
        try {
          if (_pageController.hasClients &&
              _pageController.positions.isNotEmpty &&
              _pageController.position.haveDimensions) {
            final p = _pageController.page;
            if (p != null && !p.isNaN && !p.isInfinite) {
              page = p;
            }
          }
        } catch (_) {}

        final double diff = index - page;

        // Skip rendering for offscreen pages
        if (diff < -1.0 || diff > 1.0) {
          return const SizedBox.shrink();
        }

        // Direct, crisp fade without floating parallax translation
        final double opacity = (1.0 - diff.abs()).clamp(0.0, 1.0);

        return RepaintBoundary(
          child: Opacity(
            opacity: opacity,
            child: staticChild,
          ),
        );
      },
    );
  }

  Widget _buildTopHeader(ThemeData theme) {
    // Lookup active Surah info
    SurahModel? currentSurah;
    if (_allSurahs.isNotEmpty && _currentSurahNumber <= _allSurahs.length) {
      currentSurah = _allSurahs[_currentSurahNumber - 1];
    }

    final arabicName = currentSurah?.name ?? widget.initialSurahName ?? "سورة";
    final englishName = currentSurah?.englishName ?? widget.initialEnglishName ?? "Surah";
    final isMeccan = (currentSurah?.revelationType.toLowerCase() ?? 'meccan') == 'meccan';
    final revelationText = isMeccan ? 'Mekah' : 'Madinah';
    final countText = "${currentSurah?.numberOfAyahs ?? 7} Ayat";
    final meaningText = currentSurah?.englishNameTranslation ?? "";
    final primaryColor = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.25),
            offset: const Offset(0, 6),
            blurRadius: 12,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // Top Navigation Icons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _bookmarkedAyahNumber != null ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                    tooltip: 'العلامة المرجعية',
                    onPressed: _scrollToCurrentBookmark,
                  ),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: theme.colorScheme.onSurface, size: 22),
                    tooltip: 'حجم الخط',
                    onPressed: _showFontSizeDialog,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Surah Title: English + Arabic with smooth fade transitions
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: Column(
              key: ValueKey<int>(_currentSurahNumber),
              children: [
                Text(
                  englishName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  arabicName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.amiri(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meaningText.isNotEmpty
                      ? "$revelationText - $meaningText - $countText"
                      : "$revelationText - $countText",
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Horizontal Surah Quick-Switch Pills Bar
          _buildHorizontalSurahPills(theme),
        ],
      ),
    );
  }

  Widget _buildHorizontalSurahPills(ThemeData theme) {
    if (_allSurahs.isEmpty) return const SizedBox.shrink();
    final primaryColor = theme.colorScheme.primary;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        controller: _pillsScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _allSurahs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final surah = _allSurahs[index];
          final isSelected = surah.number == _currentSurahNumber;

          return GestureDetector(
            onTap: () => _switchSurah(surah.number),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                "${surah.number}. ${surah.englishName}",
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFontSizeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final primaryColor = theme.colorScheme.primary;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حجم الخط العربي',
                    style: GoogleFonts.amiri(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(
                      _bismillahText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.amiri(
                        fontSize: _arabicFontSize,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('أ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                      Expanded(
                        child: Slider(
                          value: _arabicFontSize,
                          min: 18.0,
                          max: 42.0,
                          divisions: 12,
                          activeColor: primaryColor,
                          label: "${_arabicFontSize.toInt()}",
                          onChanged: (val) {
                            setModalState(() {
                              _arabicFontSize = val;
                            });
                            setState(() {
                              _arabicFontSize = val;
                            });
                          },
                        ),
                      ),
                      Text('أ', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Dedicated View Item for each Surah Page with independent scroll, error handling and caching
class _SurahPageViewItem extends StatefulWidget {
  final int surahNumber;
  final double arabicFontSize;
  final int? targetAyahNumber;
  final int? bookmarkedAyahNumber;
  final ValueChanged<int?> onBookmarkChanged;

  const _SurahPageViewItem({
    super.key,
    required this.surahNumber,
    required this.arabicFontSize,
    this.targetAyahNumber,
    this.bookmarkedAyahNumber,
    required this.onBookmarkChanged,
  });

  @override
  State<_SurahPageViewItem> createState() => _SurahPageViewItemState();
}

class _SurahPageViewItemState extends State<_SurahPageViewItem> {
  SurahDetailModel? _surahDetail;
  bool _isLoading = true;
  String? _errorMessage;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  static const String _bismillahText = "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ";

  @override
  void initState() {
    super.initState();
    _loadSurahData();
  }

  Future<void> _loadSurahData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await QuranService().getSurahDetail(widget.surahNumber);

      if (mounted) {
        setState(() {
          _surahDetail = detail;
          _isLoading = false;
          if (detail == null) {
            _errorMessage = 'تعذر تحميل السورة. يرجى التحقق من الاتصال بالإنترنت.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'حدث خطأ في التحميل: $e';
        });
      }
    }
  }

  void scrollToAyah(int ayahNum) {
    if (_surahDetail == null) return;
    final showBismillahHeader = widget.surahNumber != 1 && widget.surahNumber != 9;
    final targetIndex = showBismillahHeader ? ayahNum : ayahNum - 1;
    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: targetIndex.clamp(0, (_surahDetail!.ayahs.length + (showBismillahHeader ? 1 : 0)) - 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.0,
      );
    }
  }

  void _toggleBookmark(AyahModel ayah) {
    if (_surahDetail == null) return;
    final isCurrent = widget.bookmarkedAyahNumber == ayah.numberInSurah;

    if (isCurrent) {
      widget.onBookmarkChanged(null);
    } else {
      widget.onBookmarkChanged(ayah.numberInSurah);
      QuranService().saveLastRead(
        LastReadModel(
          surahNumber: _surahDetail!.number,
          surahArabicName: _surahDetail!.name,
          surahEnglishName: _surahDetail!.englishName,
          ayahNumberInSurah: ayah.numberInSurah,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      AppSnackBar.showSuccess(
        context,
        'تم حفظ الآية ${ayah.numberInSurah} كعلامة مرجعية.',
        title: 'تم الحفظ',
        icon: Icons.bookmark_added_rounded,
      );
    }
  }

  void _copyAyah(AyahModel ayah) {
    Clipboard.setData(ClipboardData(text: "${ayah.text} ﴿${ayah.numberInSurah}﴾"));
    AppSnackBar.showInfo(
      context,
      'تم نسخ الآية الكريمة إلى الحافظة.',
      title: 'نسخ',
      icon: Icons.copy_rounded,
    );
  }

  String _toArabicDigits(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number.toString().split('').map((ch) => arabicDigits[int.parse(ch)]).join();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return _buildSkeletonLoading(theme);
    }

    if (_errorMessage != null) {
      return _buildErrorView(theme);
    }

    return _buildVersesList(theme);
  }

  Widget _buildVersesList(ThemeData theme) {
    final ayahs = _surahDetail?.ayahs ?? [];
    final showBismillahHeader = widget.surahNumber != 1 && widget.surahNumber != 9;
    final totalCount = ayahs.length + (showBismillahHeader ? 1 : 0);
    final primaryColor = theme.colorScheme.primary;

    int initialIndex = 0;
    if (widget.targetAyahNumber != null && widget.targetAyahNumber! > 1) {
      initialIndex = showBismillahHeader ? widget.targetAyahNumber! : widget.targetAyahNumber! - 1;
      if (initialIndex >= totalCount) {
        initialIndex = totalCount - 1;
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ScrollablePositionedList.separated(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          initialScrollIndex: initialIndex,
          initialAlignment: 0.0,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: totalCount,
          separatorBuilder: (_, __) => Divider(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            height: 24,
            thickness: 1,
          ),
          itemBuilder: (context, index) {
            if (showBismillahHeader && index == 0) {
              return _buildBismillahHeader(theme);
            }

            final ayahIndex = showBismillahHeader ? index - 1 : index;
            final ayah = ayahs[ayahIndex];

            // Clean redundant bismillah in ayah 1 if bismillah header is already showing
            String arabicText = ayah.text;
            if (showBismillahHeader && ayahIndex == 0 && arabicText.startsWith(_bismillahText)) {
              arabicText = arabicText.replaceFirst(_bismillahText, '').trim();
            }

            final isBookmarked = widget.bookmarkedAyahNumber == ayah.numberInSurah;
            final isTargetAyah = widget.targetAyahNumber == ayah.numberInSurah && widget.targetAyahNumber! > 1;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: isTargetAyah
                  ? BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Action / Verse Number Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _toggleBookmark(ayah),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isBookmarked
                                ? primaryColor.withValues(alpha: 0.18)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: isBookmarked ? primaryColor : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            size: 22,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          if (isTargetAyah) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'بداية الجزء',
                                style: GoogleFonts.amiri(
                                  fontSize: 11,
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (ayah.sajda) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'سجدة',
                                style: GoogleFonts.amiri(
                                  fontSize: 12,
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          IconButton(
                            icon: Icon(
                              Icons.copy_rounded,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            tooltip: 'نسخ الآية',
                            onPressed: () => _copyAyah(ayah),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Pure Arabic Verse Text with Ornate Ending Glyphs
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: arabicText,
                            style: GoogleFonts.amiri(
                              fontSize: widget.arabicFontSize,
                              color: theme.colorScheme.onSurface,
                              height: 2.3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: " ﴿${_toArabicDigits(ayah.numberInSurah)}﴾",
                            style: GoogleFonts.amiri(
                              fontSize: widget.arabicFontSize * 0.95,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBismillahHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Center(
        child: Text(
          _bismillahText,
          textAlign: TextAlign.center,
          style: GoogleFonts.amiri(
            fontSize: widget.arabicFontSize * 1.1,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
            height: 1.8,
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading(ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;
    final isTargetAyah = widget.targetAyahNumber != null && widget.targetAyahNumber! > 1;

    return Column(
      children: [
        if (isTargetAyah)
          Padding(
            padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "جاري الانتقال إلى الآية ${widget.targetAyahNumber}...",
                    style: GoogleFonts.amiri(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: Shimmer.fromColors(
            baseColor: theme.colorScheme.primaryContainer,
            highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.separated(
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 18),
                itemBuilder: (_, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 16, width: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 10),
                    Container(height: 48, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
              onPressed: _loadSurahData,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('إعادة المحاولة', style: GoogleFonts.amiri(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
