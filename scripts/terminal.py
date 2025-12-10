#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#!/usr/bin/env python3
import serial
import serial.tools.list_ports
import threading
import time
import os
import sys
from datetime import datetime
import argparse
import signal

class SerialTerminal:
    def __init__(self, default_port=None, default_baudrate=115200, exe_file=None, 
                 interactive=False, auto_interactive=False):
        self.serial_port = None
        self.connected = False
        self.running = False
        self.receive_thread = None
        self.default_port = default_port
        self.default_baudrate = default_baudrate
        self.exe_file = exe_file
        self.interactive = interactive
        self.auto_interactive = auto_interactive  # 发送完文件后自动进入交互模式
        self.buffer = []
        self.lock = threading.Lock()
        self.bootloader_active = False
        self.bootloader_state = 0  # 0:等待启动信息, 1:等待命令菜单, 2:等待文件传输, 3:完成
        self.bootloader_timeout = 30  # 30秒超时
        self.bootloader_start_time = None
        self.input_buffer = ""
        
    def list_ports(self):
        """列出可用的串口"""
        ports = serial.tools.list_ports.comports()
        if not ports:
            print("未找到可用的串口")
            return []
        
        print("可用串口列表:")
        for i, port in enumerate(ports):
            print(f"  [{i}] {port.device} - {port.description}")
        return ports
    
    def connect(self, port=None, baudrate=None, timeout=1):
        """连接到指定串口"""
        # 使用默认参数如果未指定
        if port is None:
            port = self.default_port
        if baudrate is None:
            baudrate = self.default_baudrate
            
        if port is None:
            print("错误: 未指定端口且没有设置默认端口", file=sys.stderr)
            return False
            
        try:
            self.serial_port = serial.Serial(
                port=port,
                baudrate=baudrate,
                timeout=timeout,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE
            )
            self.connected = True
            self.running = True
            print(f"成功连接到 {port}，波特率: {baudrate}")
            
            # 启动接收线程
            self.receive_thread = threading.Thread(target=self._receive_data, daemon=True)
            self.receive_thread.start()
            
            # 如果指定了exe文件并且不是交互模式，启动bootloader模式
            if self.exe_file and not self.interactive:
                self.start_bootloader_mode()
            
            return True
        except Exception as e:
            print(f"连接失败: {e}", file=sys.stderr)
            return False
    
    def start_bootloader_mode(self):
        """启动bootloader模式"""
        self.bootloader_active = True
        self.bootloader_state = 0
        self.bootloader_start_time = time.time()
        print(f"[Bootloader] 启动自动模式，等待bootloader启动信息...")
        print(f"[Bootloader] 请重启MCU或按复位键...")
        print(f"[Bootloader] 超时时间: {self.bootloader_timeout}秒")
    
    def disconnect(self):
        """断开连接"""
        self.running = False
        if self.serial_port and self.serial_port.is_open:
            self.serial_port.close()
        self.connected = False
        print("串口已断开")
    
    def _receive_data(self):
        """接收数据的线程函数"""
        while self.running and self.connected:
            try:
                if self.serial_port and self.serial_port.in_waiting > 0:
                    data = self.serial_port.read(self.serial_port.in_waiting)
                    if data:
                        # 线程安全地添加到缓冲区
                        with self.lock:
                            self.buffer.append(('rx', data, datetime.now()))
                        
                        # 解码数据
                        decoded_data = data.decode('utf-8', errors='replace')
                        
                        # 显示接收到的数据（在交互模式或自动交互模式下）
                        if self.interactive or self.auto_interactive or self.bootloader_active:
                            sys.stdout.write(decoded_data)
                            sys.stdout.flush()
                        
                        # 处理bootloader自动交互
                        if self.bootloader_active and not self.interactive:
                            self._handle_bootloader_interaction(decoded_data)
                            
                time.sleep(0.01)
                
                # 检查bootloader超时
                if self.bootloader_active and self.bootloader_start_time:
                    elapsed = time.time() - self.bootloader_start_time
                    if elapsed > self.bootloader_timeout:
                        print(f"\n[Bootloader] 超时 ({self.bootloader_timeout}秒)，请检查连接和MCU状态")
                        self.bootloader_active = False
                        if not self.interactive:
                            self.running = False
                        
            except Exception as e:
                if self.running:
                    print(f"\n接收数据出错: {e}", file=sys.stderr)
                break
    
    def _handle_bootloader_interaction(self, received_data):
        """处理bootloader自动交互"""
        lowercase_data = received_data.lower()
        
        if self.bootloader_state == 0:
            # 等待启动信息
            if "auto-boot in" in lowercase_data or "neorv32 bootloader" in lowercase_data:
                print("\n[Bootloader] 检测到bootloader，发送任意键中断自动启动...")
                time.sleep(0.1)
                self.send_data(' ')  # 发送空格键中断自动启动
                self.bootloader_state = 1
                
        elif self.bootloader_state == 1:
            # 等待命令菜单 - 检测多种可能的命令提示符
            if "available cmds:" in lowercase_data or "cmd:>" in lowercase_data or "type 'h' for help" in lowercase_data:
                print("\n[Bootloader] 检测到命令菜单，发送'u'命令上传文件...")
                time.sleep(0.1)
                self.send_data('u')
                self.bootloader_state = 2
                
        elif self.bootloader_state == 2:
            # 等待文件传输提示
            if "awaiting neorv32_exe.bin" in lowercase_data or ("awaiting" in lowercase_data and "bin" in lowercase_data):
                print(f"\n[Bootloader] 检测到文件传输请求，开始发送文件: {self.exe_file}")
                if self.send_exe_file(self.exe_file):
                    print("\n[Bootloader] 文件发送完成，发送'e'命令执行...")
                    time.sleep(0.1)
                    self.send_data('e')
                    self.bootloader_state = 3
                    self.bootloader_active = False
                    print("\n[Bootloader] 自动交互完成!")
                    
                    # 如果设置了自动交互模式，启动交互模式
                    if self.auto_interactive:
                        print("\n[INFO] 正在切换到交互模式...")
                        self.interactive = True
                        print("[INFO] 已进入交互模式，按Ctrl+C退出")
                    else:
                        print("[INFO] 程序上传完成")
                
        elif self.bootloader_state == 3:
            # 程序执行状态
            if "crc passed" in lowercase_data or "executing" in lowercase_data:
                print("\n[Bootloader] 程序执行成功!")
    
    def _handle_interactive_upload(self):
        """处理交互模式下的文件上传"""
        if not self.exe_file:
            print("[ERROR] 没有指定可执行文件")
            return
        
        if not os.path.exists(self.exe_file):
            print(f"[ERROR] 文件不存在: {self.exe_file}")
            return
        
        # 启动bootloader模式
        self.bootloader_active = True
        self.bootloader_state = 0
        self.bootloader_start_time = time.time()
        print(f"[Bootloader] 启动上传模式，等待bootloader启动信息...")
        print(f"[Bootloader] 请重启MCU或按复位键...")
        print(f"[Bootloader] 超时时间: {self.bootloader_timeout}秒")
        
        # 等待bootloader完成
        try:
            while self.running and self.bootloader_active:
                time.sleep(0.1)
                
            if self.bootloader_state == 3:  # 成功完成
                print("[INFO] 文件上传完成，继续交互模式...")
            else:
                print("[ERROR] 文件上传失败")
                
        except KeyboardInterrupt:
            print("\n[INFO] 上传被用户中断")
            self.bootloader_active = False
    
    def send_data(self, data):
        """发送数据"""
        if not self.connected:
            print("未连接到串口", file=sys.stderr)
            return False
        
        try:
            if isinstance(data, str):
                data = data.encode('utf-8')
            
            self.serial_port.write(data)
            with self.lock:
                self.buffer.append(('tx', data, datetime.now()))
            return True
        except Exception as e:
            print(f"发送数据失败: {e}", file=sys.stderr)
            return False
    
    def send_exe_file(self, file_path, delay=0.001):
        """发送neorv32 exe文件（二进制格式）"""
        if not self.connected:
            print("未连接到串口", file=sys.stderr)
            return False
        
        if not os.path.exists(file_path):
            print(f"文件不存在: {file_path}", file=sys.stderr)
            return False
        
        try:
            file_size = os.path.getsize(file_path)
            print(f"开始发送文件: {file_path} ({file_size} 字节)")
            
            with open(file_path, 'rb') as f:
                bytes_sent = 0
                while True:
                    chunk = f.read(1024)  # 每次读取1KB
                    if not chunk:
                        break
                    
                    self.serial_port.write(chunk)
                    with self.lock:
                        self.buffer.append(('tx_file', chunk, datetime.now()))
                    
                    bytes_sent += len(chunk)
                    if file_size > 0:
                        progress = (bytes_sent / file_size) * 100
                        print(f"\r发送进度: {progress:.1f}% ({bytes_sent}/{file_size} 字节)", end='')
                    
                    # 添加延迟避免数据溢出
                    time.sleep(delay)
            
            print(f"\n文件发送完成!")
            return True
            
        except Exception as e:
            print(f"\n文件发送失败: {e}", file=sys.stderr)
            return False
    
    def run_interactive(self):
        """运行交互式终端"""
        print("=== NEORV32 串口终端 ===")
        print("Ctrl+C 退出程序")
        if self.exe_file:
            print(f"[INFO] 检测到可执行文件: {self.exe_file}")
            print("[INFO] 在交互模式下输入 'u' 可以上传文件")
        
        # 如果有默认参数，尝试自动连接
        if self.default_port and not self.connected:
            self.connect()
        elif not self.connected:
            print("请使用 'connect <port>' 命令连接串口")
            return
        
        try:
            # 保持运行直到用户中断
            self.interactive = True
            
            # 检测操作系统
            import platform
            is_windows = platform.system() == 'Windows'
            
            if not is_windows:
                # Unix/Linux/Mac系统 - 使用termios实现字符级输入
                import select
                import termios
                import tty
                
                # 保存终端设置
                old_settings = termios.tcgetattr(sys.stdin)
                try:
                    # 设置为非阻塞模式
                    tty.setraw(sys.stdin.fileno())
                    
                    while self.running:
                        # 检查是否有输入可读
                        if select.select([sys.stdin], [], [], 0) == ([sys.stdin], [], []):
                            # 读取用户输入
                            char = sys.stdin.read(1)
                            if char:
                                # 检查是否输入了'u'字符
                                if char.lower() == 'u' and self.exe_file:
                                    print("\n[INFO] 检测到'u'命令，开始上传文件...")
                                    self._handle_interactive_upload()
                                else:
                                    # 发送到串口
                                    self.send_data(char)
                                    # 回显字符
                                    sys.stdout.write(char)
                                    sys.stdout.flush()
                        
                        time.sleep(0.01)
                finally:
                    # 恢复终端设置
                    termios.tcsetattr(sys.stdin, termios.TCSADRAIN, old_settings)
            else:
                # Windows系统 - 使用msvcrt实现字符级输入
                try:
                    import msvcrt
                    
                    while self.running:
                        # 检查是否有按键
                        if msvcrt.kbhit():
                            char = msvcrt.getch()
                            # 处理特殊键
                            if char == b'\x03':  # Ctrl+C
                                raise KeyboardInterrupt
                            
                            # 解码字符
                            try:
                                char_str = char.decode('utf-8')
                            except UnicodeDecodeError:
                                # 对于某些特殊键，可能需要读取第二个字节
                                if msvcrt.kbhit():
                                    char += msvcrt.getch()
                                try:
                                    char_str = char.decode('utf-8')
                                except UnicodeDecodeError:
                                    char_str = char.decode('latin-1', errors='replace')
                            
                            # 检查是否输入了'u'字符
                            if char_str.lower() == 'u' and self.exe_file:
                                print("\n[INFO] 检测到'u'命令，开始上传文件...")
                                self._handle_interactive_upload()
                            else:
                                # 发送到串口
                                self.send_data(char_str)
                                # 回显字符
                                sys.stdout.write(char_str)
                                sys.stdout.flush()
                        
                        time.sleep(0.01)
                        
                except ImportError:
                    # 如果msvcrt不可用，回退到行输入模式
                    print("\n[INFO] 使用简化输入模式（仅支持回车发送整行）")
                    if self.exe_file:
                        print("[INFO] 输入 'u' 并按回车可以上传文件")
                    while self.running:
                        try:
                            # 使用input()读取整行输入
                            line = input()
                            if line.lower() == 'u' and self.exe_file:
                                print("[INFO] 检测到'u'命令，开始上传文件...")
                                self._handle_interactive_upload()
                            elif line:
                                # 添加换行符并发送
                                self.send_data(line + '\r\n')
                        except EOFError:
                            break
                        except KeyboardInterrupt:
                            break
                
        except KeyboardInterrupt:
            print("\n收到中断信号")
        finally:
            if self.connected:
                self.disconnect()
    
    def run_bootloader(self):
        """运行bootloader模式"""
        print("=== NEORV32 Bootloader 模式 ===")
        
        # 连接并启动bootloader
        if not self.connect():
            return False
            
        try:
            # 等待bootloader完成
            while self.running and self.bootloader_active:
                time.sleep(0.1)
                
            # 如果是自动交互模式，继续运行
            if self.auto_interactive and self.running:
                print("\n[INFO] 进入交互模式...")
                self.run_interactive()
            elif self.bootloader_state == 3:  # 成功完成
                print("[INFO] 程序上传完成，自动进入交互模式...")
                print("[INFO] 按 Ctrl+C 退出程序")
                # 自动进入交互模式
                if self.running:
                    self.interactive = True
                    self.run_interactive()
            else:
                print("[INFO] bootloader未完成，程序退出")
                    
        except KeyboardInterrupt:
            print("\n收到中断信号")
        finally:
            if self.connected:
                self.disconnect()
            
            # 根据结果返回适当的退出码
            return self.bootloader_state == 3
    
    def show_help(self):
        """显示帮助信息"""
        help_text = f"""
=== 帮助信息 ===
命令行参数:
  -p, --port PORT           串口端口 (默认: {self.default_port or 'None'})
  -b, --baudrate BAUD       波特率 (默认: {self.default_baudrate})
  -f, --file FILE           EXE文件路径
  -i, --interactive         交互模式
  -a, --auto-interactive    发送文件后自动进入交互模式
  -h, --help                显示此帮助

使用方法:
  1. 自动上传后进入交互模式:
     {sys.argv[0]} -p COM3 -f program.exe -a
     
  2. 仅上传模式:
     {sys.argv[0]} -p COM3 -f program.exe
     
  3. 交互模式:
     {sys.argv[0]} -p COM3 -i
"""
        print(help_text)

