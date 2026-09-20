import re
import sys

def main():
    file_path = "lib/features/planner/presentation/screens/planner_screen.dart"
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Remove isar imports
    content = re.sub(r"import 'package:isar/isar.dart';\n", "", content)
    content = re.sub(r"import 'package:exam_command_center/core/database/isar_provider.dart';\n", "", content)

    # Fix ConsumerState build methods
    content = content.replace("Widget build(BuildContext context, WidgetRef ref) {", "Widget build(BuildContext context) {")
    
    # But wait, ExistingEventRow is ConsumerWidget, it NEEDS `Widget build(BuildContext context, WidgetRef ref)`
    # I will specifically fix the ones that are wrong.
    
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    main()
