import 'package:flutter/cupertino.dart';
import 'dart:async';
import '../utils/sleep_stage_detector.dart';
import '../utils/sleep_data_manager.dart';
import '../models/sleep_record.dart';

// 睡眠状态枚举
enum SleepState {
  notStarted,  // 未开始睡眠
  sleeping,    // 正在睡眠
}

class StartSleepScreen extends StatefulWidget {
  const StartSleepScreen({super.key});

  @override
  State<StartSleepScreen> createState() => _StartSleepScreenState();
}

class _StartSleepScreenState extends State<StartSleepScreen> {
  // 状态变量
  SleepState _sleepState = SleepState.notStarted;
  DateTime? _earliestWakeTime;  // 最早醒来时间
  DateTime? _latestWakeTime;    // 最晚醒来时间
  DateTime? _sleepStartTime;    // 睡眠开始时间
  Timer? _sleepTimer;          // 睡眠计时器
  Duration _sleepDuration = Duration.zero;  // 已睡眠时长
  SleepStageDetector? _sleepStageDetector;
  String _currentSleepStage = '未开始';

  @override
  void initState() {
    super.initState();
    // 设置默认时间
    final now = DateTime.now();
    _earliestWakeTime = now.add(const Duration(hours: 8));
    _latestWakeTime = now.add(const Duration(hours: 9));
  }

  // 计算预期睡眠时长
  String _getExpectedSleepDuration() {
    final now = DateTime.now();
    final duration = _latestWakeTime!.difference(now);
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60);
    
    return '预计睡眠时长：$hours小时$minutes分钟';
  }

  // 更新睡眠时长
  void _updateSleepDuration() {
    if (_sleepStartTime == null) return;
    
    setState(() {
      _sleepDuration = DateTime.now().difference(_sleepStartTime!);
    });
  }

  // 开始睡眠
  void _startSleep() {
    setState(() {
      _sleepState = SleepState.sleeping;
      _sleepStartTime = DateTime.now();
    });
    
    // 初始化睡眠阶段检测
    _sleepStageDetector = SleepStageDetector(
      onSleepStageChanged: (stage) {
        setState(() {
          _currentSleepStage = _sleepStageDetector!.getSleepStageDescription(stage);
        });
      }
    );
    _sleepStageDetector!.startDetecting();
    
    // 启动计时器
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateSleepDuration();
    });
  }

  // 结束睡眠
  void _endSleep() async {
    _sleepStageDetector?.stopDetecting();
    _sleepTimer?.cancel();

    // 如果没有记录到任何睡眠阶段，添加一个默认的浅睡眠记录
    if (_sleepStageDetector != null && _sleepStageDetector!.stageRecords.isEmpty && _sleepStartTime != null) {
      final now = DateTime.now();
      _sleepStageDetector!.stageRecords.add(SleepStageRecord(
        startTime: _sleepStartTime!,
        endTime: now,
        stageName: '浅睡眠',
      ));
    }
    
    // 保存睡眠记录
    if (_sleepStageDetector != null && _sleepStartTime != null) {
      final session = SleepSession(
        date: _sleepStartTime!,
        stages: _sleepStageDetector!.stageRecords,
        dataSource: 'sensor',
      );
      await SleepDataManager.saveSleepSession(session);
    }

    setState(() {
      _sleepState = SleepState.notStarted;
      _sleepStartTime = null;
      _sleepDuration = Duration.zero;
      _currentSleepStage = '未开始';
      // 重新设置默认唤醒时间
      final now = DateTime.now();
      _earliestWakeTime = now.add(const Duration(hours: 8));
      _latestWakeTime = now.add(const Duration(hours: 9));
    });
  }

  // 格式化时间显示
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60);
    final seconds = (duration.inSeconds % 60);
    return '$hours小时$minutes分钟$seconds秒';
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 根据睡眠状态返回不同的界面
    return _sleepState == SleepState.notStarted
        ? _buildSetupScreen()
        : _buildSleepingScreen();
  }

  // 构建设置界面
  Widget _buildSetupScreen() {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('开始睡眠'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 时间选择器容器
              Row(
                children: [
                  // 最早醒来时间选择器
                  Expanded(
                    child: _buildTimeSelector(
                      '最早醒来时间',
                      _earliestWakeTime,
                      (DateTime time) {
                        setState(() => _earliestWakeTime = time);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 最晚醒来时间选择器
                  Expanded(
                    child: _buildTimeSelector(
                      '最晚醒来时间',
                      _latestWakeTime,
                      (DateTime time) {
                        setState(() => _latestWakeTime = time);
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              const Text(
                '智能闹钟将在您的浅睡眠阶段唤醒您，\n让您醒来更加轻松自然。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CupertinoColors.systemGrey,
                  fontSize: 14,
                ),
              ),
              
              const SizedBox(height: 20),
              Text(
                _getExpectedSleepDuration(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 40),
              CupertinoButton.filled(
                onPressed: _earliestWakeTime != null && _latestWakeTime != null
                    ? _startSleep
                    : null,
                child: const Text('开始睡眠'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建睡眠中界面
  Widget _buildSleepingScreen() {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('睡眠监测中'),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '当前睡眠阶段\n$_currentSleepStage',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '已睡眠时间\n${_formatDuration(_sleepDuration)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  '预计唤醒时间\n${_earliestWakeTime?.hour}:${_earliestWakeTime?.minute} - '
                  '${_latestWakeTime?.hour}:${_latestWakeTime?.minute}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 60),
                CupertinoButton.filled(  // 使用 filled 样式
                  onPressed: _endSleep,
                  child: const Text('结束睡眠'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建时间选择器
  Widget _buildTimeSelector(
    String title,
    DateTime? selectedTime,
    Function(DateTime) onTimeSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        const SizedBox(height: 8),
        Container(
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemGrey5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: true,
            initialDateTime: selectedTime ?? DateTime.now().add(const Duration(hours: 8)),
            onDateTimeChanged: onTimeSelected,
          ),
        ),
      ],
    );
  }
} 