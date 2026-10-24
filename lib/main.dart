// ===========================================================================
//  NUTRITRACK  -  ONE APP: LOG IN + PARENT / TEACHER / SCHOOL NURSE / ADMIN
//
//  Log in page -> opens the dashboard of the selected role.
//  Every side menu has a Log Out button (it is in the top bar on phones).
//
//  pubspec.yaml needs:  fl_chart, google_fonts, image_picker
//    flutter pub add fl_chart google_fonts image_picker
//  Run: put this file in lib/main.dart, then  flutter run -d chrome
// ===========================================================================
import 'dart:async';

import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';


// ---------------------------------------------------------------------------
// THEME: white paper + handwritten fonts + crayon colors
// ---------------------------------------------------------------------------
const Color kInk = Color(0xFF2F3047);
const Color kInkSoft = Color(0xFF6B6D85);
const Color kGreen = Color(0xFF4CAF50);
const Color kGreenLight = Color(0xFFDFF3DC);
const Color kRed = Color(0xFFEF5350);
const Color kOrange = Color(0xFFFFA726);
const Color kBlue = Color(0xFF42A5F5);
const Color kPurple = Color(0xFF9575CD);
const Color kYellow = Color(0xFFFFCA28);
const Color kPink = Color(0xFFF48FB1);

TextStyle ink(double size, {FontWeight? weight, Color? color}) =>
    TextStyle(fontSize: size, fontWeight: weight, color: color ?? kInk);

TextStyle title(double size, {Color? color}) => GoogleFonts.caveat(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color ?? kInk,
    );

ThemeData buildTheme() {
  final OutlineInputBorder base = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: kInk, width: 1.6),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: kGreen),
    scaffoldBackgroundColor: Colors.white,
    textTheme: GoogleFonts.patrickHandTextTheme(ThemeData.light().textTheme)
        .apply(bodyColor: kInk, displayColor: kInk),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: kInkSoft, fontSize: 16),
      border: base,
      enabledBorder: base,
      focusedBorder: base.copyWith(
        borderSide: const BorderSide(color: kGreen, width: 2.4),
      ),
      errorBorder: base.copyWith(
        borderSide: const BorderSide(color: kRed, width: 1.6),
      ),
      focusedErrorBorder: base.copyWith(
        borderSide: const BorderSide(color: kRed, width: 2.4),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: kGreenLight,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.patrickHand(fontSize: 15, color: kInk),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// STATUS (WHO BMI-for-age z-score classification)
// ---------------------------------------------------------------------------
class StatusInfo {
  final String label;
  final Color color;
  final IconData icon;
  final String group;
  final String advice;

  const StatusInfo(
    this.label,
    this.color,
    this.icon,
    this.group,
    this.advice,
  );
}

const List<StatusInfo> kStatusList = [
  StatusInfo(
    'Severely Underweight',
    kPurple,
    Icons.warning_amber_rounded,
    'gain',
    'Very low weight for age. Please see the school nurse or a doctor soon, and follow the high-energy meals below.',
  ),
  StatusInfo(
    'Underweight',
    kBlue,
    Icons.arrow_circle_down_rounded,
    'gain',
    'Weight is a bit low for age. Add more healthy, energy-rich food and keep moving every day.',
  ),
  StatusInfo(
    'Normal',
    kGreen,
    Icons.check_circle_rounded,
    'keep',
    'Great job! Weight is healthy for age. Keep eating balanced meals and staying active.',
  ),
  StatusInfo(
    'Overweight',
    kOrange,
    Icons.arrow_circle_up_rounded,
    'lose',
    'Weight is a little high for age. Choose more veggies and fruits, less sweets and fried food.',
  ),
  StatusInfo(
    'Obese',
    kRed,
    Icons.error_rounded,
    'lose',
    'Weight is high for age. Follow the lighter meals below and please consult a doctor or nutritionist.',
  ),
];

StatusInfo statusForZ(double z) {
  if (z < -3) return kStatusList[0];
  if (z < -2) return kStatusList[1];
  if (z <= 1) return kStatusList[2];
  if (z <= 2) return kStatusList[3];
  return kStatusList[4];
}

const StatusInfo kNotMeasuredStatus = StatusInfo(
  'Not measured yet', kInkSoft, Icons.hourglass_empty_rounded, 'keep',
  'No measurement yet. The teacher or school nurse will take the first measurement.',
);

StatusInfo statusByLabel(String l) => kStatusList.firstWhere(
  (s) => s.label == l, orElse: () => kNotMeasuredStatus,
);

// ---------------------------------------------------------------------------
// BMI + Z-SCORE
// ---------------------------------------------------------------------------
class Lms {
  final double l, m, s;

  const Lms(this.l, this.m, this.s);
}

const List<Lms> _boysLms = [
  Lms(-0.89, 15.26, 0.0839),
  Lms(-1.05, 15.30, 0.0880),
  Lms(-1.25, 15.50, 0.0930),
  Lms(-1.45, 15.75, 0.0980),
  Lms(-1.62, 16.05, 0.1030),
  Lms(-1.75, 16.40, 0.1075),
  Lms(-1.85, 16.85, 0.1120),
  Lms(-1.90, 17.35, 0.1160),
  Lms(-1.90, 17.95, 0.1190),
];

const List<Lms> _girlsLms = [
  Lms(-0.95, 15.24, 0.0950),
  Lms(-1.05, 15.25, 0.0990),
  Lms(-1.15, 15.40, 0.1040),
  Lms(-1.25, 15.70, 0.1100),
  Lms(-1.30, 16.10, 0.1160),
  Lms(-1.35, 16.55, 0.1210),
  Lms(-1.40, 17.10, 0.1250),
  Lms(-1.45, 17.80, 0.1270),
  Lms(-1.50, 18.50, 0.1280),
];

Lms lmsFor(bool girl, double age) {
  final List<Lms> t = girl ? _girlsLms : _boysLms;
  final double a = age.clamp(5.0, 13.0).toDouble();
  final int i = a.floor();

  if (i >= 13) return t.last;

  final double f = a - i;
  final Lms x = t[i - 5];
  final Lms y = t[i - 4];

  return Lms(
    x.l + (y.l - x.l) * f,
    x.m + (y.m - x.m) * f,
    x.s + (y.s - x.s) * f,
  );
}

double zScore(double bmi, Lms x) =>
    ((pow(bmi / x.m, x.l) - 1) / (x.l * x.s)).toDouble();

double bmiAtZ(Lms x, double z) =>
    (x.m * pow(1 + x.l * x.s * z, 1 / x.l)).toDouble();

// ---------------------------------------------------------------------------
// HOUSEHOLD OPTIONS + ALLERGY MATCHING
// ---------------------------------------------------------------------------
const List<String> kHouseholdOptions = [
  'Only for the kid',
  '3 members',
  '4 members',
  '5 members',
  '6 members',
  '7 members',
];

int servingsFor(String household) =>
    household.startsWith('Only') ? 1 : int.parse(household.split(' ').first);

// typed allergy word -> ingredient words to avoid
const Map<String, List<String>> kAllergenWords = {
  'egg': ['egg'],
  'milk': ['milk', 'yogurt'],
  'dairy': ['milk', 'yogurt'],
  'peanut': ['peanut'],
  'nuts': ['peanut'],
  'shrimp': ['shrimp'],
  'seafood': ['shrimp', 'bangus', 'tilapia'],
  'fish': ['bangus', 'tilapia'],
  'soy': ['soy', 'tofu'],
  'chicken': ['chicken'],
  'pork': ['pork'],
  'wheat': ['pandesal', 'oat'],
  'gluten': ['pandesal', 'oat'],
  'oat': ['oat'],
};

// "egg, Peanuts; shrimp and milk" -> [egg, Peanuts, shrimp, milk]
List<String> parseAllergies(String raw) {
  return raw
      .split(RegExp(r'[,;/\n]|\band\b', caseSensitive: false))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

bool hasAllergen(String ingName, List<String> allergies) {
  final String full = ingName.toLowerCase();

  // avoid false match: "Eggplant" is not egg, "milkfish" is not milk
  final String n = full.replaceAll('eggplant', '').replaceAll('milkfish', '');

  for (final raw in allergies) {
    final String t = raw.toLowerCase().trim();

    if (t.isEmpty) continue;

    bool keyed = false;

    for (final w in t.split(RegExp(r'\s+'))) {
      for (final e in kAllergenWords.entries) {
        if (w == e.key || w == '${e.key}s' || w == '${e.key}es') {
          keyed = true;

          for (final word in e.value) {
            if (n.contains(word)) return true;
          }
        }
      }
    }

    // typed something not in the list (e.g. "tofu", "peanut butter")
    if (!keyed && t.length >= 3) {
      if (full.contains(t)) return true;

      if (t.endsWith('s') && full.contains(t.substring(0, t.length - 1))) {
        return true;
      }
    }
  }

  return false;
}

bool mealIsSafe(MealT t, List<String> allergies) =>
    !t.ings.any((g) => hasAllergen(g.name, allergies));

// ---------------------------------------------------------------------------
// ACCOUNT VALIDATION + SMALL HELPERS
// ---------------------------------------------------------------------------
String? validateEmail(String? v) {
  final String t = (v ?? '').trim();

  if (t.isEmpty) return 'Please enter an email';

  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
    return 'Enter a valid email';
  }

  return null;
}

String? validatePassword(String? v) {
  final String t = v ?? '';

  if (t.isEmpty) return 'Please enter a password';

  if (t.length < 6) return 'At least 6 characters';

  return null;
}

// removes spaces and dashes: "0917 123-4567" -> "09171234567"
String cleanPhone(String raw) => raw.replaceAll(RegExp(r'[\s-]'), '');

// PH mobile number: 09XXXXXXXXX or +639XXXXXXXXX
String? validatePhone(String? v) {
  final String t = cleanPhone(v ?? '');

  if (t.isEmpty) return 'Please enter a phone number';

  if (!RegExp(r'^(09|\+639)\d{9}$').hasMatch(t)) {
    return 'Use 09XXXXXXXXX or +639XXXXXXXXX';
  }

  return null;
}

// 128.0 -> "128", 34.5 -> "34.5"
String fmtNum(double? v) {
  if (v == null) return '';

  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

// ---------------------------------------------------------------------------
// STUDENT
// ---------------------------------------------------------------------------
const String kBosy = 'Beginning of the School Year';
const String kEosy = 'End of the School Year';

// summary option that combines both check-ups of the school year
const String kWhole = 'Whole School Year';
const String kNoCheck = 'Not measured yet';

// The school year starts in June:  Oct 2026 -> "2026-2027", Mar 2026 -> "2025-2026"
String schoolYearOf(DateTime d) =>
    d.month >= 6 ? '${d.year}-${d.year + 1}' : '${d.year - 1}-${d.year}';

class Student {
  final String name;
  final String grade;
  final bool girl;
  final int ageY;
  final int ageM;
  final double heightCm;
  final double weightKg;
  final double bmi;
  final double z;
  final StatusInfo status;

  // Beginning of the School Year / End of the School Year
  final String schoolYearPeriod;

  final List<String> allergies;
  final String medicalStatus; // empty = none
  final String household;

  // parent account (manages the student's account)
  final String parentEmail;
  final String parentPassword;
  final String parentPhone;

  // LRN + section
  final String lrn;
  final String section;

  // date of the check-up (Beginning / End of the School Year)
  final DateTime measuredOn;

  const Student._(
    this.name,
    this.grade,
    this.girl,
    this.ageY,
    this.ageM,
    this.heightCm,
    this.weightKg,
    this.bmi,
    this.z,
    this.status,
    this.schoolYearPeriod,
    this.allergies,
    this.medicalStatus,
    this.household,
    this.parentEmail,
    this.parentPassword,
    this.parentPhone,
    this.lrn,
    this.section,
    this.measuredOn,
  );

  factory Student.create({
    required String name,
    required String grade,
    required bool girl,
    required int ageY,
    required int ageM,
    required double heightCm,
    required double weightKg,
    required String schoolYearPeriod,
    List<String> allergies = const [],
    String medicalStatus = '',
    String household = 'Only for the kid',
    String parentEmail = '',
    String parentPassword = '',
    String parentPhone = '',
    String lrn = '',
    String section = '',
    DateTime? measuredOn,
  }) {
    final bool measured = heightCm > 0 && weightKg > 0;
    final double hm = heightCm / 100;
    final double bmi = measured ? weightKg / (hm * hm) : 0;
    final double age = ageY + ageM / 12;
    final double z = measured ? zScore(bmi, lmsFor(girl, age)) : 0;

    return Student._(
      name,
      grade,
      girl,
      ageY,
      ageM,
      heightCm,
      weightKg,
      bmi,
      z,
      measured ? statusForZ(z) : kNotMeasuredStatus,
      schoolYearPeriod,
      allergies,
      medicalStatus,
      household,
      parentEmail,
      parentPassword,
      parentPhone,
      lrn,
      section,
      measuredOn ?? DateTime.now(),
    );
  }

  double get age => ageY + ageM / 12;
  bool get measured => heightCm > 0 && weightKg > 0;

  Lms get lms => lmsFor(girl, age);

  String get firstName => name.split(' ').first;

  int get servings => servingsFor(household);

  String get schoolYear => schoolYearOf(measuredOn);

  Student copyWith({
    String? name,
    String? grade,
    bool? girl,
    int? ageY,
    int? ageM,
    double? heightCm,
    double? weightKg,
    String? schoolYearPeriod,
    List<String>? allergies,
    String? medicalStatus,
    String? household,
    String? parentEmail,
    String? parentPassword,
    String? parentPhone,
    String? lrn,
    String? section,
    DateTime? measuredOn,
  }) {
    return Student.create(
      name: name ?? this.name,
      grade: grade ?? this.grade,
      girl: girl ?? this.girl,
      ageY: ageY ?? this.ageY,
      ageM: ageM ?? this.ageM,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      schoolYearPeriod: schoolYearPeriod ?? this.schoolYearPeriod,
      allergies: allergies ?? this.allergies,
      medicalStatus: medicalStatus ?? this.medicalStatus,
      household: household ?? this.household,
      parentEmail: parentEmail ?? this.parentEmail,
      parentPassword: parentPassword ?? this.parentPassword,
      parentPhone: parentPhone ?? this.parentPhone,
      lrn: lrn ?? this.lrn,
      section: section ?? this.section,
      measuredOn: measuredOn ?? this.measuredOn,
    );
  }
}

String shortName(String name) {
  return name.length > 8 ? '${name.substring(0, 7)}…' : name;
}

// search helper: matches student name or LRN
bool studentMatchesQuery(Student s, String query) {
  final String q = query.trim().toLowerCase();

  if (q.isEmpty) return true;

  return s.name.toLowerCase().contains(q) || s.lrn.toLowerCase().contains(q);
}

// ---------------------------------------------------------------------------
// PROGRESS (BOSY vs EOSY of the same student, in the same school year)
// ---------------------------------------------------------------------------
class ProgressPair {
  final Student before; // Beginning of the School Year
  final Student after; // End of the School Year

  const ProgressPair(this.before, this.after);
}

// Students that have BOTH a Beginning and an End record in the same school
// year. Sorted oldest to newest (the last one is the newest school year).
List<ProgressPair> buildPairs(List<Student> all) {
  final Map<String, Student> bosy = {};
  final Map<String, Student> eosy = {};

  void keep(Map<String, Student> m, String k, Student s) {
    final Student? cur = m[k];

    if (cur == null || s.measuredOn.isAfter(cur.measuredOn)) m[k] = s;
  }

  for (final s in all) {
    final String k = '${s.name.trim().toLowerCase()}|${s.schoolYear}';

    if (s.schoolYearPeriod == kBosy) {
      keep(bosy, k, s);
    } else if (s.schoolYearPeriod == kEosy) {
      keep(eosy, k, s);
    }
  }

  final List<ProgressPair> out = [
    for (final e in bosy.entries)
      if (eosy.containsKey(e.key)) ProgressPair(e.value, eosy[e.key]!),
  ];

  out.sort((a, b) => a.after.measuredOn.compareTo(b.after.measuredOn));

  return out;
}

// All school years that have a school check-up (newest first).
// Always has at least one item (the current school year).
List<String> schoolYearsOf(List<Student> all) {
  final Set<String> years = {
    for (final s in all)
      if (s.measured && s.schoolYearPeriod != kHome) s.schoolYear,
  };

  if (years.isEmpty) years.add(schoolYearOf(DateTime.now()));

  return years.toList()..sort((a, b) => b.compareTo(a));
}

// One record per student for the chosen school year and period.
//   period = kBosy / kEosy  -> that check-up
//   period = kWhole         -> the newest school check-up of the school year
// The newest record wins. Home checks are not part of the summary.
List<Student> latestForSummary(List<Student> all, String sy, String period) {
  final Map<String, Student> latest = {};

  for (final s in all) {
    if (!s.measured || s.schoolYearPeriod == kHome) continue;

    if (s.schoolYear != sy) continue;

    if (period != kWhole && s.schoolYearPeriod != period) continue;

    final String k = s.name.trim().toLowerCase();
    final Student? cur = latest[k];

    if (cur == null || s.measuredOn.isAfter(cur.measuredOn)) latest[k] = s;
  }

  return latest.values.toList();
}

// how far a z-score is from the normal range (-2 to +1)
double zGap(double z) {
  if (z < -2) return -2 - z;
  if (z > 1) return z - 1;
  return 0;
}

String signed(double v, int digits) =>
    '${v >= 0 ? '+' : ''}${v.toStringAsFixed(digits)}';

// ---------------------------------------------------------------------------
// MEAL + EXERCISE ENGINE
// ---------------------------------------------------------------------------
class Ing {
  final String name;
  final double amount;
  final String unit;

  const Ing(this.name, this.amount, this.unit);
}

class MealT {
  final String dish;
  final int kcal;
  final List<Ing> ings;

  const MealT(this.dish, this.kcal, this.ings);
}

class SlotMeta {
  final String name;
  final String time;
  final IconData icon;
  final Color color;
  final double share;

  const SlotMeta(this.name, this.time, this.icon, this.color, this.share);
}

const List<SlotMeta> kSlots = [
  SlotMeta('Breakfast', '6:30 AM', Icons.free_breakfast_rounded, kOrange, 0.25),
  SlotMeta('Lunch', '12:00 NN', Icons.lunch_dining_rounded, kGreen, 0.30),
  SlotMeta(
    'Snacks',
    '3:00 PM',
    Icons.emoji_food_beverage_rounded,
    kPink,
    0.15,
  ),
  SlotMeta('Dinner', '6:30 PM', Icons.dinner_dining_rounded, kBlue, 0.30),
];

const Map<String, Map<String, List<MealT>>> kMeals = <String, Map<String, List<MealT>>>{};

class Exercise {
  final String name;
  final String reps;
  final String tip;
  final IconData icon;

  const Exercise(this.name, this.reps, this.tip, this.icon);
}

const Map<String, List<Exercise>> kExercises = <String, List<Exercise>>{};

// ---------------------------------------------------------------------------
// PRICES (estimates in PHP per g / ml / pc). Change them to your local prices.
// ---------------------------------------------------------------------------
const Map<String, double> kPrice = {
  'Malagkit rice': 0.06, 'Cocoa powder': 0.5, 'Brown sugar': 0.07,
  'Fresh milk': 0.07, 'Boiled egg': 9, 'Rolled oats': 0.12, 'Banana': 6,
  'Peanut butter': 0.25, 'Cooked rice': 0.04, 'Chicken thigh': 0.25,
  'Green papaya': 0.04, 'Malunggay leaves': 0.03, 'Ginger': 0.1,
  'Cooking oil': 0.15, 'Bangus (milkfish)': 0.25, 'Kangkong': 0.04,
  'Radish': 0.04, 'Tomato': 5, 'Saba banana': 7, 'Boiled camote': 0.04,
  'Roasted peanuts': 0.25, 'Lean pork': 0.3, 'Potato': 0.07, 'Cabbage': 0.06,
  'Corn on the cob': 15, 'Eggplant': 15, 'Egg': 9, 'Pandesal': 3,
  'Ripe papaya': 0.05, 'Chicken breast': 0.28, 'String beans (sitaw)': 0.07,
  'Soy sauce': 0.1, 'Vinegar': 0.05, 'Garlic': 0.2, 'Mung beans': 0.12,
  'Spinach': 0.05, 'Plain yogurt': 0.15, 'Lakatan banana': 8, 'Tilapia': 0.2,
  'Onion': 0.12, 'Brown rice (cooked)': 0.06, 'Low-fat milk': 0.08,
  'Apple': 25, 'Cucumber': 0.04, 'Calamansi': 1, 'Watermelon': 0.03,
  'Guava': 8, 'Squash': 0.04, 'Okra': 0.07, 'Shrimp': 0.35, 'Tofu': 0.1,
  'Carrot': 0.06,
};

double ingCost(Ing g, double scale, int servings) =>
    g.amount * scale * servings * (kPrice[g.name] ?? 0.1);

// Filipino words the parent may type -> the word used in the meals
const Map<String, String> kFilipinoFood = {
  'itlog': 'egg', 'manok': 'chicken', 'baboy': 'pork', 'isda': 'fish',
  'talong': 'eggplant', 'kamatis': 'tomato', 'kanin': 'rice', 'bigas': 'rice',
  'gatas': 'milk', 'saging': 'banana', 'hipon': 'shrimp', 'sibuyas': 'onion',
  'bawang': 'garlic', 'kamote': 'camote', 'mais': 'corn',
  'repolyo': 'cabbage', 'patatas': 'potato', 'karot': 'carrot',
  'kalabasa': 'squash', 'pipino': 'cucumber', 'mani': 'peanut',
  'luya': 'ginger', 'suka': 'vinegar', 'toyo': 'soy', 'mantika': 'oil',
  'monggo': 'mung', 'papaya': 'papaya', 'mansanas': 'apple',
};

// true when the parent already has this ingredient at home
bool inPantry(String ingName, List<String> pantry) {
  final String full = ingName.toLowerCase();
  final String n = full.replaceAll('eggplant', '').replaceAll('milkfish', '');

  for (final raw in pantry) {
    String t = raw.toLowerCase().trim();

    if (t.length < 3) continue;

    t = kFilipinoFood[t] ?? t;

    final String s = t.endsWith('s') ? t.substring(0, t.length - 1) : t;

    if (n.contains(t) || n.contains(s)) return true;

    if (t.length >= 5 && full.contains(t)) return true;
  }

  return false;
}

// PLUG YOUR PHOTO RECOGNITION HERE.
// The app cannot read food from a picture by itself. Connect an image
// recognition / vision API (for example Claude's API) and return the names of
// the foods it sees, e.g. ['egg', 'kangkong', 'tomato'].
Future<List<String>> recognizeFoodPhotos(List<Uint8List> photos) async {
  return <String>[];
}

class PlannedIng {
  final String name;
  final String amount;
  final bool have; // already available at home

  const PlannedIng(this.name, this.amount, {this.have = false});
}

class PlannedMeal {
  final SlotMeta slot;
  final String dish;
  final int kcal;
  final List<PlannedIng> ings;
  final double cost; // PHP to buy (ingredients at home are free)

  const PlannedMeal(this.slot, this.dish, this.kcal, this.ings, {this.cost = 0});
}

class DailyPlan {
  final int kcal;
  final List<PlannedMeal> meals;
  final List<Exercise> exercises;
  final int servings;
  final double? cost; // total PHP to buy today
  final double? budget; // budget typed by the parent
  final String? note; // budget / ingredients message

  const DailyPlan(
    this.kcal,
    this.meals,
    this.exercises, {
    this.servings = 1,
    this.cost,
    this.budget,
    this.note,
  });
}

// A meal plan that was given to a student (saved as a read-only record).
class MealPlanRecord {
  final DateTime date;
  final String period; // Beginning / End of the School Year
  final String status; // nutrition status label when the plan was made
  final DailyPlan plan;

  const MealPlanRecord(this.date, this.period, this.status, this.plan);

  bool sameDay(DateTime d) =>
      date.year == d.year && date.month == d.month && date.day == d.day;
}

String fmtAmount(double a, String unit) {
  if (unit == 'pc') {
    double v = (a * 2).round() / 2;

    if (v < 0.5) v = 0.5;

    final int whole = v.floor();
    final bool half = v - whole > 0;
    final String t = whole == 0 ? '½' : (half ? '$whole½' : '$whole');

    return '$t ${v <= 1 ? 'pc' : 'pcs'}';
  }

  int r = ((a / 5).round() * 5);

  if (r < 5) r = 5;

  if (r >= 1000) {
    return '${(r / 1000).toStringAsFixed(1)} ${unit == 'g' ? 'kg' : 'L'}';
  }

  return '$r $unit';
}

int dailyKcal(Student s) {
  final double a = s.age.clamp(5.0, 13.0).toDouble();
  double base = 1450 + (a - 6) * 90;

  if (s.girl) base -= 150;

  final double mult = switch (s.status.group) {
    'gain' => s.status.label == 'Severely Underweight' ? 1.25 : 1.15,
    'lose' => s.status.label == 'Obese' ? 0.85 : 0.90,
    _ => 1.0,
  };

  return (base * mult).round();
}

// One child:  generatePlan(student)
// Many children: generateSharedPlan(kids)   (see shared section)
// One child:  generatePlan(student)
// Many children: generateSharedPlan(kids)   (see shared section)
DailyPlan generatePlan(
  Student s, {
  int shuffle = 0,
  double? budget,
  List<String> pantry = const [],
  bool homeOnly = false,
}) =>
    generatePlanFor(
      group: s.status.group,
      kcal: dailyKcal(s),
      servings: s.servings,
      allergies: s.allergies,
      shuffle: shuffle,
      budget: budget,
      pantry: pantry,
      homeOnly: homeOnly,
    );

class _Cand {
  final MealT t;
  final double scale;
  final double cost;
  final int hits;

  const _Cand(this.t, this.scale, this.cost, this.hits);
}

_Cand _makeCand(
  MealT t,
  SlotMeta slot,
  int kcal,
  int servings,
  List<String> pantry,
) {
  final double scale = (kcal * slot.share / t.kcal).clamp(0.6, 1.6).toDouble();

  double cost = 0;
  int hits = 0;

  for (final g in t.ings) {
    if (pantry.isNotEmpty && inPantry(g.name, pantry)) {
      hits++; // already at home = free
    } else {
      cost += ingCost(g, scale, servings);
    }
  }

  return _Cand(t, scale, cost, hits);
}

DailyPlan generatePlanFor({
  required String group,
  required int kcal,
  required int servings,
  required List<String> allergies,
  int shuffle = 0,
  double? budget,
  List<String> pantry = const [],
  bool homeOnly = false,
}) {
  // No sample meals or exercises are bundled in the app.
  // Connect the AI/PHP generation endpoint before displaying a plan.
  return DailyPlan(
    kcal,
    const <PlannedMeal>[],
    const <Exercise>[],
    servings: servings,
    cost: 0,
    budget: budget,
    note: 'No AI-generated plan is available yet. Connect the AI service to generate meals and exercises.',
  );
}

String todayText() {
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final DateTime d = DateTime.now();

  return '${m[d.month - 1]} ${d.day}, ${d.year}';
}

// Mar 5, 2026
String fmtDate(DateTime d) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  return '${m[d.month - 1]} ${d.day}, ${d.year}';
}


// ===========================================================================
// ===========================================================================
//  NUTRITRACK - SHARED PART (same in all 4 account files)
//  Data store, demo data, navigation shell and reusable widgets.
// ===========================================================================
// ===========================================================================

// ---------------------------------------------------------------------------
// SMALL HELPERS
// ---------------------------------------------------------------------------

// Parents can also measure their child at home (e.g. summer vacation).
const String kHome = 'Home Check (Parent)';

// Beginning = blue, End = orange, Home check = purple
Color colorForPeriod(String p) =>
    p == kBosy ? kBlue : (p == kEosy ? kOrange : kPurple);

// Mar 5
String shortDate(DateTime d) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  return '${m[d.month - 1]} ${d.day}';
}

void showToast(BuildContext context, String msg, {Color color = kInk}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        content: Text(msg, style: const TextStyle(color: Colors.white)),
      ),
    );
}

// healthy weight range (kg) for the child's height and age
String healthyRangeText(Student s) {
  final double hm = s.heightCm / 100;
  final double lo = bmiAtZ(s.lms, -2) * hm * hm;
  final double hi = bmiAtZ(s.lms, 1) * hm * hm;

  return 'Healthy weight for ${s.heightCm.toStringAsFixed(0)} cm at this age: '
      '${lo.toStringAsFixed(1)} – ${hi.toStringAsFixed(1)} kg';
}

// ---------------------------------------------------------------------------
// SHARED MEAL PLAN (one plan that works for several children)
// ---------------------------------------------------------------------------

// All children in the same group -> that group's meals.
// Different groups (e.g. one needs to gain, one needs to lose) -> the
// balanced "keep" meals, which are safe and healthy for everybody.
String sharedGroupOf(List<Student> kids) {
  final Set<String> g = kids.map((k) => k.status.group).toSet();

  return g.length == 1 ? g.first : 'keep';
}

// every allergy of every selected child (so the plan is safe for all)
List<String> unionAllergies(List<Student> kids) {
  final Map<String, String> seen = {};

  for (final k in kids) {
    for (final a in k.allergies) {
      seen.putIfAbsent(a.toLowerCase().trim(), () => a.trim());
    }
  }

  return seen.values.toList();
}

DailyPlan generateSharedPlan(
  List<Student> kids, {
  int shuffle = 0,
  double? budget,
  List<String> pantry = const [],
  bool homeOnly = false,
}) {
  final int total = kids.map((k) => dailyKcal(k)).reduce((a, b) => a + b);
  final int kcal = (total / kids.length).round();
  final int servings = kids.map((k) => k.servings).reduce(max);

  return generatePlanFor(
    group: sharedGroupOf(kids),
    kcal: kcal,
    servings: servings,
    allergies: unionAllergies(kids),
    shuffle: shuffle,
    budget: budget,
    pantry: pantry,
    homeOnly: homeOnly,
  );
}

// how much more / less this child should eat from the shared plan
String portionTip(Student k, int planKcal) {
  final int target = dailyKcal(k);
  final int d = target - planKcal;

  if (d >= 80) {
    return 'Give a bigger portion: about +$d kcal '
        '(more rice and protein, or an extra healthy snack).';
  }

  if (d <= -80) {
    return 'Give a smaller portion: about ${-d} kcal less '
        '(less rice, more vegetables, no sweet drinks or fried extras).';
  }

  return 'Regular portion. It already matches about $target kcal a day.';
}

// ---------------------------------------------------------------------------
// ACCOUNTS
// ---------------------------------------------------------------------------
const String kRoleParent = 'Parent';
const String kRoleTeacher = 'Teacher';
const String kRoleNurse = 'School Nurse';
const String kRoleAdmin = 'Admin';

class StaffAccount {
  final String id;
  final String role;
  final String name;
  final String email;
  final String password;
  final String phone;
  final String detail;
  final String employeeId;
  final String school;

  const StaffAccount({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    required this.detail,
    this.employeeId = '',
    this.school = '',
  });

  StaffAccount copyWith({
    String? name,
    String? email,
    String? password,
    String? phone,
    String? detail,
    String? employeeId,
    String? school,
  }) {
    return StaffAccount(
      id: id,
      role: role,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      phone: phone ?? this.phone,
      detail: detail ?? this.detail,
      employeeId: employeeId ?? this.employeeId,
      school: school ?? this.school,
    );
  }
}

// Account snapshots and activity records retained for the Admin History dashboard.
class AccountArchive {
  final String id;
  final String role;
  final String name;
  final String email;
  final String phone;
  final String detail;
  final String employeeId;
  final String school;
  final DateTime createdAt;
  final DateTime? deletedAt;

  const AccountArchive({required this.id, required this.role, required this.name,
    required this.email, required this.phone, required this.detail,
    this.employeeId = '', this.school = '', required this.createdAt,
    this.deletedAt});

  bool get isActive => deletedAt == null;
}

class ActivityLogEntry {
  final DateTime at;
  final String accountName;
  final String accountEmail;
  final String role;
  final String action;
  final String details;
  const ActivityLogEntry({required this.at, required this.accountName,
    required this.accountEmail, required this.role, required this.action,
    required this.details});
}

// one row of the admin's User Records
class AccountView {
  final String id; // staff id, or the parent email
  final String role;
  final String name;
  final String email;
  final String password;
  final String phone;
  final String detail;
  final String employeeId;
  final String school;
  final List<Student> children;
  final DateTime? createdAt;
  final bool isActive;

  const AccountView({
    required this.id,
    required this.role,
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    required this.detail,
    this.employeeId = '',
    this.school = '',
    this.children = const [],
    this.createdAt,
    this.isActive = true,
  });
}

// Password reset requests are stored in the shared demo store and shown to Admin.
// For a real deployment, persist these records through a secure backend.
class PasswordResetRequest {
  final String id;
  final String role;
  final String userName;
  final String userEmail;
  final String studentName;
  final String lrn;
  final String relationshipToStudent;
  final String registeredPhoneLast4;
  final String accountDetail;
  final String schoolDepartment;
  final DateTime submittedAt;
  bool reviewed;

  PasswordResetRequest({
    required this.id,
    required this.role,
    required this.userName,
    required this.userEmail,
    required this.studentName,
    required this.lrn,
    required this.relationshipToStudent,
    required this.registeredPhoneLast4,
    required this.accountDetail,
    required this.schoolDepartment,
    required this.submittedAt,
    this.reviewed = false,
  });
}

IconData roleIcon(String role) {
  switch (role) {
    case kRoleParent:
      return Icons.family_restroom_rounded;
    case kRoleTeacher:
      return Icons.school_rounded;
    case kRoleNurse:
      return Icons.medical_services_rounded;
    default:
      return Icons.admin_panel_settings_rounded;
  }
}

