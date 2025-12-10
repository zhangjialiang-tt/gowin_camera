# git_changed_files.py
import os
import subprocess
import shutil
import argparse
from typing import List, Optional


class GitFileManager:
    """Git文件管理器
    用于获取Git仓库中已修改的文件，并支持将这些文件复制到指定目录
    同时保持原有的目录结构
    """

    def __init__(self, base_dir: Optional[str] = None):
        """初始化Git文件管理器

        Args:
            base_dir: 基础目录路径，默认为当前工作目录
        """
        self.base_dir = base_dir or os.getcwd()
        self.git_root = self._get_git_root()

    def _get_git_root(self) -> str:
        """获取Git仓库根目录

        Returns:
            str: Git仓库根目录的绝对路径

        Raises:
            subprocess.CalledProcessError: 当Git命令执行失败时抛出
        """
        try:
            return subprocess.check_output(
                ["git", "rev-parse", "--show-toplevel"],
                text=True,
                stderr=subprocess.PIPE,
                cwd=self.base_dir,
                encoding='utf-8'  # 指定UTF-8编码
            ).strip()
        except subprocess.CalledProcessError as e:
            print(f"错误：无法获取Git仓库根目录 - {e}")
            raise

    def get_changed_files(self, include_untracked: bool = True,
                          extensions_only: bool = True) -> List[str]:
        """获取Git仓库中已修改的文件列表

        Args:
            include_untracked: 是否包含未跟踪的文件
            extensions_only: 是否只包含有扩展名的文件

        Returns:
            List[str]: 修改文件的绝对路径列表
        """
        try:
            # 构建git status命令
            # 使用 -c core.quotepath=false 来防止路径被引用/转义
            cmd = ["git", "-c", "core.quotepath=false", "status", "--porcelain"]
            if include_untracked:
                cmd.append("-uall")

            result = subprocess.check_output(
                cmd,
                text=True,
                stderr=subprocess.PIPE,
                cwd=self.base_dir,
                encoding='utf-8'  # 指定UTF-8编码
            )

            changed_files = []
            for line in result.splitlines():
                status = line[:2]
                path_info = line[3:].strip()

                # 跳过已删除的文件
                if status.strip() == "D":
                    continue

                file_path = path_info
                # 处理重命名的文件 (e.g., 'R  old -> new')
                if status.strip().startswith('R'):
                    try:
                        # 对于重命名的文件，格式为 "old_path -> new_path"
                        # 我们只关心 new_path
                        file_path = path_info.split(' -> ')[1]
                    except IndexError:
                        print(f"警告：无法解析重命名路径: '{path_info}'")
                        continue

                # git status的输出中，包含空格等特殊字符的路径可能会被引号包围
                # 这是一个简单的处理，不能处理路径中包含转义引号的情况
                if file_path.startswith('"') and file_path.endswith('"'):
                    file_path = file_path[1:-1]

                # 根据配置决定是否跳过无扩展名的文件
                if extensions_only and not os.path.splitext(file_path)[1]:
                    continue

                # 转换为绝对路径
                abs_path = os.path.abspath(os.path.join(self.git_root, file_path))
                changed_files.append(abs_path)

            return changed_files

        except subprocess.CalledProcessError as e:
            print(f"错误：执行Git命令失败 - {e}")
            return []
        except Exception as e:
            print(f"错误：意外异常 - {e}")
            return []

    def get_commit_files(self, commit_id: str, extensions_only: bool = True) -> List[str]:
        """获取指定commit中修改的文件列表

        Args:
            commit_id: 提交的commit ID
            extensions_only: 是否只包含有扩展名的文件

        Returns:
            List[str]: 修改文件的绝对路径列表
        """
        try:
            # 使用git show命令获取指定commit的修改文件
            cmd = ["git", "-c", "core.quotepath=false", "show", 
                   "--name-only", "--pretty=format:", commit_id]
            
            result = subprocess.check_output(
                cmd,
                text=True,
                stderr=subprocess.PIPE,
                cwd=self.base_dir,
                encoding='utf-8'  # 指定UTF-8编码
            )

            changed_files = []
            for file_path in result.splitlines():
                if not file_path.strip():
                    continue
                    
                # 根据配置决定是否跳过无扩展名的文件
                if extensions_only and not os.path.splitext(file_path)[1]:
                    continue

                # 检查文件是否存在（可能已被删除）
                full_path = os.path.join(self.git_root, file_path)
                if not os.path.exists(full_path):
                    print(f"警告：文件不存在 - {file_path}")
                    continue

                # 转换为绝对路径
                abs_path = os.path.abspath(full_path)
                changed_files.append(abs_path)

            return changed_files

        except subprocess.CalledProcessError as e:
            print(f"错误：执行Git命令失败 - {e}")
            return []
        except Exception as e:
            print(f"错误：意外异常 - {e}")
            return []

    def copy_to_temp(self, temp_dir: Optional[str] = None,
                     include_untracked: bool = True,
                     extensions_only: bool = True,
                     commit_id: Optional[str] = None) -> None:
        """将修改的文件复制到临时目录，保持原有的目录结构

        Args:
            temp_dir: 目标临时目录，默认为当前目录下的temp文件夹
            include_untracked: 是否包含未跟踪的文件
            extensions_only: 是否只包含有扩展名的文件
            commit_id: 指定commit ID，如果提供，则只复制该commit中的文件
        """
        # 获取修改的文件
        if commit_id:
            files = self.get_commit_files(commit_id, extensions_only)
        else:
            files = self.get_changed_files(include_untracked, extensions_only)
            
        if not files:
            print("提示：未发现修改的文件")
            return

        # 创建临时目录
        temp_dir = temp_dir or os.path.join(self.base_dir, "temp")
        os.makedirs(temp_dir, exist_ok=True)

        # 复制文件
        for src_path in files:
            try:
                if not os.path.exists(src_path):
                    print(f"警告：源文件不存在 - {src_path}")
                    continue

                # 获取相对路径
                try:
                    # 首先尝试使用git ls-files获取相对路径
                    rel_path = subprocess.check_output(
                        ["git", "-c", "core.quotepath=false", "ls-files", "--full-name", src_path],
                        text=True,
                        stderr=subprocess.PIPE,
                        cwd=self.base_dir,
                        encoding='utf-8'  # 指定UTF-8编码
                    ).strip()
                    if not rel_path:  # 如果是未跟踪的文件，git ls-files返回空字符串
                        rel_path = os.path.relpath(src_path, self.git_root)
                except subprocess.CalledProcessError:
                    # 如果git ls-files失败，则使用os.path.relpath计算相对路径
                    rel_path = os.path.relpath(src_path, self.git_root)

                # 统一路径分隔符为正斜杠
                rel_path = rel_path.replace(os.path.sep, '/')

                # 创建目标路径
                dst_path = os.path.join(temp_dir, rel_path)
                dst_dir = os.path.dirname(dst_path)
                os.makedirs(dst_dir, exist_ok=True)

                # 复制文件
                shutil.copy2(src_path, dst_path)
                print(f"已复制: {rel_path}")

            except Exception as e:
                print(f"错误：复制文件失败 {src_path} - {e}")

    def package_changed_files(self, output_path: Optional[str] = None,
                              temp_dir: Optional[str] = None,
                              include_untracked: bool = True,
                              extensions_only: bool = True,
                              format: str = 'zip',
                              commit_id: Optional[str] = None) -> Optional[str]:
        """将修改的文件复制到临时目录并打包

        Args:
            output_path: 输出文件路径，默认为当前目录下的changed_files.zip或changed_files.tar.gz
            temp_dir: 临时目录路径，默认为当前目录下的temp文件夹
            include_untracked: 是否包含未跟踪的文件
            extensions_only: 是否只包含有扩展名的文件
            format: 打包格式，支持'zip'和'tar'，默认为'tar'
            commit_id: 指定commit ID，如果提供，则只打包该commit中的文件

        Returns:
            str: 打包文件的路径，如果打包失败则返回None
        """
        # 首先复制文件到临时目录
        self.copy_to_temp(temp_dir, include_untracked, extensions_only, commit_id)

        # 如果没有文件被复制，直接返回
        temp_dir = temp_dir or os.path.join(self.base_dir, "temp")
        if not os.path.exists(temp_dir) or not os.listdir(temp_dir):
            return None

        try:
            # 确定输出文件路径
            if output_path is None:
                # 获取当前时间戳
                from datetime import datetime
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                prefix = f"commit_{commit_id[:7]}_" if commit_id else "changed_files_"
                output_name = f"{prefix}{timestamp}"
                output_name += ".zip" if format == 'zip' else ".tar.gz"
                output_path = os.path.join(self.base_dir, output_name)

            # 创建输出目录（如果不存在）
            os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)

            # 根据格式选择打包方式
            if format == 'zip':
                import zipfile
                with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zf:
                    for root, _, files in os.walk(temp_dir):
                        for file in files:
                            file_path = os.path.join(root, file)
                            arcname = os.path.relpath(file_path, temp_dir)
                            zf.write(file_path, arcname)
            elif format == 'tar':
                import tarfile
                with tarfile.open(output_path, 'w:gz') as tf:
                    tf.add(temp_dir, arcname='', recursive=True)
            else:
                raise ValueError(f"不支持的打包格式：{format}")

            print(f"打包完成：{output_path}")
            
            # 删除临时目录
            if os.path.exists(temp_dir):
                shutil.rmtree(temp_dir)
                print(f"已清理临时目录：{temp_dir}")
            
            return output_path

        except Exception as e:
            print(f"错误：打包文件失败 - {e}")
            return None


