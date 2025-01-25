class SleepStageRecord {
  final DateTime startTime;
  final DateTime endTime;
  final String stageName;

  SleepStageRecord({
    required this.startTime,
    required this.endTime,
    required this.stageName,
  });

  Map<String, dynamic> toJson() => {
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'stageName': stageName,
  };

  factory SleepStageRecord.fromJson(Map<String, dynamic> json) => SleepStageRecord(
    startTime: DateTime.parse(json['startTime']),
    endTime: DateTime.parse(json['endTime']),
    stageName: json['stageName'],
  );
}

class SleepSession {
  final DateTime date;
  final List<SleepStageRecord> stages;
  final String dataSource; // 'sensor' 或 'health'

  SleepSession({
    required this.date,
    required this.stages,
    required this.dataSource,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'stages': stages.map((stage) => stage.toJson()).toList(),
    'dataSource': dataSource,
  };

  factory SleepSession.fromJson(Map<String, dynamic> json) => SleepSession(
    date: DateTime.parse(json['date']),
    stages: (json['stages'] as List)
        .map((stage) => SleepStageRecord.fromJson(stage))
        .toList(),
    dataSource: json['dataSource'],
  );
} 