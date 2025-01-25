import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/sleep_data_manager.dart';

class SleepRecordScreen extends StatefulWidget {
  const SleepRecordScreen({super.key});

  @override
  State<SleepRecordScreen> createState() => _SleepRecordScreenState();
}

class _SleepRecordScreenState extends State<SleepRecordScreen> {
  static const platform = MethodChannel('com.example.sleep_tracker/health');
  List<Map<String, dynamic>> _sleepRecords = [];
  bool _isLoading = true;
  String _currentDataSource = 'sensor';

  @override
  void initState() {
    super.initState();
    _loadSleepData();
  }

  Future<void> _loadSleepData() async {
    try {
      _currentDataSource = await SleepDataManager.getDataSource();
      
      if (_currentDataSource == 'health') {
        final List<dynamic> data = await platform.invokeMethod('getLast30DaysSleepData');
        setState(() {
          _sleepRecords = data.map((item) {
            return {
              'date': DateTime.parse(item['date'] as String),
              'totalDuration': Duration(seconds: item['totalDuration'] as int),
              'deepSleep': Duration(seconds: item['deepSleep'] as int),
              'lightSleep': Duration(seconds: item['lightSleep'] as int),
              'remSleep': Duration(seconds: item['remSleep'] as int),
              'bedTime': DateTime.parse(item['bedTime'] as String),
              'wakeTime': DateTime.parse(item['wakeTime'] as String),
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        final sessions = await SleepDataManager.getSleepSessions();
        setState(() {
          _sleepRecords = sessions.where((s) => s.dataSource == 'sensor').map((session) {
            Duration deepSleep = Duration.zero;
            Duration lightSleep = Duration.zero;
            Duration remSleep = Duration.zero;
            
            for (var stage in session.stages) {
              final duration = stage.endTime.difference(stage.startTime);
              switch (stage.stageName) {
                case '深睡眠':
                  deepSleep += duration;
                  break;
                case '浅睡眠':
                  lightSleep += duration;
                  break;
                case 'REM睡眠':
                  remSleep += duration;
                  break;
              }
            }
            
            return {
              'date': session.date,
              'totalDuration': deepSleep + lightSleep + remSleep,
              'deepSleep': deepSleep,
              'lightSleep': lightSleep,
              'remSleep': remSleep,
              'bedTime': session.stages.first.startTime,
              'wakeTime': session.stages.last.endTime,
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('获取睡眠数据失败: $e');
    }
  }

  void _showSleepDetail(Map<String, dynamic> record) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => _SleepDetailSheet(record: record),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60);
    return '$hours小时$minutes分钟';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('睡眠记录'),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  CupertinoSliverRefreshControl(
                    onRefresh: _loadSleepData,
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final record = _sleepRecords[index];
                        final date = record['date'] as DateTime;
                        final duration = record['totalDuration'] as Duration?;
                        
                        return Column(
                          children: [
                            Dismissible(
                              key: Key(date.toIso8601String()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: CupertinoColors.destructiveRed,
                                child: const Icon(
                                  CupertinoIcons.delete,
                                  color: CupertinoColors.white,
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                bool? confirmDelete = await showCupertinoDialog<bool>(
                                  context: context,
                                  builder: (BuildContext context) => CupertinoAlertDialog(
                                    title: const Text('确认删除'),
                                    content: const Text('确定要删除这条睡眠记录吗？'),
                                    actions: <CupertinoDialogAction>[
                                      CupertinoDialogAction(
                                        isDestructiveAction: true,
                                        onPressed: () {
                                          Navigator.pop(context, true);
                                        },
                                        child: const Text('删除'),
                                      ),
                                      CupertinoDialogAction(
                                        isDefaultAction: true,
                                        onPressed: () {
                                          Navigator.pop(context, false);
                                        },
                                        child: const Text('取消'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmDelete == true) {
                                  await SleepDataManager.deleteSleepSession(date);
                                  setState(() {
                                    _sleepRecords.removeAt(index);
                                  });
                                  return true;
                                }
                                return false;
                              },
                              child: CupertinoListTile(
                                leading: const Icon(
                                  FontAwesomeIcons.moon,
                                  color: CupertinoColors.systemBlue,
                                  size: 20,
                                ),
                                title: Text(
                                  '${date.month}月${date.day}日',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  duration != null 
                                      ? '睡眠时长：${_formatDuration(duration)}'
                                      : '无睡眠记录',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ),
                                trailing: duration != null 
                                    ? const Icon(
                                        CupertinoIcons.chevron_forward,
                                        color: CupertinoColors.systemGrey,
                                      )
                                    : null,
                                onTap: duration != null 
                                    ? () => _showSleepDetail(record)
                                    : null,
                              ),
                            ),
                            if (index < _sleepRecords.length - 1)
                              Container(
                                height: 0.5,
                                margin: const EdgeInsets.symmetric(horizontal: 16),
                                color: CupertinoColors.separator,
                              ),
                          ],
                        );
                      },
                      childCount: _sleepRecords.length,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SleepDetailSheet extends StatelessWidget {
  final Map<String, dynamic> record;

  const _SleepDetailSheet({required this.record});

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60);
    return '$hours小时$minutes分钟';
  }

  @override
  Widget build(BuildContext context) {
    final date = record['date'] as DateTime;
    final bedTime = record['bedTime'] as DateTime;
    final wakeTime = record['wakeTime'] as DateTime;
    final deepSleep = record['deepSleep'] as Duration;
    final lightSleep = record['lightSleep'] as Duration;
    final remSleep = record['remSleep'] as Duration;

    return CupertinoPopupSurface(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.month}月${date.day}日睡眠详情',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('入睡时间', _formatTime(bedTime)),
            _buildDetailRow('起床时间', _formatTime(wakeTime)),
            const SizedBox(height: 8),
            _buildDetailRow('深度睡眠', _formatDuration(deepSleep)),
            _buildDetailRow('浅度睡眠', _formatDuration(lightSleep)),
            _buildDetailRow('REM睡眠', _formatDuration(remSleep)),
            const SizedBox(height: 16),
            CupertinoButton(
              child: const Text('关闭'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: CupertinoColors.systemGrey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
} 