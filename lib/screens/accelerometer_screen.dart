import 'package:flutter/cupertino.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

class AccelerometerScreen extends StatefulWidget {
  const AccelerometerScreen({super.key});

  @override
  State<AccelerometerScreen> createState() => _AccelerometerScreenState();
}

class _AccelerometerScreenState extends State<AccelerometerScreen> {
  AccelerometerEvent? _accelerometerEvent;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  @override
  void initState() {
    super.initState();
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      setState(() {
        _accelerometerEvent = event;
      });
    });
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('加速度传感器'),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '实时加速度数据',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(
                'X: ${_accelerometerEvent?.x.toStringAsFixed(2) ?? "0.00"} m/s²',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 10),
              Text(
                'Y: ${_accelerometerEvent?.y.toStringAsFixed(2) ?? "0.00"} m/s²',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 10),
              Text(
                'Z: ${_accelerometerEvent?.z.toStringAsFixed(2) ?? "0.00"} m/s²',
                style: const TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 