// lib/core/models/cyclic_models.dart

import 'models.dart';

class CyclicCourse {
  final String? id;
  final CourseType courseType;
  final String? customLabel;
  final String description;
  final List<String> allergens;
  final int sortOrder;

  CyclicCourse({
    this.id,
    this.courseType = CourseType.primo,
    this.customLabel,
    this.description = '',
    this.allergens = const [],
    this.sortOrder = 0,
  });

  CyclicCourse copyWith({
    CourseType? courseType,
    String? customLabel,
    String? description,
    List<String>? allergens,
  }) =>
      CyclicCourse(
        id: id,
        courseType: courseType ?? this.courseType,
        customLabel: customLabel ?? this.customLabel,
        description: description ?? this.description,
        allergens: allergens ?? this.allergens,
        sortOrder: sortOrder,
      );

  factory CyclicCourse.fromJson(Map<String, dynamic> json) => CyclicCourse(
        id: json['id'] as String?,
        courseType:
            CourseType.fromString(json['course_type'] as String? ?? 'custom'),
        customLabel: json['custom_label'] as String?,
        description: json['description'] as String,
        allergens: (json['allergens'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}

class CyclicDay {
  final String? id;
  final int dayOfWeek; // 1=Lun, 2=Mar, 3=Mer, 4=Gio, 5=Ven
  final List<CyclicCourse> courses;

  CyclicDay({
    this.id,
    required this.dayOfWeek,
    List<CyclicCourse>? courses,
  }) : courses = courses ?? [];

  String get dayName {
    switch (dayOfWeek) {
      case 1:
        return 'Lunedì';
      case 2:
        return 'Martedì';
      case 3:
        return 'Mercoledì';
      case 4:
        return 'Giovedì';
      case 5:
        return 'Venerdì';
      default:
        return 'Giorno $dayOfWeek';
    }
  }

  String get dayEmoji {
    switch (dayOfWeek) {
      case 1:
        return '🌱';
      case 2:
        return '🌿';
      case 3:
        return '🍃';
      case 4:
        return '🌾';
      case 5:
        return '🎉';
      default:
        return '📅';
    }
  }

  factory CyclicDay.fromJson(Map<String, dynamic> json) => CyclicDay(
        id: json['id'] as String?,
        dayOfWeek: json['day_of_week'] as int,
        courses: (json['cycle_courses'] as List<dynamic>?)
                ?.map((e) => CyclicCourse.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class CyclicWeek {
  final String? id;
  final int weekNumber;
  final List<CyclicDay> days;

  CyclicWeek({
    this.id,
    required this.weekNumber,
    List<CyclicDay>? days,
  }) : days = days ?? _defaultDays();

  static List<CyclicDay> _defaultDays() =>
      List.generate(5, (i) => CyclicDay(dayOfWeek: i + 1));

  String get label => 'Settimana $weekNumber';

  factory CyclicWeek.fromJson(Map<String, dynamic> json) => CyclicWeek(
        id: json['id'] as String?,
        weekNumber: json['week_number'] as int,
        days: (json['cycle_days'] as List<dynamic>?)
                ?.map((e) => CyclicDay.fromJson(e as Map<String, dynamic>))
                .toList() ??
            _defaultDays(),
      );
}