Color roleColor(String role) {
  switch (role) {
    case kRoleParent:
      return kGreen;
    case kRoleTeacher:
      return kBlue;
    case kRoleNurse:
      return kPink;
    default:
      return kPurple;
  }
}

// ---------------------------------------------------------------------------
// DEMO DATA  (same students in every account file)
// ---------------------------------------------------------------------------
List<Student> _seedStudents() => <Student>[];

// ---------------------------------------------------------------------------
// STORE for transient UI state. Account and student data must come from the PHP/MySQL API..
// ---------------------------------------------------------------------------
class NutriStore extends ChangeNotifier {
  final List<Student> students = <Student>[];
  final Map<String, AccountArchive> accountHistory = {};
  final Map<String, DateTime> _accountCreatedAt = {};
  final Set<String> disabledParentEmails = <String>{};
  final List<ActivityLogEntry> activityHistory = <ActivityLogEntry>[];

  String _archiveKey(String role, String id) => '$role::${id.trim().toLowerCase()}';

  bool isParentDisabled(String email) =>
      disabledParentEmails.contains(email.trim().toLowerCase());

  void _log(String role, String name, String email, String action, String details) {
    activityHistory.insert(0, ActivityLogEntry(
      at: DateTime.now(), accountName: name, accountEmail: email,
      role: role, action: action, details: details));
  }

  void _rememberAccount({required String id, required String role,
    required String name, required String email, required String phone,
    required String detail, String employeeId = '', String school = '',
    DateTime? createdAt, DateTime? deletedAt}) {
    final String key = _archiveKey(role, id);
    final DateTime created = _accountCreatedAt.putIfAbsent(key,
      () => createdAt ?? DateTime.now());
    accountHistory[key] = AccountArchive(id: id, role: role, name: name,
      email: email, phone: phone, detail: detail, employeeId: employeeId,
      school: school, createdAt: created, deletedAt: deletedAt);
  }

  void _archiveStaff(StaffAccount a, {DateTime? deletedAt}) => _rememberAccount(
    id: a.id, role: a.role, name: a.name, email: a.email, phone: a.phone,
    detail: a.detail, employeeId: a.employeeId, school: a.school,
    deletedAt: deletedAt);

  void _archiveParent(String email, {DateTime? deletedAt}) {
    final String e = email.trim().toLowerCase();
    final List<Student> kids = latestPerChild().where((c) =>
      c.parentEmail.trim().toLowerCase() == e).toList();
    final Student? first = kids.isEmpty ? null : kids.first;
    final AccountArchive? old = accountHistory[_archiveKey(kRoleParent, e)];
    _rememberAccount(id: e, role: kRoleParent,
      name: parentNameFor(e), email: first?.parentEmail ?? old?.email ?? e,
      phone: first?.parentPhone ?? old?.phone ?? '',
      detail: kids.isEmpty ? (old?.detail ?? 'Parent account') :
        '${kids.length} ${kids.length == 1 ? 'child' : 'children'}',
      createdAt: old?.createdAt, deletedAt: deletedAt ?? old?.deletedAt);
  }


  // Password reset requests submitted from the login screen for Admin review.
  // This list is in-memory for this demo and clears when the app restarts.
  final List<PasswordResetRequest> passwordResetRequests = [];

  void addPasswordResetRequest(PasswordResetRequest request) {
    passwordResetRequests.insert(0, request);
    notifyListeners();
  }

  void markPasswordResetReviewed(PasswordResetRequest request) {
    request.reviewed = true;
    notifyListeners();
  }

  void removePasswordResetRequest(PasswordResetRequest request) {
    passwordResetRequests.remove(request);
    notifyListeners();
  }

  // meal plans given to each student (key = lowercase name)
  final Map<String, List<MealPlanRecord>> mealHistory = {};

  // parent full names (key = lowercase parent email)
  final Map<String, String> parentNames = <String, String>{};

  final List<StaffAccount> staff = <StaffAccount>[];

  NutriStore();

  static String keyOf(String name) => name.trim().toLowerCase();

  StaffAccount? staffOf(String role) {
    for (final account in staff) {
      if (account.role == role) return account;
    }
    return null;
  }

  String parentNameFor(String email) {
    final String e = email.trim().toLowerCase();

    return parentNames[e] ?? email.split('@').first;
  }

  // ---- reading -------------------------------------------------------------

  // all check-ups of one student, oldest first
  List<Student> recordsOf(String name) {
    final String k = NutriStore.keyOf(name);

    return students.where((s) => NutriStore.keyOf(s.name) == k).toList()
      ..sort((a, b) => a.measuredOn.compareTo(b.measuredOn));
  }

  Student? latestOf(String name) {
    final List<Student> r = recordsOf(name);

    return r.isEmpty ? null : r.last;
  }

  // one (latest) record per student, A to Z
  List<Student> latestPerChild() {
    final Map<String, Student> m = {};

    for (final s in students) {
      final String k = NutriStore.keyOf(s.name);
      final Student? cur = m[k];

      if (cur == null || s.measuredOn.isAfter(cur.measuredOn)) {
        m[k] = s;
      }
    }

    return m.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  // the children of one parent account (a parent can have many)
  List<Student> childrenOf(String email) {
    final String e = email.trim().toLowerCase();

    return latestPerChild()
        .where((s) => s.parentEmail.trim().toLowerCase() == e)
        .toList();
  }

  List<AccountView> allAccounts() {
    final List<AccountView> out = [];

    for (final a in staff) {
      out.add(
        AccountView(
          id: a.id,
          role: a.role,
          name: a.name,
          email: a.email,
          password: a.password,
          phone: a.phone,
          detail: a.detail,
          employeeId: a.employeeId,
          school: a.school,
          createdAt: accountHistory[_archiveKey(a.role, a.id)]?.createdAt,
          isActive: true,
        ),
      );
    }

    final Map<String, List<Student>> byParent = {};

    for (final s in latestPerChild()) {
      byParent
          .putIfAbsent(s.parentEmail.trim().toLowerCase(), () => [])
          .add(s);
    }

    for (final e in byParent.entries) {
      final Student first = e.value.first;

      out.add(
        AccountView(
          id: e.key,
          role: kRoleParent,
          name: parentNameFor(e.key),
          email: first.parentEmail,
          password: first.parentPassword,
          phone: first.parentPhone,
          detail: e.value.length == 1 ? '1 child' : '${e.value.length} children',
          children: e.value,
          createdAt: accountHistory[_archiveKey(kRoleParent, e.key)]?.createdAt,
          isActive: !isParentDisabled(e.key),
        ),
      );
    }

    // Retain deleted staff and deleted parents in User Records; they cannot log in.
    for (final archived in accountHistory.values) {
      if (archived.isActive) continue;
      if (out.any((a) => a.role == archived.role &&
          (a.id == archived.id || a.email.toLowerCase() == archived.email.toLowerCase()))) continue;
      out.add(AccountView(id: archived.id, role: archived.role,
        name: archived.name, email: archived.email, password: '',
        phone: archived.phone, detail: archived.detail,
        employeeId: archived.employeeId, school: archived.school,
        children: archived.role == kRoleParent ? latestPerChild().where((c) =>
          c.parentEmail.trim().toLowerCase() == archived.email.trim().toLowerCase()).toList() : const [],
        createdAt: archived.createdAt, isActive: false));
    }

    return out;
  }

  // ---- writing -------------------------------------------------------------
  void _putPlan(String name, MealPlanRecord rec) {
    final List<MealPlanRecord> list =
        mealHistory.putIfAbsent(NutriStore.keyOf(name), () => []);

    final int i = list.indexWhere(
      (r) => r.period == rec.period && r.sameDay(rec.date),
    );

    if (i >= 0) {
      list[i] = rec;
    } else {
      list.add(rec);
    }

    list.sort((a, b) => b.date.compareTo(a.date));
  }

  // ---- staff + parent accounts (admin) --------------------------------------
  String newStaffId() => 's-${DateTime.now().microsecondsSinceEpoch}';

  // true when the email is already used by a staff or parent account
  bool emailInUse(
    String email, {
    String? exceptStaffId,
    String? exceptParentEmail,
  }) {
    final String e = email.trim().toLowerCase();

    if (staff.any((a) => a.id != exceptStaffId && a.email.toLowerCase() == e)) {
      return true;
    }

    if (exceptParentEmail != null &&
        e == exceptParentEmail.trim().toLowerCase()) {
      return false;
    }

    return students.any((s) => s.parentEmail.trim().toLowerCase() == e);
  }

  void addStaff(StaffAccount a) {
    staff.add(a);
    _archiveStaff(a);
    _log(a.role, a.name, a.email, 'Account created',
      'Account created by Admin. Employee ID: ${a.employeeId.isEmpty ? 'N/A' : a.employeeId}; School: ${a.school.isEmpty ? 'N/A' : a.school}.');
    notifyListeners();
  }

  void updateStaff(
    String id, {
    required String name,
    required String email,
    required String password,
    required String phone,
    required String detail,
    String? employeeId,
    String? school,
  }) {
    final int i = staff.indexWhere((a) => a.id == id);

    if (i < 0) return;

    staff[i] = staff[i].copyWith(
      name: name, email: email, password: password, phone: phone,
      detail: detail, employeeId: employeeId, school: school,
    );
    _archiveStaff(staff[i]);
    _log(staff[i].role, staff[i].name, staff[i].email, 'Account updated',
      'Admin/staff account information was updated.');
    notifyListeners();
  }

  void deleteStaff(String id) {
    final int i = staff.indexWhere((a) => a.id == id);
    if (i < 0) return;
    final StaffAccount a = staff[i];
    _archiveStaff(a, deletedAt: DateTime.now());
    _log(a.role, a.name, a.email, 'Account deleted',
      'Admin deactivated/deleted this account. The account is retained in history and can no longer log in.');
    staff.removeAt(i);
    notifyListeners();
  }

  void deleteParent(String email) {
    final String e = email.trim().toLowerCase();
    if (isParentDisabled(e)) return;
    _archiveParent(e, deletedAt: DateTime.now());
    disabledParentEmails.add(e);
    final AccountArchive? a = accountHistory[_archiveKey(kRoleParent, e)];
    _log(kRoleParent, a?.name ?? parentNameFor(e), e, 'Account deleted',
      'Admin deactivated this parent account. Student records and previous activity are retained; this account can no longer log in.');
    notifyListeners();
  }

  // changes the parent account of ALL the children that use the old email
  void updateParent(
    String oldEmail, {
    required String name,
    required String email,
    required String password,
    required String phone,
  }) {
    final String o = oldEmail.trim().toLowerCase();
    final String newNormalizedEmail = email.trim().toLowerCase();
    if (o != newNormalizedEmail) {
      _archiveParent(o, deletedAt: DateTime.now());
      _log(kRoleParent, parentNameFor(o), o, 'Account email changed',
        'The parent account email was changed by Admin. The previous email is retained in account history.');
    }

    for (var i = 0; i < students.length; i++) {
      final Student s = students[i];

      if (s.parentEmail.trim().toLowerCase() != o) continue;

      students[i] = s.copyWith(
        parentEmail: email.trim(),
        parentPassword: password,
        parentPhone: cleanPhone(phone),
      );
    }

    parentNames.remove(o);
    parentNames[email.trim().toLowerCase()] = name.trim();
    if (isParentDisabled(o)) {
      disabledParentEmails.remove(o);
      disabledParentEmails.add(email.trim().toLowerCase());
    }
    _archiveParent(email.trim().toLowerCase());
    _log(kRoleParent, name.trim(), email.trim(), 'Account updated',
      'Parent account contact information was updated by Admin.');
    notifyListeners();
  }

  // admin: change the info of a child (all of the child's check-ups follow)
  void updateChildInfo(
    String oldName, {
    required String name,
    required String lrn,
    required String grade,
    required String section,
    required int ageY,
    required bool girl,
    required List<String> allergies,
    required String medical,
    required String household,
  }) {
    final String k = NutriStore.keyOf(oldName);
    final Student? latest = latestOf(oldName);

    for (var i = 0; i < students.length; i++) {
      final Student s = students[i];

      if (NutriStore.keyOf(s.name) != k) continue;

      students[i] = s.copyWith(
        name: name.trim(),
        lrn: lrn.trim(),
        grade: grade,
        section: section.trim(),
        girl: girl,
        allergies: allergies,
        medicalStatus: medical.trim(),
        household: household,
        ageY: identical(s, latest) ? ageY : null,
      );
    }

    final String nk = NutriStore.keyOf(name);

    if (nk != k && mealHistory.containsKey(k)) {
      mealHistory.putIfAbsent(nk, () => []).addAll(mealHistory.remove(k)!);
    }

    final String parentEmail = latest?.parentEmail.trim().toLowerCase() ?? '';
    _log(kRoleAdmin, 'Admin', '', 'Student information updated', 'Student profile information was updated for $oldName. Parent account: $parentEmail.');
    notifyListeners();
  }

  // a new check-up (saved to the student's account, managed by the parent)
  void addRecord(Student s, {String? actorRole, String? actorName, String? actorEmail}) {
    // the first real measurement replaces the "not measured yet" record
    if (s.measured) {
      students.removeWhere(
        (x) => !x.measured && NutriStore.keyOf(x.name) == NutriStore.keyOf(s.name),
      );
    }

    students.insert(0, s);

    if (s.measured) {
      _putPlan(s.name, MealPlanRecord(DateTime.now(), s.schoolYearPeriod,
        s.status.label, generatePlan(s)));
      final String email = s.parentEmail.trim().toLowerCase();
      _archiveParent(email);
      final String measurementDetails = 'Measurement recorded for ${s.name} on ${fmtDate(s.measuredOn)}; BMI ${s.bmi.toStringAsFixed(1)}, nutrition status ${s.status.label}.';
      if (actorRole != null) {
        _log(actorRole, actorName ?? actorRole, actorEmail ?? '', 'Student measurement recorded', measurementDetails);
      }
      if (actorRole == null || actorRole != kRoleParent) {
        _log(kRoleParent, parentNameFor(email), email, 'Student measurement recorded', measurementDetails);
      }
    } else {
      final String email = s.parentEmail.trim().toLowerCase();
      _archiveParent(email);
      _log(kRoleParent, parentNameFor(email), email, 'Student record created/updated',
        'Student record for ${s.name} was saved.');
    }

    notifyListeners();
  }

  // admin creates a student + parent account
  void addStudentWithParent(Student s, String parentName) {
    if (parentName.trim().isNotEmpty) {
      parentNames[s.parentEmail.trim().toLowerCase()] = parentName.trim();
    }
    final String email = s.parentEmail.trim().toLowerCase();
    _archiveParent(email);
    _log(kRoleParent, parentNameFor(email), email, 'Account created',
      'Parent account created with student ${s.name}.');
    addRecord(s);
  }

  void addMealPlan(String name, MealPlanRecord rec) {
    _putPlan(name, rec);
    final Student? child = latestOf(name);
    if (child != null) {
      final String email = child.parentEmail.trim().toLowerCase();
      _log(kRoleParent, parentNameFor(email), email, 'Nutrition meal plan saved',
        'Nutrition meal plan saved for ${child.name} on ${fmtDate(rec.date)} (${rec.status}).');
    }
    notifyListeners();
  }

  void replaceRecord(Student oldS, Student newS) {
    final int i = students.indexOf(oldS);

    if (i >= 0) {
      students[i] = newS;
      notifyListeners();
    }
  }

  void removeRecord(Student s) {
    students.remove(s);
    final String email = s.parentEmail.trim().toLowerCase();
    _log(kRoleParent, parentNameFor(email), email, 'Student measurement/record removed',
      'A record for ${s.name} dated ${fmtDate(s.measuredOn)} was removed from the active student records.');
    notifyListeners();
  }

  // teacher: grade, section and age.
  // grade + section apply to every record; age applies to the latest check-up.
  void updateStudentInfo(
    String name, {
    required String grade,
    required String section,
    required int ageY,
  }) {
    final String k = NutriStore.keyOf(name);
    final Student? latest = latestOf(name);

    for (var i = 0; i < students.length; i++) {
      final Student s = students[i];

      if (NutriStore.keyOf(s.name) != k) continue;

      students[i] = s.copyWith(
        grade: grade,
        section: section,
        ageY: identical(s, latest) ? ageY : null,
      );
    }

    _log('Teacher', name, '', 'Student information updated', 'Grade, section, or age information was updated for $name.');
    notifyListeners();
  }

  // parent: allergies, medical status and who the meal plan is for
  void updateHealthInfo(
    String name, {
    required List<String> allergies,
    required String medical,
    required String household,
  }) {
    final String k = NutriStore.keyOf(name);

    for (var i = 0; i < students.length; i++) {
      final Student s = students[i];

      if (NutriStore.keyOf(s.name) != k) continue;

      students[i] = s.copyWith(
        allergies: allergies,
        medicalStatus: medical,
        household: household,
      );
    }

    final Student? latest = latestOf(name);
    final String email = latest?.parentEmail.trim().toLowerCase() ?? '';
    _log(kRoleParent, parentNameFor(email), email, 'Student health information updated', 'Allergy, medical, or household information was updated for $name.');
    notifyListeners();
  }

  void updateParentPhone(String email, String phone) {
    final String e = email.trim().toLowerCase();

    for (var i = 0; i < students.length; i++) {
      final Student s = students[i];

      if (s.parentEmail.trim().toLowerCase() != e) continue;

      students[i] = s.copyWith(parentPhone: phone);
    }

    _log(kRoleParent, parentNameFor(e), e, 'Parent contact updated', 'Parent phone number was updated.');
    notifyListeners();
  }

  // admin: Student Health Data page (info + parent account)
  void saveHealthData(
    Student? oldBefore,
    Student? newBefore,
    Student? oldAfter,
    Student? newAfter,
  ) {
    void swap(Student? oldS, Student? newS) {
      if (newS == null) return;

      if (oldS == null) {
        students.add(newS);
        return;
      }

      final int i = students.indexOf(oldS);

      if (i >= 0) {
        students[i] = newS;
      } else {
        students.add(newS);
      }
    }

    final Student? oldBase = oldBefore ?? oldAfter;
    final Student? newBase = newBefore ?? newAfter;

    final String? oldKey = oldBase == null ? null : NutriStore.keyOf(oldBase.name);
    final String? newKey = newBase == null ? null : NutriStore.keyOf(newBase.name);

    // the records of the other check-ups (e.g. home checks) follow the edit
    if (oldBase != null && newBase != null) {
      for (var i = 0; i < students.length; i++) {
        final Student s = students[i];

        if (identical(s, oldBefore) || identical(s, oldAfter)) continue;

        if (NutriStore.keyOf(s.name) != oldKey) continue;

        students[i] = s.copyWith(
          name: newBase.name,
          grade: newBase.grade,
          girl: newBase.girl,
          allergies: newBase.allergies,
          medicalStatus: newBase.medicalStatus,
          household: newBase.household,
          parentEmail: newBase.parentEmail,
          parentPassword: newBase.parentPassword,
          parentPhone: newBase.parentPhone,
        );
      }

      final String oldEmail = oldBase.parentEmail.trim().toLowerCase();
      final String newEmail = newBase.parentEmail.trim().toLowerCase();

      if (oldEmail != newEmail &&
          parentNames.containsKey(oldEmail) &&
          !parentNames.containsKey(newEmail)) {
        parentNames[newEmail] = parentNames[oldEmail]!;
      }
    }

    swap(oldBefore, newBefore);
    swap(oldAfter, newAfter);

    if (oldKey != null &&
        newKey != null &&
        oldKey != newKey &&
        mealHistory.containsKey(oldKey)) {
      mealHistory.putIfAbsent(newKey, () => []).addAll(
            mealHistory.remove(oldKey)!,
          );
    }

    _log(kRoleAdmin, 'Admin', '', 'Student health record updated', 'Admin saved student health data or parent account information.');
    notifyListeners();
  }
}

// one store for the whole app (created the first time it is used)
final NutriStore kStore = NutriStore();

// ---------------------------------------------------------------------------
// NAVIGATION SHELL (sidebar on wide screens, bottom bar on phones)
// ---------------------------------------------------------------------------
class NavDef {
  final String label;
  final String shortLabel; // used by the phone bottom bar
  final IconData icon;
  final WidgetBuilder builder;

  const NavDef(this.label, this.shortLabel, this.icon, this.builder);
}

class RoleChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const RoleChip({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ink(15, weight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class RoleShell extends StatefulWidget {
  final String roleLabel;
  final Color roleColor;
  final IconData roleIcon;
  final String userName;
  final List<NavDef> tabs;

  // called after the user confirms Log Out (null = no log out button)
  final VoidCallback? onLogout;

  const RoleShell({
    super.key,
    required this.roleLabel,
    required this.roleColor,
    required this.roleIcon,
    required this.userName,
    required this.tabs,
    this.onLogout,
  });

  // lets a page jump to another tab:  RoleShell.goTo(context, 1)
  static void goTo(BuildContext context, int i) {
    context.findAncestorStateOfType<_RoleShellState>()?.go(i);
  }

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int index = 0;

  void go(int i) => setState(() => index = i);

  Future<void> _confirmLogout() async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: PaperCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.logout_rounded, color: kRed, size: 30),
                    const SizedBox(width: 8),
                    Text('Log out?', style: title(34, color: kRed)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'You will go back to the log in page.',
                  style: ink(16),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kInk, width: 1.4),
                      ),
                      child: Text('Stay', style: ink(15)),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(backgroundColor: kRed),
                      child: Text(
                        'Log Out',
                        style: ink(15, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (yes == true) widget.onLogout?.call();
  }

  Widget _logoutItem() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _confirmLogout,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: kRed.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kRed, width: 1.8),
        ),
        child: Row(
          children: [
            const Icon(Icons.logout_rounded, size: 24, color: kRed),
            const SizedBox(width: 12),
            Text(
              'Log Out',
              style: ink(19, weight: FontWeight.w700, color: kRed),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideItem(NavDef item, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? kGreenLight : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? kInk : Colors.transparent,
              width: 1.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 24,
                color: selected ? kGreen : kInkSoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: ink(19, weight: selected ? FontWeight.w700 : null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      width: 270,
      margin: const EdgeInsets.all(16),
      child: PaperCard(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, c) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Brand(),
                      const SizedBox(height: 14),
                      RoleChip(
                        label: widget.roleLabel,
                        color: widget.roleColor,
                        icon: widget.roleIcon,
                      ),
                      const SizedBox(height: 22),
                      for (var i = 0; i < widget.tabs.length; i++)
                        _sideItem(
                          widget.tabs[i],
                          i == index,
                          () => setState(() => index = i),
                        ),
                      const Spacer(),
                      const SizedBox(height: 12),
                      if (widget.onLogout != null) ...[
                        _logoutItem(),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kYellow.withAlpha(50),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 19,
                              backgroundColor: widget.roleColor.withAlpha(45),
                              child: Icon(
                                widget.roleIcon,
                                color: widget.roleColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.userName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: ink(15, weight: FontWeight.w700),
                                  ),
                                  Text(
                                    widget.roleLabel,
                                    style: ink(13, color: kInkSoft),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey(index),
        child: Align(
          alignment: Alignment.topCenter,
          // Builder = pages get a context under the shell (for RoleShell.goTo)
          child: Builder(builder: widget.tabs[index].builder),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final bool wide = c.maxWidth >= 800;

        return Scaffold(
          body: ArtBackground(
            child: SafeArea(
              child: wide
                  ? Row(
                      children: [
                        _sidebar(),
                        Expanded(child: content),
                      ],
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Row(
                            children: [
                              const _Brand(),
                              const Spacer(),
                              Flexible(
                                child: RoleChip(
                                  label: widget.roleLabel,
                                  color: widget.roleColor,
                                  icon: widget.roleIcon,
                                ),
                              ),
                              if (widget.onLogout != null)
                                IconButton(
                                  tooltip: 'Log out',
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    color: kRed,
                                  ),
                                  onPressed: _confirmLogout,
                                ),
                            ],
                          ),
                        ),
                        Expanded(child: content),
                      ],
                    ),
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (i) => setState(() => index = i),
                  destinations: [
                    for (final n in widget.tabs)
                      NavigationDestination(
                        icon: Icon(n.icon),
                        label: n.shortLabel,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

// the app itself (each account file passes its own shell)
class NutritrackApp extends StatelessWidget {
  final String appTitle;
  final Widget home;

  const NutritrackApp({super.key, required this.appTitle, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: appTitle,
      theme: buildTheme(),
      home: home,
    );
  }
}

// ---------------------------------------------------------------------------
// BACKGROUND DOODLES
// ---------------------------------------------------------------------------
class _DoodlePainter extends CustomPainter {
  static const List<Color> _colors = [
    kRed,
    kGreen,
    kOrange,
    kBlue,
    kPurple,
    Color(0xFFE6A800),
    kPink,
  ];

  void _apple(Canvas c, double s, Paint line, Paint fill) {
    final Path p = Path()
      ..moveTo(0, -s * .45)
      ..cubicTo(s * .5, -s * .95, s * 1.15, -s * .3, s * .95, s * .35)
      ..cubicTo(s * .75, s * 1.0, s * .25, s * 1.05, 0, s * .85)
      ..cubicTo(-s * .25, s * 1.05, -s * .75, s * 1.0, -s * .95, s * .35)
      ..cubicTo(-s * 1.15, -s * .3, -s * .5, -s * .95, 0, -s * .45)
      ..close();

    c.drawPath(p, fill);
    c.drawPath(p, line);

    c.drawLine(Offset(0, -s * .45), Offset(s * .1, -s * .95), line);

    final Path leaf = Path()
      ..moveTo(s * .1, -s * .8)
      ..quadraticBezierTo(s * .6, -s * 1.2, s * .85, -s * .8)
      ..quadraticBezierTo(s * .4, -s * .6, s * .1, -s * .8);

    c.drawPath(
      leaf,
      Paint()
        ..color = kGreen.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _carrot(Canvas c, double s, Paint line, Paint fill) {
    final Path p = Path()
      ..moveTo(-s * .4, -s * .5)
      ..quadraticBezierTo(0, -s * .75, s * .4, -s * .5)
      ..lineTo(0, s * 1.1)
      ..close();

    c.drawPath(p, fill);
    c.drawPath(p, line);

    c.drawLine(Offset(-s * .18, -s * .1), Offset(s * .05, -s * .1), line);
    c.drawLine(Offset(-s * .06, s * .3), Offset(s * .15, s * .3), line);

    final Paint leaf = Paint()
      ..color = kGreen.withAlpha(170)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    c.drawLine(Offset(0, -s * .6), Offset(-s * .35, -s * 1.1), leaf);
    c.drawLine(Offset(0, -s * .6), Offset(0, -s * 1.2), leaf);
    c.drawLine(Offset(0, -s * .6), Offset(s * .35, -s * 1.1), leaf);
  }

  void _banana(Canvas c, double s, Paint line, Paint fill) {
    final Path p = Path()
      ..moveTo(-s, -s * .4)
      ..quadraticBezierTo(-s * .1, s * 1.0, s, -s * .2)
      ..quadraticBezierTo(s * .1, s * .35, -s, -s * .4)
      ..close();

    c.drawPath(p, fill);
    c.drawPath(p, line);

    c.drawLine(Offset(s, -s * .2), Offset(s * 1.12, -s * .5), line);
  }

  void _broccoli(Canvas c, double s, Paint line, Paint fill) {
    final Paint green = Paint()
      ..color = kGreen.withAlpha(60)
      ..style = PaintingStyle.fill;

    final Paint greenLine = Paint()
      ..color = kGreen.withAlpha(180)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    for (final o in [
      Offset(-s * .5, -s * .2),
      Offset(0, -s * .5),
      Offset(s * .5, -s * .2),
    ]) {
      c.drawCircle(o, s * .5, green);
      c.drawCircle(o, s * .5, greenLine);
    }

    final Path stem = Path()
      ..moveTo(-s * .2, s * .2)
      ..lineTo(-s * .25, s)
      ..lineTo(s * .25, s)
      ..lineTo(s * .2, s * .2);

    c.drawPath(stem, greenLine);
  }

  void _kidHead(Canvas c, double s, Paint line) {
    c.drawCircle(Offset(0, -s * .9), s * .3, line);

    c.drawArc(
      Rect.fromCircle(center: Offset(0, -s * .85), radius: s * .15),
      0.3,
      2.5,
      false,
      line,
    );

    c.drawCircle(Offset(-s * .1, -s * .98), 0.8, line);
    c.drawCircle(Offset(s * .1, -s * .98), 0.8, line);

    c.drawLine(Offset(0, -s * .6), Offset(0, s * .2), line);
  }

  void _kidJump(Canvas c, double s, Paint line) {
    _kidHead(c, s, line);

    c.drawLine(Offset(0, -s * .4), Offset(-s * .8, -s * .95), line);
    c.drawLine(Offset(0, -s * .4), Offset(s * .8, -s * .95), line);
    c.drawLine(Offset(0, s * .2), Offset(-s * .5, s), line);
    c.drawLine(Offset(0, s * .2), Offset(s * .5, s), line);
  }

  void _kidApple(Canvas c, double s, Paint line, Color color) {
    _kidHead(c, s, line);

    c.drawLine(Offset(0, -s * .4), Offset(-s * .5, s * .1), line);
    c.drawLine(Offset(0, -s * .4), Offset(s * .6, -s * .1), line);
    c.drawLine(Offset(0, s * .2), Offset(-s * .2, s), line);
    c.drawLine(Offset(0, s * .2), Offset(s * .2, s), line);

    c.drawCircle(
      Offset(s * .72, -s * .28),
      s * .2,
      Paint()..color = kRed.withAlpha(130),
    );
  }

  void _dumbbell(Canvas c, double s, Paint line, Paint fill) {
    c.drawLine(Offset(-s * .6, 0), Offset(s * .6, 0), line);

    for (final dx in [-1.0, 1.0]) {
      final RRect big = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(dx * s * .72, 0),
          width: s * .32,
          height: s * .95,
        ),
        const Radius.circular(4),
      );

      final RRect small = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(dx * s * 1.0, 0),
          width: s * .2,
          height: s * .6,
        ),
        const Radius.circular(3),
      );

      c.drawRRect(big, fill);
      c.drawRRect(big, line);
      c.drawRRect(small, line);
    }
  }

  void _drop(Canvas c, double s, Paint line, Paint fill) {
    final Path p = Path()
      ..moveTo(0, -s)
      ..cubicTo(s * .9, -s * .1, s * .8, s * .9, 0, s * .9)
      ..cubicTo(-s * .8, s * .9, -s * .9, -s * .1, 0, -s);

    c.drawPath(p, fill);
    c.drawPath(p, line);
  }

  void _star(Canvas c, double s, Paint line, Paint fill) {
    final Path p = Path();

    for (var i = 0; i < 10; i++) {
      final double r = i.isEven ? s : s * .45;
      final double a = -pi / 2 + i * pi / 5;
      final Offset o = Offset(cos(a) * r, sin(a) * r);

      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }

    p.close();
    c.drawPath(p, fill);
    c.drawPath(p, line);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Random rnd = Random(7);
    const double cell = 150;

    final int cols = (size.width / cell).ceil();
    final int rows = (size.height / cell).ceil();

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final double x =
            c * cell + cell / 2 + (rnd.nextDouble() - .5) * cell * .5;

        final double y =
            r * cell + cell / 2 + (rnd.nextDouble() - .5) * cell * .5;

        final double s = 20 + rnd.nextDouble() * 10;
        final Color color = _colors[rnd.nextInt(_colors.length)];

        final int type = (r * 7 + c * 3 + rnd.nextInt(2)) % 9;

        final double angle = (rnd.nextDouble() - .5) * .7;

        final Paint line = Paint()
          ..color = color.withAlpha(150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        final Paint fill = Paint()
          ..color = color.withAlpha(40)
          ..style = PaintingStyle.fill;

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);

        switch (type) {
          case 0:
            _apple(canvas, s, line, fill);
          case 1:
            _carrot(canvas, s, line, fill);
          case 2:
            _banana(canvas, s, line, fill);
          case 3:
            _broccoli(canvas, s, line, fill);
          case 4:
            _kidJump(canvas, s, line);
          case 5:
            _kidApple(canvas, s, line, color);
          case 6:
            _dumbbell(canvas, s, line, fill);
          case 7:
            _drop(canvas, s, line, fill);
          default:
            _star(canvas, s, line, fill);
        }

        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ArtBackground extends StatelessWidget {
  final Widget child;

  const ArtBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _DoodlePainter()),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// REUSABLE HAND-DRAWN WIDGETS
// ---------------------------------------------------------------------------
class _SketchBorderPainter extends CustomPainter {
  Path _wobbly(Size size, Random rnd, double jitter) {
    final List<Offset> pts = [];

    void edge(Offset a, Offset b) {
      final double len = (b - a).distance;
      final int n = max(1, (len / 30).floor());

      for (var i = 0; i < n; i++) {
        final Offset o = Offset.lerp(a, b, i / n)!;

        pts.add(
          o +
              Offset(
                (rnd.nextDouble() - .5) * jitter,
                (rnd.nextDouble() - .5) * jitter,
              ),
        );
      }
    }

    final Offset tl = const Offset(1, 1);
    final Offset tr = Offset(size.width - 1, 1);
    final Offset br = Offset(size.width - 1, size.height - 1);
    final Offset bl = Offset(1, size.height - 1);

    edge(tl, tr);
    edge(tr, br);
    edge(br, bl);
    edge(bl, tl);

    Offset mid(Offset a, Offset b) =>
        Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

    final Path p = Path()
      ..moveTo(
        mid(pts.last, pts.first).dx,
        mid(pts.last, pts.first).dy,
      );

    for (var i = 0; i < pts.length; i++) {
      final Offset cur = pts[i];
      final Offset next = pts[(i + 1) % pts.length];
      final Offset m = mid(cur, next);

      p.quadraticBezierTo(cur.dx, cur.dy, m.dx, m.dy);
    }

    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var pass = 0; pass < 2; pass++) {
      final Random rnd = Random(size.width.toInt() + pass * 13);

      final Paint paint = Paint()
        ..color = kInk.withAlpha(pass == 0 ? 210 : 110)
        ..style = PaintingStyle.stroke
        ..strokeWidth = pass == 0 ? 2.0 : 1.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(
        _wobbly(size, rnd, pass == 0 ? 1.6 : 3.0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PaperCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(245),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kInk.withAlpha(28),
            offset: const Offset(3, 4),
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: _SketchBorderPainter(),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SketchButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const SketchButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = kGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kInk, width: 2),
        boxShadow: const [
          BoxShadow(color: kInk, offset: Offset(3, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: ink(21, weight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String titleText;
  final String subtitle;

  const PageHeader({
    super.key,
    required this.titleText,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titleText, style: title(42, color: kGreen)),
        Text(subtitle, style: ink(16, color: kInkSoft)),
      ],
    );
  }
}

class LegendChip extends StatelessWidget {
  final String text;
  final Color color;

  const LegendChip({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(text, style: ink(14)),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final StatusInfo info;

  const StatusPill({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: info.color.withAlpha(35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: info.color, width: 1.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: 16, color: info.color),
          const SizedBox(width: 4),
          Text(
            info.label,
            style: ink(14, weight: FontWeight.w700, color: info.color),
          ),
        ],
      ),
    );
  }
}

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withAlpha(40),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ink(14, color: kInkSoft),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: title(34, color: color)),
                  ),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ink(12, color: kInkSoft),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final Color Function(String)? colorOf;

  const _ChipRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.colorOf,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: ink(16, weight: FontWeight.w700, color: kInkSoft),
          ),
        ),
        for (final o in options)
          ChoiceChip(
            label: Text(o),
            selected: o == selected,
            showCheckmark: false,
            selectedColor: colorOf?.call(o) ?? kGreen,
            backgroundColor: Colors.white,
            side: const BorderSide(color: kInk, width: 1.4),
            labelStyle: ink(
              15,
              color: o == selected ? Colors.white : kInk,
              weight: o == selected ? FontWeight.w700 : null,
            ),
            onSelected: (_) => onSelected(o),
          ),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: kGreenLight,
            shape: BoxShape.circle,
            border: Border.all(color: kInk, width: 2),
          ),
          child: const Icon(Icons.eco_rounded, color: kGreen, size: 26),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nutritrack', style: title(32, color: kGreen)),
            Text('student health detector', style: ink(13, color: kInkSoft)),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// STUDENT HEALTH DATA PAGE
// (student info + parent account + meal plan history)
// ---------------------------------------------------------------------------
class StudentHealthDataPage extends StatefulWidget {
  final Student? before; // Beginning of the School Year record
  final Student? after; // End of the School Year record

  // meal plans given to the student (read-only records)
  final List<MealPlanRecord> history;

  final void Function(
    Student? oldBefore,
    Student? newBefore,
    Student? oldAfter,
    Student? newAfter,
  ) onSave;

  const StudentHealthDataPage({
    super.key,
    required this.before,
    required this.after,
    required this.history,
    required this.onSave,
  });

  @override
  State<StudentHealthDataPage> createState() => _StudentHealthDataPageState();
}

class _StudentHealthDataPageState extends State<StudentHealthDataPage> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final Student _base;

  late final TextEditingController _name;
  late final TextEditingController _allergy;
  late final TextEditingController _medical;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _pass;
  late final TextEditingController _confirm;

  late String grade;
  late bool girl;
  late String household;

  bool _showPass = false;
  bool _showConfirm = false;

  @override
  void initState() {
    super.initState();

    _base = (widget.before ?? widget.after)!;

    _name = TextEditingController(text: _base.name);
    _allergy = TextEditingController(text: _base.allergies.join(', '));
    _medical = TextEditingController(text: _base.medicalStatus);
    _email = TextEditingController(text: _base.parentEmail);
    _phone = TextEditingController(text: _base.parentPhone);
    _pass = TextEditingController(text: _base.parentPassword);
    _confirm = TextEditingController(text: _base.parentPassword);

    grade = _base.grade;
    girl = _base.girl;
    household = _base.household;
  }

  @override
  void dispose() {
    _name.dispose();
    _allergy.dispose();
    _medical.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  // applies the edited info to an existing record (measurements stay as is)
  Student? _apply(Student? s) {
    if (s == null) return null;

    return s.copyWith(
      name: _name.text.trim(),
      grade: grade,
      girl: girl,
      allergies: parseAllergies(_allergy.text),
      medicalStatus: _medical.text.trim(),
      household: household,
      parentEmail: _email.text.trim(),
      parentPassword: _pass.text,
      parentPhone: cleanPhone(_phone.text),
    );
  }

  void _save() {
    if (!_form.currentState!.validate()) {
      return;
    }

    final Student? newBefore = _apply(widget.before);
    final Student? newAfter = _apply(widget.after);

    widget.onSave(widget.before, newBefore, widget.after, newAfter);

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    Navigator.of(context).pop();

    messenger.showSnackBar(
      SnackBar(
        content: Text('Saved health data for ${_name.text.trim()}.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.of(context).size.width >= 900;

    final Widget infoCard = PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_rounded, color: kBlue, size: 28),
              const SizedBox(width: 8),
              Text('Student Info', style: title(28, color: kBlue)),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            style: ink(17),
            decoration: const InputDecoration(labelText: 'Student name'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Please enter a name' : null,
          ),
          const SizedBox(height: 14),
          _ChipRow(
            label: 'Grade',
            options: [
              'Kindergarten',
              for (var i = 1; i <= 6; i++) 'Grade $i',
            ],
            selected: grade,
            onSelected: (v) => setState(() => grade = v),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 74,
                child: Text(
                  'Gender',
                  style: ink(16, weight: FontWeight.w700, color: kInkSoft),
                ),
              ),
              for (final g in const [true, false])
                ChoiceChip(
                  avatar: Icon(
                    g ? Icons.female_rounded : Icons.male_rounded,
                    size: 18,
                    color: g == girl ? Colors.white : kInk,
                  ),
                  label: Text(g ? 'Girl' : 'Boy'),
                  selected: g == girl,
                  showCheckmark: false,
                  selectedColor: g ? kPink : kBlue,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: kInk, width: 1.4),
                  labelStyle: ink(
                    15,
                    color: g == girl ? Colors.white : kInk,
                    weight: g == girl ? FontWeight.w700 : null,
                  ),
                  onSelected: (_) => setState(() => girl = g),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _allergy,
            style: ink(17),
            decoration: const InputDecoration(
              labelText: 'Allergies (optional)',
              hintText: 'e.g. egg, peanuts, shrimp (leave blank if none)',
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _medical,
            style: ink(17),
            decoration: const InputDecoration(
              labelText: 'Medical status (optional)',
              hintText: 'e.g. asthma, diabetes (leave blank if none)',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: household,
            decoration: const InputDecoration(labelText: 'Meal plan is for'),
            items: [
              for (final h in kHouseholdOptions)
                DropdownMenuItem(value: h, child: Text(h)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => household = v);
            },
          ),
        ],
      ),
    );

    final Widget parentCard = PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.family_restroom_rounded, color: kGreen, size: 28),
              const SizedBox(width: 8),
              Text('Parent Account', style: title(28, color: kGreen)),
            ],
          ),
          Text(
            'Account of the student that is managed by the parents.',
            style: ink(14, color: kInkSoft),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            style: ink(17),
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_rounded),
            ),
            validator: validateEmail,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            style: ink(17),
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '09XXXXXXXXX',
              prefixIcon: Icon(Icons.phone_rounded),
            ),
            validator: validatePhone,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _pass,
            style: ink(17),
            obscureText: !_showPass,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPass
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),
            validator: validatePassword,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirm,
            style: ink(17),
            obscureText: !_showConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _showConfirm
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: () => setState(() => _showConfirm = !_showConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Please confirm the password';
              }

              if (v != _pass.text) {
                return 'Passwords do not match';
              }

              return null;
            },
          ),
        ],
      ),
    );

    return Scaffold(
      body: ArtBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const _Brand(),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: double.infinity),
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const PageHeader(
                              titleText: 'Student Health Data',
                              subtitle:
                                  'Edit the student\'s info and parent account. See the meal plans given to the student.',
                            ),
                            const SizedBox(height: 16),
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: infoCard),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        parentCard,
                                        const SizedBox(height: 16),
                                        _MealHistoryCard(
                                          history: widget.history,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              infoCard,
                              const SizedBox(height: 16),
                              parentCard,
                              const SizedBox(height: 16),
                              _MealHistoryCard(history: widget.history),
                            ],
                            const SizedBox(height: 22),
                            Center(
                              child: SketchButton(
                                label: 'Save Changes',
                                icon: Icons.save_rounded,
                                onTap: _save,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MEAL PLAN HISTORY (records only, cannot be edited)
// ---------------------------------------------------------------------------
class _MealHistoryCard extends StatelessWidget {
  final List<MealPlanRecord> history;

  const _MealHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: kOrange, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Meal Plan History',
                  style: title(28, color: kOrange),
                ),
              ),
            ],
          ),
          Text(
            'Meal plans given to the student. These are records only and cannot be edited.',
            style: ink(14, color: kInkSoft),
          ),
          const SizedBox(height: 10),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No meal plan has been given yet. One is saved here when the student\'s result is opened.',
                style: ink(15, color: kInkSoft),
              ),
            )
          else
            for (var i = 0; i < history.length; i++) ...[
              _MealHistoryTile(record: history[i]),
              if (i != history.length - 1)
                Divider(height: 1, color: kInk.withAlpha(40)),
            ],
        ],
      ),
    );
  }
}

