import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RhythmXService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("No logged-in user found");
    }
    return user.uid;
  }

  String get todayKey {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  // =========================
  // TASKS
  // =========================

  Future<void> addTask({
    required String title,
    required String description,
    required String priority,
    required String category,
    required String energyRequired,
    required int estimatedMinutes,
    DateTime? dueDate,
  }) async {
    await _db.collection('tasks').add({
      'uid': uid,
      'title': title,
      'description': description,
      'priority': priority,
      'category': category,
      'energyRequired': energyRequired,
      'estimatedMinutes': estimatedMinutes,
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': null,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMyTasks() {
    return _db.collection('tasks').where('uid', isEqualTo: uid).snapshots();
  }

  Future<void> markTaskDone(String taskId) async {
    await _db.collection('tasks').doc(taskId).update({
      'status': 'done',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markTaskPending(String taskId) async {
    await _db.collection('tasks').doc(taskId).update({
      'status': 'pending',
      'completedAt': null,
    });
  }

  Future<void> deleteTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).delete();
  }

  // =========================
  // SCORING
  // =========================

  int _stateScore(String value) {
    switch (value) {
      case "low":
        return 1;
      case "medium":
        return 2;
      case "high":
        return 3;
      default:
        return 2;
    }
  }

  int _energyScore(String energy) {
    switch (energy) {
      case "low":
        return 1;
      case "medium":
        return 2;
      case "high":
        return 3;
      default:
        return 2;
    }
  }

  int _priorityScore(String priority) {
    switch (priority) {
      case "high":
        return 3;
      case "medium":
        return 2;
      case "low":
        return 1;
      default:
        return 2;
    }
  }

  int calculateReadinessScore({
    required String energy,
    required String focus,
    required String stress,
  }) {
    final energyScore = _stateScore(energy);
    final focusScore = _stateScore(focus);
    final stressScore = _stateScore(stress);

    final rawScore = ((energyScore + focusScore + (4 - stressScore)) / 9) * 100;

    return rawScore.round();
  }

  String getRecommendedAction(int readinessScore) {
    if (readinessScore >= 75) {
      return "Deep Work";
    } else if (readinessScore >= 55) {
      return "Normal Tasks";
    } else if (readinessScore >= 35) {
      return "Light Tasks";
    } else {
      return "Rest / Recovery";
    }
  }

  // =========================
  // RECOMMENDATION ENGINE
  // =========================

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getRecommendedTasks({
    required String currentEnergy,
    required int availableMinutes,
  }) async {
    final snapshot = await _db
        .collection('tasks')
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .get();

    final currentEnergyScore = _energyScore(currentEnergy);

    final filteredTasks = snapshot.docs.where((doc) {
      final taskData = doc.data();

      final taskEnergy = taskData['energyRequired'] ?? 'medium';
      final taskMinutes = (taskData['estimatedMinutes'] as num?)?.toInt() ?? 30;

      final taskEnergyScore = _energyScore(taskEnergy);

      return taskEnergyScore <= currentEnergyScore &&
          taskMinutes <= availableMinutes;
    }).toList();

    filteredTasks.sort((a, b) {
      final taskA = a.data();
      final taskB = b.data();

      final priorityA = _priorityScore(taskA['priority'] ?? 'medium');
      final priorityB = _priorityScore(taskB['priority'] ?? 'medium');

      return priorityB.compareTo(priorityA);
    });

    return filteredTasks;
  }

  // =========================
  // SMART DAILY SCHEDULE
  // =========================

  Future<List<Map<String, dynamic>>> generateSmartSchedule({
    required String currentEnergy,
    required int availableMinutes,
    int startHour = 9,
  }) async {
    final tasks = await getRecommendedTasks(
      currentEnergy: currentEnergy,
      availableMinutes: availableMinutes,
    );

    final schedule = <Map<String, dynamic>>[];

    int usedMinutes = 0;

    DateTime cursor = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      startHour,
      0,
    );

    for (final doc in tasks) {
      final data = doc.data();

      final taskMinutes = (data['estimatedMinutes'] as num?)?.toInt() ?? 30;

      if (usedMinutes + taskMinutes > availableMinutes) {
        continue;
      }

      final startTime = cursor;
      final endTime = cursor.add(Duration(minutes: taskMinutes));

      schedule.add({
        'taskId': doc.id,
        'title': data['title'] ?? '',
        'description': data['description'] ?? '',
        'priority': data['priority'] ?? 'medium',
        'category': data['category'] ?? 'general',
        'energyRequired': data['energyRequired'] ?? 'medium',
        'estimatedMinutes': taskMinutes,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
      });

      usedMinutes += taskMinutes;

      cursor = endTime.add(const Duration(minutes: 10));
    }

    return schedule;
  }

  Future<void> saveDailySchedule({
    required List<Map<String, dynamic>> schedule,
    required int readinessScore,
    required String recommendedAction,
    required String energy,
    required String focus,
    required String stress,
    required int availableMinutes,
  }) async {
    await _db.collection('daily_schedules').doc("${uid}_$todayKey").set({
      'uid': uid,
      'dateKey': todayKey,
      'schedule': schedule,
      'readinessScore': readinessScore,
      'recommendedAction': recommendedAction,
      'energy': energy,
      'focus': focus,
      'stress': stress,
      'availableMinutes': availableMinutes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getTodaySchedule() async {
    final doc = await _db
        .collection('daily_schedules')
        .doc("${uid}_$todayKey")
        .get();

    if (!doc.exists) {
      return null;
    }

    return doc.data();
  }

  Future<void> deleteTodaySchedule() async {
    await _db.collection('daily_schedules').doc("${uid}_$todayKey").delete();
  }

  // =========================
  // TODAY STATE + DAILY LOGS
  // =========================

  Future<void> saveTodayState({
    required String energy,
    required String focus,
    required String stress,
    required int availableMinutes,
    required int readinessScore,
    required String recommendedAction,
    String? recommendedTaskId,
    String? recommendedTaskTitle,
  }) async {
    final todayData = {
      'uid': uid,
      'dateKey': todayKey,
      'energy': energy,
      'focus': focus,
      'stress': stress,
      'availableMinutes': availableMinutes,
      'readinessScore': readinessScore,
      'recommendedAction': recommendedAction,
      'recommendedTaskId': recommendedTaskId,
      'recommendedTaskTitle': recommendedTaskTitle,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _db.collection('today_state').doc(uid).set(todayData);

    await _db.collection('daily_logs').add({
      ...todayData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> getTodayState() async {
    final doc = await _db.collection('today_state').doc(uid).get();

    if (!doc.exists) {
      return null;
    }

    final data = doc.data();

    if (data == null) {
      return null;
    }

    if (data['dateKey'] != todayKey) {
      return null;
    }

    return data;
  }

  // =========================
  // ANALYTICS
  // =========================

  Future<Map<String, dynamic>> getAnalytics() async {
    final snapshot = await _db
        .collection('daily_logs')
        .where('uid', isEqualTo: uid)
        .get();

    if (snapshot.docs.isEmpty) {
      return {'totalChecks': 0, 'averageScore': 0, 'currentStreak': 0};
    }

    int totalScore = 0;
    final dateKeys = <String>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final score = data['readinessScore'] ?? 0;
      final dateKey = data['dateKey'];

      if (score is int) {
        totalScore += score;
      }

      if (dateKey is String) {
        dateKeys.add(dateKey);
      }
    }

    final averageScore = (totalScore / snapshot.docs.length).round();
    final currentStreak = _calculateCurrentStreak(dateKeys);

    return {
      'totalChecks': snapshot.docs.length,
      'averageScore': averageScore,
      'currentStreak': currentStreak,
    };
  }

  int _calculateCurrentStreak(Set<String> dateKeys) {
    int streak = 0;
    DateTime cursor = DateTime.now();

    while (true) {
      final key =
          "${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}";

      if (dateKeys.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }
}
