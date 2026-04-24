import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/transaction.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;
  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedType = 'Expense';
  String? _selectedCategory;
  String? _selectedTransactionType = 'Cash';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isEditMode = false;

  final List<String> _expenseCategories = [
    'Bills', 'Clothes', 'Entertainment', 'Food', 'Footwear', 'Fuel', 'General',
    'Health/Medical', 'Holidays', 'Home', 'Kids', 'Other', 'Pets', 'Shopping',
    'Sports', 'Transportation', 'Vehicle',
  ];

  final List<String> _incomeCategories = [
    'Savings', 'Salary', 'Deposit', 'Commission', 'Investments', 'Part-Time', 'Bonus',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _isEditMode = true;
      final t = widget.transaction!;
      _selectedType = t.type;
      _selectedCategory = t.category;
      _selectedTransactionType = t.transactionType;
      _selectedDate = t.date;
      _amountController.text = t.amount.toString();
      _descriptionController.text = t.description ?? '';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
        return;
    }
    
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid positive number')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = await AuthService.getCurrentUserId();
      if (userId == null) return;

      final transaction = Transaction(
        id: widget.transaction?.id,
        userId: userId,
        type: _selectedType!,
        amount: amount,
        category: _selectedCategory!,
        date: _selectedDate,
        description: _descriptionController.text.trim(),
        transactionType: _selectedTransactionType!,
      );

      if (_isEditMode) {
        await ApiService.updateTransaction(widget.transaction!.id!, {
          'type': transaction.type,
          'amount': transaction.amount,
          'category': transaction.category,
          'date': transaction.date.toIso8601String().split('T')[0],
          'description': transaction.description,
          'transaction_type': transaction.transactionType,
        });
      } else {
        await ApiService.addTransaction(transaction);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const mainGreen = Color(0xFF1D976C);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Transaction' : 'Add Transaction', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: mainGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Transaction Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _typeChip('Income', mainGreen),
                  const SizedBox(width: 12),
                  _typeChip('Expense', mainGreen),
                ],
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: _inputDecoration('Category'),
                items: (_selectedType == 'Income' ? _incomeCategories : _expenseCategories)
                    .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                decoration: _inputDecoration('Amount (Rs.)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')), // only allow numbers and decimal
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final amount = double.tryParse(v);
                  if (amount == null || amount <= 0) return 'Enter a positive number';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: _inputDecoration('Date'),
                  child: Text('${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}'),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Payment Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _modeChip('Cash', mainGreen),
                  const SizedBox(width: 12),
                  _modeChip('Online', mainGreen),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitTransaction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_isEditMode ? 'UPDATE' : 'ADD', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String type, Color color) {
    final isSelected = _selectedType == type;
    return ChoiceChip(
      label: Text(type),
      selected: isSelected,
      selectedColor: color,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      onSelected: (v) {
        if (v) {
          setState(() {
            _selectedType = type;
            _selectedCategory = null; // Clear category when type changes to fix crash
          });
        }
      },
    );
  }

  Widget _modeChip(String mode, Color color) {
    final isSelected = _selectedTransactionType == mode;
    return ChoiceChip(
      label: Text(mode),
      selected: isSelected,
      selectedColor: color,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      onSelected: (v) => setState(() => _selectedTransactionType = v ? mode : null),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1D976C), width: 2)),
    );
  }
}