class _MealHistoryTile extends StatelessWidget {
  final MealPlanRecord record;

  const _MealHistoryTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final DailyPlan plan = record.plan;
    final StatusInfo st = statusByLabel(record.status);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 10),
        expandedAlignment: Alignment.centerLeft,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(st.icon, color: st.color),
        title: Text(
          fmtDate(record.date),
          style: ink(17, weight: FontWeight.w700),
        ),
        subtitle: Text(
          '${record.period} • ${record.status} • about ${plan.kcal} kcal',
          style: ink(13, color: kInkSoft),
        ),
        children: [
          Text(
            plan.servings == 1
                ? 'Portions for: the kid only'
                : 'Portions for: ${plan.servings} family members (ingredient amounts are for the whole family; kcal is per person)',
            style: ink(14, color: kInkSoft),
          ),
          const SizedBox(height: 8),
          for (final m in plan.meals)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(m.slot.icon, color: m.slot.color, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '${m.slot.name} • ${m.slot.time}',
                        style: ink(
                          15,
                          weight: FontWeight.w700,
                          color: m.slot.color,
                        ),
                      ),
                      const Spacer(),
                      Text('~${m.kcal} kcal', style: ink(13, color: kInkSoft)),
                    ],
                  ),
                  Text(m.dish, style: ink(16, weight: FontWeight.w700)),
                  for (final g in m.ings)
                    Text('• ${g.name} - ${g.amount}', style: ink(14)),
                ],
              ),
            ),
          Row(
            children: [
              const Icon(Icons.directions_run_rounded, color: kOrange, size: 20),
              const SizedBox(width: 6),
              Text(
                'Exercises',
                style: ink(15, weight: FontWeight.w700, color: kOrange),
              ),
            ],
          ),
          for (final e in plan.exercises)
            Text('• ${e.name} (${e.reps})', style: ink(14)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MEASUREMENT HISTORY PAGE
// (opened by tapping the health status; measurements can be edited here)
// ---------------------------------------------------------------------------
class MeasurementHistoryPage extends StatefulWidget {
  final List<Student> records; // all check-ups of the same student
  final void Function(Student oldS, Student newS) onUpdate;

  const MeasurementHistoryPage({
    super.key,
    required this.records,
    required this.onUpdate,
  });

  @override
  State<MeasurementHistoryPage> createState() => _MeasurementHistoryPageState();
}

class _MeasurementHistoryPageState extends State<MeasurementHistoryPage> {
  late List<Student> _records;

  @override
  void initState() {
    super.initState();
    _records = List<Student>.from(widget.records);
  }

  Future<void> _edit(Student s) async {
    final Student? updated = await showDialog<Student>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditMeasurementDialog(record: s),
    );

    if (updated == null || !mounted) return;

    widget.onUpdate(s, updated);

    final int i = _records.indexOf(s);

    setState(() {
      if (i >= 0) _records[i] = updated;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Measurement updated.')),
    );
  }

  Widget _recordCard(Student s) {
    final StatusInfo st = s.status;

    final Color periodColor = colorForPeriod(s.schoolYearPeriod);

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.straighten_rounded, color: periodColor, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.schoolYearPeriod,
                  style: title(26, color: periodColor),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _edit(s),
                icon: const Icon(Icons.edit_rounded, color: kGreen, size: 18),
                label: Text('Edit', style: ink(14, weight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kInk, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          Text(
            'Measured on ${fmtDate(s.measuredOn)}',
            style: ink(14, color: kInkSoft),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatBubble(
                label: 'BMI',
                value: s.bmi.toStringAsFixed(1),
                color: st.color,
              ),
              _StatBubble(
                label: 'Z-score',
                value: s.z.toStringAsFixed(2),
                color: st.color,
              ),
              StatusPill(info: st),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Age ${s.ageY} yrs • Height ${s.heightCm.toStringAsFixed(0)} cm • Weight ${s.weightKg.toStringAsFixed(1)} kg',
            style: ink(16),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Student> sorted = List<Student>.from(_records)
      ..sort((a, b) => a.measuredOn.compareTo(b.measuredOn));

    final Student info = sorted.first;

    return Scaffold(
      body: ArtBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const _Brand(),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: double.infinity),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const PageHeader(
                            titleText: 'Measurement History',
                            subtitle:
                                'All check-ups of this student. Tap Edit to change a measurement.',
                          ),
                          const SizedBox(height: 16),
                          PaperCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(info.name, style: title(38)),
                                Text(
                                  '${info.grade} • ${info.girl ? 'Girl' : 'Boy'}'
                                  '${info.section.isEmpty ? '' : ' • ${info.section}'}'
                                  '${info.lrn.isEmpty ? '' : ' • LRN ${info.lrn}'}',
                                  style: ink(15, color: kInkSoft),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, c) {
                              final int cols = c.maxWidth >= 800 ? 2 : 1;

                              const double gap = 16;

                              final double w =
                                  (c.maxWidth - gap * (cols - 1)) / cols;

                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: [
                                  for (final s in sorted)
                                    SizedBox(width: w, child: _recordCard(s)),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// edit one measurement (date, age, height, weight)
class _EditMeasurementDialog extends StatefulWidget {
  final Student record;

  const _EditMeasurementDialog({required this.record});

  @override
  State<_EditMeasurementDialog> createState() => _EditMeasurementDialogState();
}

class _EditMeasurementDialogState extends State<_EditMeasurementDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final TextEditingController _ageY;
  late final TextEditingController _dateC;
  late final TextEditingController _h;
  late final TextEditingController _w;

  late DateTime _date;

  @override
  void initState() {
    super.initState();

    final Student r = widget.record;

    _date = r.measuredOn;
    _ageY = TextEditingController(text: r.ageY.toString());
    _dateC = TextEditingController(text: fmtDate(r.measuredOn));
    _h = TextEditingController(text: fmtNum(r.heightCm));
    _w = TextEditingController(text: fmtNum(r.weightKg));
  }

  @override
  void dispose() {
    _ageY.dispose();
    _dateC.dispose();
    _h.dispose();
    _w.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (d != null) {
      setState(() {
        _date = d;
        _dateC.text = fmtDate(d);
      });
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;

    Navigator.of(context).pop(
      widget.record.copyWith(
        ageY: int.parse(_ageY.text.trim()),
        heightCm: double.parse(_h.text.trim()),
        weightKg: double.parse(_w.text.trim()),
        measuredOn: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color color = colorForPeriod(widget.record.schoolYearPeriod);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: PaperCard(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Measurement', style: title(32, color: kGreen)),
                  Text(
                    widget.record.schoolYearPeriod,
                    style: ink(15, weight: FontWeight.w700, color: color),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ageY,
                          style: ink(17),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Age',
                            suffixText: 'yrs',
                          ),
                          validator: (v) {
                            final int? n = int.tryParse(v ?? '');

                            return (n == null || n < 5 || n > 13)
                                ? '5 to 13 only'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _dateC,
                          readOnly: true,
                          style: ink(17),
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            suffixIcon: Icon(Icons.calendar_month_rounded),
                          ),
                          onTap: _pickDate,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Pick a date'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _h,
                          style: ink(17),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Height',
                            suffixText: 'cm',
                          ),
                          validator: (v) {
                            final double? n = double.tryParse(v ?? '');

                            return (n == null || n < 80 || n > 200)
                                ? '80 to 200 cm'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _w,
                          style: ink(17),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Weight',
                            suffixText: 'kg',
                          ),
                          validator: (v) {
                            final double? n = double.tryParse(v ?? '');

                            return (n == null || n < 8 || n > 120)
                                ? '8 to 120 kg'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kInk, width: 1.4),
                        ),
                        child: Text('Cancel', style: ink(15)),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(backgroundColor: kGreen),
                        child: Text(
                          'Save',
                          style: ink(15, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PAGE 1: SUMMARY DASHBOARD
// ---------------------------------------------------------------------------
class PieBlock extends StatelessWidget {
  final Map<String, int> data;
  final Color Function(String) colorOf;

  const PieBlock({super.key, required this.data, required this.colorOf});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 34,
              sections: [
                for (final e in data.entries)
                  PieChartSectionData(
                    value: e.value.toDouble(),
                    color: colorOf(e.key),
                    radius: 62,
                    borderSide: const BorderSide(color: kInk, width: 1.6),
                    title: '${e.value}',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final e in data.entries)
              LegendChip(
                text: '${e.key} (${e.value})',
                color: colorOf(e.key),
              ),
          ],
        ),
      ],
    );
  }
}

class BmiBarChart extends StatelessWidget {
  final List<Student> students;

  const BmiBarChart({super.key, required this.students});

  @override
  Widget build(BuildContext context) {
    final double maxBmi = students.map((s) => s.bmi).reduce(max);

    final double maxY = maxBmi * 1.2;

    return Column(
      children: [
        SizedBox(
          height: 280,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: kInk.withAlpha(30),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              barGroups: [
                for (var i = 0; i < students.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: students[i].bmi,
                        width: 24,
                        color: students[i].status.color,
                        borderSide: const BorderSide(color: kInk, width: 1.4),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ],
                  ),
              ],
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (v, meta) => v % 5 == 0
                        ? Text(v.toInt().toString(), style: ink(13))
                        : const SizedBox.shrink(),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final int i = value.toInt();

                      if (i < 0 || i >= students.length) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          shortName(students[i].firstName),
                          style: ink(12),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final s in kStatusList)
              LegendChip(text: s.label, color: s.color),
          ],
        ),
      ],
    );
  }
}

class ChartCard extends StatelessWidget {
  final String titleText;
  final String subtitle;
  final Widget child;

  const ChartCard({
    super.key,
    required this.titleText,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titleText, style: title(28, color: kGreen)),
          Text(subtitle, style: ink(14, color: kInkSoft)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// grouped bars: BMI at beginning vs end of the school year
class ProgressBarChart extends StatelessWidget {
  final List<ProgressPair> pairs;

  const ProgressBarChart({super.key, required this.pairs});

  @override
  Widget build(BuildContext context) {
    final double maxBmi =
        pairs.expand((p) => [p.before.bmi, p.after.bmi]).reduce(max);

    final double maxY = maxBmi * 1.2;

    BarChartRodData rod(double v, Color color) => BarChartRodData(
          toY: v,
          width: 18,
          color: color,
          borderSide: const BorderSide(color: kInk, width: 1.4),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        );

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: kInk.withAlpha(30),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              barGroups: [
                for (var i = 0; i < pairs.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 4,
                    barRods: [
                      rod(pairs[i].before.bmi, kBlue),
                      rod(pairs[i].after.bmi, kOrange),
                    ],
                  ),
              ],
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (v, meta) => v % 5 == 0
                        ? Text(v.toInt().toString(), style: ink(13))
                        : const SizedBox.shrink(),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final int i = value.toInt();

                      if (i < 0 || i >= pairs.length) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          shortName(pairs[i].after.firstName),
                          style: ink(12),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            LegendChip(text: kBosy, color: kBlue),
            LegendChip(text: kEosy, color: kOrange),
          ],
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final ProgressPair pair;

  const _ProgressRow({required this.pair});

  @override
  Widget build(BuildContext context) {
    final Student b = pair.before;
    final Student a = pair.after;

    final double d = zGap(a.z) - zGap(b.z);

    final String verdict;
    final Color color;
    final IconData icon;

    if (d < -0.05) {
      verdict = 'Improved';
      color = kGreen;
      icon = Icons.trending_up_rounded;
    } else if (d > 0.05) {
      verdict = 'Needs attention';
      color = kRed;
      icon = Icons.trending_down_rounded;
    } else if (a.status.label == 'Normal') {
      verdict = 'Stayed healthy';
      color = kGreen;
      icon = Icons.check_circle_rounded;
    } else {
      verdict = 'No big change';
      color = kOrange;
      icon = Icons.trending_flat_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(a.name, style: ink(19, weight: FontWeight.w700)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color, width: 1.6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 4),
                    Text(
                      verdict,
                      style: ink(14, weight: FontWeight.w700, color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(info: b.status),
              const Icon(Icons.arrow_forward_rounded, size: 18, color: kInkSoft),
              StatusPill(info: a.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'BMI ${b.bmi.toStringAsFixed(1)} → ${a.bmi.toStringAsFixed(1)} (${signed(a.bmi - b.bmi, 1)})',
            style: ink(15),
          ),
          Text(
            'Weight ${b.weightKg.toStringAsFixed(1)} → ${a.weightKg.toStringAsFixed(1)} kg (${signed(a.weightKg - b.weightKg, 1)})',
            style: ink(15),
          ),
          Text(
            'Height ${b.heightCm.toStringAsFixed(0)} → ${a.heightCm.toStringAsFixed(0)} cm (${signed(a.heightCm - b.heightCm, 0)})',
            style: ink(15),
          ),
          Text(
            'Z-score ${b.z.toStringAsFixed(2)} → ${a.z.toStringAsFixed(2)}',
            style: ink(14, color: kInkSoft),
          ),
        ],
      ),
    );
  }
}

class SummaryPage extends StatefulWidget {
  final List<Student> students;

  const SummaryPage({super.key, required this.students});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  String? sy; // school year, e.g. 2025-2026
  String period = kWhole;

  // SEARCH (student name or LRN) - filters only the individual charts
  final TextEditingController _searchC = TextEditingController();
  String query = '';

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // School years that have check-ups (newest first) and the chosen one.
    final List<String> years = schoolYearsOf(widget.students);
    final String curSy = (sy != null && years.contains(sy)) ? sy! : years.first;

    // school check-ups of the chosen school year (home checks are not counted)
    final List<Student> inYear = widget.students
        .where((s) => s.measured && s.schoolYearPeriod != kHome && s.schoolYear == curSy)
        .toList();

    // One record per student: Beginning, End, or the whole school year.
    final List<Student> students = latestForSummary(inYear, curSy, period);

    // Students with BOTH check-ups in this school year (Student Progress).
    final List<ProgressPair> pairs = buildPairs(inYear);

    final int distinctNames =
        inYear.map((s) => s.name.trim().toLowerCase()).toSet().length;

    final int oneCheckup = distinctNames - pairs.length;

    final String periodShort = period == kWhole
        ? 'Whole year'
        : (period == kBosy ? 'Beginning' : 'End');

    final Widget periodPicker = PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey('sy$curSy'),
            isExpanded: true,
            initialValue: curSy,
            decoration: const InputDecoration(labelText: 'School year'),
            items: [
              for (final y in years)
                DropdownMenuItem(value: y, child: Text('SY $y')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => sy = v);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey('period$period'),
            isExpanded: true,
            initialValue: period,
            decoration: const InputDecoration(labelText: 'Show summary for'),
            items: const [
              DropdownMenuItem(value: kWhole, child: Text(kWhole)),
              DropdownMenuItem(value: kBosy, child: Text(kBosy)),
              DropdownMenuItem(value: kEosy, child: Text(kEosy)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => period = v);
            },
          ),
          const SizedBox(height: 8),
          Text(
            period == kWhole
                ? 'Whole School Year shows every student of SY $curSy, using their newest check-up of the school year.'
                : 'Shows every student saved for $period of SY $curSy.',
            style: ink(13, color: kInkSoft),
          ),
          Text(
            'Student Progress below compares students that have both check-ups in the same school year.',
            style: ink(13, color: kInkSoft),
          ),
          if (oneCheckup > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$oneCheckup student(s) have only one check-up in SY $curSy (they will appear in Student Progress once both are saved).',
                style: ink(13, weight: FontWeight.w700, color: kOrange),
              ),
            ),
        ],
      ),
    );

    if (students.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              titleText: 'Summary Dashboard',
              subtitle: 'How the class is doing, at a glance.',
            ),
            const SizedBox(height: 16),
            periodPicker,
            const SizedBox(height: 24),
            Center(
              child: Text(
                'No student records for this period yet.',
                style: ink(20, color: kInkSoft),
              ),
            ),
          ],
        ),
      );
    }

    final int total = students.length;

    final int normal =
        students.where((s) => s.status.label == 'Normal').length;

    final int attention = total - normal;

    final Map<String, int> counts = {};

    for (final st in kStatusList) {
      final int n = students.where((s) => s.status.label == st.label).length;

      if (n > 0) {
        counts[st.label] = n;
      }
    }

    // students / pairs shown in the individual charts (search filter)
    final List<Student> chartStudents =
        students.where((s) => studentMatchesQuery(s, query)).toList();

    final List<ProgressPair> chartPairs = pairs
        .where(
          (p) =>
              studentMatchesQuery(p.before, query) ||
              studentMatchesQuery(p.after, query),
        )
        .toList();

    final bool searching = query.trim().isNotEmpty;

    final List<Widget> kpis = [
      KpiCard(
        label: 'Total Students',
        value: '$total',
        sub: 'SY $curSy • $periodShort',
        icon: Icons.groups_rounded,
        color: kBlue,
      ),
      // one card for every weight status
      for (final st in kStatusList)
        KpiCard(
          label: st.label,
          value: '${counts[st.label] ?? 0}',
          sub:
              '${((counts[st.label] ?? 0) / total * 100).toStringAsFixed(0)}% of students',
          icon: st.icon,
          color: st.color,
        ),
      KpiCard(
        label: 'Needs Attention',
        value: '$attention',
        sub: 'not in normal range',
        icon: Icons.flag_rounded,
        color: kYellow,
      ),
    ];

    final Widget searchCard = PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchC,
            style: ink(18),
            decoration: InputDecoration(
              labelText: 'Search student (name or LRN)',
              hintText: 'Type a name or LRN to see the individual charts',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchC.clear();
                        setState(() => query = '');
                      },
                    ),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 8),
          Text(
            searching
                ? 'Showing ${chartStudents.length} of $total students in BMI per Student and ${chartPairs.length} of ${pairs.length} in Student Progress.'
                : 'Search to see the charts of a specific student. The summary above stays the same.',
            style: ink(13, color: kInkSoft),
          ),
        ],
      ),
    );

    final Widget pieCard = ChartCard(
      titleText: 'Nutrition Status',
      subtitle: 'Number of students in each group',
      child: PieBlock(
        data: counts,
        colorOf: (k) => statusByLabel(k).color,
      ),
    );

    final Widget bmiCard = ChartCard(
      titleText: 'BMI per Student',
      subtitle: 'Each bar is a student, colored by status',
      child: chartStudents.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No student matches your search.',
                style: ink(16, color: kInkSoft),
              ),
            )
          : BmiBarChart(students: chartStudents),
    );

    return LayoutBuilder(
      builder: (context, c) {
        // usable width (page padding is 20 on each side)
        final double avail = c.maxWidth - 40;

        final bool wide = avail >= 900;

        final int cols = avail >= 1250 ? 7 : (avail >= 720 ? 4 : 2);

        const double gap = 12;

        final double kw = (avail - gap * (cols - 1)) / cols;

        final Widget progressRows = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < chartPairs.length; i++) ...[
              _ProgressRow(pair: chartPairs[i]),
              if (i != chartPairs.length - 1)
                Divider(height: 1, color: kInk.withAlpha(40)),
            ],
          ],
        );

        final Widget progressCard = ChartCard(
          titleText: 'Student Progress',
          subtitle: 'Beginning vs End of the School Year • SY $curSy',
          child: chartPairs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    searching
                        ? 'No student with both check-ups matches your search.'
                        : 'No student has both a Beginning and an End check-up yet.',
                    style: ink(16, color: kInkSoft),
                  ),
                )
              : wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: ProgressBarChart(pairs: chartPairs),
                        ),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: progressRows),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProgressBarChart(pairs: chartPairs),
                        const SizedBox(height: 10),
                        progressRows,
                      ],
                    ),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                titleText: 'Summary Dashboard',
                subtitle: 'How the class is doing, at a glance.',
              ),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: periodPicker),
                    const SizedBox(width: 16),
                    Expanded(child: searchCard),
                  ],
                )
              else ...[
                periodPicker,
                const SizedBox(height: 16),
                searchCard,
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final k in kpis)
                    // taller card = no more "bottom overflowed" error
                    SizedBox(width: kw, height: 124, child: k),
                ],
              ),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: pieCard),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: bmiCard),
                  ],
                )
              else ...[
                pieCard,
                const SizedBox(height: 16),
                bmiCard,
              ],
              const SizedBox(height: 16),
              progressCard,
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// RESULT PAGE
// ---------------------------------------------------------------------------
class ZScaleBar extends StatelessWidget {
  final double z;

  const ZScaleBar({super.key, required this.z});

  @override
  Widget build(BuildContext context) {
    final double frac = (z.clamp(-4.0, 4.0).toDouble() + 4) / 8;

    return LayoutBuilder(
      builder: (context, c) {
        final double w = c.maxWidth;

        Widget seg(int flex, Color color) => Expanded(
              flex: flex,
              child: Container(height: 16, color: color.withAlpha(170)),
            );

        Widget label(String t, double f) => Positioned(
              left: f * w - 14,
              top: 46,
              width: 28,
              child: Text(
                t,
                textAlign: TextAlign.center,
                style: ink(13, color: kInkSoft),
              ),
            );

        return SizedBox(
          height: 68,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 26,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kInk, width: 1.8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      seg(1, kPurple),
                      seg(1, kBlue),
                      seg(3, kGreen),
                      seg(1, kOrange),
                      seg(2, kRed),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: frac * w - 15,
                top: 0,
                child: const Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 30,
                  color: kInk,
                ),
              ),
              label('-3', 1 / 8),
              label('-2', 2 / 8),
              label('+1', 5 / 8),
              label('+2', 6 / 8),
            ],
          ),
        );
      },
    );
  }
}

class _StatBubble extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBubble({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(label, style: ink(14, color: kInkSoft)),
          Text(value, style: title(40, color: color)),
        ],
      ),
    );
  }
}

class ResultPage extends StatelessWidget {
  final Student student;

  const ResultPage({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final Student s = student;
    final StatusInfo st = s.status;
    final DailyPlan plan = generatePlan(s);

    final bool wide = MediaQuery.of(context).size.width >= 900;

    final double hm = s.heightCm / 100;

    final double lo = bmiAtZ(s.lms, -2) * hm * hm;

    final double hi = bmiAtZ(s.lms, 1) * hm * hm;

    final Widget summary = PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.name, style: title(42)),
          Text(
            '${s.grade} • ${s.ageY} yrs • ${s.girl ? 'Girl' : 'Boy'} • ${s.heightCm.toStringAsFixed(0)} cm • ${s.weightKg.toStringAsFixed(1)} kg',
            style: ink(15, color: kInkSoft),
          ),
          const SizedBox(height: 6),
          Text(
            '${s.schoolYearPeriod} • ${fmtDate(s.measuredOn)}',
            style: ink(
              14,
              weight: FontWeight.w700,
              color: colorForPeriod(s.schoolYearPeriod),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatBubble(
                label: 'BMI',
                value: s.bmi.toStringAsFixed(1),
                color: st.color,
              ),
              _StatBubble(
                label: 'Z-score',
                value: s.z.toStringAsFixed(2),
                color: st.color,
              ),
              Transform.rotate(
                angle: -0.05,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: st.color, width: 3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(st.icon, color: st.color, size: 30),
                      const SizedBox(width: 8),
                      Text(st.label, style: title(34, color: st.color)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ZScaleBar(z: s.z),
          const SizedBox(height: 6),
          Text(
            'Healthy weight for ${s.heightCm.toStringAsFixed(0)} cm at this age: ${lo.toStringAsFixed(1)} – ${hi.toStringAsFixed(1)} kg',
            style: ink(16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: st.color.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_note_rounded, color: st.color),
                const SizedBox(width: 10),
                Expanded(child: Text(st.advice, style: ink(16))),
              ],
            ),
          ),
        ],
      ),
    );

