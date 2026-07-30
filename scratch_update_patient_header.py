import os
import re

file_path = r'lib\features\patients\screens\patient_profile_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
import_stmt = "import 'package:pms_app/features/scheduling/screens/scheduling_audit_history_screen.dart';\n"
if "scheduling_audit_history_screen.dart" not in content:
    # Find last import
    last_import = content.rfind("import ")
    if last_import != -1:
        end_of_last_import = content.find('\n', last_import)
        content = content[:end_of_last_import + 1] + import_stmt + content[end_of_last_import + 1:]

# Add history button to _planHeader
old_header = """        const Spacer(),
        Text(
          '₹${plan.sessionFee.toInt()}/session',
          style: isDesktop
              ? TextStyle(color: context.colors.textMuted, fontSize: 11)
              : context.textStyles.caption.copyWith(color: context.colors.textSecondary),
        ),
        // ⋮ Close Treatment menu
        if (canClose) ...[const SizedBox(width: 4), PopupMenuButton<String>("""

new_header = """        const Spacer(),
        Text(
          '₹${plan.sessionFee.toInt()}/session',
          style: isDesktop
              ? TextStyle(color: context.colors.textMuted, fontSize: 11)
              : context.textStyles.caption.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Schedule History',
          icon: Icon(Icons.history_rounded, size: 18, color: context.colors.textHint),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SchedulingAuditHistoryScreen(plan: plan),
            ),
          ),
        ),
        // ⋮ Close Treatment menu
        if (canClose) ...[const SizedBox(width: 8), PopupMenuButton<String>("""

content = content.replace(old_header, new_header)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully!")
