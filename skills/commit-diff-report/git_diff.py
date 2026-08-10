#!/usr/bin/env python3
"""
Git Commit Difference Tool
A Python script to generate comprehensive diff reports between git commits
with project tree visualization and detailed file changes.
"""

import argparse
import subprocess
import sys
import os
from datetime import datetime
from pathlib import Path
from collections import defaultdict
import re


def compact_diff(diff_text, max_lines=500, max_hunk_lines=100):
    """Condense a unified git diff for LLM consumption.

    Port of rtk's (Rust Token Killer) compact_diff: strips diff noise
    (index/mode/+++/--- lines and the `diff --git` banner), keeps `@@` hunk
    headers with their trailing function context, caps each hunk's changed
    lines, and appends a per-file `+added -removed` tally. Overflow collapses
    to truncation markers instead of dumping the full diff.
    """
    result = []
    current_file = ""
    added = 0
    removed = 0
    in_hunk = False
    hunk_shown = 0
    hunk_skipped = 0
    was_truncated = False

    def flush_hunk_skip():
        nonlocal hunk_skipped, was_truncated
        if hunk_skipped > 0:
            result.append(f"  ... ({hunk_skipped} lines truncated)")
            was_truncated = True
            hunk_skipped = 0

    for line in diff_text.splitlines():
        if line.startswith("diff --git"):
            flush_hunk_skip()
            if current_file and (added > 0 or removed > 0):
                result.append(f"  +{added} -{removed}")
            current_file = line.split(" b/", 1)[1] if " b/" in line else "unknown"
            result.append(f"\n{current_file}")
            added = removed = 0
            in_hunk = False
            hunk_shown = 0
        elif line.startswith("@@"):
            flush_hunk_skip()
            in_hunk = True
            hunk_shown = 0
            # Keep the full hunk header, including function context after the 2nd @@.
            result.append(f"  {line}")
        elif in_hunk:
            if line.startswith('+') and not line.startswith("+++"):
                added += 1
                if hunk_shown < max_hunk_lines:
                    result.append(f"  {line}")
                    hunk_shown += 1
                else:
                    hunk_skipped += 1
            elif line.startswith('-') and not line.startswith("---"):
                removed += 1
                if hunk_shown < max_hunk_lines:
                    result.append(f"  {line}")
                    hunk_shown += 1
                else:
                    hunk_skipped += 1
            elif hunk_shown < max_hunk_lines and not line.startswith("\\"):
                # Context line: only after at least one change has been shown.
                if hunk_shown > 0:
                    result.append(f"  {line}")
                    hunk_shown += 1

        if len(result) >= max_lines:
            result.append("\n... (more changes truncated)")
            was_truncated = True
            break

    flush_hunk_skip()
    if current_file and (added > 0 or removed > 0):
        result.append(f"  +{added} -{removed}")
    if was_truncated:
        result.append("[full diff: re-run with --full]")

    return "\n".join(result)