    final Widget planHeader = PaperCard(
      child: Row(
        children: [
          const Icon(Icons.restaurant_menu_rounded, color: kGreen, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Nutrition Plan',
                  style: title(32, color: kGreen),
                ),
                Text(
                  '${todayText()} • about ${plan.kcal} kcal • drink 6–8 glasses of water',
                  style: ink(14, color: kInkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // servings / allergy / medical note
    final Widget dietNote = PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: kBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan.servings == 1
                      ? 'Portions for: the kid only'
                      : 'Portions for: ${plan.servings} family members (ingredient amounts are for the whole family; kcal is per person)',
                  style: ink(15),
                ),
              ),
            ],
          ),
          if (s.allergies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.block_rounded, color: kRed),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Avoiding: ${s.allergies.join(', ')}',
                    style: ink(15, weight: FontWeight.w700, color: kRed),
                  ),
                ),
              ],
            ),
          ],
          if (s.medicalStatus.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.medical_services_rounded, color: kPurple),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Medical status: ${s.medicalStatus}. Please check this meal plan with a doctor or nutritionist.',
                    style: ink(15),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    final Widget meals = LayoutBuilder(
      builder: (context, c) {
        final int cols = c.maxWidth >= 1300 ? 4 : (c.maxWidth >= 700 ? 2 : 1);

        const double gap = 14;

        final double w = (c.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final m in plan.meals)
              SizedBox(width: w, child: _MealCard(meal: m)),
          ],
        );
      },
    );

    final Widget exercise = PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_run_rounded, color: kOrange, size: 30),
              const SizedBox(width: 10),
              Text('Exercise Time!', style: title(32, color: kOrange)),
            ],
          ),
          Text(
            'Do these 3 simple moves today.',
            style: ink(14, color: kInkSoft),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < plan.exercises.length; i++)
            _ExerciseRow(n: i + 1, ex: plan.exercises[i]),
        ],
      ),
    );

    final Widget note = PaperCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: kInkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nutritrack is a screening guide, not a medical diagnosis. '
              'Portions are estimates. Please consult a doctor or nutritionist for allergies or health conditions.',
              style: ink(14, color: kInkSoft),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: ArtBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const _Brand(),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: double.infinity),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: summary),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    children: [
                                      planHeader,
                                      const SizedBox(height: 14),
                                      dietNote,
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            summary,
                            const SizedBox(height: 16),
                            planHeader,
                            const SizedBox(height: 14),
                            dietNote,
                          ],
                          const SizedBox(height: 16),
                          meals,
                          const SizedBox(height: 16),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: exercise),
                                const SizedBox(width: 16),
                                Expanded(child: note),
                              ],
                            )
                          else ...[
                            exercise,
                            const SizedBox(height: 16),
                            note,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  final PlannedMeal meal;
  final bool selected;
  final VoidCallback? onTap;

  const _MealCard({required this.meal, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color color = meal.slot.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: PaperCard(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withAlpha(40),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(meal.slot.icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meal.slot.name, style: title(30, color: color)),
                    Text(meal.slot.time, style: ink(13, color: kInkSoft)),
                  ],
                ),
              ),
              if (selected && onTap != null)
                const Icon(Icons.check_circle_rounded, color: kGreen, size: 22),
              if (onTap != null) const SizedBox(width: 6),
              LegendChip(text: '~${meal.kcal} kcal', color: color),
            ],
          ),
          if (selected && onTap != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Selected for changes', style: ink(12, color: kGreen, weight: FontWeight.w700)),
            ),
          const SizedBox(height: 8),
          Text(meal.dish, style: ink(19, weight: FontWeight.w700)),
          Text(
            'PHP ${meal.cost.toStringAsFixed(0)}',
            style: ink(14, color: kInkSoft, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text('Ingredients', style: ink(14, color: kInkSoft)),
          const SizedBox(height: 4),
          for (final g in meal.ings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    g.have ? Icons.home_rounded : Icons.eco_rounded,
                    size: 15,
                    color: g.have ? kGreen : color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g.have ? '${g.name} (have at home)' : g.name,
                      style: ink(16, color: g.have ? kGreen : null),
                    ),
                  ),
                  Text(g.amount, style: ink(16, weight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final int n;
  final Exercise ex;

  const _ExerciseRow({required this.n, required this.ex});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kOrange.withAlpha(40),
              shape: BoxShape.circle,
              border: Border.all(color: kOrange, width: 2),
            ),
            child: Text('$n', style: title(28, color: kOrange)),
          ),
          const SizedBox(width: 12),
          Icon(ex.icon, color: kInkSoft, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ex.name, style: ink(19, weight: FontWeight.w700)),
                Text(ex.tip, style: ink(14, color: kInkSoft)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kYellow.withAlpha(60),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kInk, width: 1.6),
            ),
            child: Text(ex.reps, style: title(26)),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// REUSABLE WIDGETS
// ---------------------------------------------------------------------------
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = kBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(40),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.6),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: ink(13, color: kInkSoft)),
              Text(
                value.trim().isEmpty ? '—' : value,
                style: ink(17, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// two columns on wide cards, one column on narrow ones
Widget infoGrid(List<Widget> rows) {
  return LayoutBuilder(
    builder: (context, c) {
      const double gap = 14;

      final int cols = c.maxWidth >= 520 ? 2 : 1;
      final double w = (c.maxWidth - gap * (cols - 1)) / cols;

      return Wrap(
        spacing: gap,
        runSpacing: 14,
        children: [for (final r in rows) SizedBox(width: w, child: r)],
      );
    },
  );
}

// read-only field (email / password cannot be changed)
class LockedField extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool secret;

  const LockedField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.secret = false,
  });

  @override
  State<LockedField> createState() => _LockedFieldState();
}

class _LockedFieldState extends State<LockedField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    final String shown = widget.secret && !_show
        ? '•' * max(widget.value.length, 6)
        : widget.value;

    return InputDecorator(
      isEmpty: shown.isEmpty,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.secret)
              IconButton(
                tooltip: _show ? 'Hide' : 'Show',
                icon: Icon(
                  _show
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: () => setState(() => _show = !_show),
              ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.lock_rounded, color: kInkSoft, size: 20),
            ),
          ],
        ),
      ),
      child: Text(shown, style: ink(18)),
    );
  }
}

class LockNote extends StatelessWidget {
  final String text;

  const LockNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kYellow.withAlpha(50),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_rounded, color: kInkSoft, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: ink(14))),
        ],
      ),
    );
  }
}

// back button + brand (top of pages opened on top of the shell)
class BackBar extends StatelessWidget {
  const BackBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const _Brand(),
        ],
      ),
    );
  }
}

// BMI of one student over time (line chart)
class BmiTrendChart extends StatelessWidget {
  final List<Student> records;

  const BmiTrendChart({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final List<Student> r = List<Student>.from(records)
      ..sort((a, b) => a.measuredOn.compareTo(b.measuredOn));

    final double minBmi = r.map((s) => s.bmi).reduce(min);
    final double maxBmi = r.map((s) => s.bmi).reduce(max);

    final double minY = max(0.0, (minBmi - 2).floorToDouble());
    final double maxY = (maxBmi + 2).ceilToDouble();

    return Column(
      children: [
        SizedBox(
          height: 230,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              minX: -0.4,
              maxX: r.length - 1 + 0.4,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: kInk.withAlpha(30),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: 2,
                    getTitlesWidget: (v, meta) =>
                        Text(v.toStringAsFixed(0), style: ink(13)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final int i = value.round();

                      if ((value - i).abs() > 0.01 ||
                          i < 0 ||
                          i >= r.length) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          shortDate(r[i].measuredOn),
                          style: ink(12),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < r.length; i++)
                      FlSpot(i.toDouble(), r[i].bmi),
                  ],
                  isCurved: false,
                  color: kGreen,
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'BMI at every check-up (school and home).',
          style: ink(13, color: kInkSoft),
        ),
      ],
    );
  }
}

// BMI + z-score + status of one measurement
class MeasurePreviewCard extends StatelessWidget {
  final Student student;
  final String heading;
  final String? subtitle;

  const MeasurePreviewCard({
    super.key,
    required this.student,
    this.heading = 'Result',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final Student s = student;
    final StatusInfo st = s.status;

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: title(30, color: kGreen)),
          if (subtitle != null)
            Text(subtitle!, style: ink(14, color: kInkSoft)),
          const SizedBox(height: 4),
          Text(
            '${s.girl ? 'Girl' : 'Boy'} • ${s.ageY} yrs • '
            '${s.heightCm.toStringAsFixed(0)} cm • ${s.weightKg.toStringAsFixed(1)} kg',
            style: ink(15, color: kInkSoft),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatBubble(
                label: 'BMI',
                value: s.bmi.toStringAsFixed(1),
                color: st.color,
              ),
              _StatBubble(
                label: 'Z-score',
                value: s.z.toStringAsFixed(2),
                color: st.color,
              ),
              Transform.rotate(
                angle: -0.05,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: st.color, width: 3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(st.icon, color: st.color, size: 26),
                      const SizedBox(width: 6),
                      Text(st.label, style: title(30, color: st.color)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ZScaleBar(z: s.z),
          const SizedBox(height: 6),
          Text(
            healthyRangeText(s),
            style: ink(16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: st.color.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_note_rounded, color: st.color),
                const SizedBox(width: 10),
                Expanded(child: Text(st.advice, style: ink(16))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// one saved measurement (school check-up or home check)
class MeasurementRecordCard extends StatelessWidget {
  final Student record;
  final VoidCallback? onEdit; // null = read only
  final VoidCallback? onDelete; // only for the parent's home checks

  const MeasurementRecordCard({
    super.key,
    required this.record,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final Student s = record;
    final StatusInfo st = s.status;
    final Color pc = colorForPeriod(s.schoolYearPeriod);

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                s.schoolYearPeriod == kHome
                    ? Icons.home_rounded
                    : Icons.straighten_rounded,
                color: pc,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.schoolYearPeriod,
                  style: title(24, color: pc),
                ),
              ),
              if (onEdit != null)
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, color: kGreen, size: 18),
                  label: Text('Edit', style: ink(14, weight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kInk, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete this home check',
                  icon: const Icon(Icons.delete_rounded, color: kRed),
                  onPressed: onDelete,
                ),
            ],
          ),
          Text(
            'Measured on ${fmtDate(s.measuredOn)}',
            style: ink(14, color: kInkSoft),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatBubble(
                label: 'BMI',
                value: s.bmi.toStringAsFixed(1),
                color: st.color,
              ),
              _StatBubble(
                label: 'Z-score',
                value: s.z.toStringAsFixed(2),
                color: st.color,
              ),
              StatusPill(info: st),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Age ${s.ageY} yrs • ${s.girl ? 'Girl' : 'Boy'} • '
            'Height ${s.heightCm.toStringAsFixed(0)} cm • '
            'Weight ${s.weightKg.toStringAsFixed(1)} kg',
            style: ink(16),
          ),
        ],
      ),
    );
  }
}

// a full day plan: header, notes, 4 meals and 3 exercises
class PlanBlock extends StatelessWidget {
  final DailyPlan plan;
  final List<String> allergies;
  final List<String> medicalNotes;
  final Set<String> selectedMealSlots;
  final ValueChanged<String>? onMealTap;

  const PlanBlock({
    super.key,
    required this.plan,
    this.allergies = const [],
    this.medicalNotes = const [],
    this.selectedMealSlots = const {},
    this.onMealTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget header = PaperCard(
      child: Row(
        children: [
          const Icon(Icons.restaurant_menu_rounded, color: kGreen, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today\'s Nutrition Plan', style: title(30, color: kGreen)),
                Text(
                  '${todayText()} • about ${plan.kcal} kcal per person • drink 6–8 glasses of water',
                  style: ink(14, color: kInkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final Widget notes = PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.cost != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.payments_rounded, color: kGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Estimated cost to buy today: PHP ${plan.cost!.toStringAsFixed(0)}',
                    style: ink(15, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (plan.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 34),
                child: Text(plan.note!, style: ink(14, color: kInkSoft)),
              ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: kBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan.servings == 1
                      ? 'Portions for: the kid only'
                      : 'Portions for: ${plan.servings} family members (ingredient amounts are for the whole family; kcal is per person)',
                  style: ink(15),
                ),
              ),
            ],
          ),
          if (allergies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.block_rounded, color: kRed),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Avoiding: ${allergies.join(', ')}',
                    style: ink(15, weight: FontWeight.w700, color: kRed),
                  ),
                ),
              ],
            ),
          ],
          for (final m in medicalNotes) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.medical_services_rounded, color: kPurple),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$m Please check this meal plan with a doctor or nutritionist.',
                    style: ink(15),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    final Widget meals = LayoutBuilder(
      builder: (context, c) {
        final int cols = c.maxWidth >= 1100 ? 4 : (c.maxWidth >= 640 ? 2 : 1);

        const double gap = 14;

        final double w = (c.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final m in plan.meals)
              SizedBox(
                width: w,
                child: _MealCard(
                  meal: m,
                  selected: selectedMealSlots.contains(m.slot.name),
                  onTap: onMealTap == null ? null : () => onMealTap!(m.slot.name),
                ),
              ),
          ],
        );
      },
    );

    final Widget exercise = PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_run_rounded, color: kOrange, size: 30),
              const SizedBox(width: 10),
              Text('Exercise Time!', style: title(30, color: kOrange)),
            ],
          ),
          Text(
            'Do these 3 simple moves today.',
            style: ink(14, color: kInkSoft),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < plan.exercises.length; i++)
            _ExerciseRow(n: i + 1, ex: plan.exercises[i]),
        ],
      ),
    );

    final Widget disclaimer = PaperCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: kInkSoft),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nutritrack is a screening guide, not a medical diagnosis. '
              'Portions are estimates. Please consult a doctor or nutritionist for allergies or health conditions.',
              style: ink(14, color: kInkSoft),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 14),
        notes,
        const SizedBox(height: 14),
        meals,
        const SizedBox(height: 14),
        exercise,
        const SizedBox(height: 14),
        disclaimer,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// MEASUREMENT PAGE for TEACHER / SCHOOL NURSE / ADMIN
// Flow:  search bar  ->  "See student records" (hidden until clicked)
//        ->  Measure button  ->  the measurement form appears below.
// Takes the nutritional status (BMI + z-score) and saves it to the
// student's account (the account managed by the parents).
// ---------------------------------------------------------------------------
class StaffMeasurementPage extends StatefulWidget {
  final NutriStore store;
  final String takenBy; // "Teacher", "School Nurse", "Admin"
  final String actorName;
  final String actorEmail;

  const StaffMeasurementPage({
    super.key,
    required this.store,
    required this.takenBy,
    this.actorName = '',
    this.actorEmail = '',
  });

  @override
  State<StaffMeasurementPage> createState() => _StaffMeasurementPageState();
}

class _StaffMeasurementPageState extends State<StaffMeasurementPage> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final GlobalKey _formAnchor = GlobalKey();

  final TextEditingController _searchC = TextEditingController();
  final TextEditingController _age = TextEditingController();
  final TextEditingController _h = TextEditingController();
  final TextEditingController _w = TextEditingController();
  final TextEditingController _dateC = TextEditingController();

  String query = '';
  bool _listOpen = false; // the student list is hidden until it is opened
  String? _picked; // student name (null = no form yet)
  String period = kBosy;
  DateTime _date = DateTime.now();

  final List<Student> _recent = [];
  Student? _savedResult; // last confirmed measurement shown on this dashboard

  @override
  void initState() {
    super.initState();
    _dateC.text = fmtDate(_date);
  }

  @override
  void dispose() {
    _searchC.dispose();
    _age.dispose();
    _h.dispose();
    _w.dispose();
    _dateC.dispose();
    super.dispose();
  }

  // "Measure" button of a student: hides the list and shows the form below
  void _pick(Student s) {
    setState(() {
      _picked = s.name;
      _listOpen = false;
      _age.text = s.ageY.toString();
      _h.clear();
      _w.clear();
      _savedResult = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? c = _formAnchor.currentContext;

      if (c != null) {
        Scrollable.ensureVisible(
          c,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearPick() {
    setState(() {
      _picked = null;
      _h.clear();
      _w.clear();
      _savedResult = null;
    });
  }

  Future<void> _pickDate() async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (d != null) {
      setState(() {
        _date = d;
        _dateC.text = fmtDate(d);
        _savedResult = null;
      });
    }
  }

  Student? _preview(Student base) {
    final int? a = int.tryParse(_age.text.trim());
    final double? h = double.tryParse(_h.text.trim());
    final double? w = double.tryParse(_w.text.trim());

    if (a == null || h == null || w == null) return null;

    if (a < 5 || a > 13 || h < 80 || h > 200 || w < 8 || w > 120) return null;

    return base.copyWith(
      ageY: a,
      ageM: 0,
      heightCm: h,
      weightKg: w,
      schoolYearPeriod: period,
      measuredOn: _date,
    );
  }

  Future<void> _save(Student base) async {
    if (!_form.currentState!.validate()) {
      showToast(context, 'Please fix the fields marked in red first.',
          color: kRed);
      return;
    }

    final String sy = schoolYearOf(_date);

    // Prevent a duplicate BOSY/EOSY record for the same student and school year.
    final bool duplicate = widget.store.students.any(
      (x) =>
          NutriStore.keyOf(x.name) == NutriStore.keyOf(base.name) &&
          x.schoolYearPeriod == period &&
          x.schoolYear == sy,
    );

    if (duplicate) {
      showToast(
        context,
        '${base.name} already has a "$period" record in SY $sy. '
        'Pick the other period or ask the admin to correct the existing one.',
        color: kRed,
      );
      return;
    }

    final Student? s = _preview(base);
    if (s == null) {
      showToast(context, 'Please enter a valid age, height, and weight.', color: kRed);
      return;
    }

    // Ask for confirmation before writing the measurement to the records.
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Measurement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to save this measurement for ${s.name}?'),
              const SizedBox(height: 14),
              Text('Grade/Section: ${s.grade} - ${s.section}'),
              Text('Sex: ${s.girl ? 'Girl' : 'Boy'}'),
              Text('Age: ${s.ageY} years'),
              Text('Height: ${s.heightCm.toStringAsFixed(1)} cm'),
              Text('Weight: ${s.weightKg.toStringAsFixed(1)} kg'),
              Text('Measurement date: ${fmtDate(s.measuredOn)}'),
              Text('Period: ${s.schoolYearPeriod} • SY ${s.schoolYear}'),
              const SizedBox(height: 10),
              const Text(
                'After saving, the BMI, Z-score, and nutritional status will be displayed on this dashboard.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.save_rounded),
            label: const Text('Confirm Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final String actorRole = widget.takenBy == 'School Nurse'
        ? kRoleNurse
        : widget.takenBy == 'Teacher'
            ? kRoleTeacher
            : kRoleAdmin;
    final String actorName = widget.actorName.isEmpty
        ? widget.takenBy
        : widget.actorName;

    widget.store.addRecord(
      s,
      actorRole: actorRole,
      actorName: actorName,
      actorEmail: widget.actorEmail,
    );

    setState(() {
      _recent.removeWhere((x) =>
          NutriStore.keyOf(x.name) == NutriStore.keyOf(s.name) &&
          x.schoolYearPeriod == s.schoolYearPeriod &&
          x.schoolYear == s.schoolYear);
      _recent.insert(0, s);
      _savedResult = s;
      // Keep the selected student and entered values visible so the result
      // remains on this same dashboard after saving.
      _picked = s.name;
      _listOpen = false;
    });

    showToast(
      context,
      'Measurement saved. ${s.name}: ${s.status.label} (BMI ${s.bmi.toStringAsFixed(1)}, Z-score ${s.z.toStringAsFixed(2)}).',
      color: kGreen,
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    String suffix,
    String? Function(String?) validator, {
    bool decimal = true,
  }) {
    return TextFormField(
      controller: c,
      style: ink(18),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: validator,
      onChanged: (_) => setState(() => _savedResult = null),
    );
  }

  Widget _studentRow(Student s) {
    final bool on = s.name == _picked;
    final Color gc = s.girl ? kPink : kBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: on ? kGreenLight : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: on ? kInk : kInk.withAlpha(60),
          width: on ? 1.8 : 1.2,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: gc.withAlpha(45),
            child: Icon(
              s.girl ? Icons.female_rounded : Icons.male_rounded,
              color: gc,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ink(17, weight: FontWeight.w700),
                ),
                Text(
                  '${s.grade} • ${s.section} • LRN ${s.lrn}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ink(13, color: kInkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => _pick(s),
            icon: const Icon(Icons.straighten_rounded, size: 18),
            label: Text('Measure', style: ink(15, color: Colors.white)),
            style: FilledButton.styleFrom(backgroundColor: kGreen),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final List<Student> all = widget.store.latestPerChild();

        final List<Student> matches =
            all.where((s) => studentMatchesQuery(s, query)).toList();

        final Student? base =
            _picked == null ? null : widget.store.latestOf(_picked!);

        final Student? preview = base == null ? null : _preview(base);

        // ---------- 1. search + (hidden) student list ----------
        final Widget finder = PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.search_rounded, color: kBlue, size: 28),
                  const SizedBox(width: 8),
                  Text('1. Find the student', style: title(28, color: kBlue)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchC,
                style: ink(18),
                decoration: InputDecoration(
                  labelText: 'Search student (name or LRN)',
                  hintText: 'Type a name or LRN',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchC.clear();
                            setState(() => query = '');
                          },
                        ),
                ),
                onChanged: (v) => setState(() {
                  query = v;

                  // typing a search shows the matching students
                  if (v.trim().isNotEmpty) _listOpen = true;
                }),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() => _listOpen = !_listOpen),
                icon: Icon(
                  _listOpen
                      ? Icons.expand_less_rounded
                      : Icons.groups_rounded,
                  color: kBlue,
                ),
                label: Text(
                  _listOpen ? 'Hide student records' : 'See student records',
                  style: ink(15, weight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kInk, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              if (_listOpen) ...[
                const SizedBox(height: 10),
                Text(
                  'Showing ${matches.length} of ${all.length} students. Tap Measure to enter the measurement.',
                  style: ink(13, color: kInkSoft),
                ),
                const SizedBox(height: 8),
                if (matches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'No student matches your search.',
                      style: ink(16, color: kInkSoft),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _studentRow(matches[i]),
                    ),
                  ),
              ],
              if (base != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kGreenLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kInk, width: 1.4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: kGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Measuring: ${base.name} • ${base.grade} • ${base.section}',
                          style: ink(16, weight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: _clearPick,
                        child: Text('Clear', style: ink(15, color: kRed)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );

        // ---------- 2. measurement form (only after Measure) ----------
        Widget? form;
        Widget? result;

        if (base != null) {
          form = PaperCard(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.straighten_rounded,
                        color: kOrange,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '2. Measurement',
                          style: title(28, color: kOrange),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${base.name} • ${base.grade} • ${base.section} • ${base.girl ? 'Girl' : 'Boy'}',
                    style: ink(15, color: kInkSoft),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey('period$period${base.name}'),
                    isExpanded: true,
                    initialValue: period,
                    decoration: const InputDecoration(
                      labelText: 'School Year Measurement',
                    ),
                    items: const [
                      DropdownMenuItem(value: kBosy, child: Text(kBosy)),
                      DropdownMenuItem(value: kEosy, child: Text(kEosy)),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          period = v;
                          _savedResult = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _dateC,
                    readOnly: true,
                    style: ink(18),
                    decoration: InputDecoration(
                      labelText: 'Date of measurement',
                      helperText: 'School year ${schoolYearOf(_date)}',
                      suffixIcon: const Icon(Icons.calendar_month_rounded),
                    ),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          _age,
                          'Age',
                          'yrs',
                          (v) {
                            final int? n = int.tryParse(v ?? '');

                            return (n == null || n < 5 || n > 13)
                                ? 'Ages 5 to 13 only'
                                : null;
                          },
                          decimal: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          _h,
                          'Height',
                          'cm',
                          (v) {
                            final double? n = double.tryParse(v ?? '');

                            return (n == null || n < 80 || n > 200)
                                ? 'Enter 80 to 200 cm'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          _w,
                          'Weight',
                          'kg',
                          (v) {
                            final double? n = double.tryParse(v ?? '');

                            return (n == null || n < 8 || n > 120)
                                ? 'Enter 8 to 120 kg'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: SketchButton(
                      label: 'Save Measurement',
                      icon: Icons.save_rounded,
                      onTap: () => _save(base),
                    ),
                  ),
                ],
              ),
            ),
          );

          final Student? resultStudent = _savedResult != null &&
                  NutriStore.keyOf(_savedResult!.name) == NutriStore.keyOf(base.name)
              ? _savedResult
              : preview;

          result = resultStudent != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MeasurePreviewCard(
                      student: resultStudent,
                      heading: identical(resultStudent, _savedResult) ||
                              (_savedResult != null && resultStudent == _savedResult)
                          ? 'Saved Measurement Result'
                          : 'BMI + Z-score Result',
                      subtitle: identical(resultStudent, _savedResult) ||
                              (_savedResult != null && resultStudent == _savedResult)
                          ? 'Confirmed and saved successfully. This result is now recorded for the student and visible to authorized staff and the parent account.'
                          : 'Preview only — confirm Save Measurement to record this result.',
                    ),
                    if (_savedResult != null &&
                        NutriStore.keyOf(_savedResult!.name) == NutriStore.keyOf(base.name) &&
                        resultStudent == _savedResult) ...[
                      const SizedBox(height: 10),
                      PaperCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Measurement Record Details', style: title(22, color: kBlue)),
                            const SizedBox(height: 8),
                            Text('Student: ${_savedResult!.name}', style: ink(15)),
                            Text('LRN: ${_savedResult!.lrn}', style: ink(15)),
                            Text('Grade/Section: ${_savedResult!.grade} - ${_savedResult!.section}', style: ink(15)),
                            Text('Date recorded: ${fmtDate(_savedResult!.measuredOn)}', style: ink(15)),
                            Text('Measurement period: ${_savedResult!.schoolYearPeriod} • SY ${_savedResult!.schoolYear}', style: ink(15)),
                            Text('Recorded by: ${widget.actorName.isEmpty ? widget.takenBy : widget.actorName} (${widget.takenBy})', style: ink(15)),
                            Text('Height: ${_savedResult!.heightCm.toStringAsFixed(1)} cm • Weight: ${_savedResult!.weightKg.toStringAsFixed(1)} kg', style: ink(15)),
                            Text('BMI: ${_savedResult!.bmi.toStringAsFixed(1)} • Z-score: ${_savedResult!.z.toStringAsFixed(2)}', style: ink(15, weight: FontWeight.w700)),
                            Text('Nutritional status: ${_savedResult!.status.label}', style: ink(16, weight: FontWeight.w700, color: _savedResult!.status.color)),
                          ],
                        ),
                      ),
                    ],
                  ],
                )
              : PaperCard(
                  child: Row(
                    children: [
                      const Icon(Icons.calculate_rounded, color: kInkSoft),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Enter age, height and weight to see the BMI, z-score and nutritional status.',
                          style: ink(16, color: kInkSoft),
                        ),
                      ),
                    ],
                  ),
                );
        }

        final Widget recent = _recent.isEmpty
            ? const SizedBox.shrink()
            : PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Saved this session', style: title(28, color: kGreen)),
                    const SizedBox(height: 6),
                    for (final s in _recent)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    style: ink(17, weight: FontWeight.w700),
                                  ),
                                  Text(
                                    '${s.schoolYearPeriod} • SY ${s.schoolYear} • BMI ${s.bmi.toStringAsFixed(1)} • z ${s.z.toStringAsFixed(2)}',
                                    style: ink(13, color: kInkSoft),
                                  ),
                                ],
                              ),
                            ),
                            StatusPill(info: s.status),
                          ],
                        ),
                      ),
                  ],
                ),
              );

        return LayoutBuilder(
          builder: (context, c) {
            final bool wide = c.maxWidth >= 1000;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    titleText: 'Measurement',
                    subtitle:
                        '${widget.takenBy}: search a student, tap Measure, then enter the measurement. It is saved to the student\'s account managed by the parents.',
                  ),
                  const SizedBox(height: 16),
                  finder,
                  if (form != null && result != null) ...[
                    SizedBox(key: _formAnchor, height: 16),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: form),
                          const SizedBox(width: 16),
                          Expanded(child: result),
                        ],
                      )
                    else ...[
                      form,
                      const SizedBox(height: 16),
                      result,
                    ],
                  ],
                  if (_recent.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    recent,
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}


// ---------------------------------------------------------------------------
// STUDENT NUTRITIONAL RECORDS (School Nurse = read only, Admin = can edit)
// ---------------------------------------------------------------------------
class StudentRecordsPage extends StatefulWidget {
  final NutriStore store;
  final bool canEdit;
  final String titleText;
  final String subtitle;

  const StudentRecordsPage({
    super.key,
    required this.store,
    required this.canEdit,
    required this.titleText,
    required this.subtitle,
  });

  @override
  State<StudentRecordsPage> createState() => _StudentRecordsPageState();
}

class _StudentRecordsPageState extends State<StudentRecordsPage> {
  String filter = 'All';
  String gradeFilter = 'All';

