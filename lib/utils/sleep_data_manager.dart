import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/sleep_record.dart';

class SleepDataManager {
  static const String _dataSourceKey = 'sleep_data_source';
  static const String _sleepSessionsKey = 'sleep_sessions';
  
  static Future<String> getDataSource() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dataSourceKey) ?? 'sensor';
  }
  
  static Future<void> setDataSource(String source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dataSourceKey, source);
  }
  
  static Future<void> saveSleepSession(SleepSession session) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> sessions = prefs.getStringList(_sleepSessionsKey) ?? [];
    sessions.add(jsonEncode(session.toJson()));
    await prefs.setStringList(_sleepSessionsKey, sessions);
  }
  
  static Future<List<SleepSession>> getSleepSessions() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> sessions = prefs.getStringList(_sleepSessionsKey) ?? [];
    return sessions
        .map((s) => SleepSession.fromJson(jsonDecode(s)))
        .toList();
  }
  
  static Future<void> deleteSleepSession(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> sessions = prefs.getStringList(_sleepSessionsKey) ?? [];
    sessions.removeWhere((s) {
      final session = SleepSession.fromJson(jsonDecode(s));
      return session.date.year == date.year && 
             session.date.month == date.month && 
             session.date.day == date.day;
    });
    await prefs.setStringList(_sleepSessionsKey, sessions);
  }
} 