def signal_handler(sig, frame):
    """处理信号"""
    print('\n程序被用户中断')
    sys.exit(0)

def main():
    """主函数 - 支持命令行参数"""
    parser = argparse.ArgumentParser(description='NEORV32 串口调试终端')
    parser.add_argument('-p', '--port', help='串口端口 (如: COM1, /dev/ttyUSB0)')
    parser.add_argument('-b', '--baudrate', type=int, default=115200, help='波特率 (默认: 115200)')
    parser.add_argument('-f', '--file', help='NEORV32 exe文件路径 (用于bootloader自动上传)')
    parser.add_argument('-i', '--interactive', action='store_true', help='交互模式')
    parser.add_argument('-a', '--auto-interactive', action='store_true', help='发送文件后自动进入交互模式')
    parser.add_argument('--list-ports', action='store_true', help='列出可用串口')
    
    args = parser.parse_args()
    
    # 设置信号处理
    signal.signal(signal.SIGINT, signal_handler)
    
    # 列出端口
    if args.list_ports:
        terminal = SerialTerminal()
        terminal.list_ports()
        return
    
    # 创建终端实例
    terminal = SerialTerminal(
        default_port=args.port, 
        default_baudrate=args.baudrate, 
        exe_file=args.file,
        interactive=args.interactive,
        auto_interactive=args.auto_interactive
    )
    
    try:
        if args.interactive:
            # 交互模式
            terminal.run_interactive()
        elif args.file:
            # bootloader自动模式
            success = terminal.run_bootloader()
            sys.exit(0 if success else 1)
        else:
            # 显示帮助
            terminal.show_help()
            
    except Exception as e:
        print(f"程序异常: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        if terminal.connected:
            terminal.disconnect()

if __name__ == "__main__":
    main()