  final TextEditingController _searchC = TextEditingController();
  String query = '';

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  void _open(Student s) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentRecordDetailPage(
          store: widget.store,
          name: s.name,
          canEdit: widget.canEdit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final List<Student> all = widget.store.latestPerChild();

        final List<Student> list = all.where((s) {
          final bool statusMatch = filter == 'All' || s.status.label == filter;
          final bool gradeMatch = gradeFilter == 'All' || s.grade == gradeFilter;

          return statusMatch && gradeMatch && studentMatchesQuery(s, query);
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(titleText: widget.titleText, subtitle: widget.subtitle),
              const SizedBox(height: 16),
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchC,
                      style: ink(18),
                      decoration: InputDecoration(
                        labelText: 'Search student (name or LRN)',
                        hintText: 'Type a name or LRN',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchC.clear();
                                  setState(() => query = '');
                                },
                              ),
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                    const SizedBox(height: 14),
                    _ChipRow(
                      label: 'Status',
                      options: ['All', ...kStatusList.map((e) => e.label)],
                      selected: filter,
                      colorOf: (o) =>
                          o == 'All' ? kGreen : statusByLabel(o).color,
                      onSelected: (v) => setState(() => filter = v),
                    ),
                    const SizedBox(height: 14),
                    _ChipRow(
                      label: 'Grade',
                      options: [
                        'All',
                        'Kindergarten',
                        for (var i = 1; i <= 6; i++) 'Grade $i',
                      ],
                      selected: gradeFilter,
                      onSelected: (v) => setState(() => gradeFilter = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Showing ${list.length} of ${all.length} students',
                  style: ink(14, color: kInkSoft),
                ),
              ),
              const SizedBox(height: 8),
              PaperCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No students match this filter.',
                            style: ink(16, color: kInkSoft),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < list.length; i++) ...[
                            _RecordRow(
                              student: list[i],
                              onTap: () => _open(list[i]),
                            ),
                            if (i != list.length - 1)
                              Divider(height: 1, color: kInk.withAlpha(40)),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecordRow extends StatelessWidget {
  final Student student;
  final VoidCallback onTap;

  const _RecordRow({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Student s = student;
    final StatusInfo st = s.status;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: st.color.withAlpha(40),
              child: Icon(
                s.girl ? Icons.female_rounded : Icons.male_rounded,
                color: st.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ink(18, weight: FontWeight.w700),
                  ),
                  Text(
                    '${s.grade} • ${s.section} • ${s.ageY} yrs • LRN ${s.lrn}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ink(14, color: kInkSoft),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusPill(info: st),
                      Text(
                        s.measured
                            ? 'BMI ${s.bmi.toStringAsFixed(1)} • z ${s.z.toStringAsFixed(2)}'
                            : 'No measurement yet',
                        style: ink(14, weight: FontWeight.w700),
                      ),
                      if (s.measured)
                        Text(
                          '${s.schoolYearPeriod} • ${fmtDate(s.measuredOn)}',
                          style: ink(
                            13,
                            weight: FontWeight.w700,
                            color: colorForPeriod(s.schoolYearPeriod),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kInkSoft),
          ],
        ),
      ),
    );
  }
}

// everything about one student: info, nutrition status, measurements, plans
class StudentRecordDetailPage extends StatelessWidget {
  final NutriStore store;
  final String name;
  final bool canEdit;

  const StudentRecordDetailPage({
    super.key,
    required this.store,
    required this.name,
    required this.canEdit,
  });

  Future<void> _editHealthData(BuildContext context) async {
    final List<Student> recs = store.recordsOf(name);

    Student? before;
    Student? after;

    for (final x in recs) {
      if (x.schoolYearPeriod == kBosy) {
        before ??= x;
      } else if (x.schoolYearPeriod == kEosy) {
        after ??= x;
      }
    }

    // a student that was not measured yet: edit the "not measured" record
    if (before == null && after == null) {
      for (final x in recs) {
        if (!x.measured) { before = x; break; }
      }
    }
    if (before == null && after == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentHealthDataPage(
          before: before,
          after: after,
          history: List<MealPlanRecord>.from(
            store.mealHistory[NutriStore.keyOf(name)] ?? const [],
          ),
          onSave: store.saveHealthData,
        ),
      ),
    );

    // the name may have been changed
    if (context.mounted && store.recordsOf(name).isEmpty) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _editMeasurement(BuildContext context, Student s) async {
    final Student? updated = await showDialog<Student>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditMeasurementDialog(record: s),
    );

    if (updated == null || !context.mounted) return;

    store.replaceRecord(s, updated);

    showToast(context, 'Measurement updated.', color: kGreen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ArtBackground(
        child: SafeArea(
          child: Column(
            children: [
              const BackBar(),
              Expanded(
                child: ListenableBuilder(
                  listenable: store,
                  builder: (context, _) {
                    final List<Student> recs = store.recordsOf(name);

                    if (recs.isEmpty) {
                      return Center(
                        child: Text(
                          'This student has no records.',
                          style: ink(18, color: kInkSoft),
                        ),
                      );
                    }

                    final Student latest = recs.last;
                    final List<Student> measuredRecs = recs.where((x) => x.measured).toList();
                    final List<Student> newestFirst = measuredRecs.reversed.toList();
                    final List<ProgressPair> pairs = buildPairs(recs);

                    final List<MealPlanRecord> history =
                        store.mealHistory[NutriStore.keyOf(name)] ?? const [];

                    final Widget infoCard = PaperCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.person_rounded,
                                color: kBlue,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text('Student Info', style: title(28, color: kBlue)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          infoGrid([
                            InfoRow(
                              icon: Icons.badge_rounded,
                              label: 'Student name',
                              value: latest.name,
                            ),
                            InfoRow(
                              icon: Icons.numbers_rounded,
                              label: 'LRN',
                              value: latest.lrn,
                            ),
                            InfoRow(
                              icon: Icons.school_rounded,
                              label: 'Grade',
                              value: latest.grade,
                            ),
                            InfoRow(
                              icon: Icons.meeting_room_rounded,
                              label: 'Section',
                              value: latest.section,
                            ),
                            InfoRow(
                              icon: Icons.cake_rounded,
                              label: 'Age',
                              value: '${latest.ageY} yrs',
                            ),
                            InfoRow(
                              icon: latest.girl
                                  ? Icons.female_rounded
                                  : Icons.male_rounded,
                              label: 'Gender',
                              value: latest.girl ? 'Girl' : 'Boy',
                              color: latest.girl ? kPink : kBlue,
                            ),
                            InfoRow(
                              icon: Icons.block_rounded,
                              label: 'Allergies',
                              value: latest.allergies.isEmpty
                                  ? 'None'
                                  : latest.allergies.join(', '),
                              color: kRed,
                            ),
                            InfoRow(
                              icon: Icons.medical_services_rounded,
                              label: 'Medical status',
                              value: latest.medicalStatus.isEmpty
                                  ? 'None'
                                  : latest.medicalStatus,
                              color: kPurple,
                            ),
                            InfoRow(
                              icon: Icons.groups_rounded,
                              label: 'Meal plan is for',
                              value: latest.household,
                              color: kGreen,
                            ),
                          ]),
                          if (canEdit) ...[
                            const SizedBox(height: 16),
                            Center(
                              child: SketchButton(
                                label: 'Edit Student & Parent Info',
                                icon: Icons.edit_rounded,
                                onTap: () => _editHealthData(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );

                    final Widget parentCard = PaperCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.family_restroom_rounded,
                                color: kGreen,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Parent Account',
                                style: title(28, color: kGreen),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          infoGrid([
                            InfoRow(
                              icon: Icons.person_rounded,
                              label: 'Parent name',
                              value: store.parentNameFor(latest.parentEmail),
                              color: kGreen,
                            ),
                            InfoRow(
                              icon: Icons.email_rounded,
                              label: 'Email',
                              value: latest.parentEmail,
                              color: kGreen,
                            ),
                            InfoRow(
                              icon: Icons.phone_rounded,
                              label: 'Phone number',
                              value: latest.parentPhone,
                              color: kGreen,
                            ),
                          ]),
                        ],
                      ),
                    );

                    final Widget statusCard = latest.measured
                        ? MeasurePreviewCard(
                            student: latest,
                            heading: 'Nutrition Status',
                            subtitle: 'Latest check-up: ${latest.schoolYearPeriod} • ${fmtDate(latest.measuredOn)}',
                          )
                        : PaperCard(
                            child: Row(children: [
                              const Icon(Icons.hourglass_empty_rounded, color: kInkSoft, size: 30),
                              const SizedBox(width: 10),
                              Expanded(child: Text('Not measured yet. The teacher or school nurse will take the first measurement.', style: ink(16, color: kInkSoft))),
                            ]),
                          );

                    final Widget records = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Measurements',
                          style: title(32, color: kOrange),
                        ),
                        Text(
                          canEdit
                              ? 'All check-ups of this student. Tap Edit to change a measurement.'
                              : 'All check-ups of this student (view only).',
                          style: ink(14, color: kInkSoft),
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, c) {
                            final int cols = c.maxWidth >= 800 ? 2 : 1;

                            const double gap = 16;

                            final double w =
                                (c.maxWidth - gap * (cols - 1)) / cols;

                            return Wrap(
                              spacing: gap,
                              runSpacing: gap,
                              children: [
                                for (final s in newestFirst)
                                  SizedBox(
                                    width: w,
                                    child: MeasurementRecordCard(
                                      record: s,
                                      onEdit: canEdit
                                          ? () => _editMeasurement(context, s)
                                          : null,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    );

                    final Widget progress = pairs.isEmpty
                        ? const SizedBox.shrink()
                        : ChartCard(
                            titleText: 'Progress',
                            subtitle: 'Beginning vs End of the School Year',
                            child: _ProgressRow(pair: pairs.last),
                          );

                    final Widget trend = measuredRecs.length < 2
                        ? const SizedBox.shrink()
                        : ChartCard(
                            titleText: 'BMI Over Time',
                            subtitle: 'Every check-up of this student',
                            child: BmiTrendChart(records: measuredRecs),
                          );

                    final Widget plans = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nutrition Plan', style: title(32, color: kGreen)),
        Text(
          'The recommended meal plan and exercises for this student today.',
          style: ink(14, color: kInkSoft),
        ),
        const SizedBox(height: 10),
        PlanBlock(
          plan: generatePlan(latest),
          allergies: latest.allergies,
          medicalNotes: [
            if (latest.medicalStatus.trim().isNotEmpty)
              'Medical status: ${latest.medicalStatus}.',
          ],
        ),
        const SizedBox(height: 20),
        Text('Meal Plan History', style: title(32, color: kOrange)),
        Text(
          'Meal plans that were given to this student before. Records only.',
          style: ink(14, color: kInkSoft),
        ),
        const SizedBox(height: 10),
        _MealHistoryCard(history: history),
      ],
                    );

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final bool wide = c.maxWidth >= 950;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PageHeader(
                                titleText: latest.name,
                                subtitle: canEdit
                                    ? 'Full student nutritional record.'
                                    : 'Student nutritional record (view only).',
                              ),
                              const SizedBox(height: 16),
                              if (wide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          infoCard,
                                          const SizedBox(height: 16),
                                          parentCard,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(child: statusCard),
                                  ],
                                )
                              else ...[
                                statusCard,
                                const SizedBox(height: 16),
                                infoCard,
                                const SizedBox(height: 16),
                                parentCard,
                              ],
                              const SizedBox(height: 20),
                              records,
                              const SizedBox(height: 16),
                              if (wide)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: trend),
                                    const SizedBox(width: 16),
                                    Expanded(child: progress),
                                  ],
                                )
                              else ...[
                                trend,
                                const SizedBox(height: 16),
                                progress,
                              ],
                              const SizedBox(height: 20),
                              plans,
                              const SizedBox(height: 24),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// USER ACCOUNT for TEACHER / SCHOOL NURSE (email + password cannot change)
// ---------------------------------------------------------------------------
class StaffAccountPage extends StatelessWidget {
  final StaffAccount account;
  final NutriStore store;

  const StaffAccountPage({super.key, required this.account, required this.store});

  Future<void> _editAssignment(BuildContext context) async {
    final detailController = TextEditingController(text: account.detail);
    final schoolController = TextEditingController(text: account.school);
    final formKey = GlobalKey<FormState>();
    final bool canEditSchool =
        account.role == kRoleTeacher || account.role == kRoleNurse;
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Assignment'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: detailController,
                decoration: const InputDecoration(labelText: 'Assignment'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter the assignment'
                    : null,
              ),
              if (canEditSchool) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: schoolController,
                  decoration: const InputDecoration(labelText: 'Assigned School'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter the assigned school'
                      : null,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      store.updateStaff(
        account.id,
        name: account.name,
        email: account.email,
        password: account.password,
        phone: account.phone,
        detail: detailController.text.trim(),
        employeeId: account.employeeId,
        school: canEditSchool ? schoolController.text.trim() : account.school,
      );
      showToast(context, 'Assignment updated.', color: kGreen);
    }
    detailController.dispose();
    schoolController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color rc = roleColor(account.role);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            titleText: 'User Account',
            subtitle: 'Your account information.',
          ),
          const SizedBox(height: 16),
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: rc.withAlpha(45),
                      child: Icon(roleIcon(account.role), color: rc, size: 34),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(account.name, style: title(36)),
                          const SizedBox(height: 4),
                          RoleChip(
                            label: account.role,
                            color: rc,
                            icon: roleIcon(account.role),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                infoGrid([
                  InfoRow(
                    icon: Icons.work_rounded,
                    label: 'Assignment',
                    value: account.detail,
                    color: rc,
                  ),
                  InfoRow(
                    icon: Icons.phone_rounded,
                    label: 'Phone number',
                    value: account.phone,
                    color: rc,
                  ),
                  if (account.employeeId.isNotEmpty)
                    InfoRow(
                      icon: Icons.badge_rounded,
                      label: 'Employee ID',
                      value: account.employeeId,
                      color: rc,
                    ),
                  if (account.school.isNotEmpty)
                    InfoRow(
                      icon: Icons.school_rounded,
                      label: 'Assigned School',
                      value: account.school,
                      color: rc,
                    ),
                ]),
                if (account.role == kRoleTeacher || account.role == kRoleNurse) ...[
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: () => _editAssignment(context),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit Assignment'),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                LockedField(
                  label: 'Email',
                  value: account.email,
                  icon: Icons.email_rounded,
                ),
                const SizedBox(height: 14),
                LockedField(
                  label: 'Password',
                  value: account.password,
                  icon: Icons.lock_rounded,
                  secret: true,
                ),
                const SizedBox(height: 14),
                const LockNote(
                  text:
                      'Your email and password cannot be changed here. '
                      'Please contact the system admin if you need help with your account.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ADMIN: USER RECORDS (parents, teachers, school nurses, admin)
// The admin can open any user and edit ALL of the user's information:
// name, email, password, phone number and assignment.
// ---------------------------------------------------------------------------
class AdminHistoryPage extends StatefulWidget {
  final NutriStore store;
  const AdminHistoryPage({super.key, required this.store});
  @override
  State<AdminHistoryPage> createState() => _AdminHistoryPageState();
}

class _AdminHistoryPageState extends State<AdminHistoryPage> {
  String _query = '';
  String _roleFilter = 'All';
  String? _selectedKey;
  final TextEditingController _searchC = TextEditingController();

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  String _key(AccountArchive a) => '${a.role}::${a.id.trim().toLowerCase()}';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final accounts = widget.store.accountHistory.values.toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final q = _query.trim().toLowerCase();
        final matches = accounts.where((a) {
          final roleOk = _roleFilter == 'All' || a.role == _roleFilter;
          final text = '${a.name} ${a.email} ${a.role} ${a.phone} ${a.detail} ${a.employeeId} ${a.school}'.toLowerCase();
          return roleOk && (q.isEmpty || text.contains(q));
        }).toList();
        AccountArchive? selected;
        if (_selectedKey != null) {
          for (final a in accounts) {
            if (_key(a) == _selectedKey) { selected = a; break; }
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PageHeader(
              titleText: 'History Dashboard',
              subtitle: selected == null
                  ? 'Search for an account, then select a name to view its complete account and activity history.'
                  : 'Complete account information and related records for ${selected.name}.',
            ),
            const SizedBox(height: 16),
            // Search is always at the top of the dashboard.
            PaperCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: _searchC,
                decoration: InputDecoration(
                  labelText: 'Search accounts by name, email, role, school, or employee ID',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty ? null : IconButton(
                    tooltip: 'Clear search', icon: const Icon(Icons.close_rounded),
                    onPressed: () { _searchC.clear(); setState(() => _query = ''); },
                  ),
                ),
                onChanged: (v) => setState(() { _query = v; _selectedKey = null; }),
              ),
              const SizedBox(height: 12),
              _ChipRow(
                label: 'Role',
                options: const ['All', kRoleParent, kRoleTeacher, kRoleNurse, kRoleAdmin],
                selected: _roleFilter,
                colorOf: (r) => r == 'All' ? kGreen : roleColor(r),
                onSelected: (r) => setState(() { _roleFilter = r; _selectedKey = null; }),
              ),
            ])),
            const SizedBox(height: 14),
            if (selected == null) ...[
              Text('Account history (${matches.length})', style: title(25)),
              const SizedBox(height: 8),
              PaperCard(child: Column(children: [
                if (matches.isEmpty)
                  const Padding(padding: EdgeInsets.all(22), child: Text('No accounts match your search.'))
                else
                  for (final a in matches)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedKey = _key(a)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          CircleAvatar(backgroundColor: roleColor(a.role).withAlpha(35), child: Icon(roleIcon(a.role), color: roleColor(a.role))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.name, style: ink(16, weight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('${a.role} • ${a.email}', style: ink(13, color: kInkSoft)),
                            Text('Created: ${fmtDate(a.createdAt)} ${a.createdAt.hour.toString().padLeft(2, '0')}:${a.createdAt.minute.toString().padLeft(2, '0')}', style: ink(12, color: kInkSoft)),
                            if (a.deletedAt != null) Text('Deactivated: ${fmtDate(a.deletedAt!)}', style: ink(12, color: kRed)),
                            if (a.employeeId.isNotEmpty || a.school.isNotEmpty)
                              Text('Employee ID: ${a.employeeId.isEmpty ? 'N/A' : a.employeeId} • School: ${a.school.isEmpty ? 'N/A' : a.school}', style: ink(12, color: kInkSoft)),
                          ])),
                          const SizedBox(width: 8),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            LegendChip(text: a.isActive ? 'Active' : 'Inactive', color: a.isActive ? kGreen : kRed),
                            const SizedBox(height: 8),
                            Icon(Icons.chevron_right_rounded, color: kInkSoft),
                          ]),
                        ]),
                      ),
                    ),
              ])),
            ] else ...[
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                onPressed: () => setState(() => _selectedKey = null),
                icon: const Icon(Icons.arrow_back_rounded), label: const Text('Back to account history'),
              )),
              _buildAccountDetail(selected),
            ],
            const SizedBox(height: 12),
            const Text('History is kept in the current app session. Persistent database storage is needed to retain it after browser refreshes or app restarts.'),
          ]),
        );
      },
    );
  }

  Widget _buildAccountDetail(AccountArchive account) {
    final bool isParent = account.role == kRoleParent;
    final String email = account.email.trim().toLowerCase();
    final List<Student> children = isParent
        ? widget.store.students.where((s) => s.parentEmail.trim().toLowerCase() == email).toList()
        : <Student>[];
    children.sort((a, b) => b.measuredOn.compareTo(a.measuredOn));

    final List<ActivityLogEntry> activities = widget.store.activityHistory.where((e) {
      final sameAccount = e.accountEmail.trim().toLowerCase() == email ||
          (e.role == account.role && e.accountName.trim().toLowerCase() == account.name.trim().toLowerCase());
      if (sameAccount) return true;
      if (isParent) {
        return children.any((s) => e.details.toLowerCase().contains(s.name.toLowerCase()));
      }
      return false;
    }).toList()..sort((a, b) => b.at.compareTo(a.at));

    final Set<String> childNames = children.map((s) => NutriStore.keyOf(s.name)).toSet();
    final List<MapEntry<String, MealPlanRecord>> plans = <MapEntry<String, MealPlanRecord>>[];
    if (isParent) {
      for (final entry in widget.store.mealHistory.entries) {
        if (childNames.contains(NutriStore.keyOf(entry.key))) {
          for (final record in entry.value) { plans.add(MapEntry(entry.key, record)); }
        }
      }
      plans.sort((a, b) => b.value.date.compareTo(a.value.date));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Account information', style: title(24)),
      const SizedBox(height: 8),
      PaperCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 26, backgroundColor: roleColor(account.role).withAlpha(35), child: Icon(roleIcon(account.role), color: roleColor(account.role), size: 28)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(account.name, style: title(25)),
            Text(account.role, style: ink(14, color: roleColor(account.role), weight: FontWeight.w700)),
            Text(account.email, style: ink(14, color: kInkSoft)),
          ])),
          LegendChip(text: account.isActive ? 'Active' : 'Inactive', color: account.isActive ? kGreen : kRed),
        ]),
        const SizedBox(height: 16),
        infoGrid([
          InfoRow(icon: Icons.calendar_month_rounded, label: 'Account created', value: '${fmtDate(account.createdAt)} ${account.createdAt.hour.toString().padLeft(2, '0')}:${account.createdAt.minute.toString().padLeft(2, '0')}', color: kBlue),
          InfoRow(icon: Icons.event_busy_rounded, label: 'Deactivated', value: account.deletedAt == null ? 'Not deactivated' : fmtDate(account.deletedAt!), color: account.deletedAt == null ? kGreen : kRed),
          InfoRow(icon: Icons.phone_rounded, label: 'Phone', value: account.phone.isEmpty ? 'N/A' : account.phone, color: kBlue),
          InfoRow(icon: Icons.work_rounded, label: 'Assignment / details', value: account.detail.isEmpty ? 'N/A' : account.detail, color: kBlue),
          if (account.employeeId.isNotEmpty) InfoRow(icon: Icons.badge_rounded, label: 'Employee ID', value: account.employeeId, color: kBlue),
          if (account.school.isNotEmpty) InfoRow(icon: Icons.school_rounded, label: 'Assigned school', value: account.school, color: kBlue),
          if (isParent) InfoRow(icon: Icons.child_care_rounded, label: 'Linked students', value: '${children.map((s) => NutriStore.keyOf(s.name)).toSet().length}', color: kPurple),
        ]),
      ])),
      const SizedBox(height: 18),
      if (isParent) ...[
        Text('Student information and measurement records', style: title(24)),
        const SizedBox(height: 8),
        if (children.isEmpty)
          const PaperCard(child: Text('No student or measurement records are linked to this parent account.'))
        else
          for (final student in children)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: PaperCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student.name, style: ink(18, weight: FontWeight.w700)),
              Text('LRN: ${student.lrn.isEmpty ? 'N/A' : student.lrn} • ${student.grade} • ${student.section}', style: ink(13, color: kInkSoft)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _historyValue('Age', '${student.ageY}y ${student.ageM}m'),
                _historyValue('Height', student.measured ? '${student.heightCm.toStringAsFixed(1)} cm' : 'Not measured'),
                _historyValue('Weight', student.measured ? '${student.weightKg.toStringAsFixed(1)} kg' : 'Not measured'),
                _historyValue('BMI', student.measured ? student.bmi.toStringAsFixed(2) : 'N/A'),
                _historyValue('WHO Z-score', student.measured ? student.z.toStringAsFixed(2) : 'N/A'),
                _historyValue('Nutritional status', student.status.label),
              ]),
              const SizedBox(height: 8),
              Text('Measurement date: ${fmtDate(student.measuredOn)} • ${student.schoolYearPeriod}', style: ink(12, color: kInkSoft)),
              if (student.allergies.isNotEmpty) Text('Allergies: ${student.allergies.join(', ')}', style: ink(13)),
              if (student.medicalStatus.isNotEmpty) Text('Medical information: ${student.medicalStatus}', style: ink(13)),
            ]))),
        const SizedBox(height: 18),
        Text('Nutrition meal plan history', style: title(24)),
        const SizedBox(height: 8),
        if (plans.isEmpty)
          const PaperCard(child: Text('No saved nutrition meal plans found for this parent’s students.'))
        else
          for (final item in plans)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: PaperCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.key, style: ink(17, weight: FontWeight.w700)),
              Text('${fmtDate(item.value.date)} • ${item.value.period} • ${item.value.status}', style: ink(12, color: kInkSoft)),
              Text('Daily target: ${item.value.plan.kcal} kcal • Servings: ${item.value.plan.servings}', style: ink(13)),
              if (item.value.plan.cost != null) Text('Estimated cost: ₱${item.value.plan.cost!.toStringAsFixed(2)}', style: ink(13)),
              const SizedBox(height: 6),
              for (final meal in item.value.plan.meals)
                Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('• ${meal.slot.name}: ${meal.dish} (${meal.kcal} kcal)', style: ink(13))),
              if (item.value.plan.exercises.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Exercise recommendations: ${item.value.plan.exercises.map((x) => x.name).join(', ')}', style: ink(13)),
              ],
            ]))),
      ],
      const SizedBox(height: 18),
      Text('Activity history', style: title(24)),
      const SizedBox(height: 8),
      if (activities.isEmpty)
        const PaperCard(child: Text('No activity events have been recorded for this account yet.'))
      else
        PaperCard(child: Column(children: [
          for (final e in activities)
            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.event_note_rounded, color: kBlue),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.action, style: ink(15, weight: FontWeight.w700)),
                Text('${e.accountName} • ${e.role} • ${e.accountEmail}', style: ink(12, color: kInkSoft)),
                const SizedBox(height: 3),
                Text(e.details, style: ink(14)),
                Text('${fmtDate(e.at)} ${e.at.hour.toString().padLeft(2, '0')}:${e.at.minute.toString().padLeft(2, '0')}', style: ink(11, color: kInkSoft)),
              ])),
            ])),
        ])),
    ]);
  }

  Widget _historyValue(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: kGreenLight.withAlpha(70), borderRadius: BorderRadius.circular(10), border: Border.all(color: kInkSoft.withAlpha(45))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: ink(11, color: kInkSoft)),
      const SizedBox(height: 2),
      Text(value, style: ink(13, weight: FontWeight.w700)),
    ]),
  );
}

class UserRecordsPage extends StatefulWidget {
  final NutriStore store;

  const UserRecordsPage({super.key, required this.store});

  @override
  State<UserRecordsPage> createState() => _UserRecordsPageState();
}

class _UserRecordsPageState extends State<UserRecordsPage> {
  String roleFilter = 'All';

  final TextEditingController _searchC = TextEditingController();
  String query = '';

  List<Map<String, dynamic>> _apiUsers = <Map<String, dynamic>>[];
  bool _loadingApiUsers = false;
  String? _apiUsersError;

  @override
  void initState() {
    super.initState();
    _loadApiUsers();
  }

  Future<void> _loadApiUsers() async {
    if (!mounted) return;
    setState(() {
      _loadingApiUsers = true;
      _apiUsersError = null;
    });
    try {
      final users = await ApiService.getUsers();
      if (!mounted) return;
      setState(() {
        _apiUsers = users;
        _loadingApiUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _apiUsersError = e.toString().replaceFirst('Exception: ', '');
        _loadingApiUsers = false;
      });
    }
  }

  String _displayRole(dynamic rawRole) {
    switch ((rawRole ?? '').toString().trim().toLowerCase()) {
      case 'parent':
        return kRoleParent;
      case 'teacher':
        return kRoleTeacher;
      case 'nurse':
      case 'school nurse':
        return kRoleNurse;
      case 'admin':
        return kRoleAdmin;
      default:
        return (rawRole ?? 'Unknown').toString();
    }
  }

