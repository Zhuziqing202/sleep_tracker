import 'package:flutter/cupertino.dart';
import '../controllers/audio_controller.dart';

class AudioSelectionCard extends StatelessWidget {
  final AudioController audioController;
  final double volume;

  const AudioSelectionCard({
    super.key,
    required this.audioController,
    required this.volume,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              '助眠音频',
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
                    onChanged: (value) {
                      audioController.setVolume(value);
                    },
                    min: 0,
                    max: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: [
                _buildAudioButton('助眠', 'sleep'),
                _buildAudioButton('浅睡眠', 'light'),
                _buildAudioButton('深睡眠', 'deep'),
                _buildAudioButton('REM睡眠', 'rem'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioButton(String label, String type) {
    return StatefulBuilder(
      builder: (context, setState) {
        final isPlaying = audioController.isPlaying(type);
        final isPaused = audioController.isPaused(type);
        
        return Container(
          width: (MediaQuery.of(context).size.width - 64) / 2, // 确保每行两个按钮
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: isPlaying || isPaused 
                ? CupertinoColors.activeBlue 
                : CupertinoColors.systemGrey5,
            borderRadius: BorderRadius.circular(12),
            onPressed: () async {
              await audioController.playAudio(type);
              setState(() {});
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPlaying 
                      ? CupertinoIcons.pause_fill
                      : isPaused 
                          ? CupertinoIcons.play_fill
                          : CupertinoIcons.play_fill,
                  color: isPlaying || isPaused 
                      ? CupertinoColors.white 
                      : CupertinoColors.label,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isPlaying || isPaused 
                        ? CupertinoColors.white 
                        : CupertinoColors.label,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 