def main():
    """主函数，处理命令行参数并执行文件操作"""
    parser = argparse.ArgumentParser(description="Git文件管理工具")
    parser.add_argument("-d", "--dir", help="指定工作目录，默认为当前目录")
    parser.add_argument("-t", "--temp", help="指定临时目录路径，默认为'./temp'")
    parser.add_argument("-o", "--output", help="指定打包文件输出路径")
    parser.add_argument("-f", "--format", choices=['zip', 'tar'], default='tar',
                        help="指定打包格式，支持zip和tar，默认为tar")
    parser.add_argument("--no-untracked", action="store_true",
                        help="不包含未跟踪的文件")
    parser.add_argument("--all-files", action="store_true",
                        help="包含所有文件（包括无扩展名的文件）")
    parser.add_argument("--list-only", action="store_true",
                        help="仅列出修改的文件，不进行复制")
    parser.add_argument("--package", action="store_true",
                        help="将修改的文件打包")
    parser.add_argument("-c", "--commit", 
                        help="指定commit ID，获取该commit中修改的文件")

    args = parser.parse_args()

    try:
        # 创建Git文件管理器实例
        manager = GitFileManager(args.dir)

        if args.list_only:
            # 仅列出修改的文件
            if args.commit:
                files = manager.get_commit_files(
                    commit_id=args.commit,
                    extensions_only=not args.all_files
                )
                if files:
                    print(f"Commit {args.commit} 中修改的文件列表:")
                    for file in files:
                        rel_path = os.path.relpath(file, manager.git_root)
                        print(f"  {rel_path}")
                else:
                    print(f"在Commit {args.commit} 中未发现修改的文件")
            else:
                files = manager.get_changed_files(
                    include_untracked=not args.no_untracked,
                    extensions_only=not args.all_files
                )
                if files:
                    print("当前工作区修改的文件列表:")
                    for file in files:
                        rel_path = os.path.relpath(file, manager.git_root)
                        print(f"  {rel_path}")
                else:
                    print("未发现修改的文件")
        elif args.package:
            # 打包修改的文件
            output_path = manager.package_changed_files(
                output_path=args.output,
                temp_dir=args.temp,
                include_untracked=not args.no_untracked,
                extensions_only=not args.all_files,
                format=args.format,
                commit_id=args.commit
            )
            if not output_path:
                return 1
        else:
            # 复制文件到临时目录
            manager.copy_to_temp(
                temp_dir=args.temp,
                include_untracked=not args.no_untracked,
                extensions_only=not args.all_files,
                commit_id=args.commit
            )

    except Exception as e:
        print(f"错误：程序执行失败 - {e}")
        return 1

    return 0


if __name__ == "__main__":
    exit(main())