  AccountView _accountFromApi(Map<String, dynamic> user) {
    final String role = _displayRole(user['role']);
    final String status = (user['status'] ?? 'pending').toString().toLowerCase();
    final String created = (user['created_at'] ?? '').toString();
    return AccountView(
      id: (user['id'] ?? '').toString(),
      role: role,
      name: (user['full_name'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      password: '',
      phone: (user['phone'] ?? '').toString(),
      detail: '',
      createdAt: DateTime.tryParse(created),
      isActive: status != 'disabled' && status != 'inactive' && status != 'deleted',
    );
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _open(AccountView a) async {
    final bool isParent = a.role == kRoleParent;

    final _UserEdit? e = await showDialog<_UserEdit>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UserEditDialog(
        store: widget.store,
        account: a,
        emailTaken: (email) => widget.store.emailInUse(
          email,
          exceptStaffId: isParent ? null : a.id,
          exceptParentEmail: isParent ? a.email : null,
        ),
      ),
    );

    if (e == null || !mounted) return;

    if (isParent) {
      widget.store.updateParent(
        a.email,
        name: e.name,
        email: e.email,
        password: e.password,
        phone: e.phone,
      );
    } else {
      widget.store.updateStaff(
        a.id,
        name: e.name,
        email: e.email,
        password: e.password,
        phone: e.phone,
        detail: e.detail,
        employeeId: e.employeeId,
        school: e.school,
      );
    }

    showToast(context, 'Saved the account of ${e.name}.', color: kGreen);
  }

  Future<void> _delete(AccountView account) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('Deactivate ${account.name} (${account.role})? They will no longer be able to log in, but their account and activity history will be retained.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    if (account.role == kRoleParent) {
      widget.store.deleteParent(account.email);
    } else {
      widget.store.deleteStaff(account.id);
    }
    showToast(context, 'Deleted ${account.name}. Account history was retained.', color: kRed);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final List<AccountView> localAccounts = widget.store.allAccounts();
        final Set<String> localEmails = localAccounts
            .map((a) => a.email.trim().toLowerCase())
            .toSet();
        final List<AccountView> apiAccounts = _apiUsers
            .map(_accountFromApi)
            .where((a) => a.email.trim().isNotEmpty &&
                !localEmails.contains(a.email.trim().toLowerCase()))
            .toList();
        final Set<String> apiEmails = apiAccounts
            .map((a) => a.email.trim().toLowerCase())
            .toSet();
        final List<AccountView> all = <AccountView>[
          ...localAccounts,
          ...apiAccounts,
        ];

        final String q = query.trim().toLowerCase();

        final List<AccountView> list = all.where((a) {
          final bool roleMatch = roleFilter == 'All' || a.role == roleFilter;

          final bool searchMatch = q.isEmpty ||
              a.name.toLowerCase().contains(q) ||
              a.email.toLowerCase().contains(q) ||
              a.children.any((c) => studentMatchesQuery(c, q));

          return roleMatch && searchMatch;
        }).toList();

        int count(String r) => all.where((a) => a.role == r).length;
        final Map<String, int> roleCounts = <String, int>{
          kRoleParent: count(kRoleParent),
          kRoleTeacher: count(kRoleTeacher),
          kRoleNurse: count(kRoleNurse),
          kRoleAdmin: count(kRoleAdmin),
        };
        final int totalUsers = roleCounts.values.fold<int>(0, (sum, value) => sum + value);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                titleText: 'User Records',
                subtitle:
                    'All parent, teacher, school nurse and admin users. Tap a user to see and edit all of their information.',
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, c) {
                  const double gap = 12;

                  final int cols = c.maxWidth >= 900 ? 4 : 2;
                  final double w = (c.maxWidth - gap * (cols - 1)) / cols;

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final r in const [
                        kRoleParent,
                        kRoleTeacher,
                        kRoleNurse,
                        kRoleAdmin,
                      ])
                        SizedBox(
                          width: w,
                          height: 124,
                          child: KpiCard(
                            label: '$r users',
                            value: '${count(r)}',
                            sub: r == kRoleParent
                                ? 'manage their children'
                                : 'school staff',
                            icon: roleIcon(r),
                            color: roleColor(r),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User Distribution', style: title(24)),
                    const SizedBox(height: 4),
                    Text(
                      'Number of accounts by role across all user records.',
                      style: ink(13, color: kInkSoft),
                    ),
                    const SizedBox(height: 12),
                    if (totalUsers == 0)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No user accounts available to chart yet.')),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final bool wide = constraints.maxWidth >= 620;
                          final chart = SizedBox(
                            height: 230,
                            width: wide ? 300 : double.infinity,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sectionsSpace: 3,
                                    centerSpaceRadius: 48,
                                    sections: [
                                      for (final entry in roleCounts.entries.where((e) => e.value > 0))
                                        PieChartSectionData(
                                          value: entry.value.toDouble(),
                                          color: roleColor(entry.key),
                                          radius: 66,
                                          title: '${entry.value}',
                                          titleStyle: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          borderSide: const BorderSide(color: Colors.white, width: 1.5),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('$totalUsers', style: title(32)),
                                    Text('Total users', style: ink(11, color: kInkSoft)),
                                  ],
                                ),
                              ],
                            ),
                          );
                          final legend = Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final entry in roleCounts.entries)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 7),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: roleColor(entry.key),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(entry.key, style: ink(14))),
                                      Text('${entry.value}', style: ink(15, weight: FontWeight.w800)),
                                    ],
                                  ),
                                ),
                            ],
                          );
                          if (wide) {
                            return Row(
                              children: [
                                chart,
                                const SizedBox(width: 24),
                                Expanded(child: legend),
                              ],
                            );
                          }
                          return Column(children: [chart, const SizedBox(height: 8), legend]);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchC,
                      style: ink(18),
                      decoration: InputDecoration(
                        labelText: 'Search user (name, email or child)',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchC.clear();
                                  setState(() => query = '');
                                },
                              ),
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                    const SizedBox(height: 14),
                    _ChipRow(
                      label: 'Role',
                      options: const [
                        'All',
                        kRoleParent,
                        kRoleTeacher,
                        kRoleNurse,
                        kRoleAdmin,
                      ],
                      selected: roleFilter,
                      colorOf: (o) => o == 'All' ? kGreen : roleColor(o),
                      onSelected: (v) => setState(() => roleFilter = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Showing ${list.length} of ${all.length} users',
                  style: ink(14, color: kInkSoft),
                ),
              ),
              const SizedBox(height: 8),
              PaperCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No users match this filter.',
                            style: ink(16, color: kInkSoft),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < list.length; i++) ...[
                            _UserRow(
                              account: list[i],
                              onTap: apiEmails.contains(list[i].email.trim().toLowerCase())
                                  ? () => showToast(
                                        context,
                                        'This account is loaded from the database. Editing and deactivation need their own PHP endpoints.',
                                        color: kBlue,
                                      )
                                  : () => _open(list[i]),
                              onDelete: apiEmails.contains(list[i].email.trim().toLowerCase())
                                  ? null
                                  : (list[i].isActive ? () => _delete(list[i]) : null),
                            ),
                            if (i != list.length - 1)
                              Divider(height: 1, color: kInk.withAlpha(40)),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  final AccountView account;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _UserRow({required this.account, required this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final AccountView a = account;
    final Color rc = roleColor(a.role);

    return InkWell(
      onTap: a.isActive ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: rc.withAlpha(40),
              child: Icon(roleIcon(a.role), color: rc, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ink(18, weight: FontWeight.w700),
                  ),
                  Text(
                    a.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ink(14, color: kInkSoft),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      LegendChip(text: a.role, color: rc),
                      LegendChip(text: a.isActive ? 'Active' : 'Inactive', color: a.isActive ? kGreen : kRed),
                      Text(a.detail, style: ink(13, color: kInkSoft)),
                      if (a.employeeId.isNotEmpty)
                        Text('ID: ${a.employeeId}', style: ink(13, color: kInkSoft)),
                      if (a.school.isNotEmpty)
                        Text('School: ${a.school}', style: ink(13, color: kInkSoft)),
                    ],
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete account',
                icon: const Icon(Icons.delete_outline_rounded, color: kRed, size: 22),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

class _UserEdit {
  final String name;
  final String email;
  final String phone;
  final String password;
  final String detail;
  final String employeeId;
  final String school;

  const _UserEdit(this.name, this.email, this.phone, this.password, this.detail,
      this.employeeId, this.school);
}

class _UserEditDialog extends StatefulWidget {
  final NutriStore store;
  final AccountView account;

  // true when another account already uses this email
  final bool Function(String email) emailTaken;

  const _UserEditDialog({
    required this.store,
    required this.account,
    required this.emailTaken,
  });

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _pass;
  late final TextEditingController _detail;
  late final TextEditingController _employeeId;
  late final TextEditingController _school;

  late List<Student> _kids;

  bool _showPass = false;

  bool get _isParent => widget.account.role == kRoleParent;

  @override
  void initState() {
    super.initState();

    final AccountView a = widget.account;

    _name = TextEditingController(text: a.name);
    _email = TextEditingController(text: a.email);
    _phone = TextEditingController(text: a.phone);
    _pass = TextEditingController(text: a.password);
    _detail = TextEditingController(text: a.detail);
    _employeeId = TextEditingController(text: a.employeeId);
    _school = TextEditingController(text: a.school);
    _kids = List<Student>.from(a.children);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _detail.dispose();
    _employeeId.dispose();
    _school.dispose();
    super.dispose();
  }

  // the info of a child is saved right away (it does not wait for Save)
  Future<void> _editChild(Student s) async {
    final _ChildEdit? e = await showDialog<_ChildEdit>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChildEditDialog(student: s, store: widget.store),
    );

    if (e == null || !mounted) return;

    widget.store.updateChildInfo(
      s.name,
      name: e.name,
      lrn: e.lrn,
      grade: e.grade,
      section: e.section,
      ageY: e.age,
      girl: e.girl,
      allergies: e.allergies,
      medical: e.medical,
      household: e.household,
    );

    setState(() {
      _kids = widget.store.childrenOf(widget.account.email);
    });

    showToast(context, 'Saved the info of ${e.name}.', color: kGreen);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;

    Navigator.of(context).pop(
      _UserEdit(
        _name.text.trim(),
        _email.text.trim(),
        cleanPhone(_phone.text),
        _pass.text,
        _detail.text.trim(),
        _employeeId.text.trim(),
        _school.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AccountView a = widget.account;
    final Color rc = roleColor(a.role);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: PaperCard(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: rc.withAlpha(45),
                        child: Icon(roleIcon(a.role), color: rc, size: 30),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Edit User', style: title(32, color: kGreen)),
                            RoleChip(
                              label: a.role,
                              color: rc,
                              icon: roleIcon(a.role),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    style: ink(17),
                    keyboardType: TextInputType.name,
                    decoration: InputDecoration(
                      labelText: _isParent ? 'Parent full name' : 'Full name',
                      prefixIcon: const Icon(Icons.person_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter a name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    style: ink(17),
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_rounded),
                    ),
                    validator: (v) {
                      final String? e = validateEmail(v);

                      if (e != null) return e;

                      if (widget.emailTaken(v!.trim())) {
                        return 'This email is already used by another account';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    style: ink(17),
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '09XXXXXXXXX',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                    validator: validatePhone,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _pass,
                    style: ink(17),
                    obscureText: !_showPass,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPass
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        onPressed: () => setState(() => _showPass = !_showPass),
                      ),
                    ),
                    validator: validatePassword,
                  ),
                  const SizedBox(height: 14),
                  if (_isParent)
                    InfoRow(
                      icon: Icons.work_rounded,
                      label: 'Assignment',
                      value: _kids.length == 1
                          ? '1 child'
                          : '${_kids.length} children',
                      color: rc,
                    )
                  else
                    TextFormField(
                      controller: _detail,
                      style: ink(17),
                      decoration: const InputDecoration(
                        labelText: 'Assignment',
                        hintText: 'e.g. Grade 3 Adviser - Section Sampaguita',
                        prefixIcon: Icon(Icons.work_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter the assignment'
                          : null,
                    ),
                  if (!_isParent && (a.role == kRoleTeacher || a.role == kRoleNurse)) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _employeeId,
                      style: ink(17),
                      decoration: const InputDecoration(
                        labelText: 'Employee ID',
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter the employee ID'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _school,
                      style: ink(17),
                      decoration: const InputDecoration(
                        labelText: 'Assigned School',
                        prefixIcon: Icon(Icons.school_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter the assigned school'
                          : null,
                    ),
                  ],
                  if (_isParent) ...[
                    const SizedBox(height: 18),
                    Text('Children', style: title(28, color: kGreen)),
                    Text(
                      'Tap the pencil to change the info of a child. '
                      'The child info is saved right away.',
                      style: ink(13, color: kInkSoft),
                    ),
                    const SizedBox(height: 6),
                    for (final c in _kids)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kInk.withAlpha(70)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: ink(17, weight: FontWeight.w700),
                                  ),
                                  Text(
                                    '${c.grade} • ${c.section} • ${c.ageY} yrs • ${c.girl ? 'Girl' : 'Boy'}',
                                    style: ink(13, color: kInkSoft),
                                  ),
                                  Text(
                                    'LRN ${c.lrn}',
                                    style: ink(13, color: kInkSoft),
                                  ),
                                  Text(
                                    'Allergies: ${c.allergies.isEmpty ? 'None' : c.allergies.join(', ')} • '
                                    'Medical: ${c.medicalStatus.isEmpty ? 'None' : c.medicalStatus}',
                                    style: ink(13, color: kInkSoft),
                                  ),
                                  const SizedBox(height: 4),
                                  StatusPill(info: c.status),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Edit child info',
                              icon: const Icon(
                                Icons.edit_rounded,
                                color: kGreen,
                              ),
                              onPressed: () => _editChild(c),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kInk, width: 1.4),
                        ),
                        child: Text(_isParent ? 'Close' : 'Cancel',
                            style: ink(15)),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(backgroundColor: kGreen),
                        child: Text(
                          'Save',
                          style: ink(15, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ADMIN: edit the info of a child (opened from the parent's User Records)
// ---------------------------------------------------------------------------
class _ChildEdit {
  final String name;
  final String lrn;
  final String grade;
  final String section;
  final int age;
  final bool girl;
  final List<String> allergies;
  final String medical;
  final String household;

  const _ChildEdit(
    this.name,
    this.lrn,
    this.grade,
    this.section,
    this.age,
    this.girl,
    this.allergies,
    this.medical,
    this.household,
  );
}

class _ChildEditDialog extends StatefulWidget {
  final Student student;
  final NutriStore store;

  const _ChildEditDialog({required this.student, required this.store});

  @override
  State<_ChildEditDialog> createState() => _ChildEditDialogState();
}

class _ChildEditDialogState extends State<_ChildEditDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _lrn;
  late final TextEditingController _section;
  late final TextEditingController _age;
  late final TextEditingController _allergy;
  late final TextEditingController _medical;

  late String grade;
  late bool girl;
  late String household;

  @override
  void initState() {
    super.initState();

    final Student s = widget.student;

    _name = TextEditingController(text: s.name);
    _lrn = TextEditingController(text: s.lrn);
    _section = TextEditingController(text: s.section);
    _age = TextEditingController(text: s.ageY.toString());
    _allergy = TextEditingController(text: s.allergies.join(', '));
    _medical = TextEditingController(text: s.medicalStatus);

    grade = s.grade;
    girl = s.girl;
    household = s.household;
  }

  @override
  void dispose() {
    _name.dispose();
    _section.dispose();
    _age.dispose();
    _allergy.dispose();
    _medical.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;

    Navigator.of(context).pop(
      _ChildEdit(
        _name.text.trim(),
        _lrn.text.trim(),
        grade,
        _section.text.trim(),
        int.parse(_age.text.trim()),
        girl,
        parseAllergies(_allergy.text),
        _medical.text.trim(),
        household,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String oldKey = NutriStore.keyOf(widget.student.name);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: PaperCard(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Child Info', style: title(32, color: kGreen)),
                  Text(
                    'Changes apply to all check-ups of this student.',
                    style: ink(14, color: kInkSoft),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _name,
                    style: ink(17),
                    decoration:
                        const InputDecoration(labelText: 'Student name'),
                    validator: (v) {
                      final String t = (v ?? '').trim();

                      if (t.isEmpty) return 'Please enter a name';

                      final String k = NutriStore.keyOf(t);

                      if (k != oldKey &&
                          widget.store.students
                              .any((x) => NutriStore.keyOf(x.name) == k)) {
                        return 'Another student already has this name';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _lrn,
                    style: ink(17),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Student LRN',
                      hintText: '12-digit LRN',
                    ),
                    validator: (v) {
                      final String t = (v ?? '').trim();

                      if (!RegExp(r'^\d{12}$').hasMatch(t)) {
                        return 'LRN must be 12 digits';
                      }

                      if (widget.store.students.any(
                        (x) =>
                            x.lrn == t && NutriStore.keyOf(x.name) != oldKey,
                      )) {
                        return 'This LRN belongs to another student';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _ChipRow(
                    label: 'Grade',
                    options: [
                      'Kindergarten',
                      for (var i = 1; i <= 6; i++) 'Grade $i',
                    ],
                    selected: grade,
                    onSelected: (v) => setState(() => grade = v),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _section,
                          style: ink(17),
                          decoration:
                              const InputDecoration(labelText: 'Section'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter a section'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _age,
                          style: ink(17),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Age',
                            suffixText: 'yrs',
                          ),
                          validator: (v) {
                            final int? n = int.tryParse(v ?? '');

                            return (n == null || n < 5 || n > 13)
                                ? '5 to 13 only'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 74,
                        child: Text(
                          'Gender',
                          style: ink(
                            16,
                            weight: FontWeight.w700,
                            color: kInkSoft,
                          ),
                        ),
                      ),
                      for (final g in const [true, false])
                        ChoiceChip(
                          avatar: Icon(
                            g ? Icons.female_rounded : Icons.male_rounded,
                            size: 18,
                            color: g == girl ? Colors.white : kInk,
                          ),
                          label: Text(g ? 'Girl' : 'Boy'),
                          selected: g == girl,
                          showCheckmark: false,
                          selectedColor: g ? kPink : kBlue,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: kInk, width: 1.4),
                          labelStyle: ink(
                            15,
                            color: g == girl ? Colors.white : kInk,
                            weight: g == girl ? FontWeight.w700 : null,
                          ),
                          onSelected: (_) => setState(() => girl = g),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _allergy,
                    style: ink(17),
                    decoration: const InputDecoration(
                      labelText: 'Allergies (optional)',
                      hintText: 'e.g. egg, peanuts, shrimp',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _medical,
                    style: ink(17),
                    decoration: const InputDecoration(
                      labelText: 'Medical status (optional)',
                      hintText: 'e.g. asthma, diabetes',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: household,
                    decoration:
                        const InputDecoration(labelText: 'Meal plan is for'),
                    items: [
                      for (final h in kHouseholdOptions)
                        DropdownMenuItem(value: h, child: Text(h)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => household = v);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kInk, width: 1.4),
                        ),
                        child: Text('Cancel', style: ink(15)),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(backgroundColor: kGreen),
                        child: Text(
                          'Save',
                          style: ink(15, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ===========================================================================
//  PARENT ACCOUNT PAGES
//  One parent account can have many children in grade school.
// ===========================================================================

// ---------------------------------------------------------------------------
// 1. SUMMARY DASHBOARD (nutritional health status of all the children)
// ---------------------------------------------------------------------------
class ParentSummaryPage extends StatelessWidget {
  final NutriStore store;
  final String email;

  const ParentSummaryPage({super.key, required this.store, required this.email});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final List<Student> kids = store.childrenOf(email);

        if (kids.isEmpty) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeader(
                  titleText: 'Summary Dashboard',
                  subtitle: 'The nutritional health of your children.',
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'No children are linked to this account yet.',
                    style: ink(20, color: kInkSoft),
                  ),
                ),
              ],
            ),
          );
        }

        final List<Student> measuredKids = kids.where((k) => k.measured).toList();
        final int normal = measuredKids.where((k) => k.status.label == 'Normal').length;
        final int attention = measuredKids.length - normal;
        final DateTime? last = measuredKids.isEmpty ? null : measuredKids
            .map((k) => k.measuredOn)
            .reduce((a, b) => a.isAfter(b) ? a : b);

        final List<Widget> kpis = [
          KpiCard(
            label: 'My Children',
            value: '${kids.length}',
            sub: 'in grade school',
            icon: Icons.family_restroom_rounded,
            color: kBlue,
          ),
          KpiCard(
            label: 'Healthy Weight',
            value: '$normal',
            sub: 'in the normal range',
            icon: Icons.check_circle_rounded,
            color: kGreen,
          ),
          KpiCard(
            label: 'Needs Attention',
            value: '$attention',
            sub: 'not in normal range',
            icon: Icons.flag_rounded,
            color: kYellow,
          ),
          KpiCard(
            label: 'Last Check-up',
            value: last == null ? '—' : shortDate(last),
            sub: last == null ? 'no check-up yet' : '${last.year}',
            icon: Icons.event_available_rounded,
            color: kPurple,
          ),
        ];

        return LayoutBuilder(
          builder: (context, c) {
            final double avail = c.maxWidth - 40;

            final int kpiCols = avail >= 900 ? 4 : 2;
            const double gap = 12;
            final double kw = (avail - gap * (kpiCols - 1)) / kpiCols;

            final int cardCols = avail >= 1000 ? 2 : 1;
            const double cardGap = 16;
            final double cw = (avail - cardGap * (cardCols - 1)) / cardCols;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHeader(
                    titleText: 'Summary Dashboard',
                    subtitle: 'The nutritional health of your children, at a glance.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final k in kpis)
                        SizedBox(width: kw, height: 124, child: k),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: cardGap,
                    runSpacing: cardGap,
                    children: [
                      for (final k in kids)
                        SizedBox(
                          width: cw,
                          child: _ChildStatusCard(store: store, child: k),
                        ),
                    ],
                  ),
                  if (measuredKids.length > 1) ...[
                    const SizedBox(height: 16),
                    ChartCard(
                      titleText: 'My Children Compared',
                      subtitle: 'Latest BMI of each child, colored by status',
                      child: BmiBarChart(students: measuredKids),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ChildStatusCard extends StatelessWidget {
  final NutriStore store;
  final Student child; // latest record of the child

  const _ChildStatusCard({required this.store, required this.child});

  @override
  Widget build(BuildContext context) {
    final Student s = child;
    final StatusInfo st = s.status;
    if (!s.measured) {
      return PaperCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name, style: title(34)),
          Text('${s.grade} • ${s.section} • ${s.ageY} yrs • ${s.girl ? 'Girl' : 'Boy'}', style: ink(14, color: kInkSoft)),
          const SizedBox(height: 10),
          Row(children: [const Icon(Icons.hourglass_empty_rounded, color: kInkSoft), const SizedBox(width: 8),
            Expanded(child: Text('Not measured yet. The teacher or school nurse will take the first measurement. You can also measure at home in the Measurement page.', style: ink(15, color: kInkSoft))),
          ]),
        ]),
      );
    }


    final List<Student> recs = store.recordsOf(s.name);
    final List<ProgressPair> pairs = buildPairs(recs);

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: st.color.withAlpha(40),
                child: Icon(
                  s.girl ? Icons.female_rounded : Icons.male_rounded,
                  color: st.color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: title(34)),
                    Text(
                      '${s.grade} • ${s.section} • ${s.ageY} yrs • ${s.girl ? 'Girl' : 'Boy'}',
                      style: ink(14, color: kInkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Latest: ${s.schoolYearPeriod} • ${fmtDate(s.measuredOn)}',
            style: ink(
              14,
              weight: FontWeight.w700,
              color: colorForPeriod(s.schoolYearPeriod),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatBubble(
                label: 'BMI',
                value: s.bmi.toStringAsFixed(1),
                color: st.color,
              ),
              _StatBubble(
                label: 'Z-score',
                value: s.z.toStringAsFixed(2),
                color: st.color,
              ),
              Transform.rotate(
                angle: -0.05,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: st.color, width: 3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(st.icon, color: st.color, size: 26),
                      const SizedBox(width: 6),
                      Text(st.label, style: title(28, color: st.color)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ZScaleBar(z: s.z),
          const SizedBox(height: 6),
          Text(healthyRangeText(s), style: ink(15, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: st.color.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.edit_note_rounded, color: st.color),
                const SizedBox(width: 10),
                Expanded(child: Text(st.advice, style: ink(15))),
              ],
            ),
          ),
          if (recs.length >= 2) ...[
            const SizedBox(height: 16),
            Text('BMI over time', style: title(24, color: kGreen)),
            const SizedBox(height: 6),
            BmiTrendChart(records: recs),
          ],
          if (pairs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: kInk.withAlpha(40)),
            Text('School year progress', style: title(24, color: kGreen)),
            _ProgressRow(pair: pairs.last),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. NUTRITION MEAL PLAN DASHBOARD
//    Separate plan for each child OR one shared plan for the selected children
// ---------------------------------------------------------------------------
const String kPlanSeparate = 'Separate plan for each child';
const String kPlanShared = 'One shared plan for all selected';

class _PlanResult {
  final List<Student> kids;
  final DailyPlan plan;
  final bool shared;

  const _PlanResult(this.kids, this.plan, this.shared);
}

class ParentMealPlanPage extends StatefulWidget {
  final NutriStore store;
  final String email;

  const ParentMealPlanPage({super.key, required this.store, required this.email});

  @override
  State<ParentMealPlanPage> createState() => _ParentMealPlanPageState();
}

class _ParentMealPlanPageState extends State<ParentMealPlanPage> {
  final Set<String> _picked = {}; // child names
  String _mode = kPlanSeparate;
  int _shuffle = 0;
  bool _made = false;
  bool _busy = false;
  bool _draftSaved = false;
  final Set<String> _changeSlots = <String>{};
  String _budgetMode = 'Budget for additional ingredients';
  String _mealScope = 'Whole day meal';
  List<_PlanResult> _results = [];

  // budget + food at home
  final TextEditingController _budget = TextEditingController();
  final TextEditingController _pantry = TextEditingController();
  final List<Uint8List> _photos = [];
  final ImagePicker _picker = ImagePicker();

  // meal plan information of each child (key = child name)
  final Map<String, TextEditingController> _allergyC = {};
  final Map<String, TextEditingController> _medicalC = {};
  final Map<String, String> _household = {};

  void _ensure(Student k) {
    _allergyC.putIfAbsent(
      k.name,
      () => TextEditingController(text: k.allergies.join(', ')),
    );
    _medicalC.putIfAbsent(
      k.name,
      () => TextEditingController(text: k.medicalStatus),
    );
    _household.putIfAbsent(k.name, () => k.household);
  }

  @override
  void initState() {
    super.initState();

    final List<Student> kids = widget.store.childrenOf(widget.email);

    _picked.addAll(kids.map((k) => k.name));

    for (final k in kids) {
      _ensure(k);
    }
  }

  @override
  void dispose() {
    _budget.dispose();
    _pantry.dispose();

    for (final c in _allergyC.values) {
      c.dispose();
    }

    for (final c in _medicalC.values) {
      c.dispose();
    }

    super.dispose();
  }

  Future<void> _addPhotos(ImageSource source) async {
    try {
      List<XFile> files = [];

      if (source == ImageSource.camera) {
        final XFile? x = await _picker.pickImage(
          source: source,
          maxWidth: 1280,
          imageQuality: 80,
        );

        if (x != null) files = [x];
      } else {
        files = await _picker.pickMultiImage(
          maxWidth: 1280,
          imageQuality: 80,
        );
      }

      final List<Uint8List> bytes = [
        for (final f in files) await f.readAsBytes(),
      ];

      if (!mounted) return;

      setState(() => _photos.addAll(bytes));
    } catch (_) {
      if (mounted) {
        showToast(context, 'Could not open the photo picker.', color: kRed);
      }
    }
  }

  DailyPlan _replaceMealSlots(
    DailyPlan current,
    DailyPlan alternative,
    Set<String> slotNames,
  ) {
    final List<PlannedMeal> meals = [
      for (final meal in current.meals)
        if (slotNames.contains(meal.slot.name))
          alternative.meals.firstWhere(
            (candidate) => candidate.slot.name == meal.slot.name,
            orElse: () => meal,
          )
        else
          meal,
    ];

    final double totalCost =
        meals.fold<double>(0, (sum, meal) => sum + meal.cost);

    return DailyPlan(
      current.kcal,
      meals,
      alternative.exercises,
      servings: current.servings,
      cost: totalCost,
      budget: alternative.budget,
      note: alternative.note,
    );
  }

  DailyPlan _applyMealScope(DailyPlan plan) {
    if (_mealScope == 'Whole day meal') return plan;

    final List<PlannedMeal> selectedMeals = plan.meals
        .where((meal) => meal.slot.name == _mealScope)
        .toList();
    final double totalCost = selectedMeals.fold<double>(
      0,
      (sum, meal) => sum + meal.cost,
    );

    return DailyPlan(
      plan.kcal,
      selectedMeals,
      plan.exercises,
      servings: plan.servings,
      cost: plan.cost == null ? null : totalCost,
      budget: plan.budget,
      note: _mealScope == 'Whole day meal'
          ? plan.note
          : 'Estimated cost for $_mealScope: PHP ${totalCost.toStringAsFixed(0)}.',
    );
  }

  Future<void> _generate() async {
    if (_busy) return;

    final List<Student> chosen = widget.store
        .childrenOf(widget.email)
        .where((k) => _picked.contains(k.name))
        .toList();

    if (chosen.isEmpty) {
      showToast(context, 'Pick at least one child first.', color: kRed);
      return;
    }

    double? budget;
    final String budgetText = _budget.text.trim().replaceAll(',', '');
    final bool needsBudget = _budgetMode == 'Budget for additional ingredients' ||
        _budgetMode == 'No ingredients at home';

    if (needsBudget && budgetText.isNotEmpty) {
      budget = double.tryParse(budgetText);
      if (budget == null || budget < 0) {
        showToast(context, 'Enter a valid budget amount.', color: kRed);
        return;
      }
    }

    final List<String> pantry = _pantry.text
        .split(RegExp(r'[,\n;]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    // Include the allergy notes in the request text so the AI can consider
    // them. The PHP endpoint should also receive a dedicated allergies field
    // in ApiService for stronger, explicit handling.
    final String allergyNotes = chosen
        .map((kid) => '${kid.name}: ${(_allergyC[kid.name]?.text ?? '').trim()}')
        .where((line) => !line.endsWith(':'))
        .join('; ');
    final String ingredientsText = <String>[
      if (pantry.isNotEmpty) 'Ingredients available at home: ${pantry.join(', ')}.',
      if (pantry.isEmpty) 'No ingredients list was provided; suggest common affordable Filipino ingredients.',
      if (allergyNotes.isNotEmpty) 'IMPORTANT ALLERGIES TO AVOID COMPLETELY: $allergyNotes.',
      'Create a balanced one-day meal plan for school-age children. Use the four meal slots Breakfast, Lunch, Snacks, and Dinner.',
      if (_mealScope != 'Whole day meal') 'Focus the displayed plan on $_mealScope, while returning the standard plan structure.',
      if (_budgetMode == 'No budget — stick with ingredients at home') 'Do not suggest buying additional ingredients; use only the ingredients listed as available at home.',
      if (_budgetMode == 'Budget for additional ingredients' && budget != null) 'Additional ingredient budget: PHP ${budget.toStringAsFixed(0)}.',
      if (_budgetMode == 'No ingredients at home' && budget != null) 'Total food budget: PHP ${budget.toStringAsFixed(0)}.',
    ].join(' ');

    setState(() {
      _busy = true;
    });

    try {
      final Map<String, dynamic> aiPlan = await ApiService.generateMealPlan(
        ingredients: ingredientsText,
        budget: budget == null ? '' : budget.toStringAsFixed(0),
        days: 1,
      );

      final List<dynamic> rawMeals = aiPlan['meals'] as List<dynamic>;
      final List<dynamic> rawExercises = aiPlan['exercises'] as List<dynamic>;
      final List<PlannedMeal> meals = [];

      for (final dynamic raw in rawMeals) {
        if (raw is! Map) continue;
        final String slotName = (raw['slot'] ?? '').toString().trim();
        SlotMeta? slot;
        for (final SlotMeta candidate in kSlots) {
          if (candidate.name.toLowerCase() == slotName.toLowerCase()) {
            slot = candidate;
            break;
          }
        }
        if (slot == null) continue;

        final List<PlannedIng> mealIngredients = [];
        final dynamic rawIngredients = raw['ingredients'];
        if (rawIngredients is List) {
          for (final dynamic ingredient in rawIngredients) {
            if (ingredient is Map) {
              final String name = (ingredient['name'] ?? '').toString().trim();
              final String amount = (ingredient['amount'] ?? '').toString().trim();
              if (name.isNotEmpty) {
                mealIngredients.add(
                  PlannedIng(
                    name,
                    amount.isEmpty ? 'as needed' : amount,
                    have: pantry.isNotEmpty && inPantry(name, pantry),
                  ),
                );
              }
            }
          }
        }

        final double aiCost = (raw['cost'] as num?)?.toDouble() ?? 0;
        final double estimatedCost = mealIngredients.fold<double>(
          0,
          (sum, ingredient) => sum + (ingredient.have ? 0 : 0),
        );

        meals.add(
          PlannedMeal(
            slot,
            (raw['dish'] ?? 'Balanced meal').toString(),
            ((raw['kcal'] as num?)?.round() ?? 0),
            mealIngredients,
            cost: aiCost >= 0 ? aiCost : estimatedCost,
          ),
        );
      }

      if (meals.isEmpty) {
        throw Exception('The AI response did not contain any usable meals.');
      }

      // Keep the existing meal-scope behavior and card layout.
      final DailyPlan plan = _applyMealScope(
        DailyPlan(
          ((aiPlan['total_kcal'] as num?)?.round() ??
              meals.fold<int>(0, (sum, meal) => sum + meal.kcal)),
          meals,
          [
            for (final dynamic raw in rawExercises)
              if (raw is Map)
                Exercise(
                  (raw['name'] ?? 'Light activity').toString(),
                  (raw['reps'] ?? '10 minutes').toString(),
                  (raw['tip'] ?? 'Take breaks and drink water.').toString(),
                  Icons.directions_walk_rounded,
                ),
          ],
          servings: _mode == kPlanShared ? chosen.length : 1,
          cost: meals.fold<double>(0, (sum, meal) => sum + meal.cost),
          budget: budget,
          note: budget == null
              ? 'AI-generated estimate. Check local prices and ingredient labels.'
              : 'AI-estimated cost; compare with your PHP ${budget.toStringAsFixed(0)} budget and local prices.',
        ),
      );

      final List<_PlanResult> newResults = [];
      if (_mode == kPlanShared) {
        newResults.add(_PlanResult(chosen, plan, true));
      } else {
        for (final Student kid in chosen) {
          newResults.add(_PlanResult([kid], plan, false));
        }
      }

      if (!mounted) return;
      setState(() {
        _results = newResults;
        _made = true;
        _draftSaved = false;
        _busy = false;
      });
      showToast(context, 'AI meal and exercise plan generated.', color: kGreen);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(
        context,
        'Could not generate the AI plan. Check that XAMPP is running and the PHP endpoint is reachable. ${e.toString().replaceFirst('Exception: ', '')}',
        color: kRed,
      );
    }
  }

  void _saveNutritionPlan() {
    if (_results.isEmpty) {
      showToast(context, 'Generate a nutrition plan first.', color: kRed);
      return;
    }
    if (_draftSaved) {
      showToast(context, 'This nutrition plan is already saved.');
      return;
    }

    final DateTime now = DateTime.now();
    for (final result in _results) {
      for (final k in result.kids) {
        widget.store.addMealPlan(
          k.name,
          MealPlanRecord(now, k.schoolYearPeriod, k.status.label, result.plan),
        );
      }
    }

    setState(() => _draftSaved = true);
    showToast(context, 'Nutrition plan saved to Meal Plan History.', color: kGreen);
  }

  Widget _resultSection(_PlanResult r) {
    if (!r.shared) {
      final Student k = r.kids.first;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaperCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: k.status.color.withAlpha(40),
                  child: Icon(
                    k.girl ? Icons.female_rounded : Icons.male_rounded,
                    color: k.status.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plan for ${k.name}', style: title(32)),
                      Text(
                        k.measured
                            ? '${k.grade} • BMI ${k.bmi.toStringAsFixed(1)} • z ${k.z.toStringAsFixed(2)}'
                            : '${k.grade} • not measured yet (balanced meals are used)',
                        style: ink(14, color: kInkSoft),
                      ),
                    ],
                  ),
                ),
                StatusPill(info: k.status),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PlanBlock(
            plan: r.plan,
            selectedMealSlots: _changeSlots,
            onMealTap: (slot) => setState(() {
              if (_changeSlots.contains(slot)) {
                _changeSlots.remove(slot);
              } else {
                _changeSlots.add(slot);
              }
            }),
            allergies: k.allergies,
            medicalNotes: [
              if (k.medicalStatus.trim().isNotEmpty)
                'Medical status of ${k.firstName}: ${k.medicalStatus}.',
            ],
          ),
        ],
      );
    }

    // ---- one shared plan ----
    final List<Student> kids = r.kids;
    final String group = sharedGroupOf(kids);
    final bool mixed = kids.map((k) => k.status.group).toSet().length > 1;

    final String groupText = switch (group) {
      'gain' => 'high-energy meals (all selected children need to gain weight)',
      'lose' => 'lighter meals (all selected children need to lose weight)',
      _ => mixed
          ? 'balanced meals, because the children have different needs'
          : 'balanced meals (all selected children are in the healthy range)',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.groups_rounded, color: kGreen, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'One plan for ${kids.map((k) => k.firstName).join(' & ')}',
                      style: title(32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in kids)
                    LegendChip(
                      text: '${k.firstName}: ${k.status.label}',
                      color: k.status.color,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'How this plan was made',
                style: ink(16, weight: FontWeight.w700, color: kInkSoft),
              ),
              const SizedBox(height: 4),
              Text('• Uses $groupText.', style: ink(15)),
              Text(
                '• Average energy of about ${r.plan.kcal} kcal per child.',
                style: ink(15),
              ),
              Text(
                unionAllergies(kids).isEmpty
                    ? '• No allergies were listed.'
                    : '• Avoids every allergy listed: ${unionAllergies(kids).join(', ')}.',
                style: ink(15),
              ),
              Text(
                '• Ingredient amounts are for ${r.plan.servings} ${r.plan.servings == 1 ? 'person' : 'family members'}.',
                style: ink(15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: kOrange, size: 28),
                  const SizedBox(width: 8),
                  Text('Portion guide per child',
                      style: title(28, color: kOrange)),
                ],
              ),
              Text(
                'Everyone eats the same meals, but each child gets the portion that fits their nutrition status.',
                style: ink(14, color: kInkSoft),
              ),
              const SizedBox(height: 10),
              for (final k in kids)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(k.status.icon, color: k.status.color, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${k.firstName} (${k.status.label})',
                              style: ink(16, weight: FontWeight.w700),
                            ),
                            Text(
                              portionTip(k, r.plan.kcal),
                              style: ink(14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PlanBlock(
          plan: r.plan,
          selectedMealSlots: _changeSlots,
          onMealTap: (slot) => setState(() {
            if (_changeSlots.contains(slot)) {
              _changeSlots.remove(slot);
            } else {
              _changeSlots.add(slot);
            }
          }),
          allergies: unionAllergies(kids),
          medicalNotes: [
            for (final k in kids)
              if (k.medicalStatus.trim().isNotEmpty)
                'Medical status of ${k.firstName}: ${k.medicalStatus}.',
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final List<Student> kids = widget.store.childrenOf(widget.email);

        for (final k in kids) {
          _ensure(k);
        }

        final List<Student> picked =
            kids.where((k) => _picked.contains(k.name)).toList();

        // ---------- who is the plan for ----------
        final Widget chooser = PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.child_care_rounded, color: kBlue, size: 28),
                  const SizedBox(width: 8),
                  Text('Who is the plan for?', style: title(28, color: kBlue)),
                ],
              ),
              Text(
                'Pick one or more children. Tap a child again to remove them.',
                style: ink(14, color: kInkSoft),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final k in kids)
                    FilterChip(
                      avatar: Icon(
                        k.status.icon,
                        size: 18,
                        color: _picked.contains(k.name)
                            ? Colors.white
                            : k.status.color,
                      ),
                      label: Text('${k.firstName} • ${k.status.label}'),
                      selected: _picked.contains(k.name),
                      showCheckmark: false,
                      selectedColor: k.status.color,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: kInk, width: 1.4),
                      labelStyle: ink(
                        15,
                        color: _picked.contains(k.name) ? Colors.white : kInk,
                        weight: _picked.contains(k.name)
                            ? FontWeight.w700
                            : null,
                      ),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _picked.add(k.name);
                        } else {
                          _picked.remove(k.name);
                        }
                      }),
                    ),
                ],
              ),
              if (picked.length > 1) ...[
                const SizedBox(height: 16),
                _ChipRow(
                  label: 'Plan',
                  options: const [kPlanSeparate, kPlanShared],
                  selected: _mode,
                  onSelected: (v) => setState(() => _mode = v),
                ),
                const SizedBox(height: 8),
                Text(
                  _mode == kPlanShared
                      ? 'One meal plan for the whole family table. It follows the nutrition status and allergies of all the selected children, so it is helpful for every one of them.'
                      : 'Each child gets their own plan based on their own nutrition status and allergies.',
                  style: ink(14, color: kInkSoft),
                ),
              ],
            ],
          ),
        );

        // ---------- meal plan information (per child) ----------
        final Widget infoCard = PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.restaurant_menu_rounded,
                    color: kGreen,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text('Meal Plan Information',
                      style: title(28, color: kGreen)),
                ],
              ),
              Text(
                'Allergies, medical status and who will eat the meals. The plan follows this information.',
                style: ink(14, color: kInkSoft),
              ),
              const SizedBox(height: 12),
              if (picked.isEmpty)
                Text(
                  'Pick a child above first.',
                  style: ink(15, color: kInkSoft),
                )
              else
                for (final k in picked)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kInk.withAlpha(70)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(k.name, style: ink(18, weight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _allergyC[k.name],
                          style: ink(17),
                          decoration: const InputDecoration(
                            labelText: 'Allergies (optional)',
                            hintText:
                                'e.g. egg, peanuts, shrimp (leave blank if none)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _medicalC[k.name],
                          style: ink(17),
                          decoration: const InputDecoration(
                            labelText: 'Medical status (optional)',
                            hintText:
                                'e.g. asthma, diabetes (leave blank if none)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey('hh${k.name}${_household[k.name]}'),
                          initialValue: _household[k.name],
                          decoration: const InputDecoration(
                            labelText: 'Meal plan is for',
                          ),
                          items: [
                            for (final h in kHouseholdOptions)
                              DropdownMenuItem(value: h, child: Text(h)),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _household[k.name] = v);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        );

        // ---------- budget + food at home ----------
        final Widget budgetCard = PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.payments_rounded, color: kOrange, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Budget & Food at Home',
                      style: title(28, color: kOrange),
                    ),
                  ),
                ],
              ),
              Text(
                'Choose which meals to generate and how to use your budget and ingredients at home.',
                style: ink(14, color: kInkSoft),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey('meal-scope-$_mealScope'),
                initialValue: _mealScope,
                decoration: const InputDecoration(
                  labelText: 'For which meals?',
                  prefixIcon: Icon(Icons.restaurant_menu_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'Breakfast', child: Text('Breakfast only')),
                  DropdownMenuItem(value: 'Lunch', child: Text('Lunch only')),
                  DropdownMenuItem(value: 'Snacks', child: Text('Snacks only')),
                  DropdownMenuItem(value: 'Dinner', child: Text('Dinner only')),
                  DropdownMenuItem(value: 'Whole day meal', child: Text('Whole day meal')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _mealScope = value;
                    _changeSlots.clear();
                  });
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                key: ValueKey('budget-mode-$_budgetMode'),
                initialValue: _budgetMode,
                decoration: const InputDecoration(
                  labelText: 'Budget and ingredient option',
                  prefixIcon: Icon(Icons.tune_rounded),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Budget for additional ingredients',
                    child: Text('Budget for additional ingredients'),
                  ),
                  DropdownMenuItem(
                    value: 'No budget — stick with ingredients at home',
                    child: Text('No budget — stick with ingredients at home'),
                  ),
                  DropdownMenuItem(
                    value: 'No ingredients at home',
                    child: Text('No ingredients at home'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _budgetMode = value);
                },
              ),
              const SizedBox(height: 14),
              if (_budgetMode == 'Budget for additional ingredients' ||
                  _budgetMode == 'No ingredients at home')
                TextField(
                  controller: _budget,
                  style: ink(18),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _budgetMode == 'No ingredients at home'
                        ? 'Budget for ingredients to buy (PHP)'
                        : (_mealScope == 'Whole day meal'
                            ? 'Budget for the whole day (PHP)'
                            : 'Budget for $_mealScope (PHP)'),
                    hintText: _budgetMode == 'No ingredients at home'
                        ? 'e.g. 250 PHP to buy ingredients'
                        : (_mealScope == 'Whole day meal'
                            ? 'e.g. 250 PHP for the whole day'
                            : 'e.g. 80 PHP for $_mealScope'),
                    prefixIcon: const Icon(Icons.payments_rounded),
                  ),
                ),
              const SizedBox(height: 14),
              if (_budgetMode != 'No ingredients at home')
                TextField(
                  controller: _pantry,
                  style: ink(18),
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Available ingredients at home',
                    hintText: 'e.g. rice, egg, kangkong, tomato, chicken',
                    prefixIcon: Icon(Icons.kitchen_rounded),
                  ),
                ),
              if (_budgetMode != 'No ingredients at home') ...[
              const SizedBox(height: 14),
              Text(
                'Photo of the food you have',
                style: ink(16, weight: FontWeight.w700, color: kInkSoft),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _addPhotos(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded, color: kBlue),
                    label: Text('Attach photo',
                        style: ink(15, weight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kInk, width: 1.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _addPhotos(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_rounded, color: kGreen),
                    label: Text('Take photo',
                        style: ink(15, weight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kInk, width: 1.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
              if (_photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < _photos.length; i++)
                      SizedBox(
                        width: 92,
                        height: 92,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _photos[i],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _photos.removeAt(i)),
                                child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: kRed,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Tip: type the ingredients too. Reading the food inside a photo needs an image-recognition service to be connected (see recognizeFoodPhotos).',
                style: ink(13, color: kInkSoft),
              ),
              ],
            ],
          ),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                titleText: 'Nutrition Meal Plan',
                subtitle:
                    'Generate a daily meal plan and exercises for your children.',
              ),
              const SizedBox(height: 16),
              chooser,
              const SizedBox(height: 16),
              infoCard,
              const SizedBox(height: 16),
              budgetCard,
              const SizedBox(height: 16),
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.refresh_rounded, color: kPurple, size: 26),
                        const SizedBox(width: 8),
                        Text('Meal Preference', style: title(27, color: kPurple)),
                      ],
                    ),
                    Text(
                      'The meal scope above controls whether you generate one meal or the whole day. You can also tap multiple visible meal cards to select or unselect them for regeneration. Your budget and available ingredients still apply.',
                      style: ink(14, color: kInkSoft),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _changeSlots.isEmpty
                          ? 'Selected meals: none (generate all meals)'
                          : 'Selected meals: ${_changeSlots.join(', ')}',
                      style: ink(14, color: kGreen, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(color: kGreen),
                        )
                      : SketchButton(
                          label: _made
                              ? (_changeSlots.isEmpty
                                  ? 'Generate Another Plan'
                                  : 'Regenerate Selected Meals')
                              : 'Generate Nutrition Plan',
                          icon: Icons.restaurant_menu_rounded,
                          onTap: _generate,
                        ),
                  if (_results.isNotEmpty)
                    SketchButton(
                      label: _draftSaved ? 'Nutrition Plan Saved' : 'Save Nutrition Plan',
                      icon: _draftSaved ? Icons.check_circle_rounded : Icons.save_rounded,
                      onTap: _draftSaved ? () {} : _saveNutritionPlan,
                    ),
                ],
              ),
              for (final r in _results) ...[
                const SizedBox(height: 20),
                _resultSection(r),
              ],
              if (picked.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Meal Plan History', style: title(34, color: kOrange)),
                Text(
                  'Saved plans appear here as records and cannot be edited.',
                  style: ink(14, color: kInkSoft),
                ),
                const SizedBox(height: 10),
                for (final k in picked) ...[
                  Text(k.name, style: title(26)),
                  const SizedBox(height: 6),
                  _MealHistoryCard(
                    history: widget.store.mealHistory[NutriStore.keyOf(k.name)] ??
                        const [],
                  ),
                  const SizedBox(height: 14),
                ],
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 3. MEASUREMENT DASHBOARD (height, weight, age, gender - done at home)
// ---------------------------------------------------------------------------
class ParentMeasurementPage extends StatefulWidget {
  final NutriStore store;
  final String email;

  const ParentMeasurementPage({
    super.key,
    required this.store,
    required this.email,
  });

  @override
  State<ParentMeasurementPage> createState() => _ParentMeasurementPageState();
}

class _ParentMeasurementPageState extends State<ParentMeasurementPage> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  final TextEditingController _age = TextEditingController();
  final TextEditingController _h = TextEditingController();
  final TextEditingController _w = TextEditingController();
  final TextEditingController _dateC = TextEditingController();

  String? _child; // selected child name
  bool _girl = true;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();

    _dateC.text = fmtDate(_date);

    final List<Student> kids = widget.store.childrenOf(widget.email);

    if (kids.isNotEmpty) _select(kids.first, notify: false);
  }

  @override
  void dispose() {
    _age.dispose();
    _h.dispose();
    _w.dispose();
    _dateC.dispose();
    super.dispose();
  }

  void _select(Student k, {bool notify = true}) {
    void apply() {
      _child = k.name;
      _age.text = k.ageY.toString();
      _girl = k.girl;
      _h.clear();
      _w.clear();
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  Future<void> _pickDate() async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (d != null) {
      setState(() {
        _date = d;
        _dateC.text = fmtDate(d);
      });
    }
  }

  Student? _preview(Student base) {
    final int? a = int.tryParse(_age.text.trim());
    final double? h = double.tryParse(_h.text.trim());
    final double? w = double.tryParse(_w.text.trim());

    if (a == null || h == null || w == null) return null;

    if (a < 5 || a > 13 || h < 80 || h > 200 || w < 8 || w > 120) return null;

    return base.copyWith(
      girl: _girl,
      ageY: a,
      ageM: 0,
      heightCm: h,
      weightKg: w,
      schoolYearPeriod: kHome,
      measuredOn: _date,
    );
  }

  void _save(Student base) {
    if (!_form.currentState!.validate()) {
      showToast(context, 'Please fix the fields marked in red first.',
          color: kRed);
      return;
    }

    final Student? s = _preview(base);

    if (s == null) return;

    widget.store.addRecord(s, actorRole: kRoleParent,
      actorName: widget.store.parentNameFor(widget.email), actorEmail: widget.email);

    setState(() {
      _h.clear();
      _w.clear();
    });

    showToast(
      context,
      'Saved! ${s.firstName} is ${s.status.label} (BMI ${s.bmi.toStringAsFixed(1)}).',
      color: kGreen,
    );
  }

  Future<void> _delete(Student s) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete this home check?', style: title(28)),
        content: Text(
          '${fmtDate(s.measuredOn)} • BMI ${s.bmi.toStringAsFixed(1)}',
          style: ink(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: ink(15)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: Text('Delete', style: ink(15, color: Colors.white)),
          ),
        ],
      ),
    );

    if (yes == true) widget.store.removeRecord(s);
  }

  Widget _field(
    TextEditingController c,
    String label,
    String suffix,
    String? Function(String?) validator, {
    bool decimal = true,
  }) {
    return TextFormField(
      controller: c,
      style: ink(18),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      validator: validator,
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final List<Student> kids = widget.store.childrenOf(widget.email);

        if (kids.isEmpty || _child == null) {
          return const Center(child: Text('No children linked to this account.'));
        }

        final Student? base = widget.store.latestOf(_child!);

        if (base == null) {
          return const Center(child: Text('No record found.'));
        }

        final Student? preview = _preview(base);

        final List<Student> recs = widget.store.recordsOf(base.name).where((s) => s.measured).toList();

        final Widget chooser = PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.child_care_rounded, color: kBlue, size: 28),
                  const SizedBox(width: 8),
                  Text('Which child?', style: title(28, color: kBlue)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final k in kids)
                    ChoiceChip(
                      avatar: Icon(
                        k.girl ? Icons.female_rounded : Icons.male_rounded,
                        size: 18,
                        color: k.name == _child ? Colors.white : kInk,
                      ),
                      label: Text('${k.name} • ${k.grade}'),
                      selected: k.name == _child,
                      showCheckmark: false,
                      selectedColor: k.girl ? kPink : kBlue,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: kInk, width: 1.4),
                      labelStyle: ink(
                        15,
                        color: k.name == _child ? Colors.white : kInk,
                        weight: k.name == _child ? FontWeight.w700 : null,
                      ),
                      onSelected: (_) => _select(k),
                    ),
                ],
              ),
            ],
          ),
        );

        final Widget form = PaperCard(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.home_rounded, color: kPurple, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Measure at home',
                        style: title(28, color: kPurple),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Great for the summer break. It is saved as a "$kHome" for ${base.firstName}.',
                  style: ink(14, color: kInkSoft),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _dateC,
                  readOnly: true,
                  style: ink(18),
                  decoration: const InputDecoration(
                    labelText: 'Date of measurement',
                    suffixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 74,
                      child: Text(
                        'Gender',
                        style: ink(
                          16,
                          weight: FontWeight.w700,
                          color: kInkSoft,
                        ),
                      ),
                    ),
                    for (final g in const [true, false])
                      ChoiceChip(
                        avatar: Icon(
                          g ? Icons.female_rounded : Icons.male_rounded,
                          size: 18,
                          color: g == _girl ? Colors.white : kInk,
                        ),
                        label: Text(g ? 'Girl' : 'Boy'),
                        selected: g == _girl,
                        showCheckmark: false,
                        selectedColor: g ? kPink : kBlue,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: kInk, width: 1.4),
                        labelStyle: ink(
                          15,
                          color: g == _girl ? Colors.white : kInk,
                          weight: g == _girl ? FontWeight.w700 : null,
                        ),
                        onSelected: (_) => setState(() => _girl = g),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _age,
                        'Age',
                        'yrs',
                        (v) {
                          final int? n = int.tryParse(v ?? '');

                          return (n == null || n < 5 || n > 13)
                              ? 'Ages 5 to 13 only'
                              : null;
                        },
                        decimal: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        _h,
                        'Height',
                        'cm',
                        (v) {
                          final double? n = double.tryParse(v ?? '');

                          return (n == null || n < 80 || n > 200)
                              ? 'Enter 80 to 200 cm'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        _w,
                        'Weight',
                        'kg',
                        (v) {
                          final double? n = double.tryParse(v ?? '');

                          return (n == null || n < 8 || n > 120)
                              ? 'Enter 8 to 120 kg'
                              : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: SketchButton(
                    label: 'Save Measurement',
                    icon: Icons.save_rounded,
                    onTap: () => _save(base),
                  ),
                ),
              ],
            ),
          ),
        );

        final Widget result = preview != null
            ? MeasurePreviewCard(
                student: preview,
                heading: 'Result',
                subtitle: 'Computed automatically while you type.',
              )
            : PaperCard(
                child: Row(
                  children: [
                    const Icon(Icons.calculate_rounded, color: kInkSoft),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Enter the age, height and weight to see the BMI, z-score and nutrition status.',
                        style: ink(16, color: kInkSoft),
                      ),
                    ),
                  ],
                ),
              );

        final Widget history = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${base.firstName}\'s Measurement History',
                style: title(32, color: kOrange)),
            Text(
              'School check-ups and your home checks. Only home checks can be deleted.',
              style: ink(14, color: kInkSoft),
            ),
            const SizedBox(height: 10),
            if (recs.length >= 2) ...[
              ChartCard(
                titleText: 'BMI Over Time',
                subtitle: 'Watch your child\'s progress during the break',
                child: BmiTrendChart(records: recs),
              ),
              const SizedBox(height: 14),
            ],
            LayoutBuilder(
              builder: (context, c) {
                final int cols = c.maxWidth >= 800 ? 2 : 1;

                const double gap = 16;

                final double w = (c.maxWidth - gap * (cols - 1)) / cols;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final s in recs.reversed)
                      SizedBox(
                        width: w,
                        child: MeasurementRecordCard(
                          record: s,
                          onDelete: s.schoolYearPeriod == kHome
                              ? () => _delete(s)
                              : null,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );

        return LayoutBuilder(
          builder: (context, c) {
            final bool wide = c.maxWidth >= 1000;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHeader(
                    titleText: 'Measurement',
                    subtitle:
                        'Measure your child at home (height, weight, age and gender) to keep track of their health during school breaks.',
                  ),
                  const SizedBox(height: 16),
                  chooser,
                  const SizedBox(height: 16),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: form),
                        const SizedBox(width: 16),
                        Expanded(child: result),
                      ],
                    )
                  else ...[
                    form,
                    const SizedBox(height: 16),
                    result,
                  ],
                  const SizedBox(height: 24),
                  history,
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 4. USER ACCOUNT (parent info + all the info of the children)
//    Email and password cannot be changed.
// ---------------------------------------------------------------------------
class ParentAccountPage extends StatelessWidget {
  final NutriStore store;
  final String email;

  const ParentAccountPage({super.key, required this.store, required this.email});

  Future<void> _editPhone(BuildContext context, String current) async {
    final String? phone = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PhoneDialog(current: current),
    );

    if (phone == null || !context.mounted) return;

    store.updateParentPhone(email, phone);

    showToast(context, 'Phone number updated.', color: kGreen);
  }

  Future<void> _editHealth(BuildContext context, Student s) async {
    final _HealthEdit? e = await showDialog<_HealthEdit>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _HealthInfoDialog(student: s),
    );

    if (e == null || !context.mounted) return;

    store.updateHealthInfo(
      s.name,
      allergies: e.allergies,
      medical: e.medical,
      household: e.household,
    );

    showToast(context, 'Saved the health info of ${s.firstName}.',
        color: kGreen);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final List<Student> kids = store.childrenOf(email);

        final String phone = kids.isEmpty ? '' : kids.first.parentPhone;
        final String password = kids.isEmpty ? '' : kids.first.parentPassword;

        final Widget parentCard = PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: kGreenLight,
                    child: Icon(
                      Icons.family_restroom_rounded,
                      color: kGreen,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store.parentNameFor(email), style: title(36)),
                        const RoleChip(
                          label: 'Parent Account',
                          color: kGreen,
                          icon: Icons.family_restroom_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LockedField(
                label: 'Email',
                value: email,
                icon: Icons.email_rounded,
              ),
              const SizedBox(height: 14),
              LockedField(
                label: 'Password',
                value: password,
                icon: Icons.lock_rounded,
                secret: true,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: InfoRow(
                      icon: Icons.phone_rounded,
                      label: 'Phone number',
                      value: phone,
                      color: kGreen,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _editPhone(context, phone),
                    icon: const Icon(Icons.edit_rounded, color: kGreen, size: 18),
                    label: Text('Edit', style: ink(14, weight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kInk, width: 1.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const LockNote(
                text:
                    'Your email and password cannot be changed here. '
                    'Please contact the school admin if you need help with your account.',
              ),
            ],
          ),
        );

        final Widget kidCards = LayoutBuilder(
          builder: (context, c) {
            final int cols = c.maxWidth >= 900 ? 2 : 1;

            const double gap = 16;

            final double w = (c.maxWidth - gap * (cols - 1)) / cols;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final k in kids)
                  SizedBox(
                    width: w,
                    child: _ChildInfoCard(
                      student: k,
                      onEdit: () => _editHealth(context, k),
                    ),
                  ),
              ],
            );
          },
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                titleText: 'User Account',
                subtitle:
                    'Your account information and the information of your children.',
              ),
              const SizedBox(height: 16),
              parentCard,
              const SizedBox(height: 24),
              Text('My Children', style: title(34, color: kBlue)),
              Text(
                'The information entered when the account was created.',
                style: ink(14, color: kInkSoft),
              ),
              const SizedBox(height: 10),
              kidCards,
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _ChildInfoCard extends StatelessWidget {
  final Student student;
  final VoidCallback onEdit;

  const _ChildInfoCard({required this.student, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final Student s = student;

    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: (s.girl ? kPink : kBlue).withAlpha(45),
                child: Icon(
                  s.girl ? Icons.female_rounded : Icons.male_rounded,
                  color: s.girl ? kPink : kBlue,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(s.name, style: title(32))),
              StatusPill(info: s.status),
            ],
          ),
          const SizedBox(height: 14),
          infoGrid([
            InfoRow(
              icon: Icons.numbers_rounded,
              label: 'LRN',
              value: s.lrn,
            ),
            InfoRow(
              icon: Icons.school_rounded,
              label: 'Grade',
              value: s.grade,
            ),
            InfoRow(
              icon: Icons.meeting_room_rounded,
              label: 'Section',
              value: s.section,
            ),
            InfoRow(
              icon: Icons.cake_rounded,
              label: 'Age',
              value: '${s.ageY} yrs',
            ),
            InfoRow(
              icon: s.girl ? Icons.female_rounded : Icons.male_rounded,
              label: 'Gender',
              value: s.girl ? 'Girl' : 'Boy',
              color: s.girl ? kPink : kBlue,
            ),
            InfoRow(
              icon: Icons.groups_rounded,
              label: 'Meal plan is for',
              value: s.household,
              color: kGreen,
            ),
            InfoRow(
              icon: Icons.block_rounded,
              label: 'Allergies',
              value: s.allergies.isEmpty ? 'None' : s.allergies.join(', '),
              color: kRed,
            ),
            InfoRow(
              icon: Icons.medical_services_rounded,
              label: 'Medical status',
              value: s.medicalStatus.isEmpty ? 'None' : s.medicalStatus,
              color: kPurple,
            ),
          ]),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, color: kGreen, size: 18),
              label: Text(
                'Edit allergies, medical & meal plan info',
                style: ink(14, weight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kInk, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Name, LRN, grade, section and age are kept by the school.',
            style: ink(13, color: kInkSoft),
          ),
        ],
      ),
    );
  }
}

