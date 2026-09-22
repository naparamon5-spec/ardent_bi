import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colour tokens lifted verbatim from the web front end
/// (`web/app/assets/css/main.css` and `useChartTheme.js`) so the two clients
/// read as one product. Ardent's brand red is #e90408.
class AppColors {
  // Brand
  static const brand = Color(0xFFE90408);
  static const brandDark = Color(0xFFFF5969);
  // Filled brand surfaces wear white ink in light mode but dark ink in dark —
  // white on #ff5969 is only ~3.9:1. brand-soft is the tinted badge/chip fill.
  static const brandInkLight = Color(0xFFFFFFFF);
  static const brandInkDark = Color(0xFF0B0B0B);
  static final brandSoftLight = Color.alphaBlend(brand.withValues(alpha: 0.12), lSurface);
  static final brandSoftDark = Color.alphaBlend(brandDark.withValues(alpha: 0.16), dSurface);

  // Navy chrome — sidebar/top bar wear the brand's dark ink in both modes, so
  // their children need their own contrast pairing (white-on-navy), not the
  // page-level tokens. Active nav mixes brand into the navy, Power BI–style.
  static const chromeBg = Color(0xFF133341);
  static const chromeHover = Color(0xFF1D4456);
  static const chromeBorder = Color(0x1AFFFFFF);
  static const chromeText = Color(0xFFFFFFFF);
  static const chromeTextSecondary = Color(0xA8FFFFFF);
  static const chromeTextMuted = Color(0x6BFFFFFF);
  static const chromeDanger = Color(0xFFFF8285);
  static final chromeActiveLight = Color.alphaBlend(brand.withValues(alpha: 0.24), chromeBg);
  static final chromeActiveDark = Color.alphaBlend(brandDark.withValues(alpha: 0.20), chromeBg);

  // Light surfaces / text
  static const lSurface = Color(0xFFFFFFFF);
  static const lPlane = Color(0xFFF0EFE9);
  static const lElevated = Color(0xFFFFFFFF);
  static const lTextPrimary = Color(0xFF0B0B0B);
  static const lTextSecondary = Color(0xFF52514E);
  static const lTextMuted = Color(0xFF898781);
  static const lGrid = Color(0xFFE1E0D9);

  // Dark surfaces / text
  static const dSurface = Color(0xFF29292A);
  static const dPlane = Color(0xFF1C1C1D);
  static const dElevated = Color(0xFF333332);
  static const dTextPrimary = Color(0xFFFFFFFF);
  static const dTextSecondary = Color(0xFFC9C8C0);
  static const dTextMuted = Color(0xFFA3A19A);
  static const dGrid = Color(0xFF3C3C3B);

  // Status — same in both modes
  static const good = Color(0xFF0CA30C);
  static const warning = Color(0xFFFAB219);
  static const serious = Color(0xFFEC835A);
  static const critical = Color(0xFFD03B3B);
  static const deltaUpLight = Color(0xFF006300);
  static const deltaUpDark = Color(0xFF0CA30C);
  static const deltaDown = Color(0xFFD03B3B);

  // Categorical series palette (fixed slot order — never reorder or cycle).
  static const seriesLight = <Color>[
    Color(0xFF2A78D6),
    Color(0xFFEB6834),
    Color(0xFF1BAF7A),
    Color(0xFFEDA100),
    Color(0xFFE87BA4),
    Color(0xFF008300),
    Color(0xFF4A3AA7),
    Color(0xFFE34948),
  ];
  static const seriesDark = <Color>[
    Color(0xFF3987E5),
    Color(0xFFD95926),
    Color(0xFF199E70),
    Color(0xFFC98500),
    Color(0xFFD55181),
    Color(0xFF008300),
    Color(0xFF9085E9),
    Color(0xFFE66767),
  ];

  // Ageing buckets — fixed named palette, positional, in AGEING_BUCKETS order.
  static const ageingLight = <Color>[
    Color(0xFF5B9BD5),
    Color(0xFF00B050),
    Color(0xFFFFE699),
    Color(0xFFFFC000),
    Color(0xFFF4B183),
    Color(0xFFC55A11),
    Color(0xFFFF3399),
  ];
  static const ageingDark = <Color>[
    Color(0xFF6BA6DE),
    Color(0xFF22C55E),
    Color(0xFFFFE699),
    Color(0xFFFFC93C),
    Color(0xFFF7C29A),
    Color(0xFFE07B39),
    Color(0xFFFF66B2),
  ];
}

