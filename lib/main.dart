import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'login_screen.dart';
import 'add_task_screen.dart';
import 'services/rhythmix_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RhythmX',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return const RhythmXHomeScreen();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}

class RhythmXHomeScreen extends StatefulWidget {
  const RhythmXHomeScreen({super.key});

  @override
  State<RhythmXHomeScreen> createState() => _RhythmXHomeScreenState();
}

class _RhythmXHomeScreenState extends State<RhythmXHomeScreen> {
  final service = RhythmXService();

  Map<String, dynamic>? todayState;
  Map<String, dynamic>? analytics;
  Map<String, dynamic>? todaySchedule;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    setState(() => isLoading = true);

    final today = await service.getTodayState();
    final stats = await service.getAnalytics();
    final schedule = await service.getTodaySchedule();

    setState(() {
      todayState = today;
      analytics = stats;
      todaySchedule = schedule;
      isLoading = false;
    });

    if (today == null && mounted) {
      await showDailyCheckDialog();
    }
  }

  Future<void> showDailyCheckDialog() async {
    String energy = "medium";
    String focus = "medium";
    String stress = "medium";

    final minutesController = TextEditingController(text: "180");
    final startHourController = TextEditingController(text: "9");

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Daily Rhythm Check"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: energy,
                      decoration: const InputDecoration(
                        labelText: "Energy",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: "low", child: Text("Low")),
                        DropdownMenuItem(
                          value: "medium",
                          child: Text("Medium"),
                        ),
                        DropdownMenuItem(value: "high", child: Text("High")),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => energy = value);
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: focus,
                      decoration: const InputDecoration(
                        labelText: "Focus",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: "low", child: Text("Low")),
                        DropdownMenuItem(
                          value: "medium",
                          child: Text("Medium"),
                        ),
                        DropdownMenuItem(value: "high", child: Text("High")),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => focus = value);
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: stress,
                      decoration: const InputDecoration(
                        labelText: "Stress",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: "low", child: Text("Low")),
                        DropdownMenuItem(
                          value: "medium",
                          child: Text("Medium"),
                        ),
                        DropdownMenuItem(value: "high", child: Text("High")),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => stress = value);
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: minutesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Available Minutes Today",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: startHourController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Start Hour",
                        hintText: "Example: 9",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    final availableMinutes =
                        int.tryParse(minutesController.text.trim()) ?? 180;

                    final startHour =
                        int.tryParse(startHourController.text.trim()) ?? 9;

                    final readinessScore = service.calculateReadinessScore(
                      energy: energy,
                      focus: focus,
                      stress: stress,
                    );

                    final recommendedAction = service.getRecommendedAction(
                      readinessScore,
                    );

                    final recommendations = await service.getRecommendedTasks(
                      currentEnergy: energy,
                      availableMinutes: availableMinutes,
                    );

                    String? taskId;
                    String? taskTitle;

                    if (recommendations.isNotEmpty) {
                      final bestTask = recommendations.first;
                      final data = bestTask.data();

                      taskId = bestTask.id;
                      taskTitle = data['title'];
                    }

                    final schedule = await service.generateSmartSchedule(
                      currentEnergy: energy,
                      availableMinutes: availableMinutes,
                      startHour: startHour,
                    );

                    await service.saveTodayState(
                      energy: energy,
                      focus: focus,
                      stress: stress,
                      availableMinutes: availableMinutes,
                      readinessScore: readinessScore,
                      recommendedAction: recommendedAction,
                      recommendedTaskId: taskId,
                      recommendedTaskTitle: taskTitle,
                    );

                    await service.saveDailySchedule(
                      schedule: schedule,
                      readinessScore: readinessScore,
                      recommendedAction: recommendedAction,
                      energy: energy,
                      focus: focus,
                      stress: stress,
                      availableMinutes: availableMinutes,
                    );

                    if (!mounted) return;

                    Navigator.pop(context);
                    await loadDashboard();
                  },
                  child: const Text("Generate Smart Schedule"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String formatDueDate(dynamic dueDate) {
    if (dueDate == null) {
      return "No due date";
    }

    if (dueDate is Timestamp) {
      final date = dueDate.toDate();
      return "${date.day}/${date.month}/${date.year}";
    }

    return "No due date";
  }

  String formatTime(dynamic timestamp) {
    if (timestamp == null) {
      return "--:--";
    }

    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return "$hour:$minute";
    }

    return "--:--";
  }

  List<dynamic> getScheduleItems() {
    final schedule = todaySchedule?['schedule'];

    if (schedule is List) {
      return schedule;
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final score = todayState?['readinessScore'] ?? 0;
    final action = todayState?['recommendedAction'] ?? "Not checked";
    final taskTitle = todayState?['recommendedTaskTitle'];

    final totalChecks = analytics?['totalChecks'] ?? 0;
    final averageScore = analytics?['averageScore'] ?? 0;
    final currentStreak = analytics?['currentStreak'] ?? 0;

    final scheduleItems = getScheduleItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text("RhythmX"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: showDailyCheckDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: loadDashboard,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (user != null)
              Text(
                "UID: ${user.uid}",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today’s Rhythm",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Readiness Score: $score",
                      style: const TextStyle(fontSize: 18),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Recommended Mode: $action",
                      style: const TextStyle(fontSize: 18),
                    ),

                    const SizedBox(height: 12),

                    if (taskTitle != null)
                      Text(
                        "Top Task: $taskTitle",
                        style: const TextStyle(fontSize: 16),
                      )
                    else
                      const Text(
                        "No matching task found for your current state.",
                        style: TextStyle(fontSize: 16),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _StatCard(title: "Checks", value: "$totalChecks"),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(title: "Avg Score", value: "$averageScore"),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(title: "Streak", value: "$currentStreak"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Smart Schedule",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: showDailyCheckDialog,
                  child: const Text("Regenerate"),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (scheduleItems.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text("No schedule generated yet."),
                ),
              )
            else
              Column(
                children: scheduleItems.map((item) {
                  final data = item as Map<String, dynamic>;

                  final start = formatTime(data['startTime']);
                  final end = formatTime(data['endTime']);
                  final title = data['title'] ?? '';
                  final priority = data['priority'] ?? 'medium';
                  final category = data['category'] ?? 'general';
                  final energy = data['energyRequired'] ?? 'medium';
                  final minutes = data['estimatedMinutes'] ?? 30;

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text("$start - $end"),
                      subtitle: Text(
                        "$title\n"
                        "Priority: $priority | Category: $category\n"
                        "Energy: $energy | Time: $minutes mins",
                      ),
                      isThreeLine: true,
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 20),

            const Text(
              "Your Tasks",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: service.getMyTasks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text("No tasks yet. Add your first task."),
                    ),
                  );
                }

                final tasks = snapshot.data!.docs;

                return Column(
                  children: tasks.map((doc) {
                    final data = doc.data();

                    final title = data['title'] ?? '';
                    final description = data['description'] ?? '';
                    final priority = data['priority'] ?? 'medium';
                    final status = data['status'] ?? 'pending';
                    final category = data['category'] ?? 'general';
                    final energyRequired = data['energyRequired'] ?? 'medium';
                    final estimatedMinutes = data['estimatedMinutes'] ?? 30;
                    final dueDate = formatDueDate(data['dueDate']);

                    final isDone = status == 'done';

                    return Card(
                      child: ListTile(
                        leading: Checkbox(
                          value: isDone,
                          onChanged: (value) async {
                            if (value == true) {
                              await service.markTaskDone(doc.id);
                            } else {
                              await service.markTaskPending(doc.id);
                            }
                            await loadDashboard();
                          },
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        subtitle: Text(
                          "$description\n"
                          "Priority: $priority | Category: $category\n"
                          "Energy: $energyRequired | Time: $estimatedMinutes mins\n"
                          "Due: $dueDate",
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await service.deleteTask(doc.id);
                            await loadDashboard();
                          },
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTaskScreen()),
          );

          await loadDashboard();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(title),
          ],
        ),
      ),
    );
  }
}