class GitDiffTool:
    def __init__(self):
        self.repo_root = self._get_repo_root()
        
    def _get_repo_root(self):
        """Get the root directory of the git repository."""
        try:
            result = subprocess.run(
                ['git', 'rev-parse', '--show-toplevel'],
                capture_output=True, text=True, check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError:
            print("Error: Not in a git repository")
            sys.exit(1)
    
    def _validate_commit(self, commit):
        """Validate that a commit exists."""
        try:
            subprocess.run(
                ['git', 'rev-parse', '--verify', commit],
                capture_output=True, text=True, check=True
            )
            return True
        except subprocess.CalledProcessError:
            return False
    
    def _get_commit_info(self, commit):
        """Get detailed information about a commit."""
        try:
            result = subprocess.run(
                ['git', 'log', '-1', '--format=%H|%h|%s|%an|%ad|%cn|%cd', commit],
                capture_output=True, text=True, check=True
            )
            parts = result.stdout.strip().split('|')
            return {
                'full_hash': parts[0],
                'short_hash': parts[1],
                'subject': parts[2],
                'author': parts[3],
                'author_date': parts[4],
                'committer': parts[5],
                'commit_date': parts[6]
            }
        except subprocess.CalledProcessError:
            return None
    
    def _get_changed_files(self, commit1, commit2):
        """Get list of changed files with their status."""
        try:
            result = subprocess.run(
                ['git', 'diff', '--name-status', commit1, commit2],
                capture_output=True, text=True, check=True
            )
            
            files = []
            for line in result.stdout.strip().split('\n'):
                if line:
                    parts = line.split('\t')
                    status = parts[0]
                    filename = parts[1]
                    
                    # Handle renamed files
                    old_filename = None
                    if status.startswith('R'):
                        old_filename = filename
                        filename = parts[2] if len(parts) > 2 else filename
                    
                    files.append({
                        'status': status,
                        'filename': filename,
                        'old_filename': old_filename
                    })
            
            return files
        except subprocess.CalledProcessError:
            return []
    
    def _get_diff_stats(self, commit1, commit2):
        """Get diff statistics."""
        try:
            result = subprocess.run(
                ['git', 'diff', '--stat', commit1, commit2],
                capture_output=True, text=True, check=True
            )
            return result.stdout
        except subprocess.CalledProcessError:
            return ""
    
    def _get_detailed_diff(self, commit1, commit2, context=3, word_diff=False):
        """Get detailed diff output."""
        cmd = ['git', 'diff', f'-U{context}']
        if word_diff:
            cmd.append('--word-diff')
        cmd.extend([commit1, commit2])
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return result.stdout
        except subprocess.CalledProcessError:
            return ""
    
    def _build_project_tree(self, changed_files):
        """Build a project tree showing changed files."""
        tree = defaultdict(list)
        
        for file_info in changed_files:
            path = Path(file_info['filename'])
            parts = path.parts
            
            # Build directory structure
            current_path = ""
            for i, part in enumerate(parts):
                if i == 0:
                    current_path = part
                else:
                    current_path = str(Path(current_path) / part)
                
                if i == len(parts) - 1:  # This is the file
                    tree[str(path.parent) if path.parent != Path('.') else '.'].append({
                        'name': part,
                        'status': file_info['status'],
                        'is_file': True,
                        'old_name': file_info.get('old_filename')
                    })
                else:  # This is a directory
                    parent = str(Path(current_path).parent) if Path(current_path).parent != Path('.') else '.'
                    if not any(item['name'] == part for item in tree[parent]):
                        tree[parent].append({
                            'name': part,
                            'status': '',
                            'is_file': False,
                            'old_name': None
                        })
        
        return tree
    
    def _format_tree(self, tree, root_dir='.', prefix='', is_last=True):
        """Format the project tree with ASCII art."""
        if root_dir not in tree:
            return ""
        
        output = []
        items = sorted(tree[root_dir], key=lambda x: (x['is_file'], x['name']))
        
        for i, item in enumerate(items):
            is_last_item = i == len(items) - 1
            
            # Choose the appropriate tree characters
            if is_last_item:
                current_prefix = prefix + "└── "
                next_prefix = prefix + "    "
            else:
                current_prefix = prefix + "├── "
                next_prefix = prefix + "│   "
            
            # Format the item name with status
            status_symbol = self._get_status_symbol(item['status'])
            name = item['name']
            
            if item['old_name'] and item['status'].startswith('R'):
                name = f"{Path(item['old_name']).name} → {name}"
            
            output.append(f"{current_prefix}{status_symbol} {name}")
            
            # If it's a directory, recurse
            if not item['is_file']:
                child_path = str(Path(root_dir) / item['name']) if root_dir != '.' else item['name']
                output.append(self._format_tree(tree, child_path, next_prefix, is_last_item))
        
        return '\n'.join(filter(None, output))
    
    def _get_status_symbol(self, status):
        """Get a symbol representing the file status."""
        symbols = {
            'A': '[+]',   # Added
            'D': '[-]',   # Deleted
            'M': '[~]',   # Modified
            'R': '[→]',   # Renamed
            'C': '[C]',   # Copied
            'T': '[T]',   # Type changed
            'U': '[U]',   # Unmerged
            '': '[ ]'     # Directory or unknown
        }
        return symbols.get(status[0] if status else '', '[?]')
    
    def _get_commit_messages(self, commit1, commit2):
        """Get commit messages between two commits."""
        try:
            result = subprocess.run(
                ['git', 'log', '--oneline', f'{commit1}..{commit2}'],
                capture_output=True, text=True, check=True
            )
            return result.stdout
        except subprocess.CalledProcessError:
            return ""
    
    def _build_compact_report(self, report_lines, commit1, commit2,
                              commit1_info, commit2_info, changed_files,
                              include_tree, include_diff, files_only,
                              context, max_lines):
        """Assemble the token-efficient report (short markers, compacted diff)."""
        # One-line header instead of the 80-char banner block.
        report_lines.append(
            f"diff {os.path.basename(self.repo_root)}: "
            f"{commit1_info['short_hash']} {commit1_info['subject']} "
            f"-> {commit2_info['short_hash']} {commit2_info['subject']}"
        )

        if files_only:
            report_lines.append("\n## changed files")
            for file_info in changed_files:
                line = f"{file_info['status']} {file_info['filename']}"
                if file_info['old_filename']:
                    line += f" (from {file_info['old_filename']})"
                report_lines.append(line)
            return

        if include_tree and changed_files:
            report_lines.append("\n## changed files [+]add [-]del [~]mod [→]ren")
            report_lines.append(self._format_tree(self._build_project_tree(changed_files)))

        if include_diff:
            # Fetch a normal unified diff, then compact it (word-diff is
            # incompatible with the +/- line parsing, so it's full-mode only).
            diff_output = self._get_detailed_diff(commit1, commit2, context, word_diff=False)
            compacted = compact_diff(diff_output, max_lines)
            if compacted:
                report_lines.append("\n## diff")
                report_lines.append(compacted)

        commit_msgs = self._get_commit_messages(commit1, commit2)
        if commit_msgs:
            report_lines.append("\n## commits")
            report_lines.append(commit_msgs.rstrip())

    def generate_report(self, commit1, commit2='HEAD', output_file=None,
                       include_stats=True, include_tree=True, include_diff=True,
                       context=3, word_diff=False, files_only=False,
                       compact=True, max_lines=500):
        """Generate a diff report.

        Compact mode (default) trims output for LLM consumption; full mode
        produces the verbose, human-readable report with section banners.
        """

        # Validate commits
        if not self._validate_commit(commit1):
            print(f"Error: Commit '{commit1}' not found")
            return False

        if not self._validate_commit(commit2):
            print(f"Error: Commit '{commit2}' not found")
            return False

        # Get commit information
        commit1_info = self._get_commit_info(commit1)
        commit2_info = self._get_commit_info(commit2)

        # Get changed files
        changed_files = self._get_changed_files(commit1, commit2)

        # Build report
        report_lines = []

        if compact:
            self._build_compact_report(
                report_lines, commit1, commit2, commit1_info, commit2_info,
                changed_files, include_tree, include_diff, files_only,
                context, max_lines
            )
            report_content = '\n'.join(report_lines)
            if output_file:
                with open(output_file, 'w') as f:
                    f.write(report_content)
                print(f"Report written to: {output_file}")
            else:
                print(report_content)
            return True

        # Full (verbose) mode below.
        # Header
        report_lines.extend([
            "=" * 80,
            "GIT COMMIT DIFFERENCE REPORT",
            "=" * 80,
            f"Repository: {os.path.basename(self.repo_root)}",
            f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "",
            "COMMIT COMPARISON:",
            f"  From: {commit1_info['short_hash']} - {commit1_info['subject']}",
            f"        Author: {commit1_info['author']} ({commit1_info['author_date']})",
            f"  To:   {commit2_info['short_hash']} - {commit2_info['subject']}",
            f"        Author: {commit2_info['author']} ({commit2_info['author_date']})",
            ""
        ])
        
        # Project tree
        if include_tree and changed_files and not files_only:
            report_lines.extend([
                "=" * 80,
                "PROJECT TREE (Changed Files)",
                "=" * 80,
                "Legend: [+] Added, [-] Deleted, [~] Modified, [→] Renamed",
                "",
                self._format_tree(self._build_project_tree(changed_files)),
                ""
            ])
        
        # Statistics
        if include_stats:
            stats = self._get_diff_stats(commit1, commit2)
            if stats:
                report_lines.extend([
                    "=" * 80,
                    "DIFF STATISTICS",
                    "=" * 80,
                    stats,
                ])
        
        # Files only
        if files_only:
            report_lines.extend([
                "=" * 80,
                "CHANGED FILES",
                "=" * 80
            ])
            for file_info in changed_files:
                status_desc = {
                    'A': 'Added',
                    'D': 'Deleted', 
                    'M': 'Modified',
                    'R': 'Renamed',
                    'C': 'Copied'
                }.get(file_info['status'][0], 'Unknown')
                
                line = f"{file_info['status']:>3} {status_desc:>8} {file_info['filename']}"
                if file_info['old_filename']:
                    line += f" (from {file_info['old_filename']})"
                report_lines.append(line)
            report_lines.append("")
        
        # Detailed diff
        if include_diff and not files_only:
            diff_output = self._get_detailed_diff(commit1, commit2, context, word_diff)
            if diff_output:
                report_lines.extend([
                    "=" * 80,
                    "DETAILED DIFFERENCES",
                    "=" * 80,
                    diff_output
                ])
        
        # Commit messages
        commit_msgs = self._get_commit_messages(commit1, commit2)
        if commit_msgs:
            report_lines.extend([
                "=" * 80,
                "COMMIT MESSAGES",
                "=" * 80,
                f"Commits between {commit1} and {commit2}:",
                "",
                commit_msgs
            ])
        
        # Output
        report_content = '\n'.join(report_lines)
        
        if output_file:
            with open(output_file, 'w') as f:
                f.write(report_content)
            print(f"Report written to: {output_file}")
        else:
            print(report_content)
        
        return True

def main():
    parser = argparse.ArgumentParser(
        description="Generate comprehensive git commit difference reports with project tree visualization"
    )
    
    parser.add_argument('commit1', help='First commit (older)')
    parser.add_argument('commit2', nargs='?', default='HEAD', help='Second commit (newer, default: HEAD)')
    
    parser.add_argument('-o', '--output', help='Output file path')
    parser.add_argument('-s', '--stats', action='store_true', default=True, help='Include diff statistics (default: enabled)')
    parser.add_argument('--no-stats', action='store_false', dest='stats', help='Disable diff statistics')
    parser.add_argument('-t', '--tree', action='store_true', default=True, help='Include project tree (default: enabled)')
    parser.add_argument('--no-tree', action='store_false', dest='tree', help='Disable project tree')
    parser.add_argument('-d', '--diff', action='store_true', default=True, help='Include detailed diff (default: enabled)')
    parser.add_argument('--no-diff', action='store_false', dest='diff', help='Disable detailed diff')
    parser.add_argument('-n', '--files-only', action='store_true', help='Show only changed files list')
    parser.add_argument('-c', '--context', type=int, default=3, help='Number of context lines (default: 3)')
    parser.add_argument('-w', '--word-diff', action='store_true', help='Show word-level differences (full mode only)')
    parser.add_argument('--full', action='store_false', dest='compact',
                        help='Verbose human-readable report (default: compact, LLM-friendly)')
    parser.add_argument('--max-lines', type=int, default=500,
                        help='Compact mode: cap total diff lines before truncating (default: 500)')

    args = parser.parse_args()

    tool = GitDiffTool()
    success = tool.generate_report(
        commit1=args.commit1,
        commit2=args.commit2,
        output_file=args.output,
        include_stats=args.stats,
        include_tree=args.tree,
        include_diff=args.diff,
        context=args.context,
        word_diff=args.word_diff,
        files_only=args.files_only,
        compact=args.compact,
        max_lines=args.max_lines
    )
    
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()