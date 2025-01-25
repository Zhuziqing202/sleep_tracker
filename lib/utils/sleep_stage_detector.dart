import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:sleep_tracker/models/sleep_record.dart';

enum SleepStage {
  awake,
  lightSleep,
  deepSleep,
  remSleep,
}

class SleepStageDetector {
  StreamSubscription<AccelerometerEvent>? _subscription;
  final _movementBuffer = <double>[];
  final int _bufferSize = 600; // 1分钟的数据(10Hz采样率)
  final Function(SleepStage) onSleepStageChanged;
  
  Timer? _analysisTimer;
  DateTime? _lastStageChange;
  SleepStage _currentStage = SleepStage.awake;
  final List<SleepStageRecord> stageRecords = [];
  SleepStage? _previousStage;
  DateTime? _stageStartTime;
  
  SleepStageDetector({required this.onSleepStageChanged});

  void startDetecting() {
    _subscription = accelerometerEvents.listen((event) {
      // 计算三轴加速度的合成值
      final magnitude = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));
      
      _movementBuffer.add(magnitude);
      if (_movementBuffer.length > _bufferSize) {
        _movementBuffer.removeAt(0);
      }
    });

    // 每30秒分析一次睡眠状态
    _analysisTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _analyzeSleepStage();
    });
  }

  void stopDetecting() {
    // 记录最后一个阶段
    if (_previousStage != null && _stageStartTime != null) {
      stageRecords.add(SleepStageRecord(
        startTime: _stageStartTime!,
        endTime: DateTime.now(),
        stageName: getSleepStageDescription(_previousStage!),
      ));
    }
    
    _subscription?.cancel();
    _analysisTimer?.cancel();
    _movementBuffer.clear();
  }

  void _analyzeSleepStage() {
    if (_movementBuffer.length < _bufferSize) return;

    // 计算运动强度
    final avgMovement = _movementBuffer.reduce((a, b) => a + b) / _movementBuffer.length;
    final variance = _calculateVariance(_movementBuffer);
    
    // 基于时间和运动模式判断睡眠阶段
    final now = DateTime.now();
    final timeSinceLastChange = _lastStageChange != null 
        ? now.difference(_lastStageChange!) 
        : const Duration(minutes: 0);

    SleepStage newStage;
    
    // 这些阈值需要通过实验和机器学习来优化
    if (avgMovement > 12) {
      newStage = SleepStage.awake;
    } else if (avgMovement > 8) {
      newStage = SleepStage.lightSleep;
    } else if (variance > 2) {
      // REM期间可能会有突发性的小动作
      newStage = SleepStage.remSleep;
    } else {
      newStage = SleepStage.deepSleep;
    }

    // 防止频繁切换状态
    if (newStage != _currentStage && timeSinceLastChange.inMinutes >= 10) {
      // 记录上一个阶段
      if (_previousStage != null && _stageStartTime != null) {
        stageRecords.add(SleepStageRecord(
          startTime: _stageStartTime!,
          endTime: now,
          stageName: getSleepStageDescription(_previousStage!),
        ));
      }
      
      _currentStage = newStage;
      _previousStage = newStage;
      _stageStartTime = now;
      _lastStageChange = now;
      onSleepStageChanged(newStage);
    }
  }

  double _calculateVariance(List<double> values) {
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((value) => pow(value - mean, 2));
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  String getSleepStageDescription(SleepStage stage) {
    switch (stage) {
      case SleepStage.awake:
        return '清醒';
      case SleepStage.lightSleep:
        return '浅睡眠';
      case SleepStage.deepSleep:
        return '深睡眠';
      case SleepStage.remSleep:
        return 'REM睡眠';
    }
  }
} 