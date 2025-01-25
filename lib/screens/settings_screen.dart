import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../screens/accelerometer_screen.dart';
import '../utils/sleep_data_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _dataSource = 'sensor';

  @override
  void initState() {
    super.initState();
    _loadDataSource();
  }

  Future<void> _loadDataSource() async {
    final source = await SleepDataManager.getDataSource();
    setState(() {
      _dataSource = source;
    });
  }

  void _showDataSourcePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('选择数据来源'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              await SleepDataManager.setDataSource('sensor');
              setState(() => _dataSource = 'sensor');
              Navigator.pop(context);
            },
            child: const Text('传感器数据'),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              await SleepDataManager.setDataSource('health');
              setState(() => _dataSource = 'health');
              Navigator.pop(context);
            },
            child: const Text('Apple健康'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ),
    );
  }

  void _showVersionInfo(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('版本信息'),
        message: const Text(
          '当前版本：v0.0.2\n\n'
          '开发团队：\n'
          '我来帮你画、&、sky',
          textAlign: TextAlign.center,
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('设置'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 10),
            CupertinoListSection(
              children: [
                CupertinoListTile(
                  leading: const Icon(
                    FontAwesomeIcons.circleInfo,
                    color: CupertinoColors.systemBlue,
                    size: 20,
                  ),
                  title: const Text('版本信息'),
                  trailing: const Icon(
                    CupertinoIcons.chevron_forward,
                    color: CupertinoColors.systemGrey,
                  ),
                  onTap: () => _showVersionInfo(context),
                ),
                CupertinoListTile(
                  leading: const Icon(
                    FontAwesomeIcons.gauge,
                    color: CupertinoColors.systemBlue,
                    size: 20,
                  ),
                  title: const Text('加速度传感器'),
                  trailing: const Icon(
                    CupertinoIcons.chevron_forward,
                    color: CupertinoColors.systemGrey,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => const AccelerometerScreen(),
                      ),
                    );
                  },
                ),
                CupertinoListTile(
                  leading: const Icon(
                    FontAwesomeIcons.database,
                    color: CupertinoColors.systemBlue,
                    size: 20,
                  ),
                  title: const Text('数据来源'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dataSource == 'sensor' ? '传感器数据' : 'Apple健康',
                        style: const TextStyle(
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        CupertinoIcons.chevron_forward,
                        color: CupertinoColors.systemGrey,
                      ),
                    ],
                  ),
                  onTap: _showDataSourcePicker,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}