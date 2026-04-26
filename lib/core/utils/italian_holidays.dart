// lib/core/utils/italian_holidays.dart

class ItalianHolidays {
  /// Restituisce true se il giorno è festivo o weekend
  static bool isHolidayOrWeekend(DateTime date) {
    if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
      return true;
    }
    return _isPublicHoliday(date);
  }

  static bool _isPublicHoliday(DateTime date) {
    final year = date.year;
    final month = date.month;
    final day = date.day;

    // Festività fisse
    final fixed = [
      (1, 1), // Capodanno
      (1, 6), // Epifania
      (4, 25), // Festa della Liberazione
      (5, 1), // Festa del Lavoro
      (6, 2), // Festa della Repubblica
      (8, 15), // Ferragosto
      (11, 1), // Ognissanti
      (12, 8), // Immacolata Concezione
      (12, 25), // Natale
      (12, 26), // Santo Stefano
    ];

    for (final f in fixed) {
      if (month == f.$1 && day == f.$2) return true;
    }

    // Pasqua (algoritmo di Butcher)
    final easter = _calculateEaster(year);
    // Pasqua
    if (month == easter.month && day == easter.day) return true;
    // Lunedì dell'Angelo (Pasquetta)
    final easterMonday = easter.add(const Duration(days: 1));
    if (month == easterMonday.month && day == easterMonday.day) return true;

    return false;
  }

  /// Algoritmo di Butcher per calcolare la Pasqua
  static DateTime _calculateEaster(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  /// Genera tutti i giorni lavorativi in un intervallo,
  /// escludendo weekend e festivi italiani
  static List<DateTime> getWorkingDays(DateTime start, DateTime end) {
    final days = <DateTime>[];
    var current = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(last)) {
      if (!isHolidayOrWeekend(current)) {
        days.add(current);
      }
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  /// Genera il calendario ciclico spalmando le settimane del ciclo
  /// su tutti i giorni lavorativi del periodo
  static List<_CyclicDayAssignment> generateCyclicCalendar({
    required DateTime startDate,
    required DateTime endDate,
    required int totalCycleWeeks,
  }) {
    final workingDays = getWorkingDays(startDate, endDate);
    final assignments = <_CyclicDayAssignment>[];

    final startMonday = startDate.subtract(
      Duration(days: startDate.weekday - 1),
    );

    for (final date in workingDays) {
      final mondayOfCurrentWeek = date.subtract(
        Duration(days: date.weekday - 1),
      );
      final weeksDiff = mondayOfCurrentWeek.difference(startMonday).inDays ~/ 7;

      final cycleWeekIndex = weeksDiff % totalCycleWeeks;
      final weekNumber = cycleWeekIndex + 1;

      // DEBUG — rimuovi dopo
      print(
          '${date.day}/${date.month} (dow:${date.weekday}) → weeksDiff:$weeksDiff → ciclo settimana $weekNumber');

      assignments.add(_CyclicDayAssignment(
        date: date,
        cycleWeekNumber: weekNumber,
        dayOfWeek: date.weekday,
      ));
    }

    return assignments;
  }
}

class _CyclicDayAssignment {
  final DateTime date;
  final int cycleWeekNumber; // 1, 2, 3...
  final int dayOfWeek; // 1=Lun, 2=Mar, 3=Mer, 4=Gio, 5=Ven

  const _CyclicDayAssignment({
    required this.date,
    required this.cycleWeekNumber,
    required this.dayOfWeek,
  });
}
