import 'package:flutter/material.dart';

/// Colour tokens from the spec ("Дизайн-система" → "Цвета").
/// Blue-teal means shade and safety, orange means sun and heat.
abstract final class AppColors {
  static const primary = Color(0xFF0E6E8C); // cień
  static const primaryContainer = Color(0xFFCDEFF7);
  static const onPrimary = Color(0xFFFFFFFF);
  static const green = Color(0xFF2E8B57); // zieleń
  static const sun = Color(
    0xFFF28C28,
  ); // słońce: fills and lines only, never text on white
  static const water = Color(0xFF2F80ED);
  static const cool = Color(0xFF5BC0EB); // miejsca chłodu
  static const heat1 = Color(0xFFF2C230);
  static const heat2 = Color(0xFFF28C28);
  static const heat3 = Color(0xFFD7263D);
  static const background = Color(0xFFF7FAFB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFEAF1F3);
  static const onSurface = Color(0xFF12232B);
  static const onSurfaceVariant = Color(0xFF4A5D66);
  static const muted = Color(0xFF9AA9B0);
  static const error = Color(0xFFB3261E);
  static const success = Color(0xFF1E8E3E);

  /// Shade layer on the map: primary at 35 % opacity.
  static const shadeLayer = Color(0x590E6E8C);

  /// Green layer on the map: green at 30 % opacity.
  static const greenLayer = Color(0x4D2E8B57);

  /// Sunny part of the ShadeBar track: sun at 35 % opacity.
  static const sunTrack = Color(0x59F28C28);

  static Color heat(int level) => switch (level) {
    1 => heat1,
    2 => heat2,
    _ => heat3,
  };
}

/// Spacing, radii and sizes from the spec ("Отступы и формы").
abstract final class AppSizes {
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const screenPadding = 16.0;
  static const radiusChip = 8.0;
  static const radiusCard = 12.0;
  static const radiusSheet = 20.0;
  static const radiusButton = 12.0;
  static const minTouchTarget = 48.0;
  static const buttonHeight = 52.0;
  static const buttonHeightSenior = 60.0;

  /// Senior mode: every text style × 1.25.
  static const seniorTextScale = 1.25;

  /// Route lines on S07.
  static const routeSelectedWidth = 6.0;
  static const routeOtherWidth = 4.0;
}

/// Extra tokens that do not fit Material's ColorScheme, plus the Senior flag.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({required this.senior});

  final bool senior;

  Color get green => AppColors.green;
  Color get sun => AppColors.sun;
  Color get water => AppColors.water;
  Color get cool => AppColors.cool;
  Color get muted => AppColors.muted;
  Color get success => AppColors.success;
  Color heat(int level) => AppColors.heat(level);
  double get buttonHeight =>
      senior ? AppSizes.buttonHeightSenior : AppSizes.buttonHeight;

  @override
  AppPalette copyWith({bool? senior}) =>
      AppPalette(senior: senior ?? this.senior);

  @override
  AppPalette lerp(AppPalette? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

extension AppThemeContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

/// Text styles from the spec (sizes in sp, line height / size).
/// Inter is bundled as static 400 / 500 / 600 / 700 files.
abstract final class AppTextStyles {
  static const fontFamily = 'Inter';

  static TextStyle _style(double size, double height, FontWeight weight) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        color: AppColors.onSurface,
      );

  /// Display 32/40 Bold — shade share on the route card.
  static final display = _style(32, 40, FontWeight.w700);

  /// Title L 24/32 SemiBold — screen titles.
  static final titleL = _style(24, 32, FontWeight.w600);

  /// Title M 20/28 SemiBold — sheet and card titles.
  static final titleM = _style(20, 28, FontWeight.w600);

  /// Body 16/24 Regular.
  static final body = _style(16, 24, FontWeight.w400);

  /// Body S 14/20 Regular — secondary text.
  static final bodyS = _style(14, 20, FontWeight.w400);

  /// Label 12/16 Medium — chips, captions.
  static final label = _style(12, 16, FontWeight.w500);

  /// Button text: Body size, SemiBold.
  static final button = _style(16, 24, FontWeight.w600);
}

abstract final class AppTheme {
  /// Light theme only (dark theme is out of scope).
  /// Senior mode changes button height here; text is scaled ×1.25 by the
  /// app's MediaQuery (on top of the system font size).
  static ThemeData light({bool senior = false}) {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onSurface,
      secondary: AppColors.green,
      onSecondary: AppColors.onPrimary,
      tertiary: AppColors.sun,
      onTertiary: AppColors.onSurface,
      error: AppColors.error,
      onError: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      surfaceContainerHighest: AppColors.surfaceVariant,
      surfaceContainerHigh: AppColors.surface, // dialogs stay white
      surfaceContainer: AppColors.surface,
      surfaceContainerLow: AppColors.surface,
      outline: AppColors.muted,
      outlineVariant: AppColors.surfaceVariant,
    );

    final buttonHeight = senior
        ? AppSizes.buttonHeightSenior
        : AppSizes.buttonHeight;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSizes.radiusButton),
    );
    final buttonSize = Size(AppSizes.minTouchTarget, buttonHeight);

    final textTheme = TextTheme(
      displaySmall: AppTextStyles.display,
      headlineSmall: AppTextStyles.titleL,
      titleLarge: AppTextStyles.titleL,
      titleMedium: AppTextStyles.titleM,
      titleSmall: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.bodyS,
      bodySmall: AppTextStyles.bodyS.copyWith(
        color: AppColors.onSurfaceVariant,
      ),
      labelLarge: AppTextStyles.button,
      labelMedium: AppTextStyles.label,
      labelSmall: AppTextStyles.label,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: AppTextStyles.fontFamily,
      textTheme: textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [AppPalette(senior: senior)],
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.titleL,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          textStyle: AppTextStyles.button,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          textStyle: AppTextStyles.button,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: Size(AppSizes.minTouchTarget, buttonHeight),
          textStyle: AppTextStyles.label,
          selectedBackgroundColor: AppColors.primaryContainer,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: buttonSize,
          shape: buttonShape,
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.button,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primary,
        labelStyle: AppTextStyles.label,
        secondaryLabelStyle: AppTextStyles.label.copyWith(
          color: AppColors.onPrimary,
        ),
        checkmarkColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusChip),
        ),
        side: BorderSide.none,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusSheet),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(AppTextStyles.label),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          borderSide: const BorderSide(color: AppColors.muted),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          borderSide: const BorderSide(color: AppColors.surfaceVariant),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceVariant,
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.onSurface,
        contentTextStyle: AppTextStyles.bodyS.copyWith(
          color: AppColors.onPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        ),
      ),
    );
  }
}
