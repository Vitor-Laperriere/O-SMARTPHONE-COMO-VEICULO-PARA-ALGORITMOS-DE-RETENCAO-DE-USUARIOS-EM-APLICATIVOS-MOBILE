enum AnalysisWindow { threeDays, sevenDays, fifteenDays, thirtyDays, semester }

extension AnalysisWindowLabel on AnalysisWindow {
  String get label => switch (this) {
    AnalysisWindow.threeDays => '3 dias',
    AnalysisWindow.sevenDays => '7 dias',
    AnalysisWindow.fifteenDays => '15 dias',
    AnalysisWindow.thirtyDays => '30 dias',
    AnalysisWindow.semester => 'Semestre',
  };

  int get dayCount => switch (this) {
    AnalysisWindow.threeDays => 3,
    AnalysisWindow.sevenDays => 7,
    AnalysisWindow.fifteenDays => 15,
    AnalysisWindow.thirtyDays => 30,
    AnalysisWindow.semester => 183,
  };

  int get detailedDayCount => switch (this) {
    AnalysisWindow.semester => 30,
    _ => dayCount,
  };

  bool get usesCompactCalendar => this == AnalysisWindow.thirtyDays;

  bool get usesMonthlyOverview => this == AnalysisWindow.semester;
}