class _PhoneDialog extends StatefulWidget {
  final String current;

  const _PhoneDialog({required this.current});

  @override
  State<_PhoneDialog> createState() => _PhoneDialogState();
}

class _PhoneDialogState extends State<_PhoneDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: PaperCard(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Phone Number', style: title(32, color: kGreen)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _c,
                  style: ink(17),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '09XXXXXXXXX',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                  validator: validatePhone,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kInk, width: 1.4),
                      ),
                      child: Text('Cancel', style: ink(15)),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () {
                        if (!_form.currentState!.validate()) return;

                        Navigator.of(context).pop(cleanPhone(_c.text));
                      },
                      style: FilledButton.styleFrom(backgroundColor: kGreen),
                      child: Text('Save', style: ink(15, color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HealthEdit {
  final List<String> allergies;
  final String medical;
  final String household;

  const _HealthEdit(this.allergies, this.medical, this.household);
}

class _HealthInfoDialog extends StatefulWidget {
  final Student student;

  const _HealthInfoDialog({required this.student});

  @override
  State<_HealthInfoDialog> createState() => _HealthInfoDialogState();
}

class _HealthInfoDialogState extends State<_HealthInfoDialog> {
  late final TextEditingController _allergy;
  late final TextEditingController _medical;
  late String household;

  @override
  void initState() {
    super.initState();

    _allergy = TextEditingController(text: widget.student.allergies.join(', '));
    _medical = TextEditingController(text: widget.student.medicalStatus);
    household = widget.student.household;
  }

  @override
  void dispose() {
    _allergy.dispose();
    _medical.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: PaperCard(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Health Info', style: title(32, color: kGreen)),
                Text(
                  widget.student.name,
                  style: ink(15, weight: FontWeight.w700, color: kInkSoft),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _allergy,
                  style: ink(17),
                  decoration: const InputDecoration(
                    labelText: 'Allergies (optional)',
                    hintText: 'e.g. egg, peanuts, shrimp',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _medical,
                  style: ink(17),
                  decoration: const InputDecoration(
                    labelText: 'Medical status (optional)',
                    hintText: 'e.g. asthma, diabetes',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: household,
                  decoration: const InputDecoration(
                    labelText: 'Meal plan is for',
                  ),
                  items: [
                    for (final h in kHouseholdOptions)
                      DropdownMenuItem(value: h, child: Text(h)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => household = v);
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kInk, width: 1.4),
                      ),
                      child: Text('Cancel', style: ink(15)),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        _HealthEdit(
                          parseAllergies(_allergy.text),
                          _medical.text.trim(),
                          household,
                        ),
                      ),
                      style: FilledButton.styleFrom(backgroundColor: kGreen),
                      child: Text('Save', style: ink(15, color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ===========================================================================
//  TEACHER: STUDENT RECORDS
//  The teacher can only see and edit the student INFO
//  (grade, section and age). No nutrition status is shown here.
// ===========================================================================
class TeacherStudentsPage extends StatefulWidget {
  final NutriStore store;

  const TeacherStudentsPage({super.key, required this.store});

  @override
  State<TeacherStudentsPage> createState() => _TeacherStudentsPageState();
}

class _TeacherStudentsPageState extends State<TeacherStudentsPage> {
  String gradeFilter = 'All';

  final TextEditingController _searchC = TextEditingController();
  String query = '';

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  void _open(Student s) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentRecordDetailPage(
          store: widget.store,
          name: s.name,
          canEdit: false, // teacher: view only, the info is edited with the pencil
        ),
      ),
    );
  }

  Future<void> _edit(Student s) async {
    final _InfoEdit? e = await showDialog<_InfoEdit>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditStudentInfoDialog(student: s),
    );

    if (e == null || !mounted) return;

    widget.store.updateStudentInfo(
      s.name,
      grade: e.grade,
      section: e.section,
      ageY: e.age,
    );

    showToast(context, 'Updated the info of ${s.firstName}.', color: kGreen);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final List<Student> all = widget.store.latestPerChild();

        final List<Student> list = all.where((s) {
          final bool gradeMatch = gradeFilter == 'All' || s.grade == gradeFilter;

          return gradeMatch && studentMatchesQuery(s, query);
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                titleText: 'Student Records',
                subtitle:
                    'Tap a student to see the nutrition status, meal plan, exercises and history. Use the pencil to update grade, section and age.',
              ),
              const SizedBox(height: 16),
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchC,
                      style: ink(18),
                      decoration: InputDecoration(
                        labelText: 'Search student (name or LRN)',
                        hintText: 'Type a name or LRN',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _searchC.clear();
                                  setState(() => query = '');
                                },
                              ),
                      ),
                      onChanged: (v) => setState(() => query = v),
                    ),
                    const SizedBox(height: 14),
                    _ChipRow(
                      label: 'Grade',
                      options: [
                        'All',
                        'Kindergarten',
                        for (var i = 1; i <= 6; i++) 'Grade $i',
                      ],
                      selected: gradeFilter,
                      onSelected: (v) => setState(() => gradeFilter = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Showing ${list.length} of ${all.length} students',
                  style: ink(14, color: kInkSoft),
                ),
              ),
              const SizedBox(height: 8),
              PaperCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No students match this filter.',
                            style: ink(16, color: kInkSoft),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < list.length; i++) ...[
                            _TeacherRow(
                              student: list[i],
                              onOpen: () => _open(list[i]),
                              onEdit: () => _edit(list[i]),
                            ),
                            if (i != list.length - 1)
                              Divider(height: 1, color: kInk.withAlpha(40)),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TeacherRow extends StatelessWidget {
  final Student student;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  const _TeacherRow({
    required this.student,
    required this.onOpen,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final Student s = student;
    final Color gc = s.girl ? kPink : kBlue;

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: gc.withAlpha(40),
            child: Icon(
              s.girl ? Icons.female_rounded : Icons.male_rounded,
              color: gc,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ink(18, weight: FontWeight.w700),
                ),
                Text('LRN ${s.lrn}', style: ink(13, color: kInkSoft)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    LegendChip(text: s.grade, color: kBlue),
                    LegendChip(text: s.section, color: kGreen),
                    LegendChip(text: '${s.ageY} yrs', color: kOrange),
                    LegendChip(text: s.girl ? 'Girl' : 'Boy', color: gc),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Edit student info',
            icon: const Icon(Icons.edit_rounded, color: kGreen),
            onPressed: onEdit,
          ),
          const Icon(Icons.chevron_right_rounded, color: kInkSoft),
        ],
      ),
      ),
    );
  }
}

class _InfoEdit {
  final String grade;
  final String section;
  final int age;

  const _InfoEdit(this.grade, this.section, this.age);
}

class _EditStudentInfoDialog extends StatefulWidget {
  final Student student;

  const _EditStudentInfoDialog({required this.student});

  @override
  State<_EditStudentInfoDialog> createState() => _EditStudentInfoDialogState();
}

class _EditStudentInfoDialogState extends State<_EditStudentInfoDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final TextEditingController _section;
  late final TextEditingController _age;
  late String grade;

  @override
  void initState() {
    super.initState();

    _section = TextEditingController(text: widget.student.section);
    _age = TextEditingController(text: widget.student.ageY.toString());
    grade = widget.student.grade;
  }

  @override
  void dispose() {
    _section.dispose();
    _age.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;

    Navigator.of(context).pop(
      _InfoEdit(grade, _section.text.trim(), int.parse(_age.text.trim())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Student s = widget.student;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: PaperCard(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Student Info', style: title(32, color: kGreen)),
                  Text(
                    '${s.name} • LRN ${s.lrn} • ${s.girl ? 'Girl' : 'Boy'}',
                    style: ink(14, color: kInkSoft),
                  ),
                  const SizedBox(height: 14),
                  _ChipRow(
                    label: 'Grade',
                    options: [
                      'Kindergarten',
                      for (var i = 1; i <= 6; i++) 'Grade $i',
                    ],
                    selected: grade,
                    onSelected: (v) => setState(() => grade = v),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _section,
                    style: ink(17),
                    decoration: const InputDecoration(labelText: 'Section'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter a section'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _age,
                    style: ink(17),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      suffixText: 'yrs',
                    ),
                    validator: (v) {
                      final int? n = int.tryParse(v ?? '');

                      return (n == null || n < 5 || n > 13)
                          ? 'Ages 5 to 13 only'
                          : null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Changing the age updates the latest check-up of the student.',
                    style: ink(13, color: kInkSoft),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kInk, width: 1.4),
                        ),
                        child: Text('Cancel', style: ink(15)),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(backgroundColor: kGreen),
                        child: Text(
                          'Save',
                          style: ink(15, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// ADD NEW STUDENT + PARENT (admin)
// 1. Student Information   2. Assign Parents
// The measurement is taken later by the teacher or the school nurse.
// ---------------------------------------------------------------------------
class CheckupPage extends StatefulWidget {
  final List<Student> students; // existing records (for duplicate check)
  final void Function(Student, String) onSave;
  final void Function(Student) onOpen;
  final VoidCallback onViewStudents;

  // true when the email already belongs to a staff account
  final bool Function(String email)? emailBlocked;

  const CheckupPage({
    super.key,
    required this.students,
    required this.onSave,
    required this.onOpen,
    required this.onViewStudents,
    this.emailBlocked,
  });

  @override
  State<CheckupPage> createState() => _CheckupPageState();
}

class _CheckupPageState extends State<CheckupPage> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _lrn = TextEditingController();
  final TextEditingController _section = TextEditingController();
  final TextEditingController _ageY = TextEditingController();

  // ASSIGN PARENTS (account that manages the student)
  final TextEditingController _parentName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _showPass = false;
  bool _showConfirm = false;

  String grade = 'Grade 1';
  bool girl = true;

  @override
  void dispose() {
    _name.dispose();
    _lrn.dispose();
    _section.dispose();
    _ageY.dispose();
    _parentName.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _clearForm() {
    _name.clear();
    _lrn.clear();
    _section.clear();
    _ageY.clear();
    _parentName.clear();
    _email.clear();
    _phone.clear();
    _pass.clear();
    _confirm.clear();

    // remove leftover red error messages
    _form.currentState?.reset();

    setState(() {
      _showPass = false;
      _showConfirm = false;
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      showToast(
        context,
        'Please fix the fields marked in red first.',
        color: kRed,
      );
      return;
    }

    final String name = _name.text.trim();
    final String lrn = _lrn.text.trim();
    final String parentName = _parentName.text.trim();
    final String email = _email.text.trim().toLowerCase();
    final String phone = cleanPhone(_phone.text);

    final bool duplicate = widget.students.any(
      (x) =>
          x.name.trim().toLowerCase() == name.toLowerCase() || x.lrn == lrn,
    );

    if (duplicate) {
      showToast(
        context,
        'A student with this name or LRN already exists.',
        color: kRed,
      );
      return;
    }

    if (widget.emailBlocked != null && widget.emailBlocked!(email)) {
      showToast(
        context,
        'The email $email already belongs to a staff account.',
        color: kRed,
      );
      return;
    }

    // Create the parent account in MySQL through the authenticated PHP API.
    // The API sends a password-setup email; it does not use the typed password.
    try {
      await ApiService.createUser(
        fullName: parentName,
        email: email,
        phone: phone,
        role: 'parent',
      );

      if (!mounted) return;

      // Keep the existing student UI flow unchanged. Student details themselves
      // still need a dedicated PHP endpoint to be persisted in the database.
      final Student s = Student.create(
        name: name,
        grade: grade,
        girl: girl,
        ageY: int.parse(_ageY.text.trim()),
        ageM: 0,
        heightCm: 0,
        weightKg: 0,
        schoolYearPeriod: kNoCheck,
        parentEmail: email,
        parentPassword: '',
        parentPhone: phone,
        lrn: lrn,
        section: _section.text.trim(),
        measuredOn: DateTime.now(),
      );

      widget.onSave(s, parentName);
      _clearForm();

      if (!mounted) return;

      final String? choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _CreatedDialog(student: s),
      );

      if (!mounted) return;
      if (choice == 'students') widget.onViewStudents();
    } catch (e) {
      if (!mounted) return;
      showToast(
        context,
        'Could not create the parent account in the database: ${e.toString().replaceFirst('Exception: ', '')}',
        color: kRed,
      );
    }
  }

  Widget _field(
    TextEditingController c,
    String label,
    String? suffix,
    String? Function(String?) validator,
    double width, {
    bool number = true,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: c,
        style: ink(18),
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.name,
        decoration: InputDecoration(labelText: label, suffixText: suffix),
        validator: validator,
      ),
    );
  }

  Widget _sectionHeader(
    IconData icon,
    String text,
    String subtitle,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: title(30, color: color))),
          ],
        ),
        Text(subtitle, style: ink(14, color: kInkSoft)),
        const SizedBox(height: 14),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: LayoutBuilder(
        builder: (context, c) {
          const double gap = 14;

          // 2 cards side by side on wide screens
          final bool wide = c.maxWidth >= 800;

          final double cardW = wide ? (c.maxWidth - 16) / 2 : c.maxWidth;

          // width inside a card (card padding is 18 on each side)
          final double inner = cardW - 36;

          final double half = inner >= 520 ? (inner - gap) / 2 : inner;

          // ---------------- 1. STUDENT INFORMATION ----------------
          final Widget studentInfo = PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  Icons.person_rounded,
                  '1. Student Information',
                  'Who is the student?',
                  kBlue,
                ),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _field(
                      _name,
                      'Student name',
                      null,
                      (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter a name'
                          : null,
                      inner,
                      number: false,
                    ),
                    SizedBox(
                      width: half,
                      child: TextFormField(
                        controller: _lrn,
                        style: ink(18),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Student LRN',
                          hintText: '12-digit LRN',
                        ),
                        validator: (v) {
                          final String t = (v ?? '').trim();

                          if (t.isEmpty) return 'Please enter the LRN';

                          if (!RegExp(r'^\d{12}$').hasMatch(t)) {
                            return 'LRN must be 12 digits';
                          }

                          return null;
                        },
                      ),
                    ),
                    _field(
                      _section,
                      'Section',
                      null,
                      (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter a section'
                          : null,
                      half,
                      number: false,
                    ),
                    _field(
                      _ageY,
                      'Age (years)',
                      'yrs',
                      (v) {
                        final int? n = int.tryParse(v ?? '');

                        return (n == null || n < 5 || n > 13)
                            ? 'Ages 5 to 13 only'
                            : null;
                      },
                      half,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ChipRow(
                  label: 'Grade',
                  options: [
                    'Kindergarten',
                    for (var i = 1; i <= 6; i++) 'Grade $i',
                  ],
                  selected: grade,
                  onSelected: (v) => setState(() => grade = v),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 74,
                      child: Text(
                        'Gender',
                        style: ink(
                          16,
                          weight: FontWeight.w700,
                          color: kInkSoft,
                        ),
                      ),
                    ),
                    for (final g in const [true, false])
                      ChoiceChip(
                        avatar: Icon(
                          g ? Icons.female_rounded : Icons.male_rounded,
                          size: 18,
                          color: g == girl ? Colors.white : kInk,
                        ),
                        label: Text(g ? 'Girl' : 'Boy'),
                        selected: g == girl,
                        showCheckmark: false,
                        selectedColor: g ? kPink : kBlue,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: kInk, width: 1.4),
                        labelStyle: ink(
                          15,
                          color: g == girl ? Colors.white : kInk,
                          weight: g == girl ? FontWeight.w700 : null,
                        ),
                        onSelected: (_) => setState(() => girl = g),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kYellow.withAlpha(50),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: kInkSoft,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The height and weight are measured later by the teacher or the school nurse. '
                          'The parent adds allergies and meal plan info in the Nutrition Meal Plan page.',
                          style: ink(14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          // ---------------- 2. ASSIGN PARENTS ----------------
          final Widget parents = PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  Icons.family_restroom_rounded,
                  '2. Assign Parents Here',
                  'Account of the student that will be managed by the parents.',
                  kGreen,
                ),
                TextFormField(
                  controller: _parentName,
                  style: ink(18),
                  keyboardType: TextInputType.name,
                  decoration: const InputDecoration(
                    labelText: 'Parent full name',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter the parent name'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  style: ink(18),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_rounded),
                  ),
                  validator: validateEmail,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  style: ink(18),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '09XXXXXXXXX',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                  validator: validatePhone,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _pass,
                  style: ink(18),
                  obscureText: !_showPass,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPass
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      onPressed: () => setState(() => _showPass = !_showPass),
                    ),
                  ),
                  validator: validatePassword,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  style: ink(18),
                  obscureText: !_showConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showConfirm
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      onPressed: () =>
                          setState(() => _showConfirm = !_showConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please confirm the password';
                    }

                    if (v != _pass.text) return 'Passwords do not match';

                    return null;
                  },
                ),
              ],
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: studentInfo),
                    const SizedBox(width: 16),
                    Expanded(child: parents),
                  ],
                )
              else ...[
                studentInfo,
                const SizedBox(height: 16),
                parents,
              ],
              const SizedBox(height: 22),
              Center(
                child: SketchButton(
                  label: 'Create Parent & Student Account',
                  icon: Icons.person_add_alt_1_rounded,
                  onTap: _submit,
                ),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

// "Student account created" popup
class _CreatedDialog extends StatelessWidget {
  final Student student;

  const _CreatedDialog({required this.student});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: PaperCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: kGreenLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: kInk, width: 2),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: kGreen,
                  size: 46,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Student Account Created!',
                textAlign: TextAlign.center,
                style: title(36, color: kGreen),
              ),
              const SizedBox(height: 4),
              Text(
                student.name,
                textAlign: TextAlign.center,
                style: ink(20, weight: FontWeight.w700),
              ),
              Text(
                '${student.grade} • ${student.section} • ${student.ageY} yrs',
                textAlign: TextAlign.center,
                style: ink(14, color: kInkSoft),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kYellow.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.save_rounded, color: kInkSoft, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saved to Student Records. The teacher or school nurse will take the first measurement.',
                        style: ink(14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop('add'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kInk, width: 1.4),
                    ),
                    child: Text('Add Another', style: ink(15)),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop('students'),
                    style: FilledButton.styleFrom(backgroundColor: kGreen),
                    child: Text(
                      'Go to Students',
                      style: ink(15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//  ADMIN: ADD NEW ACCOUNT
//  Step 1: choose the user role.  Step 2: the form for that role appears.
//    Parent        -> student info + first check-up + parent account
//    Teacher       -> staff account
//    School Nurse  -> staff account
//    Admin         -> staff account
// ===========================================================================
class AddAccountPage extends StatefulWidget {
  final NutriStore store;
  final void Function(Student) onOpen; // View Result (parent flow)
  final VoidCallback onViewStudents; // go to Student Nutritional Records
  final VoidCallback onViewUsers; // go to User Records

  const AddAccountPage({
    super.key,
    required this.store,
    required this.onOpen,
    required this.onViewStudents,
    required this.onViewUsers,
  });

  @override
  State<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<AddAccountPage> {
  String? _role; // null = no role chosen yet, so no form is shown

  static const List<String> _roles = [
    kRoleParent,
    kRoleTeacher,
    kRoleNurse,
    kRoleAdmin,
  ];

  String _about(String r) {
    switch (r) {
      case kRoleParent:
        return 'Student info, first check-up and the parent account.';
      case kRoleTeacher:
        return 'Measures students and updates the student info.';
      case kRoleNurse:
        return 'Measures students and views all student records.';
      default:
        return 'Full access: records, users and new accounts.';
    }
  }

  Widget _roleTile(String r, double w) {
    final bool on = r == _role;
    final Color rc = roleColor(r);

    return SizedBox(
      width: w,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _role = r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: on ? rc.withAlpha(35) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? rc : kInk, width: on ? 2.6 : 1.4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: rc.withAlpha(45),
                child: Icon(roleIcon(r), color: rc, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r, style: title(28, color: rc)),
                    Text(_about(r), style: ink(13, color: kInkSoft)),
                  ],
                ),
              ),
              if (on) Icon(Icons.check_circle_rounded, color: rc),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? r = _role;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            titleText: 'Add New Account',
            subtitle: 'Choose who the account is for, then fill up the form.',
          ),
          const SizedBox(height: 16),
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.badge_rounded, color: kBlue, size: 28),
                    const SizedBox(width: 8),
                    Text('Who is the account for?',
                        style: title(28, color: kBlue)),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, c) {
                    const double gap = 12;

                    final int cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
                    final double w = (c.maxWidth - gap * (cols - 1)) / cols;

                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [for (final x in _roles) _roleTile(x, w)],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (r == null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_rounded, color: kInkSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pick a role above to open the form.',
                      style: ink(16, color: kInkSoft),
                    ),
                  ),
                ],
              ),
            )
          else if (r == kRoleParent)
            CheckupPage(
              key: const ValueKey('form-parent'),
              students: widget.store.students,
              onSave: widget.store.addStudentWithParent,
              onOpen: widget.onOpen,
              onViewStudents: widget.onViewStudents,
              emailBlocked: (e) => widget.store.staff.any(
                (a) => a.email.toLowerCase() == e.trim().toLowerCase(),
              ),
            )
          else
            StaffAccountForm(
              key: ValueKey('form-$r'),
              store: widget.store,
              role: r,
              onViewUsers: widget.onViewUsers,
            ),
        ],
      ),
    );
  }
}

