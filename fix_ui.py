import os
import re

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
            if 'isar' in content.lower():
                content = re.sub(r"import '.*isar_provider\.dart';", "", content)
                content = re.sub(r"import 'package:isar/isar\.dart';", "", content)
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(content)
