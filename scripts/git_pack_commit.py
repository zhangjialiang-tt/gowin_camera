#!/usr/bin/env python3
"""
Git Commit Files Packager
========================
打包Git某次提交中所有改动的文件，并保持目录结构。

Usage:
    python3 git_pack_commit.py [--commit <hash>] [--output <path>] [--format zip|tar.gz]
"""

import os
import sys
import tempfile
import argparse
import shutil
import subprocess
from pathlib import Path
import tarfile
import zipfile
from typing import List, Tuple, Optional


def run_git_command(cmd: List[str], cwd: Optional[str] = None) -> str:
    """执行Git命令并返回输出"""
    try:
        result = subprocess.run(
            cmd, cwd=cwd, capture_output=True, text=True, check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Git命令失败: {' '.join(cmd)}", file=sys.stderr)
        print(f"错误: {e.stderr}", file=sys.stderr)
        sys.exit(1)


def get_changed_files(commit_hash: str, repo_path: str = ".") -> List[Tuple[str, str]]:
    """
    获取指定提交中改动的文件列表

    Returns:
        List[(文件路径, 操作类型)] 操作类型: A(新增), M(修改), D(删除), R(重命名)
    """
    # 使用git diff-tree获取文件列表和操作类型
    cmd = ["git", "diff-tree", "--no-commit-id", "--name-status", "-r", commit_hash]
    output = run_git_command(cmd, cwd=repo_path)

    files = []
    for line in output.split("\n"):
        if not line:
            continue
        parts = line.split("\t", 1)
        if len(parts) == 2:
            status, file_path = parts
            files.append((file_path, status))

    return files


def get_file_content_at_commit(
    commit_hash: str, file_path: str, repo_path: str = "."
) -> bytes:
    """获取文件在指定提交时的内容"""
    cmd = ["git", "show", f"{commit_hash}:{file_path}"]
    try:
        result = subprocess.run(cmd, cwd=repo_path, capture_output=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError:
        # 文件可能已删除或不存在
        return b""


def package_commit_files(
    commit_hash: Optional[str] = None,
    output_path: Optional[str] = None,
    repo_path: str = ".",
    archive_format: str = "tar.gz",
) -> str:
    """
    打包指定提交的所有改动文件

    Args:
        commit_hash: 提交哈希，默认使用最新提交
        output_path: 输出文件路径，默认自动生成
        repo_path: Git仓库路径
        archive_format: 打包格式 ("zip" 或 "tar.gz")

    Returns:
        生成的打包文件路径
    """
    # 验证是Git仓库
    if not os.path.exists(os.path.join(repo_path, ".git")):
        print(f"错误: {repo_path} 不是Git仓库", file=sys.stderr)
        sys.exit(1)

    # 获取提交哈希（如果未指定）
    if not commit_hash:
        commit_hash = run_git_command(["git", "rev-parse", "HEAD"], repo_path)

    print(f"处理提交: {commit_hash[:7]}")

    # 获取改动文件
    changed_files = get_changed_files(commit_hash, repo_path)

    if not changed_files:
        print("没有改动的文件")
        sys.exit(0)

    # 过滤掉删除的文件（无法打包）
    files_to_pack = [(f, s) for f, s in changed_files if s != "D"]
    print(f"找到 {len(files_to_pack)} 个需要打包的文件")

    # 创建临时目录来重建文件结构
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)

        # 复制文件到临时目录
        for file_path, status in files_to_pack:
            src_path = Path(repo_path) / file_path
            dest_path = temp_path / file_path

            # 确保目标目录存在
            dest_path.parent.mkdir(parents=True, exist_ok=True)

            # 对于重命名的文件，使用旧名称
            if status.startswith("R"):
                # Git显示格式: "R100<TAB>old_name<TAB>new_name"
                # 但我们这里简化处理，直接使用新名称
                pass

            # 获取文件在提交时的内容
            content = get_file_content_at_commit(commit_hash, file_path, repo_path)

            if content:
                # 写入文件
                with open(dest_path, "wb") as f:
                    f.write(content)

                # 保留原文件权限（可选）
                if src_path.exists():
                    shutil.copymode(src_path, dest_path)

                print(f"  + {file_path}")
            else:
                print(f"  - 跳过（无法读取）: {file_path}")

        # 生成输出文件名
        if not output_path:
            commit_short = commit_hash[:7]
            output_path = f"commit_{commit_short}_files.{archive_format}"

        # 打包
        if archive_format == "zip":
            _create_zip(temp_path, output_path)
        else:  # tar.gz
            _create_tar_gz(temp_path, output_path)

        print(f"\n✅ 打包成功: {os.path.abspath(output_path)}")
        return output_path


def _create_tar_gz(source_dir: Path, output_path: str):
    """创建tar.gz压缩包"""
    with tarfile.open(output_path, "w:gz") as tar:
        tar.add(source_dir, arcname=".")

    # 设置文件权限
    os.chmod(output_path, 0o644)


def _create_zip(source_dir: Path, output_path: str):
    """创建ZIP压缩包"""
    with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as zipf:
        for file_path in source_dir.rglob("*"):
            if file_path.is_file():
                arcname = file_path.relative_to(source_dir)
                zipf.write(file_path, arcname)

    # 设置文件权限
    os.chmod(output_path, 0o644)


def main():
    parser = argparse.ArgumentParser(description="打包Git提交中的改动文件")
    parser.add_argument("--commit", "-c", help="提交哈希（默认: 最新提交）")
    parser.add_argument("--output", "-o", help="输出文件路径（默认: 自动命名）")
    parser.add_argument(
        "--repo", "-r", default=".", help="Git仓库路径（默认: 当前目录）"
    )
    parser.add_argument(
        "--format",
        "-f",
        choices=["zip", "tar.gz"],
        default="tar.gz",
        help="打包格式（默认: tar.gz）",
    )
    parser.add_argument("--verbose", "-v", action="store_true", help="显示详细信息")

    args = parser.parse_args()

    if not args.verbose:
        sys.stdout = open(os.devnull, "w")
        # 重要错误仍会显示到stderr

    try:
        package_commit_files(
            commit_hash=args.commit,
            output_path=args.output,
            repo_path=args.repo,
            archive_format=args.format,
        )
    except Exception as e:
        print(f"错误: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
