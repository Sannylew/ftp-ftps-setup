#!/bin/bash

# BRCE FTP服务配置脚本
# 基于 ftp_manager.sh 的 vsftpd 配置逻辑
# 专门用于配置FTP访问 /opt/brce/file 目录
# 集成实时同步功能，解决文件修改延迟问题
# 版本: 2.0

set -e

echo "======================================================"
echo "📁 BRCE FTP服务配置工具 (零延迟版)"
echo "======================================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
    echo "❌ 此脚本需要 root 权限，请使用 sudo 运行"
    exit 1
fi

# 固定配置（专门为BRCE程序设计）
BRCE_DIR="/opt/brce/file"
FTP_USER="sunny"

# 验证用户名函数（来自主程序）
validate_username() {
    local username="$1"
    if [[ ! "$username" =~ ^[a-z][-a-z0-9]*$ ]] || [ ${#username} -gt 32 ]; then
        echo "❌ 用户名不合法！只能包含小写字母、数字和连字符，最多32字符"
        return 1
    fi
    return 0
}

# 检查实时同步依赖
check_sync_dependencies() {
    local missing_deps=()
    
    if ! command -v rsync &> /dev/null; then
        missing_deps+=("rsync")
    fi
    
    if ! command -v inotifywait &> /dev/null; then
        missing_deps+=("inotify-tools")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "📦 安装实时同步依赖..."
        if command -v apt-get &> /dev/null; then
            apt-get update -qq
            apt-get install -y "${missing_deps[@]}"
        elif command -v yum &> /dev/null; then
            yum install -y "${missing_deps[@]}"
        else
            echo "❌ 无法自动安装依赖: ${missing_deps[*]}"
            return 1
        fi
        echo "✅ 依赖安装完成"
    else
        echo "✅ 实时同步依赖已安装"
    fi
}

# 智能权限配置函数（基于主程序逻辑）
configure_smart_permissions() {
    local user="$1"
    local source_dir="$2"
    local user_home="/home/$user"
    local ftp_home="$user_home/ftp"
    
    echo "🔧 配置FTP目录权限（完整读写删除权限）..."
    
    mkdir -p "$ftp_home"
    
    # 配置用户主目录
    chown root:root "$user_home"
    chmod 755 "$user_home"
    
    # 确保源目录存在
    mkdir -p "$source_dir"
    
    # 关键修复：设置源目录权限，确保FTP用户有完整权限
    echo "🔧 设置源目录权限: $source_dir"
    chown -R "$user":"$user" "$source_dir"
    chmod -R 755 "$source_dir"
    
    # 如果源目录在/opt下，设置特殊权限
    if [[ "$source_dir" == /opt/* ]]; then
        echo "⚠️  检测到/opt目录，设置访问权限..."
        chmod o+x /opt 2>/dev/null || true
        dirname_path=$(dirname "$source_dir")
        while [ "$dirname_path" != "/" ] && [ "$dirname_path" != "/opt" ]; do
            chmod o+x "$dirname_path" 2>/dev/null || true
            dirname_path=$(dirname "$dirname_path")
        done
    fi
    
    # 设置FTP目录权限
    chown "$user":"$user" "$ftp_home"
    chmod 755 "$ftp_home"
    
    echo "✅ 权限配置完成（用户拥有完整读写删除权限）"
}

# 生成vsftpd配置文件（基于主程序配置）
generate_optimal_config() {
    local ftp_home="$1"
    
    echo "📡 生成vsftpd配置..."
    
    # 备份原配置
    [ -f /etc/vsftpd.conf ] && cp /etc/vsftpd.conf /etc/vsftpd.conf.backup.$(date +%Y%m%d_%H%M%S)
    
    # 生成优化的配置（基于主程序，适合视频文件，禁用缓存）
    cat > /etc/vsftpd.conf <<EOF
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
local_root=$ftp_home
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
utf8_filesystem=YES
pam_service_name=vsftpd
seccomp_sandbox=NO
xferlog_enable=YES
xferlog_file=/var/log/vsftpd.log
log_ftp_protocol=YES
async_abor_enable=YES
ascii_upload_enable=YES
ascii_download_enable=YES
hide_ids=YES
use_localtime=YES
file_open_mode=0755
local_umask=022
# 禁用缓存，确保实时性
ls_recurse_enable=NO
use_sendfile=NO
EOF

    echo "✅ 配置文件已生成"
}

# 创建实时同步脚本（解决延迟问题）
create_sync_script() {
    local user="$1"
    local source_dir="$2"
    local target_dir="$3"
    local script_path="/usr/local/bin/ftp_sync_${user}.sh"
    
    echo "📝 创建实时同步脚本..."
    
    cat > "$script_path" << EOF
#!/bin/bash

# BRCE FTP实时同步脚本
# 解决文件修改延迟问题

USER="$user"
SOURCE_DIR="$source_dir"
TARGET_DIR="$target_dir"

echo "\$(date): 启动BRCE FTP实时同步服务"
echo "源目录: \$SOURCE_DIR"
echo "目标目录: \$TARGET_DIR"

# 初始同步
echo "\$(date): 执行初始同步..."
rsync -av --delete "\$SOURCE_DIR/" "\$TARGET_DIR/" >/dev/null 2>&1

# 设置正确权限
chown -R "\$USER:\$USER" "\$TARGET_DIR" >/dev/null 2>&1
find "\$TARGET_DIR" -type f -exec chmod 644 {} \; >/dev/null 2>&1 || true
find "\$TARGET_DIR" -type d -exec chmod 755 {} \; >/dev/null 2>&1 || true

echo "\$(date): 初始同步完成，开始监控文件变化..."

# 实时监控并同步
inotifywait -m -r -e modify,create,delete,move,moved_to,moved_from "\$SOURCE_DIR" |
while read path action file; do
    echo "\$(date): 检测到变化: \$action \$file (路径: \$path)"
    
    # 短暂延迟避免频繁同步
    sleep 0.05
    
    # 执行同步（删除目标中不存在的文件）
    rsync -av --delete "\$SOURCE_DIR/" "\$TARGET_DIR/" >/dev/null 2>&1
    
    # 确保权限正确
    chown -R "\$USER:\$USER" "\$TARGET_DIR" >/dev/null 2>&1
    find "\$TARGET_DIR" -type f -exec chmod 644 {} \; >/dev/null 2>&1 || true
    find "\$TARGET_DIR" -type d -exec chmod 755 {} \; >/dev/null 2>&1 || true
    
    echo "\$(date): 同步完成 - \$action \$file"
done
EOF

    chmod +x "$script_path"
    echo "✅ 实时同步脚本已创建: $script_path"
}

# 创建systemd服务
create_sync_service() {
    local user="$1"
    local service_name="brce-ftp-sync"
    local script_path="/usr/local/bin/ftp_sync_${user}.sh"
    
    echo "🔧 创建实时同步系统服务..."
    
    cat > "/etc/systemd/system/${service_name}.service" << EOF
[Unit]
Description=BRCE FTP Real-time Sync Service
After=network.target vsftpd.service
Requires=vsftpd.service

[Service]
Type=simple
ExecStart=$script_path
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    echo "✅ 系统服务已创建: ${service_name}.service"
}

# 启动实时同步服务
start_sync_service() {
    local service_name="brce-ftp-sync"
    
    echo "🚀 启动实时同步服务..."
    
    systemctl enable "$service_name"
    systemctl start "$service_name"
    
    if systemctl is-active --quiet "$service_name"; then
        echo "✅ 实时同步服务已启动: $service_name"
        echo "🔥 现在文件变化将零延迟同步到FTP！"
    else
        echo "❌ 实时同步服务启动失败"
        echo "📋 查看错误日志:"
        journalctl -u "$service_name" --no-pager -n 10
        return 1
    fi
}

# 停止实时同步服务
stop_sync_service() {
    local service_name="brce-ftp-sync"
    
    echo "⏹️ 停止实时同步服务..."
    
    systemctl stop "$service_name" 2>/dev/null || true
    systemctl disable "$service_name" 2>/dev/null || true
    
    echo "✅ 实时同步服务已停止"
}

# 主安装函数
install_brce_ftp() {
    echo ""
    echo "======================================================"
    echo "🚀 开始配置BRCE FTP服务 (零延迟版)"
    echo "======================================================"
    echo ""
    echo "🎯 目标目录: $BRCE_DIR"
    echo "👤 FTP用户: $FTP_USER"
    echo "⚡ 特性: 实时同步，零延迟"
    echo ""
    
    # 确认配置
    read -p "是否使用零延迟实时同步？(y/n，默认: y): " confirm
    confirm=${confirm:-y}
    
    if [[ "$confirm" != "y" ]]; then
        echo "❌ 配置已取消"
        return 1
    fi
    
    # 检查目录是否存在，如果不存在则创建
    if [ ! -d "$BRCE_DIR" ]; then
        echo "📁 创建BRCE目录: $BRCE_DIR"
        mkdir -p "$BRCE_DIR"
        echo "✅ 目录创建成功"
    else
        echo "✅ BRCE目录已存在: $BRCE_DIR"
    fi
    
    # 获取FTP密码
    read -p "自动生成密码？(y/n，默认: y): " auto_pwd
    auto_pwd=${auto_pwd:-y}
    
    if [[ "$auto_pwd" == "y" ]]; then
        ftp_pass=$(openssl rand -base64 12)
        echo "🔑 自动生成的密码: $ftp_pass"
    else
        while true; do
            read -s -p "FTP密码（至少8位）: " ftp_pass
            echo
            if [ ${#ftp_pass} -ge 8 ]; then
                break
            fi
            echo "❌ 密码至少8位"
        done
    fi
    
    echo ""
    echo "⚙️  开始部署..."
    
    # 安装vsftpd和实时同步依赖
    echo "📦 安装软件包..."
    if command -v apt-get &> /dev/null; then
        apt-get update -qq
        apt-get install -y vsftpd rsync inotify-tools
    elif command -v yum &> /dev/null; then
        yum install -y vsftpd rsync inotify-tools
    else
        echo "❌ 不支持的包管理器"
        exit 1
    fi
    
    # 检查实时同步依赖
    check_sync_dependencies
    
    # 创建用户（基于主程序逻辑）
    echo "👤 配置用户..."
    if id -u "$FTP_USER" &>/dev/null; then
        echo "⚠️  用户已存在，重置密码"
    else
        if command -v adduser &> /dev/null; then
            adduser "$FTP_USER" --disabled-password --gecos ""
        else
            useradd -m -s /bin/bash "$FTP_USER"
        fi
    fi
    echo "$FTP_USER:$ftp_pass" | chpasswd
    
    # 配置权限
    ftp_home="/home/$FTP_USER/ftp"
    configure_smart_permissions "$FTP_USER" "$BRCE_DIR"
    
    # 停止旧的实时同步服务（如果存在）
    stop_sync_service
    
    # 卸载旧挂载（如果存在）
    if mountpoint -q "$ftp_home" 2>/dev/null; then
        echo "📤 卸载旧bind挂载"
        umount "$ftp_home" 2>/dev/null || true
        # 从fstab中移除
        sed -i "\|$ftp_home|d" /etc/fstab 2>/dev/null || true
    fi
    
    # 创建实时同步脚本和服务
    create_sync_script "$FTP_USER" "$BRCE_DIR" "$ftp_home"
    create_sync_service "$FTP_USER"
    
    # 生成配置
    generate_optimal_config "$ftp_home"
    
    # 启动服务
    echo "🔄 启动FTP服务..."
    systemctl restart vsftpd
    systemctl enable vsftpd
    
    # 启动实时同步服务
    start_sync_service
    
    # 配置防火墙（基于主程序逻辑）
    echo "🔥 配置防火墙..."
    if command -v ufw &> /dev/null; then
        ufw allow 21/tcp >/dev/null 2>&1 || true
        ufw allow 40000:40100/tcp >/dev/null 2>&1 || true
        echo "✅ UFW: 已开放FTP端口"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-service=ftp >/dev/null 2>&1 || true
        firewall-cmd --permanent --add-port=40000-40100/tcp >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
        echo "✅ Firewalld: 已开放FTP端口"
    fi
    
    # 获取服务器IP（基于主程序逻辑）
    external_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "localhost")
    
    echo ""
    echo "======================================================"
    echo "🎉 BRCE FTP服务部署完成！(零延迟版)"
    echo "======================================================"
    echo ""
    echo "📋 连接信息："
    echo "   服务器: $external_ip"
    echo "   端口: 21"
    echo "   用户: $FTP_USER"
    echo "   密码: $ftp_pass"
    echo "   访问目录: $BRCE_DIR"
    echo ""
    echo "⚡ 零延迟特性："
    echo "   ✅ 文件创建 - 立即可见"
    echo "   ✅ 文件删除 - 立即消失"
    echo "   ✅ 文件修改 - 立即更新"
    echo "   ✅ 目录操作 - 实时同步"
    echo ""
    echo "💡 连接建议："
    echo "   - 使用被动模式（PASV）"
    echo "   - 端口范围: 40000-40100"
    echo "   - 支持大文件传输（视频文件）"
    echo ""
    echo "🎥 现在root删除文件，FTP立即看不到了！"
}

# 检查FTP状态
check_ftp_status() {
    echo ""
    echo "======================================================"
    echo "📊 BRCE FTP服务状态 (零延迟版)"
    echo "======================================================"
    
    # 检查服务状态
    if systemctl is-active --quiet vsftpd; then
        echo "✅ FTP服务运行正常"
    else
        echo "❌ FTP服务未运行"
    fi
    
    # 检查实时同步服务
    if systemctl is-active --quiet brce-ftp-sync; then
        echo "✅ 实时同步服务运行正常"
    else
        echo "❌ 实时同步服务未运行"
    fi
    
    # 检查端口
    if ss -tlnp | grep -q ":21 "; then
        echo "✅ FTP端口21已开启"
    else
        echo "❌ FTP端口21未开启"
    fi
    
    # 检查用户
    if id "$FTP_USER" &>/dev/null; then
        echo "✅ FTP用户 $FTP_USER 存在"
    else
        echo "❌ FTP用户 $FTP_USER 不存在"
    fi
    
    # 检查目录
    FTP_HOME="/home/$FTP_USER/ftp"
    if [ -d "$FTP_HOME" ]; then
        echo "✅ FTP目录存在: $FTP_HOME"
    else
        echo "❌ FTP目录不存在: $FTP_HOME"
    fi
    
    if [ -d "$BRCE_DIR" ]; then
        echo "✅ BRCE目录存在: $BRCE_DIR"
        file_count=$(find "$BRCE_DIR" -type f 2>/dev/null | wc -l)
        echo "📁 源目录文件数: $file_count"
        
        if [ -d "$FTP_HOME" ]; then
            ftp_file_count=$(find "$FTP_HOME" -type f 2>/dev/null | wc -l)
            echo "📁 FTP目录文件数: $ftp_file_count"
            
            if [ "$file_count" -eq "$ftp_file_count" ]; then
                echo "✅ 文件数量同步正确"
            else
                echo "⚠️  文件数量不匹配"
            fi
        fi
    else
        echo "❌ BRCE目录不存在: $BRCE_DIR"
    fi
    
    # 显示同步服务日志
    echo ""
    echo "📋 实时同步日志 (最近5条):"
    journalctl -u brce-ftp-sync --no-pager -n 5 2>/dev/null || echo "暂无日志"
    
    # 显示连接信息
    external_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "localhost")
    echo ""
    echo "📍 连接信息："
    echo "   服务器: $external_ip"
    echo "   端口: 21"
    echo "   用户名: $FTP_USER"
    echo "   模式: ⚡ 零延迟实时同步"
}

# 测试实时同步
test_realtime_sync() {
    echo ""
    echo "======================================================"
    echo "🧪 测试实时同步功能"
    echo "======================================================"
    
    TEST_FILE="$BRCE_DIR/realtime_test_$(date +%s).txt"
    FTP_HOME="/home/$FTP_USER/ftp"
    
    echo "📝 创建测试文件: $TEST_FILE"
    echo "实时同步测试 - $(date)" > "$TEST_FILE"
    
    echo "⏱️  等待3秒检查同步..."
    sleep 3
    
    if [ -f "$FTP_HOME/$(basename "$TEST_FILE")" ]; then
        echo "✅ 文件创建同步成功"
    else
        echo "❌ 文件创建同步失败"
    fi
    
    echo "📝 修改测试文件..."
    echo "修改后的内容 - $(date)" >> "$TEST_FILE"
    
    echo "⏱️  等待3秒检查同步..."
    sleep 3
    
    if diff "$TEST_FILE" "$FTP_HOME/$(basename "$TEST_FILE")" >/dev/null 2>&1; then
        echo "✅ 文件修改同步成功"
    else
        echo "❌ 文件修改同步失败"
    fi
    
    echo "🗑️ 删除测试文件..."
    rm -f "$TEST_FILE"
    
    echo "⏱️  等待3秒检查同步..."
    sleep 3
    
    if [ ! -f "$FTP_HOME/$(basename "$TEST_FILE")" ]; then
        echo "✅ 文件删除同步成功"
        echo "🎉 实时同步功能正常！零延迟确认！"
    else
        echo "❌ 文件删除同步失败"
    fi
}

# 卸载FTP服务
uninstall_brce_ftp() {
    echo ""
    echo "======================================================"
    echo "🗑️ 卸载BRCE FTP服务"
    echo "======================================================"
    
    read -p "⚠️  确定要卸载BRCE FTP服务吗？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "❌ 取消卸载"
        return 1
    fi
    
    echo "🛑 停止FTP服务..."
    systemctl stop vsftpd 2>/dev/null || true
    systemctl disable vsftpd 2>/dev/null || true
    
    echo "⏹️ 停止实时同步服务..."
    stop_sync_service
    
    echo "🗑️ 删除同步服务文件..."
    rm -f "/etc/systemd/system/brce-ftp-sync.service"
    rm -f "/usr/local/bin/ftp_sync_${FTP_USER}.sh"
    systemctl daemon-reload
    
    echo "🗑️ 删除FTP用户..."
    userdel -r "$FTP_USER" 2>/dev/null || true
    
    echo "✅ 卸载完成"
    echo "💡 注意: BRCE目录 $BRCE_DIR 保持不变"
}

# 主菜单
main_menu() {
    echo ""
    echo "请选择操作："
    echo "1) 🚀 安装/配置BRCE FTP服务 (零延迟)"
    echo "2) 📊 查看FTP服务状态"
    echo "3) 🔄 重启FTP服务"
    echo "4) 🧪 测试实时同步功能"
    echo "5) 🗑️ 卸载FTP服务"
    echo "0) 退出"
    echo ""
    
    read -p "请输入选项 (0-5): " choice
    
    case $choice in
        1)
            install_brce_ftp
            ;;
        2)
            check_ftp_status
            ;;
        3)
            echo "🔄 重启FTP服务..."
            systemctl restart vsftpd
            systemctl restart brce-ftp-sync 2>/dev/null || true
            if systemctl is-active --quiet vsftpd; then
                echo "✅ FTP服务重启成功"
            else
                echo "❌ FTP服务重启失败"
            fi
            ;;
        4)
            test_realtime_sync
            ;;
        5)
            uninstall_brce_ftp
            ;;
        0)
            echo "👋 退出程序"
            exit 0
            ;;
        *)
            echo "❌ 无效选项"
            ;;
    esac
}

# 主程序循环
while true; do
    main_menu
done 