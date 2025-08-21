import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ruya_tabir_app/models/dream.dart';

class DreamService {
  static const String _dreamsKey = 'dreams';

  Future<List<Dream>> getDreams() async {
    final prefs = await SharedPreferences.getInstance();
    final dreamsString = prefs.getString(_dreamsKey);
    if (dreamsString == null) {
      return [];
    }
    final List<dynamic> dreamsJson = jsonDecode(dreamsString);
    return dreamsJson
        .map((json) => Dream.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveDream(Dream dream) async {
    final prefs = await SharedPreferences.getInstance();
    final dreams = await getDreams();
    // Ensure the dream has a unique ID before saving
    final Dream dreamToSave;
    if (dreams.any((d) => d.id == dream.id)) {
      // If ID exists, or if it's a generic one from a new unsaved dream, generate new one.
      // This handles cases where an ID might not have been properly assigned yet,
      // or if it's a placeholder.
      dreamToSave = Dream(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Generate a new unique ID
        text: dream.text,
        interpretation: dream.interpretation,
        date: dream.date,
        status: dream.status,
        isSynced: dream.isSynced,
      );
    } else {
      dreamToSave = dream;
    }

    // Add new or updated dream
    final updatedDreams = [...dreams.where((d) => d.id != dreamToSave.id), dreamToSave];
    
    updatedDreams.sort((a, b) => b.date.compareTo(a.date));

    final dreamsString = jsonEncode(updatedDreams.map((d) => d.toJson()).toList());
    await prefs.setString(_dreamsKey, dreamsString);
  }

  Future<void> deleteDream(String dreamId) async {
    final prefs = await SharedPreferences.getInstance();
    final dreams = await getDreams();
    dreams.removeWhere((dream) => dream.id == dreamId);
    final dreamsString = jsonEncode(dreams.map((dream) => dream.toJson()).toList());
    await prefs.setString(_dreamsKey, dreamsString);
  }
} 