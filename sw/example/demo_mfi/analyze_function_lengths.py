#!/usr/bin/env python3
"""
Script to analyze function lengths in C source files.
Identifies functions exceeding 50 lines and interrupt handlers exceeding 30 lines.
"""

import re
import sys
from pathlib import Path

def count_non_comment_lines(lines):
    """Count non-comment, non-blank lines."""
    count = 0
    in_multiline_comment = False
    
    for line in lines:
        stripped = line.strip()
        
        # Handle multi-line comments
        if '/*' in stripped:
            in_multiline_comment = True
        if '*/' in stripped:
            in_multiline_comment = False
            continue
            
        if in_multiline_comment:
            continue
            
        # Skip single-line comments and blank lines
        if stripped.startswith('//') or not stripped:
            continue
            
        count += 1
    
    return count

def extract_functions(filepath):
    """Extract all functions from a C file with their line counts."""
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # Pattern to match function definitions
    # Matches: return_type function_name(params) {
    pattern = r'^\s*(?:static\s+)?(?:inline\s+)?(?:const\s+)?(\w+(?:\s*\*)*)\s+(\w+)\s*\([^)]*\)\s*\{'
    
    functions = []
    lines = content.split('\n')
    
    i = 0
    while i < len(lines):
        match = re.match(pattern, lines[i])
        if match:
            return_type = match.group(1).strip()
            func_name = match.group(2).strip()
            start_line = i + 1  # 1-indexed
            
            # Find the end of the function by counting braces
            brace_count = 1
            j = i + 1
            func_lines = [lines[i]]
            
            while j < len(lines) and brace_count > 0:
                line = lines[j]
                func_lines.append(line)
                
                # Count braces (simple approach, may not handle all edge cases)
                brace_count += line.count('{') - line.count('}')
                j += 1
            
            end_line = j  # 1-indexed
            line_count = count_non_comment_lines(func_lines)
            
            is_interrupt = 'interrupt' in func_name.lower() or 'handler' in func_name.lower()
            
            functions.append({
                'name': func_name,
                'return_type': return_type,
                'start_line': start_line,
                'end_line': end_line,
                'total_lines': end_line - start_line + 1,
                'code_lines': line_count,
                'is_interrupt': is_interrupt
            })
            
            i = j
        else:
            i += 1
    
    return functions

def analyze_file(filepath):
    """Analyze a single C file for long functions."""
    functions = extract_functions(filepath)
    
    long_functions = []
    long_interrupts = []
    
    for func in functions:
        if func['is_interrupt'] and func['code_lines'] > 30:
            long_interrupts.append(func)
        elif not func['is_interrupt'] and func['code_lines'] > 50:
            long_functions.append(func)
    
    return long_functions, long_interrupts, functions

def main():
    # List of C source files to analyze
    c_files = [
        'main.c',
        'mfi_auth.c',
        'mfi_auth_chip.c',
        'mfi_auth_protocol.c',
        'mfi_auth_utils.c',
        'mfi_auth_params.c',
        'mfi_auth_flow.c',
        'mfi_iic/mfi_iic.c',
        'mfi_usb/mfi_usb.c'
    ]
    
    all_long_functions = []
    all_long_interrupts = []
    all_functions = []
    
    print("=" * 80)
    print("Function Length Analysis Report")
    print("=" * 80)
    print()
    
    for filepath in c_files:
        path = Path(filepath)
        if not path.exists():
            print(f"⚠ Skipping {filepath} (not found)")
            continue
        
        long_funcs, long_ints, all_funcs = analyze_file(filepath)
        
        if long_funcs or long_ints:
            print(f"\n📁 {filepath}")
            print("-" * 80)
            
            if long_funcs:
                print(f"\n  Functions exceeding 50 lines:")
                for func in long_funcs:
                    print(f"    • {func['name']}() - {func['code_lines']} lines (lines {func['start_line']}-{func['end_line']})")
                    all_long_functions.append((filepath, func))
            
            if long_ints:
                print(f"\n  Interrupt handlers exceeding 30 lines:")
                for func in long_ints:
                    print(f"    • {func['name']}() - {func['code_lines']} lines (lines {func['start_line']}-{func['end_line']})")
                    all_long_interrupts.append((filepath, func))
        
        all_functions.extend([(filepath, f) for f in all_funcs])
    
    # Summary
    print("\n" + "=" * 80)
    print("Summary")
    print("=" * 80)
    print(f"Total functions analyzed: {len(all_functions)}")
    print(f"Functions exceeding 50 lines: {len(all_long_functions)}")
    print(f"Interrupt handlers exceeding 30 lines: {len(all_long_interrupts)}")
    
    if all_long_functions or all_long_interrupts:
        print("\n⚠ Action required: The following functions need refactoring:")
        for filepath, func in all_long_functions:
            print(f"  • {filepath}: {func['name']}() ({func['code_lines']} lines)")
        for filepath, func in all_long_interrupts:
            print(f"  • {filepath}: {func['name']}() ({func['code_lines']} lines) [INTERRUPT]")
        return 1
    else:
        print("\n✓ All functions meet length requirements!")
        return 0

if __name__ == '__main__':
    sys.exit(main())
