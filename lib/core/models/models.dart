// ─── ENUMS ───────────────────────────────────────────────────────────────────

enum UserRole { user, school, admin }

enum CourseType {
  primo,
  secondo,
  contorno,
  frutta,
  dessert,
  custom;

  String get label {
    switch (this) {
      case CourseType.primo:
        return 'Primo';
      case CourseType.secondo:
        return 'Secondo';
      case CourseType.contorno:
        return 'Contorno';
      case CourseType.frutta:
        return 'Frutta';
      case CourseType.dessert:
        return 'Dessert';
      case CourseType.custom:
        return 'Extra';
    }
  }

  String get emoji {
    switch (this) {
      case CourseType.primo:
        return '🍝';
      case CourseType.secondo:
        return '🍗';
      case CourseType.contorno:
        return '🥗';
      case CourseType.frutta:
        return '🍎';
      case CourseType.dessert:
        return '🍮';
      case CourseType.custom:
        return '🍽';
    }
  }

  static CourseType fromString(String value) {
    return CourseType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CourseType.custom,
    );
  }
}

enum SchoolType {
  nido,
  materna,
  primaria,
  media;

  String get label {
    switch (this) {
      case SchoolType.nido:
        return 'Nido';
      case SchoolType.materna:
        return 'Materna';
      case SchoolType.primaria:
        return 'Primaria';
      case SchoolType.media:
        return 'Media';
    }
  }

  String get emoji {
    switch (this) {
      case SchoolType.nido:
        return '🌱';
      case SchoolType.materna:
        return '🎨';
      case SchoolType.primaria:
        return '🏫';
      case SchoolType.media:
        return '📚';
    }
  }

  static SchoolType fromString(String value) {
    return SchoolType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SchoolType.primaria,
    );
  }
}

// ─── LOCATION MODELS ─────────────────────────────────────────────────────────

class Region {
  final String id;
  final String name;

  const Region({required this.id, required this.name});

  factory Region.fromJson(Map<String, dynamic> json) => Region(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

class Province {
  final String id;
  final String name;
  final String regionId;

  const Province(
      {required this.id, required this.name, required this.regionId});

  factory Province.fromJson(Map<String, dynamic> json) => Province(
        id: json['id'] as String,
        name: json['name'] as String,
        regionId: json['region_id'] as String,
      );
}

class Municipality {
  final String id;
  final String name;
  final String provinceId;

  const Municipality(
      {required this.id, required this.name, required this.provinceId});

  factory Municipality.fromJson(Map<String, dynamic> json) => Municipality(
        id: json['id'] as String,
        name: json['name'] as String,
        provinceId: json['province_id'] as String,
      );
}

// ─── SCHOOL MODEL ─────────────────────────────────────────────────────────────

class School {
  final String id;
  final String userId;
  final String name;
  final SchoolType schoolType;
  final String municipalityId;
  final String municipalityName;
  final String provinceName;
  final String regionName;
  final String? address;
  final String? phone;
  final String? logoUrl;
  final bool isApproved;
  final DateTime createdAt;

  const School({
    required this.id,
    required this.userId,
    required this.name,
    required this.schoolType,
    required this.municipalityId,
    required this.municipalityName,
    required this.provinceName,
    required this.regionName,
    this.address,
    this.phone,
    this.logoUrl,
    required this.isApproved,
    required this.createdAt,
  });

  factory School.fromJson(Map<String, dynamic> json) => School(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: json['name'] as String,
        schoolType:
            SchoolType.fromString(json['school_type'] as String? ?? 'primaria'),
        municipalityId: json['municipality_id'] as String,
        municipalityName: json['municipalities']?['name'] as String? ?? '',
        provinceName:
            json['municipalities']?['provinces']?['name'] as String? ?? '',
        regionName: json['municipalities']?['provinces']?['regions']?['name']
                as String? ??
            '',
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        logoUrl: json['logo_url'] as String?,
        isApproved: json['is_approved'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  String get locationLabel => '$municipalityName ($provinceName)';
  String get fullLocationLabel =>
      '$municipalityName, $provinceName — $regionName';
}

// ─── MENU MODELS ─────────────────────────────────────────────────────────────

class MenuCourse {
  final String id;
  final String menuDayId;
  final CourseType courseType;
  final String? customLabel;
  final String description;
  final List<String> allergens;
  final int sortOrder;

  const MenuCourse({
    required this.id,
    required this.menuDayId,
    required this.courseType,
    this.customLabel,
    required this.description,
    required this.allergens,
    required this.sortOrder,
  });

  String get displayLabel => courseType == CourseType.custom
      ? (customLabel ?? 'Extra')
      : courseType.label;

  factory MenuCourse.fromJson(Map<String, dynamic> json) => MenuCourse(
        id: json['id'] as String,
        menuDayId: json['menu_day_id'] as String,
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

  Map<String, dynamic> toJson() => {
        'menu_day_id': menuDayId,
        'course_type': courseType.name,
        'custom_label': customLabel,
        'description': description,
        'allergens': allergens,
        'sort_order': sortOrder,
      };
}

class MenuDay {
  final String id;
  final String menuId;
  final DateTime dayDate;
  final List<MenuCourse> courses;

  const MenuDay({
    required this.id,
    required this.menuId,
    required this.dayDate,
    required this.courses,
  });

  factory MenuDay.fromJson(Map<String, dynamic> json) => MenuDay(
        id: json['id'] as String,
        menuId: json['menu_id'] as String,
        dayDate: DateTime.parse(json['day_date'] as String),
        courses: (json['menu_courses'] as List<dynamic>?)
                ?.map((e) => MenuCourse.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  bool get isToday {
    final now = DateTime.now();
    return dayDate.year == now.year &&
        dayDate.month == now.month &&
        dayDate.day == now.day;
  }
}

class SchoolMenu {
  final String id;
  final String schoolId;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String? pdfUrl;
  final bool isActive;
  final String menuType; // aggiungi
  final List<MenuDay> days;

  const SchoolMenu({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.pdfUrl,
    required this.isActive,
    required this.menuType,
    required this.days,
  });

  factory SchoolMenu.fromJson(Map<String, dynamic> json) => SchoolMenu(
        id: json['id'] as String,
        schoolId: json['school_id'] as String,
        title: json['title'] as String? ?? 'Menu',
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        pdfUrl: json['pdf_url'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        menuType: json['menu_type'] as String? ?? 'standard', // aggiungi
        days: (json['menu_days'] as List<dynamic>?)
                ?.map((e) => MenuDay.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  MenuDay? get todayMenu {
    final now = DateTime.now();
    try {
      return days.firstWhere(
        (d) =>
            d.dayDate.year == now.year &&
            d.dayDate.month == now.month &&
            d.dayDate.day == now.day,
      );
    } catch (_) {
      return null;
    }
  }

  List<MenuDay> get upcomingDays {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return days.where((d) => !d.dayDate.isBefore(today)).toList()
      ..sort((a, b) => a.dayDate.compareTo(b.dayDate));
  }
}

// ─── USER PROFILE ─────────────────────────────────────────────────────────────

class UserProfile {
  final String id;
  final String? fullName;
  final String? avatarUrl;
  final UserRole role;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    this.fullName,
    this.avatarUrl,
    required this.role,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        fullName: json['full_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        role: UserRole.values.firstWhere(
          (r) => r.name == (json['role'] as String? ?? 'user'),
          orElse: () => UserRole.user,
        ),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  String get displayName => fullName ?? 'Utente';
  String get initials {
    if (fullName == null || fullName!.isEmpty) return '?';
    final parts = fullName!.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName![0].toUpperCase();
  }
}
