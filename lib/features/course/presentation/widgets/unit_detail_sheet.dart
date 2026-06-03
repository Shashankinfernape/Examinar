import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../domain/models/unit.dart';
import '../../domain/models/question.dart';
import '../../data/repositories/course_repository.dart';

class UnitDetailSheet extends ConsumerStatefulWidget {
  final Unit unit;

  const UnitDetailSheet({super.key, required this.unit});

  @override
  ConsumerState<UnitDetailSheet> createState() => _UnitDetailSheetState();
}

class _UnitDetailSheetState extends ConsumerState<UnitDetailSheet> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: unit.name);
  }

  Unit get unit => widget.unit;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('EDIT UNIT', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                hintText: 'Unit Name...',
                hintStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _delete,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF28B82).withOpacity(0.5)),
                    ),
                    child: const Center(
                      child: Text('DELETE', style: TextStyle(color: Color(0xFFF28B82), fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('SAVE CHANGES', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() async {
    if (_nameController.text.isEmpty) return;
    final repo = await ref.read(courseRepositoryProvider.future);
    await repo.isar.writeTxn(() async {
      unit.name = _nameController.text;
      await repo.isar.units.put(unit);
    });
    if (mounted) Navigator.pop(context);
  }

  void _delete() async {
    final repo = await ref.read(courseRepositoryProvider.future);
    await repo.isar.writeTxn(() async {
      await repo.isar.units.delete(unit.id);
      // Optional: Delete associated questions
      final qs = await repo.isar.questions.where().filter().unitIdEqualTo(unit.id).findAll();
      for (var q in qs) {
        await repo.isar.questions.delete(q.id);
      }
    });
    if (mounted) Navigator.pop(context);
  }
}
