import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

TextStyle kHeadingStyle({double size = 20, Color color = AppColors.textPrimary}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w700, color: color);

TextStyle kTitleStyle({double size = 16, Color color = AppColors.textPrimary}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w600, color: color);

TextStyle kBodyStyle({double size = 14, Color color = AppColors.textPrimary}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w400, color: color);

TextStyle kCaptionStyle({double size = 12, Color color = AppColors.textSecondary}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w400, color: color);

TextStyle kButtonStyle({double size = 14, Color color = AppColors.white}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: FontWeight.w600, color: color);

TextStyle kEventLogStyle({double size = 11, Color color = AppColors.textSecondary}) =>
    GoogleFonts.sourceCodePro(fontSize: size, fontWeight: FontWeight.w400, color: color);
