import 'package:flutter/cupertino.dart';

class MusicSettingsCard extends StatelessWidget {
  final double volume;
  final bool isPlaying;
  final Function(double) onVolumeChanged;
  final Function(bool) onPlayingChanged;

  const MusicSettingsCard({
    super.key,
    required this.volume,
    required this.isPlaying,
    required this.onVolumeChanged,
    required this.onPlayingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '音乐设置',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  CupertinoIcons.volume_up,
                  color: CupertinoColors.systemGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CupertinoSlider(
                    value: volume,
                    onChanged: onVolumeChanged,
                    min: 0,
                    max: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '播放背景音乐',
                  style: TextStyle(fontSize: 16),
                ),
                CupertinoSwitch(
                  value: isPlaying,
                  onChanged: onPlayingChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 