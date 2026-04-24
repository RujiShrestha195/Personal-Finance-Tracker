import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/goal.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<Goal> _goals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final userId = await AuthService.getCurrentUserId();
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final goals = await ApiService.getUserGoals(userId);
      setState(() {
        _goals = goals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading goals: ${e.toString()}')),
        );
      }
    }
  }

  void _showAddGoalDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddGoalDialog(
        onGoalAdded: _loadGoals,
      ),
    );
  }

  void _showEditGoalDialog(Goal goal) {
    showDialog(
      context: context,
      builder: (context) => _EditGoalDialog(
        goal: goal,
        onGoalUpdated: _loadGoals,
      ),
    );
  }

  Future<void> _deleteGoal(int goalId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: const Text('Are you sure you want to delete this goal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteGoal(goalId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Goal deleted successfully')),
          );
          _loadGoals();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GOALS'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
              ? const Center(
                  child: Text('No goals set yet. Tap the button below to add one.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _goals.length,
                  itemBuilder: (context, index) {
                    final goal = _goals[index];
                    return _GoalCard(
                      goal: goal,
                      onEdit: () => _showEditGoalDialog(goal),
                      onDelete: () => _deleteGoal(goal.id!),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddGoalDialog,
        label: const Text('SET A GOAL'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = goal.progressPercentage;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    goal.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: onEdit,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (goal.description != null && goal.description!.isNotEmpty)
              Text(
                goal.description!,
                style: TextStyle(color: Colors.grey[600]),
              ),
            const SizedBox(height: 12),
            Text(
              'Target Date: ${goal.targetDate.toString().split(' ')[0]}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Text(
              'Saved: Rs. ${goal.savedAmount.toStringAsFixed(2)} / Target: Rs. ${goal.targetAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 100 ? Colors.green : Colors.blue,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${progress.toStringAsFixed(1)}% complete',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDelete,
                  child: const Text(
                    'DELETE GOAL',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddGoalDialog extends StatefulWidget {
  final VoidCallback onGoalAdded;

  const _AddGoalDialog({required this.onGoalAdded});

  @override
  State<_AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<_AddGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _savedAmountController = TextEditingController(text: '0');
  final _descriptionController = TextEditingController();
  DateTime? _targetDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _savedAmountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _createGoal() async {
    if (!_formKey.currentState!.validate()) return;
    if (_targetDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target date')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) return;

      final goal = Goal(
        userId: userId,
        name: _nameController.text.trim(),
        targetAmount: double.parse(_targetAmountController.text),
        savedAmount: double.tryParse(_savedAmountController.text) ?? 0.0,
        targetDate: _targetDate!,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isReached: false,
      );

      await ApiService.createGoal(goal);
      if (mounted) {
        Navigator.pop(context);
        widget.onGoalAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('New Goal'),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Goal Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Goal name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetAmountController,
                decoration: const InputDecoration(
                  labelText: 'Target Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Target amount is required';
                  }
                  if (double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Target amount must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _savedAmountController,
                decoration: const InputDecoration(
                  labelText: 'Saved Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Saved amount is required (default: 0)';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Invalid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Target Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _targetDate == null
                        ? 'Select date'
                        : _targetDate!.toString().split(' ')[0],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createGoal,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('SET GOAL'),
        ),
      ],
    );
  }
}

class _EditGoalDialog extends StatefulWidget {
  final Goal goal;
  final VoidCallback onGoalUpdated;

  const _EditGoalDialog({
    required this.goal,
    required this.onGoalUpdated,
  });

  @override
  State<_EditGoalDialog> createState() => _EditGoalDialogState();
}

class _EditGoalDialogState extends State<_EditGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _savedAmountController;
  bool _isReached = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal.name);
    _savedAmountController = TextEditingController(
      text: widget.goal.savedAmount.toString(),
    );
    _isReached = widget.goal.isReached;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _savedAmountController.dispose();
    super.dispose();
  }

  Future<void> _updateGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final savedAmount = double.tryParse(_savedAmountController.text) ?? 0.0;
      
      // Can only mark as reached if saved amount >= target amount
      if (_isReached && savedAmount < widget.goal.targetAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot mark as reached. Saved amount must be equal to or greater than target amount.',
            ),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      await ApiService.updateGoal(widget.goal.id!, {
        'name': _nameController.text.trim(),
        'saved_amount': savedAmount,
        'is_reached': _isReached && savedAmount >= widget.goal.targetAmount,
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onGoalUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addSavedAmount() async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Saved Amount'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount to add',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0.0;
              Navigator.pop(context, amount);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      final newAmount = (double.tryParse(_savedAmountController.text) ?? 0.0) + result;
      setState(() {
        _savedAmountController.text = newAmount.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canReach = (double.tryParse(_savedAmountController.text) ?? 0.0) >=
        widget.goal.targetAmount;

    return AlertDialog(
      title: const Text('Edit Goal'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Goal Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Goal name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _savedAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Saved Amount',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Saved amount is required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid amount';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addSavedAmount,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Mark as Reached'),
                value: _isReached,
                enabled: canReach,
                onChanged: canReach
                    ? (value) => setState(() => _isReached = value ?? false)
                    : null,
              ),
              if (!canReach)
                Text(
                  'Saved amount must be >= target amount to mark as reached',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateGoal,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}

