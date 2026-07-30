path = r'c:\App Development\PMS\lib\features\appointments\screens\appointment_list_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

target = """                                     // Col 1: Time (flex 2) - Hidden if in progress
                                     if (!isInProgress) ...[
                                       Expanded(
                                         flex: 2,
                                         child: Center(
                                           child: Column(
                                             mainAxisSize: MainAxisSize.min,
                                             children: [
                                               Text(
                                                 TimeUtils.formatStringTime(apt.time).replaceAll(' AM', '').replaceAll(' PM', ''),
                                                 style: TextStyle(
                                                   color: accentColor,
                                                   fontSize: 22,
                                                   fontWeight: FontWeight.w800,
                                                   letterSpacing: -0.5,
                                                 ),
                                               ),
                                               Text(
                                                 TimeUtils.formatStringTime(apt.time).contains('AM') ? 'AM' : 'PM',
                                                 style: TextStyle(
                                                   color: accentColor,
                                                   fontSize: 14,
                                                   fontWeight: FontWeight.w600,
                                                 ),
                                               ),
                                             ],
                                           ),
                                         ),
                                       ),
                                       VerticalDivider(color: context.colors.border.withValues(alpha: 0.3), width: 1),
                                     ],"""

replacement = """                                     // Col 1: Time (flex 2)
                                     Expanded(
                                       flex: 2,
                                       child: Center(
                                         child: Column(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             Text(
                                               TimeUtils.formatStringTime(apt.time).replaceAll(' AM', '').replaceAll(' PM', ''),
                                               style: TextStyle(
                                                 color: accentColor,
                                                 fontSize: 22,
                                                 fontWeight: FontWeight.w800,
                                                 letterSpacing: -0.5,
                                               ),
                                             ),
                                             Text(
                                               TimeUtils.formatStringTime(apt.time).contains('AM') ? 'AM' : 'PM',
                                               style: TextStyle(
                                                 color: accentColor,
                                                 fontSize: 14,
                                                 fontWeight: FontWeight.w600,
                                               ),
                                             ),
                                           ],
                                         ),
                                       ),
                                     ),
                                     VerticalDivider(color: context.colors.border.withValues(alpha: 0.3), width: 1),"""

if target in content:
    content = content.replace(target, replacement)
    print("Replaced successfully")
else:
    # Try with normalized line endings
    content_norm = content.replace('\r\n', '\n')
    target_norm = target.replace('\r\n', '\n')
    if target_norm in content_norm:
        content_norm = content_norm.replace(target_norm, replacement.replace('\r\n', '\n'))
        content = content_norm
        print("Replaced with normalized line endings")
    else:
        print("Target not found!")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