/// Small helper so widgets can read the right token for the active brightness
/// without threading Theme lookups everywhere.
class BiTokens {
  final bool isDark;
  const BiTokens(this.isDark);

  Color get surface => isDark ? AppColors.dSurface : AppColors.lSurface;
  Color get plane => isDark ? AppColors.dPlane : AppColors.lPlane;
  Color get elevated => isDark ? AppColors.dElevated : AppColors.lElevated;
  Color get textPrimary => isDark ? AppColors.dTextPrimary : AppColors.lTextPrimary;
  Color get textSecondary => isDark ? AppColors.dTextSecondary : AppColors.lTextSecondary;
  Color get textMuted => isDark ? AppColors.dTextMuted : AppColors.lTextMuted;
  Color get gridline => isDark ? AppColors.dGrid : AppColors.lGrid;
  Color get deltaUp => isDark ? AppColors.deltaUpDark : AppColors.deltaUpLight;
  Color get brand => isDark ? AppColors.brandDark : AppColors.brand;
  Color get brandInk => isDark ? AppColors.brandInkDark : AppColors.brandInkLight;
  Color get brandSoft => isDark ? AppColors.brandSoftDark : AppColors.brandSoftLight;
  Color get chrome => AppColors.chromeBg;
  Color get chromeActive => isDark ? AppColors.chromeActiveDark : AppColors.chromeActiveLight;
  Color get chromeBorder => AppColors.chromeBorder;
  Color get chromeText => AppColors.chromeText;
  Color get chromeTextSecondary => AppColors.chromeTextSecondary;
  Color get chromeTextMuted => AppColors.chromeTextMuted;
  List<Color> get series => isDark ? AppColors.seriesDark : AppColors.seriesLight;
  List<Color> get ageing => isDark ? AppColors.ageingDark : AppColors.ageingLight;

  static BiTokens of(BuildContext context) =>
      BiTokens(Theme.of(context).brightness == Brightness.dark);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: brightness,
  ).copyWith(
    primary: dark ? AppColors.brandDark : AppColors.brand,
    onPrimary: dark ? AppColors.brandInkDark : AppColors.brandInkLight,
    surface: dark ? AppColors.dSurface : AppColors.lSurface,
    // The seeded surface-container steps pick the red seed up as a pink tint
    // (sheets, menus, dialogs, switch tracks). The web keeps those surfaces
    // plain card white / dark elevated, so pin them neutral.
    surfaceContainerLowest: dark ? AppColors.dSurface : AppColors.lElevated,
    surfaceContainerLow: dark ? AppColors.dSurface : AppColors.lElevated,
    surfaceContainer: dark ? AppColors.dElevated : AppColors.lElevated,
    surfaceContainerHigh: dark ? AppColors.dElevated : AppColors.lElevated,
    surfaceContainerHighest: dark ? AppColors.dElevated : AppColors.lElevated,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  return base.copyWith(
    scaffoldBackgroundColor: dark ? AppColors.dPlane : AppColors.lPlane,
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? AppColors.dElevated : AppColors.lElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: dark ? AppColors.dGrid : AppColors.lGrid),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.chromeBg,
      foregroundColor: AppColors.chromeText,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.dSurface : AppColors.lSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: dark ? AppColors.dGrid : AppColors.lGrid),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: dark ? AppColors.dGrid : AppColors.lGrid),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? AppColors.dElevated : AppColors.lElevated,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: dark ? AppColors.dGrid : AppColors.lGrid,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? AppColors.dElevated : AppColors.lElevated,
      surfaceTintColor: Colors.transparent,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: dark ? AppColors.dElevated : AppColors.lElevated,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: dark ? AppColors.brandDark : AppColors.brand,
      headerForegroundColor: dark ? AppColors.brandInkDark : AppColors.brandInkLight,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected)
          ? (dark ? AppColors.brandDark : AppColors.brand)
          : (dark ? AppColors.dGrid : AppColors.lGrid)),
      thumbColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected)
          ? (dark ? AppColors.brandInkDark : AppColors.brandInkLight)
          : (dark ? AppColors.dTextMuted : AppColors.lSurface)),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected)
          ? (dark ? AppColors.brandDark : AppColors.brand)
          : Colors.transparent),
      checkColor: WidgetStatePropertyAll(dark ? AppColors.brandInkDark : AppColors.brandInkLight),
      side: BorderSide(color: dark ? AppColors.dGrid : AppColors.lGrid, width: 1.5),
    ),
  );
}
