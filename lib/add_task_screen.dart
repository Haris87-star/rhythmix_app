import 'package:flutter/material.dart';
import 'services/rhythmix_service.dart' as rhythmix;

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final minutesController = TextEditingController();

  final service = rhythmix.RhythmXService();

  String priority = "medium";
  String category = "study";
  String energyRequired = "medium";

  DateTime? dueDate;
  bool isLoading = false;

  Future<void> pickDueDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );

    if (selectedDate != null) {
      setState(() {
        dueDate = selectedDate;
      });
    }
  }

  Future<void> addTask() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();
    final estimatedMinutes = int.tryParse(minutesController.text.trim()) ?? 30;

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Task title is required")));
      return;
    }

    if (estimatedMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Estimated minutes must be valid")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await service.addTask(
        title: title,
        description: description,
        priority: priority,
        category: category,
        energyRequired: energyRequired,
        estimatedMinutes: estimatedMinutes,
        dueDate: dueDate,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Task saved successfully")));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to save task: $e")));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dueDateText = dueDate == null
        ? "No due date selected"
        : "${dueDate!.day}/${dueDate!.month}/${dueDate!.year}";

    return Scaffold(
      appBar: AppBar(title: const Text("Add RhythmX Task")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Task Title",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: priority,
              decoration: const InputDecoration(
                labelText: "Priority",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "low", child: Text("Low")),
                DropdownMenuItem(value: "medium", child: Text("Medium")),
                DropdownMenuItem(value: "high", child: Text("High")),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => priority = value);
                }
              },
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(
                labelText: "Category",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "study", child: Text("Study")),
                DropdownMenuItem(value: "work", child: Text("Work")),
                DropdownMenuItem(value: "health", child: Text("Health")),
                DropdownMenuItem(value: "personal", child: Text("Personal")),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => category = value);
                }
              },
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: energyRequired,
              decoration: const InputDecoration(
                labelText: "Energy Required",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "low", child: Text("Low Energy")),
                DropdownMenuItem(value: "medium", child: Text("Medium Energy")),
                DropdownMenuItem(value: "high", child: Text("High Energy")),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => energyRequired = value);
                }
              },
            ),

            const SizedBox(height: 12),

            TextField(
              controller: minutesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Estimated Minutes",
                hintText: "Example: 45",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: Text(dueDateText)),
                TextButton(
                  onPressed: pickDueDate,
                  child: const Text("Pick Due Date"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : addTask,
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Save Task"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
