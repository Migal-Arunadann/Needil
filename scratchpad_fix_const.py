import re

with open('lib/features/patients/screens/patient_profile_screen.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

def fix_line(num):
    idx = num - 1
    lines[idx] = re.sub(r'\bconst\b\s+(?=[A-Z][a-zA-Z]*\()', '', lines[idx])
    lines[idx] = re.sub(r'\bconst\b\s+(?=EdgeInsets)', '', lines[idx])
    lines[idx] = re.sub(r'\bconst\b\s+(?=Icon)', '', lines[idx])
    lines[idx] = re.sub(r'\bconst\b\s+(?=Text)', '', lines[idx])

fix_line(209)
fix_line(259)
fix_line(1139)
fix_line(1163)
fix_line(1295)
fix_line(1335)

with open('lib/features/patients/screens/patient_profile_screen.dart', 'w', encoding='utf-8') as f:
    f.writelines(lines)