// form that creates a Teacher / School Nurse / Admin account
class StaffAccountForm extends StatefulWidget {
  final NutriStore store;
  final String role;
  final VoidCallback onViewUsers;

  const StaffAccountForm({
    super.key,
    required this.store,
    required this.role,
    required this.onViewUsers,
  });

  @override
  State<StaffAccountForm> createState() => _StaffAccountFormState();
}

class _StaffAccountFormState extends State<StaffAccountForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _detail = TextEditingController();
  final TextEditingController _employeeId = TextEditingController();
  final TextEditingController _school = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _showPass = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _detail.dispose();
    _employeeId.dispose();
    _school.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String get _hint {
    switch (widget.role) {
      case kRoleTeacher:
        return 'e.g. Grade 3 Adviser - Section Sampaguita';
      case kRoleNurse:
        return 'e.g. School Nurse - Health Clinic';
      default:
        return 'e.g. Nutritrack System Admin';
    }
  }

  void _clear() {
    _name.clear();
    _email.clear();
    _phone.clear();
    _detail.clear();
    _employeeId.clear();
    _school.clear();
    _pass.clear();
    _confirm.clear();

    _form.currentState?.reset();

    setState(() {
      _showPass = false;
      _showConfirm = false;
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) {
      showToast(
        context,
        'Please fix the fields marked in red first.',
        color: kRed,
      );
      return;
    }

    if (widget.role == kRoleAdmin) {
      showToast(
        context,
        'Admin account creation is not enabled by the PHP API.',
        color: kRed,
      );
      return;
    }

    if ((widget.role == kRoleTeacher ||
            widget.role == kRoleNurse) &&
        _employeeId.text.trim().isEmpty) {
      showToast(
        context,
        'Please enter the employee ID.',
        color: kRed,
      );
      return;
    }

    if ((widget.role == kRoleTeacher ||
            widget.role == kRoleNurse) &&
        _school.text.trim().isEmpty) {
      showToast(
        context,
        'Please enter the assigned school.',
        color: kRed,
      );
      return;
    }

    final String email = _email.text.trim().toLowerCase();

    if (widget.store.emailInUse(email)) {
      showToast(
        context,
        'The email $email is already used by another local account.',
        color: kRed,
      );
      return;
    }

    // Convert the UI role to the role accepted by the PHP API.
    final String apiRole =
        widget.role == kRoleNurse ? 'nurse' : 'teacher';

    try {
      // Create the account through PHP/MySQL, not the local Flutter list.
      final Map<String, dynamic> created =
          await ApiService.createUser(
        fullName: _name.text.trim(),
        email: email,
        phone: cleanPhone(_phone.text),
        role: apiRole,
      );

      if (!mounted) return;

      // Use the ID returned by the database API.
      final StaffAccount account = StaffAccount(
        id: (created['id'] ?? '').toString(),
        role: widget.role,
        name: (created['full_name'] ?? _name.text.trim()).toString(),
        email: (created['email'] ?? email).toString(),
        password: '',
        phone: (created['phone'] ?? cleanPhone(_phone.text)).toString(),
        detail: _detail.text.trim(),
        employeeId: _employeeId.text.trim(),
        school: _school.text.trim(),
      );

      // Do not call widget.store.addStaff(account).
      // The account must come from the API/database.

      _clear();

      final String? choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _StaffCreatedDialog(account: account),
      );

      if (!mounted) return;

      if (choice == 'users') {
        widget.onViewUsers();
      }
    } catch (e) {
      if (!mounted) return;

      showToast(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        color: kRed,
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final Color rc = roleColor(widget.role);

    return PaperCard(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(roleIcon(widget.role), color: rc, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'New ${widget.role} Account',
                    style: title(30, color: rc),
                  ),
                ),
              ],
            ),
            Text(
              'Fill up the information of the ${widget.role.toLowerCase()}.',
              style: ink(14, color: kInkSoft),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                const double gap = 14;

                final double half =
                    c.maxWidth >= 640 ? (c.maxWidth - gap) / 2 : c.maxWidth;

                Widget cell(Widget w) => SizedBox(width: half, child: w);

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    cell(
                      TextFormField(
                        controller: _name,
                        style: ink(18),
                        keyboardType: TextInputType.name,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter the name'
                            : null,
                      ),
                    ),
                    cell(
                      TextFormField(
                        controller: _detail,
                        style: ink(18),
                        decoration: InputDecoration(
                          labelText: 'Assignment',
                          hintText: _hint,
                          prefixIcon: const Icon(Icons.work_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please enter the assignment'
                            : null,
                      ),
                    ),
                    if (widget.role == kRoleTeacher || widget.role == kRoleNurse)
                      cell(
                        TextFormField(
                          controller: _employeeId,
                          style: ink(18),
                          decoration: const InputDecoration(
                            labelText: 'Employee ID',
                            prefixIcon: Icon(Icons.badge_rounded),
                          ),
                          validator: (v) =>
                              (widget.role == kRoleTeacher || widget.role == kRoleNurse) &&
                                      (v == null || v.trim().isEmpty)
                                  ? 'Please enter the employee ID'
                                  : null,
                        ),
                      ),
                    if (widget.role == kRoleTeacher || widget.role == kRoleNurse)
                      cell(
                        TextFormField(
                          controller: _school,
                          style: ink(18),
                          decoration: const InputDecoration(
                            labelText: 'Assigned School',
                            prefixIcon: Icon(Icons.school_rounded),
                          ),
                          validator: (v) =>
                              (widget.role == kRoleTeacher || widget.role == kRoleNurse) &&
                                      (v == null || v.trim().isEmpty)
                                  ? 'Please enter the assigned school'
                                  : null,
                        ),
                      ),
                    cell(
                      TextFormField(
                        controller: _email,
                        style: ink(18),
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_rounded),
                        ),
                        validator: validateEmail,
                      ),
                    ),
                    cell(
                      TextFormField(
                        controller: _phone,
                        style: ink(18),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          hintText: '09XXXXXXXXX',
                          prefixIcon: Icon(Icons.phone_rounded),
                        ),
                        validator: validatePhone,
                      ),
                    ),
                    cell(
                      TextFormField(
                        controller: _pass,
                        style: ink(18),
                        obscureText: !_showPass,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPass
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                            onPressed: () =>
                                setState(() => _showPass = !_showPass),
                          ),
                        ),
                        validator: validatePassword,
                      ),
                    ),
                    cell(
                      TextFormField(
                        controller: _confirm,
                        style: ink(18),
                        obscureText: !_showConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showConfirm
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                            onPressed: () =>
                                setState(() => _showConfirm = !_showConfirm),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please confirm the password';
                          }

                          if (v != _pass.text) return 'Passwords do not match';

                          return null;
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            Center(
              child: SketchButton(
                label: 'Create ${widget.role} Account',
                icon: Icons.person_add_alt_1_rounded,
                color: rc,
                onTap: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// "Account created" popup for Teacher / School Nurse / Admin
class _StaffCreatedDialog extends StatelessWidget {
  final StaffAccount account;

  const _StaffCreatedDialog({required this.account});

  @override
  Widget build(BuildContext context) {
    final Color rc = roleColor(account.role);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: PaperCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: kGreenLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: kInk, width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: kGreen, size: 46),
              ),
              const SizedBox(height: 12),
              Text(
                'Account Created!',
                textAlign: TextAlign.center,
                style: title(36, color: kGreen),
              ),
              const SizedBox(height: 4),
              Text(
                account.name,
                textAlign: TextAlign.center,
                style: ink(20, weight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              RoleChip(
                label: account.role,
                color: rc,
                icon: roleIcon(account.role),
              ),
              const SizedBox(height: 8),
              Text(
                account.email,
                textAlign: TextAlign.center,
                style: ink(14, color: kInkSoft),
              ),
              Text(
                account.detail,
                textAlign: TextAlign.center,
                style: ink(14, color: kInkSoft),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop('add'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kInk, width: 1.4),
                    ),
                    child: Text('Add Another', style: ink(15)),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop('users'),
                    style: FilledButton.styleFrom(backgroundColor: kGreen),
                    child: Text(
                      'Go to User Records',
                      style: ink(15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// ADMIN: PASSWORD RESET REQUESTS
// ---------------------------------------------------------------------------
class PasswordResetRequestsPage extends StatelessWidget {
  final NutriStore store;

  const PasswordResetRequestsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final requests = store.passwordResetRequests;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                titleText: 'Password Reset Requests',
                subtitle: 'Review account recovery requests submitted from the login screen.',
              ),
              const SizedBox(height: 14),
              PaperCard(
                child: Row(
                  children: [
                    const Icon(Icons.lock_reset_rounded, color: kPurple, size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${requests.where((r) => !r.reviewed).length} pending request(s)',
                        style: title(27, color: kPurple),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (requests.isEmpty)
                PaperCard(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 26),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 42, color: kInkSoft),
                          const SizedBox(height: 8),
                          Text('No password reset requests yet.', style: ink(16, color: kInkSoft)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                for (final request in requests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PaperCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: request.reviewed ? kGreenLight : const Color(0xFFFFF0D6),
                                child: Icon(
                                  request.reviewed ? Icons.check_rounded : Icons.pending_actions_rounded,
                                  color: request.reviewed ? kGreen : kOrange,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(request.userName, style: ink(17, weight: FontWeight.w700)),
                                    Text(request.role, style: ink(14, color: kInkSoft)),
                                    Text(request.userEmail, style: ink(14, color: kBlue)),
                                  ],
                                ),
                              ),
                              Text(
                                request.reviewed ? 'Reviewed' : 'Pending',
                                style: ink(12, weight: FontWeight.w700, color: request.reviewed ? kGreen : kOrange),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          if (request.role == kRoleParent) ...[
                            _requestDetail('Student name', request.studentName),
                            _requestDetail('Student LRN', request.lrn),
                            _requestDetail('Relationship to student', request.relationshipToStudent),
                          ],
                          if (request.accountDetail.isNotEmpty)
                            _requestDetail(
                              request.role == kRoleTeacher ? 'Teacher / employee ID' : 'Employee ID',
                              request.accountDetail,
                            ),
                          if (request.schoolDepartment.isNotEmpty)
                            _requestDetail('School / department', request.schoolDepartment),
                          _requestDetail('Registered phone (last 4 digits)', request.registeredPhoneLast4),
                          _requestDetail('Submitted', request.submittedAt.toLocal().toString().split('.').first),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (!request.reviewed)
                                OutlinedButton.icon(
                                  onPressed: () => store.markPasswordResetReviewed(request),
                                  icon: const Icon(Icons.check_circle_outline_rounded),
                                  label: const Text('Mark reviewed'),
                                ),
                              TextButton.icon(
                                onPressed: () => store.removePasswordResetRequest(request),
                                icon: const Icon(Icons.delete_outline_rounded, color: kRed),
                                label: const Text('Remove request', style: TextStyle(color: kRed)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Demo only: verify the person using school procedures. This request does not automatically change or email a password.',
                            style: ink(12, color: kInkSoft),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _requestDetail(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 155, child: Text(label, style: ink(13, color: kInkSoft))),
          Expanded(child: Text(value, style: ink(14, weight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ===========================================================================
//  LOG IN  ->  DASHBOARD OF THE ROLE   (+ Log Out in every side menu)
// ===========================================================================
const List<String> kRoles = [kRoleParent, kRoleTeacher, kRoleNurse, kRoleAdmin];
// Admin accounts cannot request their own reset from this form.
const List<String> kPasswordResetRoles = [kRoleParent, kRoleTeacher, kRoleNurse];

// security settings of the log in page
const int kMaxAttempts = 5; // wrong tries before the lock
const int kLockSeconds = 30; // lock time

// who is logged in
class Session {
  final String role;
  final String email;
  final String name;
  final String id; // staff id, or the parent email

  const Session(this.role, this.email, this.name, this.id);
}

class LoginPage extends StatefulWidget {
  final NutriStore store;

  // called after a successful login (the app opens that role's dashboard)
  final void Function(Session session) onSuccess;

  const LoginPage({super.key, required this.store, required this.onSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();

  String _role = kRoleParent;
  bool _showPass = false;
  bool _busy = false;

  int _failed = 0;
  int _lockLeft = 0;
  String? _error;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  bool get _locked => _lockLeft > 0;

  void _startLock() {
    _lockLeft = kLockSeconds;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      setState(() {
        _lockLeft--;

        if (_lockLeft <= 0) {
          _lockLeft = 0;
          _failed = 0;
          _error = null;
          t.cancel();
        }
      });
    });
  }

  // checks the role, email, password (and the child's LRN for parents)
  // against the same data the dashboards use
  Session? _find() {
    final String email = _email.text.trim().toLowerCase();
    final NutriStore st = widget.store;

    if (_role == kRoleParent) {
      if (st.isParentDisabled(email)) return null;
      final List<Student> kids = st.childrenOf(email);

      if (kids.isEmpty) return null;

      if (kids.first.parentPassword != _pass.text) return null;


      return Session(kRoleParent, email, st.parentNameFor(email), email);
    }

    for (final a in st.staff) {
      if (a.role == _role &&
          a.email.toLowerCase() == email &&
          a.password == _pass.text) {
        return Session(a.role, a.email.toLowerCase(), a.name, a.id);
      }
    }

    return null;
  }

  Future<void> _login() async {
    if (_locked || _busy) return;
    if (!_form.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    // All roles authenticate against the PHP/MySQL API.
    // No local/demo credentials are accepted on the login page.
    try {
      final Map<String, dynamic> user = await ApiService.login(
        email: _email.text.trim(),
        password: _pass.text,
      );

      if (!mounted) return;
      final String apiRole = (user['role'] ?? '').toString().trim().toLowerCase();
      final String expectedRole = switch (_role) {
        kRoleParent => 'parent',
        kRoleTeacher => 'teacher',
        kRoleNurse => 'nurse',
        kRoleAdmin => 'admin',
        _ => _role.toLowerCase(),
      };
      if (apiRole != expectedRole) {
        await ApiService.logout();
        throw Exception('The selected role does not match this account.');
      }

      final String userEmail = (user['email'] ?? _email.text).toString().trim().toLowerCase();
      final String userName = (user['full_name'] ?? user['name'] ?? 'User').toString();
      final String userId = (user['id'] ?? '').toString();

      setState(() {
        _busy = false;
        _failed = 0;
        _error = null;
      });

      widget.onSuccess(Session(_role, userEmail, userName, userId));
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed++;
        if (_failed >= kMaxAttempts) {
          _error = 'Too many failed attempts. Please wait ${kLockSeconds}s.';
          _startLock();
        } else {
          final String detail = e.toString().replaceFirst('Exception: ', '').trim();
          _error = 'Login failed: $detail';
        }
      });
      return;
    }
  }

  Future<void> _forgot() async {
    final GlobalKey<FormState> resetForm = GlobalKey<FormState>();
    final TextEditingController userName = TextEditingController();
    final TextEditingController userEmail = TextEditingController();
    final TextEditingController studentName = TextEditingController();
    final TextEditingController studentLrn = TextEditingController();
    final TextEditingController relationshipToStudent = TextEditingController();
    final TextEditingController registeredPhoneLast4 = TextEditingController();
    final TextEditingController accountDetail = TextEditingController();
    final TextEditingController schoolDepartment = TextEditingController();
    String resetRole = kPasswordResetRoles.contains(_role) ? _role : kRoleParent;

    final bool? submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: PaperCard(
              padding: const EdgeInsets.all(22),
              child: SingleChildScrollView(
                child: Form(
                  key: resetForm,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lock_reset_rounded, color: kBlue, size: 30),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Password reset request', style: title(30, color: kBlue))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose Parent, Teacher, or School Nurse and complete the matching required details. Admin accounts are not eligible to request a reset here.',
                        style: ink(15),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        key: ValueKey<String>('password-reset-role-$resetRole'),
                        initialValue: resetRole,
                        decoration: const InputDecoration(labelText: 'Account type'),
                        items: [
                          for (final role in kPasswordResetRoles)
                            DropdownMenuItem(value: role, child: Text(role)),
                        ],
                        onChanged: (value) {
                          if (value != null && value != resetRole) {
                            setDialogState(() {
                              resetRole = value;
                              // Clear role-specific values when switching account types,
                              // so a Parent's LRN never carries into a staff request.
                              studentName.clear();
                              studentLrn.clear();
                              relationshipToStudent.clear();
                              registeredPhoneLast4.clear();
                              accountDetail.clear();
                              schoolDepartment.clear();
                              // Do not reset the entire Form here: that would reset the
                              // dropdown back to its original role. The keyed dropdown
                              // and role-specific fields rebuild for the newly selected role.
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: userName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'User full name',
                          hintText: 'Enter the name registered to the account',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty ? 'Enter the full name on the account.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: userEmail,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'User email account',
                          hintText: 'name@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final email = (value ?? '').trim().toLowerCase();
                          if (email.isEmpty ||
                              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                            return 'Enter a valid email for this account.';
                          }
                          return null;
                        },
                      ),
                      if (resetRole == kRoleParent) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: studentName,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Student full name',
                            prefixIcon: Icon(Icons.school_outlined),
                          ),
                          validator: (value) => resetRole == kRoleParent && (value ?? '').trim().isEmpty
                              ? 'Enter the student full name.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: studentLrn,
                          keyboardType: TextInputType.number,
                          maxLength: 12,
                          decoration: const InputDecoration(
                            labelText: 'Student LRN',
                            hintText: '12-digit LRN',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (value) {
                            if (resetRole != kRoleParent) return null;
                            final lrn = (value ?? '').trim();
                            if (lrn.isEmpty) return 'Enter the student LRN.';
                            if (!RegExp(r'^\d{12}$').hasMatch(lrn)) return 'LRN must be 12 digits.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: relationshipToStudent,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Relationship to student',
                            hintText: 'e.g. Mother, Father, Guardian',
                            prefixIcon: Icon(Icons.family_restroom_rounded),
                          ),
                          validator: (value) => resetRole == kRoleParent && (value ?? '').trim().isEmpty
                              ? 'Enter your relationship to the student.'
                              : null,
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: accountDetail,
                          decoration: InputDecoration(
                            labelText: resetRole == kRoleTeacher ? 'Teacher ID' : 'Employee ID',
                            hintText: 'Enter the ID registered with the school',
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                          validator: (value) => resetRole != kRoleParent && (value ?? '').trim().isEmpty
                              ? 'Enter your school-issued ID.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: schoolDepartment,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'School / department',
                            hintText: 'e.g. Grade 5, School Clinic',
                            prefixIcon: Icon(Icons.apartment_rounded),
                          ),
                          validator: (value) => resetRole != kRoleParent && (value ?? '').trim().isEmpty
                              ? 'Enter your school or department.'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: registeredPhoneLast4,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        decoration: const InputDecoration(
                          labelText: 'Last 4 digits of registered phone number',
                          hintText: 'e.g. 1234',
                          prefixIcon: Icon(Icons.phone_android_rounded),
                        ),
                        validator: (value) {
                          final digits = (value ?? '').trim();
                          if (!RegExp(r'^\d{4}$').hasMatch(digits)) {
                            return 'Enter the last 4 digits of the phone number registered to the account.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Admin accounts cannot request resets through this form. The Admin must compare these details with the school’s official account records before approving a request. Never enter a password or verification code here.',
                        style: ink(13, color: kInkSoft),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton.icon(
                            onPressed: () {
                              if (resetForm.currentState!.validate()) {
                                Navigator.of(ctx).pop(true);
                              }
                            },
                            style: FilledButton.styleFrom(backgroundColor: kGreen),
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Submit request'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (submitted == true && mounted) {
      final request = PasswordResetRequest(
        id: 'reset-${DateTime.now().microsecondsSinceEpoch}',
        role: resetRole,
        userName: userName.text.trim(),
        userEmail: userEmail.text.trim().toLowerCase(),
        studentName: resetRole == kRoleParent ? studentName.text.trim() : '',
        lrn: resetRole == kRoleParent ? studentLrn.text.trim() : '',
        relationshipToStudent: resetRole == kRoleParent ? relationshipToStudent.text.trim() : '',
        registeredPhoneLast4: registeredPhoneLast4.text.trim(),
        accountDetail: resetRole == kRoleParent ? '' : accountDetail.text.trim(),
        schoolDepartment: resetRole == kRoleParent ? '' : schoolDepartment.text.trim(),
        submittedAt: DateTime.now(),
      );
      widget.store.addPasswordResetRequest(request);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Request submitted'),
          content: const Text(
            'Your password reset request has been added to the Admin account under Password Requests. The administrator must verify your details and handle the reset securely. This demo stores requests only while the app is running; email delivery and cross-device storage require a connected backend.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    userName.dispose();
    userEmail.dispose();
    studentName.dispose();
    studentLrn.dispose();
    relationshipToStudent.dispose();
    registeredPhoneLast4.dispose();
    accountDetail.dispose();
    schoolDepartment.dispose();
  }

  void _fill(AccountView a) {
    setState(() {
      _role = a.role;
      _email.text = a.email;
      _pass.text = a.password;
        _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color rc = roleColor(_role);

    final Widget roleRow = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final r in kRoles)
          ChoiceChip(
            avatar: Icon(
              roleIcon(r),
              size: 18,
              color: r == _role ? Colors.white : roleColor(r),
            ),
            label: Text(r),
            selected: r == _role,
            showCheckmark: false,
            selectedColor: roleColor(r),
            backgroundColor: Colors.white,
            side: const BorderSide(color: kInk, width: 1.4),
            labelStyle: ink(
              15,
              color: r == _role ? Colors.white : kInk,
              weight: r == _role ? FontWeight.w700 : null,
            ),
            onSelected: (_) => setState(() {
              _role = r;
              _error = null;
            }),
          ),
      ],
    );

    final Widget card = PaperCard(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: _Brand()),
            const SizedBox(height: 18),
            Text(
              'Welcome back!',
              textAlign: TextAlign.center,
              style: title(44, color: kGreen),
            ),
            Text(
              'Log in to see your Nutritrack dashboard.',
              textAlign: TextAlign.center,
              style: ink(16, color: kInkSoft),
            ),
            const SizedBox(height: 18),
            Text(
              'I am a...',
              textAlign: TextAlign.center,
              style: ink(16, weight: FontWeight.w700, color: kInkSoft),
            ),
            const SizedBox(height: 8),
            roleRow,
            const SizedBox(height: 20),
            TextFormField(
              controller: _email,
              enabled: !_locked,
              style: ink(18),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_rounded),
              ),
              validator: validateEmail,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pass,
              enabled: !_locked,
              style: ink(18),
              obscureText: !_showPass,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  tooltip: _showPass ? 'Hide password' : 'Show password',
                  icon: Icon(
                    _showPass
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  onPressed: () => setState(() => _showPass = !_showPass),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Please enter your password' : null,
            ),

            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgot,
                child: Text(
                  'Forgot password?',
                  style: ink(15, weight: FontWeight.w700, color: kBlue),
                ),
              ),
            ),
            if (_error != null || _locked) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kRed.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kRed, width: 1.4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _locked ? Icons.lock_clock_rounded : Icons.error_rounded,
                      color: kRed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _locked
                            ? 'Too many wrong tries. Please wait $_lockLeft seconds before trying again.'
                            : _error!,
                        style: ink(15, color: kRed, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            Center(
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          color: kGreen,
                          strokeWidth: 4,
                        ),
                      ),
                    )
                  : SketchButton(
                      label: 'Log In as $_role',
                      icon: Icons.login_rounded,
                      color: _locked ? kInkSoft : rc,
                      onTap: _login,
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_rounded, color: kInkSoft, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Accounts are created by the school. Never share your password. '
                    'After $kMaxAttempts wrong tries the login is locked for $kLockSeconds seconds.',
                    style: ink(13, color: kInkSoft),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );


    return Scaffold(
      body: ArtBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    card,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


void main() {
  runApp(const NutritrackRoot());
}

class NutritrackRoot extends StatefulWidget {
  const NutritrackRoot({super.key});

  @override
  State<NutritrackRoot> createState() => _NutritrackRootState();
}

class _NutritrackRootState extends State<NutritrackRoot> {
  Session? _session; // null = not logged in
  int _loginKey = 0; // new key = fresh (empty) log in form

  void _logout() {
    setState(() {
      _session = null;
      _loginKey++;
    });
  }

  // API-authenticated staff (especially Admin) may exist in MySQL but not
  // in the local demo store. Avoid firstWhere throwing StateError in that case.
  StaffAccount _staff(Session s) {
    for (final account in kStore.staff) {
      if (account.id == s.id) return account;
    }

    return StaffAccount(
      id: s.id,
      role: s.role,
      name: s.name,
      email: s.email,
      password: '',
      phone: '',
      detail: '',
    );
  }

  Widget _summaryTab(BuildContext context) => ListenableBuilder(
        listenable: kStore,
        builder: (context, _) => SummaryPage(students: kStore.students),
      );

  Widget _shellFor(Session s) {
    switch (s.role) {
      case kRoleParent:
        return RoleShell(
          roleLabel: 'Parent Account',
          roleColor: kGreen,
          roleIcon: Icons.family_restroom_rounded,
          userName: s.name,
          onLogout: _logout,
          tabs: [
            NavDef(
              'Summary Dashboard',
              'Summary',
              Icons.dashboard_rounded,
              (context) => ParentSummaryPage(store: kStore, email: s.email),
            ),
            NavDef(
              'Nutrition Meal Plan',
              'Meal Plan',
              Icons.restaurant_menu_rounded,
              (context) => ParentMealPlanPage(store: kStore, email: s.email),
            ),
            NavDef(
              'Measurement',
              'Measure',
              Icons.straighten_rounded,
              (context) =>
                  ParentMeasurementPage(store: kStore, email: s.email),
            ),
            NavDef(
              'User Account',
              'Account',
              Icons.account_circle_rounded,
              (context) => ParentAccountPage(store: kStore, email: s.email),
            ),
          ],
        );

      case kRoleTeacher:
        final StaffAccount me = _staff(s);

        return RoleShell(
          roleLabel: 'Teacher Account',
          roleColor: kBlue,
          roleIcon: Icons.school_rounded,
          userName: me.name,
          onLogout: _logout,
          tabs: [
            NavDef('Summary Dashboard', 'Summary', Icons.dashboard_rounded,
                _summaryTab),
            NavDef(
              'Measurement',
              'Measure',
              Icons.straighten_rounded,
              (context) =>
                  StaffMeasurementPage(store: kStore, takenBy: 'Teacher', actorName: me.name, actorEmail: me.email),
            ),
            NavDef(
              'Student Records',
              'Students',
              Icons.groups_rounded,
              (context) => TeacherStudentsPage(store: kStore),
            ),
            NavDef(
              'User Account',
              'Account',
              Icons.account_circle_rounded,
              (context) => StaffAccountPage(account: me, store: kStore),
            ),
          ],
        );

      case kRoleNurse:
        final StaffAccount me = _staff(s);

        return RoleShell(
          roleLabel: 'School Nurse Account',
          roleColor: kPink,
          roleIcon: Icons.medical_services_rounded,
          userName: me.name,
          onLogout: _logout,
          tabs: [
            NavDef('Summary Dashboard', 'Summary', Icons.dashboard_rounded,
                _summaryTab),
            NavDef(
              'Measurement',
              'Measure',
              Icons.straighten_rounded,
              (context) =>
                  StaffMeasurementPage(store: kStore, takenBy: 'School Nurse', actorName: me.name, actorEmail: me.email),
            ),
            NavDef(
              'Student Records',
              'Students',
              Icons.groups_rounded,
              (context) => StudentRecordsPage(
                store: kStore,
                canEdit: false,
                titleText: 'Student Records',
                subtitle:
                    'Nutrition status, nutrition plan, measurements and student info. View only.',
              ),
            ),
            NavDef(
              'User Account',
              'Account',
              Icons.account_circle_rounded,
              (context) => StaffAccountPage(account: me, store: kStore),
            ),
          ],
        );

      default: // admin
        final StaffAccount me = _staff(s);

        return RoleShell(
          roleLabel: 'Admin Account',
          roleColor: kPurple,
          roleIcon: Icons.admin_panel_settings_rounded,
          userName: me.name,
          onLogout: _logout,
          tabs: [
            NavDef('Summary Dashboard', 'Summary', Icons.dashboard_rounded,
                _summaryTab),
            NavDef(
              'Student Nutritional Records',
              'Students',
              Icons.groups_rounded,
              (context) => StudentRecordsPage(
                store: kStore,
                canEdit: true,
                titleText: 'Student Nutritional Records',
                subtitle:
                    'Every student: info, parent account, nutrition status, measurements and meal plans. Tap a student to open and edit.',
              ),
            ),
            NavDef(
              'User Records',
              'Users',
              Icons.manage_accounts_rounded,
              (context) => UserRecordsPage(store: kStore),
            ),
            NavDef(
              'Add New Account',
              'Add',
              Icons.person_add_alt_1_rounded,
              (context) => AddAccountPage(
                store: kStore,
                onOpen: (st) => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ResultPage(student: st)),
                ),
                onViewStudents: () => RoleShell.goTo(context, 1),
                onViewUsers: () => RoleShell.goTo(context, 2),
              ),
            ),
            NavDef(
              'History',
              'History',
              Icons.history_rounded,
              (context) => AdminHistoryPage(store: kStore),
            ),
            NavDef(
              'Password Requests',
              'Requests',
              Icons.lock_reset_rounded,
              (context) => PasswordResetRequestsPage(store: kStore),
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Session? s = _session;

    return NutritrackApp(
      appTitle: 'Nutritrack',
      home: s == null
          ? LoginPage(
              key: ValueKey(_loginKey),
              store: kStore,
              onSuccess: (session) => setState(() => _session = session),
            )
          : ListenableBuilder(
              listenable: kStore,
              builder: (context, _) => _shellFor(s),
            ),
    );
  }
}
