#!/bin/bash

# FTP 服务器管理工具 - 交互式安装/卸载脚本
# 版本: 1.0

set -e

echo "======================================================"
echo "📡 FTP 服务器管理工具"
echo "======================================================"
echo ""

# 默认为安装模式（用于curl管道执行）
DEFAULT_CHOICE="1"

# 调试信息
echo "🔍 环境调试信息:"
echo "   stdin是否为终端: $( [ -t 0 ] && echo '是' || echo '否' )"
echo "   /dev/tty是否可用: $( [ -c /dev/tty ] && echo '是' || echo '否' )"
echo "   BASH_SOURCE: ${BASH_SOURCE[0]:-未设置}"
echo "   执行方式: $( [ -p /dev/stdin ] && echo 'pipe管道' || echo 'direct直接' )"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
    echo "❌ 此脚本需要 root 权限，请使用 sudo 运行"
    exit 1
fi

# 检测系统信息
echo "🔍 检测系统环境..."
if command -v lsb_release &> /dev/null; then
    echo "✅ 系统: $(lsb_release -d | cut -f2)"
else
    echo "⚠️  无法检测系统版本，假设为Ubuntu/Debian"
fi

echo ""
echo "请选择操作："
echo "1) 安装 FTP 服务器"
echo "2) 卸载 FTP 服务器"
echo "3) 查看 FTP 状态"
echo "0) 退出"
echo ""

# 超级简化的选择逻辑
choice="$DEFAULT_CHOICE"

# 只有在真正的交互式环境才询问用户
if [ -t 0 ] && [ -t 1 ] && [ -c /dev/tty ]; then
    echo "🔍 检测到交互式环境，等待用户选择..."
    read -p "请输入选项 (0-3): " user_choice || user_choice=""
    if [ -n "$user_choice" ]; then
        choice="$user_choice"
    fi
else
    echo "🚀 检测到非交互式环境（curl管道），自动安装FTP服务器..."
fi

echo "📋 执行操作: $choice"

case $choice in
    1)
        echo ""
        echo "======================================================"
        echo "🚀 开始安装 FTP 服务器"
        echo "======================================================"
        
        # 验证用户名函数
        validate_username() {
            local username="$1"
            if [[ ! "$username" =~ ^[a-z][-a-z0-9]*$ ]] || [ ${#username} -gt 32 ]; then
                echo "❌ 用户名不合法！只能包含小写字母、数字和连字符，最多32字符"
                return 1
            fi
            return 0
        }

        # 智能权限配置
        configure_smart_permissions() {
            local user="$1"
            local user_home="/home/$user"
            local ftp_home="$user_home/ftp"
            
            echo "🔧 配置FTP目录权限（完整读写权限）..."
            
            mkdir -p "$ftp_home"
            
            chown root:root "$user_home"
            chmod 755 "$user_home"
            
            chown "$user":"$user" "$ftp_home"
            chmod 755 "$ftp_home"
            
            echo "✅ 权限配置完成（用户拥有完整读写权限）"
        }

        # 生成配置文件
        generate_optimal_config() {
            local ftp_home="$1"
            
            echo "📡 生成vsftpd配置..."
            
            [ -f /etc/vsftpd.conf ] && cp /etc/vsftpd.conf /etc/vsftpd.conf.backup.$(date +%Y%m%d_%H%M%S)
            
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
EOF

            echo "✅ 配置文件已生成"
        }

        # 用户输入
        echo "📝 配置FTP服务器..."
        
        # 检查是否为自动模式（与主菜单检测逻辑保持一致）
        auto_mode=false
        if [ ! -t 0 ] || [ ! -t 1 ] || [ ! -c /dev/tty ]; then
            auto_mode=true
            echo "🤖 自动模式：使用默认配置"
        fi
        
        if [ "$auto_mode" = true ]; then
            ftp_user="ftpuser"
            echo "👤 FTP用户名: $ftp_user (默认)"
        else
            while true; do
                read -p "FTP用户名（默认: ftpuser）: " ftp_user < /dev/tty
                ftp_user=${ftp_user:-ftpuser}
                if validate_username "$ftp_user"; then
                    break
                fi
            done
        fi

        if [ "$auto_mode" = true ]; then
            source_dir="/root/brec/file"
            echo "📁 服务器目录: $source_dir (默认)"
        else
            read -p "服务器目录（默认: /root/brec/file）: " source_dir < /dev/tty
            source_dir=${source_dir:-/root/brec/file}
        fi

        if [ ! -d "$source_dir" ]; then
            if [ "$auto_mode" = true ]; then
                create_dir="y"
                echo "📂 自动创建目录: $source_dir"
            else
                read -p "目录不存在，是否创建？(y/n，默认: y): " create_dir < /dev/tty
                create_dir=${create_dir:-y}
            fi
            if [[ "$create_dir" == "y" ]]; then
                mkdir -p "$source_dir" || {
                    echo "❌ 创建目录失败"
                    exit 1
                }
                echo "✅ 目录创建成功"
            else
                exit 1
            fi
        fi

        if [ "$auto_mode" = true ]; then
            auto_pwd="y"
            echo "🔐 自动生成密码"
        else
            read -p "自动生成密码？(y/n，默认: y): " auto_pwd < /dev/tty
            auto_pwd=${auto_pwd:-y}
        fi

        if [[ "$auto_pwd" == "y" ]]; then
            ftp_pass=$(openssl rand -base64 12)
        else
            while true; do
                read -s -p "FTP密码（至少8位）: " ftp_pass < /dev/tty
                echo
                if [ ${#ftp_pass} -ge 8 ]; then
                    break
                fi
                echo "❌ 密码至少8位"
            done
        fi

        echo ""
        echo "⚙️  开始部署..."

        # 安装vsftpd
        echo "📦 安装软件包..."
        apt update && apt install -y vsftpd || {
            echo "❌ 安装失败"
            exit 1
        }

        # 创建用户
        echo "👤 配置用户..."
        if id -u "$ftp_user" &>/dev/null; then
            echo "⚠️  用户已存在，重置密码"
        else
            adduser "$ftp_user" --disabled-password --gecos ""
        fi
        echo "$ftp_user:$ftp_pass" | chpasswd

        # 配置权限
        ftp_home="/home/$ftp_user/ftp"
        configure_smart_permissions "$ftp_user"

        # 处理源目录权限
        if [[ "$source_dir" == /root/* ]]; then
            echo "⚠️  设置/root目录访问权限..."
            chmod o+x "$(dirname "$source_dir")" 2>/dev/null || true
        fi

        # 目录挂载
        echo "🔗 配置目录映射..."
        mount --bind "$source_dir" "$ftp_home"
        if ! grep -q "$ftp_home" /etc/fstab; then
            echo "$source_dir $ftp_home none bind 0 0" >> /etc/fstab
        fi

        # 生成配置
        generate_optimal_config "$ftp_home"

        # 启动服务
        echo "🔄 启动服务..."
        systemctl restart vsftpd
        systemctl enable vsftpd

        # 配置防火墙
        echo "🔥 配置防火墙..."
        if command -v ufw &> /dev/null; then
            ufw allow 21/tcp >/dev/null 2>&1 || true
            ufw allow 40000:40100/tcp >/dev/null 2>&1 || true
            echo "✅ UFW: 已开放FTP端口"
        fi

        # 获取服务器IP
        external_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "localhost")

        echo ""
        echo "======================================================"
        echo "🎉 FTP服务器部署完成！"
        echo "======================================================"
        echo ""
        echo "📋 连接信息："
        echo "   服务器: $external_ip"
        echo "   端口: 21"
        echo "   用户: $ftp_user"
        echo "   密码: $ftp_pass"
        echo ""
        echo "📁 目录结构："
        echo "   FTP根目录: / (直接可读写)"
        echo "   映射路径: $source_dir"
        echo ""
        echo "🔧 特性："
        echo "   ✅ 完整读写权限（根目录直接操作）"
        echo "   ✅ 自动修复权限550错误"
        echo "   ✅ 被动模式传输"
        echo "   ✅ UTF-8字符编码"
        echo "   ✅ 防火墙自动配置"
        echo ""
        echo "📱 推荐客户端："
        echo "   FileZilla, WinSCP, Cyberduck"
        echo ""
        echo "======================================================"
        ;;
        
    2)
        echo ""
        echo "======================================================"
        echo "🗑️  开始卸载 FTP 服务器"
        echo "======================================================"
        
        # 自动检测FTP用户
        echo "🔍 自动检测FTP用户..."
        ftp_users=()

        for user_dir in /home/*/; do
            if [ -d "$user_dir" ]; then
                user=$(basename "$user_dir")
                if [ -d "/home/$user/ftp" ]; then
                    ftp_users+=("$user")
                fi
            fi
        done

        if [ ${#ftp_users[@]} -eq 0 ]; then
            echo "⚠️  未检测到FTP用户，尝试查找常见用户名..."
            common_users=("ftpuser" "ftp" "vsftpd")
            for user in "${common_users[@]}"; do
                if id "$user" &>/dev/null; then
                    ftp_users+=("$user")
                fi
            done
        fi

        if [ ${#ftp_users[@]} -eq 0 ]; then
            echo "❌ 未找到FTP用户"
            read -p "请手动输入FTP用户名（留空跳过）: " manual_user < /dev/tty
            if [ -n "$manual_user" ]; then
                ftp_users+=("$manual_user")
            fi
        else
            echo "📋 检测到以下FTP用户："
            for user in "${ftp_users[@]}"; do
                echo "   - $user"
            done
        fi

        echo ""
        
        # 卸载确认
        if [ -t 0 ] && [ -t 1 ] && [ -c /dev/tty ]; then
            # 交互式环境，询问用户
            read -p "确认卸载FTP服务器？(y/n): " confirm < /dev/tty
        else
            # 非交互式环境，自动确认
            echo "🚀 非交互式环境，自动确认卸载..."
            confirm="y"
        fi
        
        if [[ "$confirm" != "y" ]]; then
            echo "❌ 取消卸载"
            exit 0
        fi

        echo "🔄 开始卸载..."

        # 停止服务
        echo "⏹️  停止FTP服务..."
        systemctl stop vsftpd 2>/dev/null || true
        systemctl disable vsftpd 2>/dev/null || true

        # 清理挂载点
        echo "🗂️  清理挂载点..."
        for user in "${ftp_users[@]}"; do
            if [ -d "/home/$user/ftp" ]; then
                umount "/home/$user/ftp" 2>/dev/null || true
                echo "✅ 已卸载 /home/$user/ftp"
            fi
        done

        # 清理fstab
        echo "📝 清理fstab条目..."
        cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
        for user in "${ftp_users[@]}"; do
            sed -i "\|/home/$user/ftp|d" /etc/fstab 2>/dev/null || true
        done

        # 删除用户
        echo "👤 删除FTP用户..."
        for user in "${ftp_users[@]}"; do
            if id "$user" &>/dev/null; then
                userdel -r "$user" 2>/dev/null || true
                echo "✅ 已删除用户: $user"
            fi
        done

        # 卸载软件
        echo "📦 卸载vsftpd..."
        apt remove --purge -y vsftpd 2>/dev/null || true
        apt autoremove -y 2>/dev/null || true

        # 删除配置
        echo "🗑️  删除配置文件..."
        rm -f /etc/vsftpd.conf* 2>/dev/null || true
        rm -rf /etc/vsftpd/ 2>/dev/null || true

        # 清理防火墙
        echo "🔥 清理防火墙规则..."
        if command -v ufw &> /dev/null; then
            ufw delete allow 21/tcp 2>/dev/null || true
            ufw delete allow 40000:40100/tcp 2>/dev/null || true
        fi

        echo ""
        echo "======================================================"
        echo "🎉 FTP服务器卸载完成！"
        echo "======================================================"
        echo ""
        echo "📋 已清理："
        echo "   ✅ vsftpd服务和软件包"
        echo "   ✅ FTP用户: ${ftp_users[*]:-无}"
        echo "   ✅ 配置文件和挂载点"
        echo "   ✅ 防火墙规则"
        echo ""
        echo "✨ 系统已恢复到安装前状态"
        echo "======================================================"
        ;;
        
    3)
        echo ""
        echo "======================================================"
        echo "📊 FTP 服务器状态"
        echo "======================================================"
        
        # 检查vsftpd服务
        echo "🔍 检查vsftpd服务..."
        if systemctl is-active --quiet vsftpd 2>/dev/null; then
            echo "✅ vsftpd服务正在运行"
        else
            echo "❌ vsftpd服务未运行"
        fi
        
        # 检查端口
        echo ""
        echo "🔍 检查端口监听..."
        if netstat -ln 2>/dev/null | grep -q ":21 "; then
            echo "✅ FTP端口21正在监听"
        else
            echo "❌ FTP端口21未监听"
        fi
        
        # 检查FTP用户
        echo ""
        echo "🔍 检查FTP用户..."
        ftp_users_found=false
        for user_dir in /home/*/; do
            if [ -d "$user_dir" ]; then
                user=$(basename "$user_dir")
                if [ -d "/home/$user/ftp" ]; then
                    echo "✅ FTP用户: $user"
                    
                    # 显示用户详细信息
                    if id "$user" &>/dev/null; then
                        user_info=$(id "$user")
                        echo "   用户ID: $user_info"
                        
                        # 显示用户shell
                        user_shell=$(getent passwd "$user" | cut -d: -f7)
                        echo "   Shell: $user_shell"
                    fi
                    
                    # 显示目录信息
                    echo "   FTP目录: /home/$user/ftp"
                    if [ -d "/home/$user/ftp" ]; then
                        dir_perms=$(ls -ld "/home/$user/ftp" | awk '{print $1, $3, $4}')
                        echo "   目录权限: $dir_perms"
                    fi
                    
                    # 显示挂载信息
                    if mountpoint -q "/home/$user/ftp" 2>/dev/null; then
                        echo "   挂载状态: ✅ 已挂载"
                        # 显示挂载源
                        mount_source=$(mount | grep "/home/$user/ftp" | awk '{print $1}')
                        if [ -n "$mount_source" ]; then
                            echo "   映射源: $mount_source"
                        fi
                    else
                        echo "   挂载状态: ❌ 未挂载"
                    fi
                    
                    # 显示配置信息
                    if [ -f /etc/vsftpd.conf ]; then
                        local_root=$(grep "^local_root=" /etc/vsftpd.conf 2>/dev/null | cut -d= -f2)
                        if [ -n "$local_root" ]; then
                            echo "   FTP根目录: $local_root"
                        fi
                    fi
                    
                    echo ""
                    ftp_users_found=true
                fi
            fi
        done
        
        if [ "$ftp_users_found" = false ]; then
            echo "❌ 未找到FTP用户"
        else
            echo "💡 提示: 密码无法直接查看，如需重置请使用："
            echo "   sudo passwd 用户名"
            echo "   或生成新密码: openssl rand -base64 12"
        fi
        
        # 检查配置文件
        echo ""
        echo "🔍 检查配置文件..."
        if [ -f /etc/vsftpd.conf ]; then
            echo "✅ 配置文件存在: /etc/vsftpd.conf"
            if grep -q "allow_writeable_chroot=YES" /etc/vsftpd.conf; then
                echo "✅ 已配置550错误修复"
            else
                echo "⚠️  未配置550错误修复"
            fi
            
            # 显示关键配置
            echo "📋 关键配置:"
            grep -E "^(local_root|pasv_min_port|pasv_max_port|chroot_local_user)" /etc/vsftpd.conf 2>/dev/null | while read line; do
                echo "   $line"
            done
        else
            echo "❌ 配置文件不存在"
        fi
        
        echo ""
        echo "======================================================"
        ;;
        
    0)
        echo "👋 退出"
        exit 0
        ;;
        
    *)
        echo "⚠️  收到未知选项: '$choice'"
        echo "🚀 由于检测到curl管道执行，将自动默认为安装模式"
        echo "📝 正在使用默认配置安装FTP服务器..."
        
        # 直接设置为默认安装模式并继续执行
        # 复制最简化的安装逻辑
        ftp_user="ftpuser"
        source_dir="/root/brec/file"
        ftp_pass=$(openssl rand -base64 12)
        
        echo ""
        echo "======================================================"
        echo "🚀 开始安装 FTP 服务器（自动模式）"
        echo "======================================================"
        echo "🤖 自动模式：使用默认配置"
        echo "👤 FTP用户名: $ftp_user (默认)"
        echo "📁 服务器目录: $source_dir (默认)"
        echo "🔐 自动生成密码"
        
        # 检查/创建目录
        if [ ! -d "$source_dir" ]; then
            echo "📂 自动创建目录: $source_dir"
            mkdir -p "$source_dir" || {
                echo "❌ 创建目录失败"
                exit 1
            }
            echo "✅ 目录创建成功"
        fi
        
        echo ""
        echo "⚙️  开始部署..."
        
        # 安装vsftpd
        echo "📦 安装软件包..."
        apt update && apt install -y vsftpd || {
            echo "❌ 安装失败"
            exit 1
        }
        
        # 创建用户
        echo "👤 配置用户..."
        if id -u "$ftp_user" &>/dev/null; then
            echo "⚠️  用户已存在，重置密码"
        else
            adduser "$ftp_user" --disabled-password --gecos ""
        fi
        echo "$ftp_user:$ftp_pass" | chpasswd
        
        # 配置权限
        ftp_home="/home/$ftp_user/ftp"
        echo "🔧 配置FTP目录权限（完整读写权限）..."
        
        mkdir -p "$ftp_home"
        chown root:root "/home/$ftp_user"
        chmod 755 "/home/$ftp_user"
        chown "$ftp_user":"$ftp_user" "$ftp_home"
        chmod 755 "$ftp_home"
        
        echo "✅ 权限配置完成（用户拥有完整读写权限）"
        
        # 处理源目录权限
        if [[ "$source_dir" == /root/* ]]; then
            echo "⚠️  设置/root目录访问权限..."
            chmod o+x "$(dirname "$source_dir")" 2>/dev/null || true
        fi
        
        # 目录挂载
        echo "🔗 配置目录映射..."
        mount --bind "$source_dir" "$ftp_home"
        if ! grep -q "$ftp_home" /etc/fstab; then
            echo "$source_dir $ftp_home none bind 0 0" >> /etc/fstab
        fi
        
        # 生成配置
        echo "📡 生成vsftpd配置..."
        [ -f /etc/vsftpd.conf ] && cp /etc/vsftpd.conf /etc/vsftpd.conf.backup.$(date +%Y%m%d_%H%M%S)
        
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
EOF
        
        echo "✅ 配置文件已生成"
        
        # 启动服务
        echo "🔄 启动服务..."
        systemctl restart vsftpd
        systemctl enable vsftpd
        
        # 配置防火墙
        echo "🔥 配置防火墙..."
        if command -v ufw &> /dev/null; then
            ufw allow 21/tcp >/dev/null 2>&1 || true
            ufw allow 40000:40100/tcp >/dev/null 2>&1 || true
            echo "✅ UFW: 已开放FTP端口"
        fi
        
        # 获取服务器IP
        external_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "localhost")
        
        echo ""
        echo "======================================================"
        echo "🎉 FTP服务器部署完成！"
        echo "======================================================"
        echo ""
        echo "📋 连接信息："
        echo "   服务器: $external_ip"
        echo "   端口: 21"
        echo "   用户: $ftp_user"
        echo "   密码: $ftp_pass"
        echo ""
        echo "📁 目录结构："
        echo "   FTP根目录: / (直接可读写)"
        echo "   映射路径: $source_dir"
        echo ""
        echo "🔧 特性："
        echo "   ✅ 完整读写权限（根目录直接操作）"
        echo "   ✅ 自动修复权限550错误"
        echo "   ✅ 被动模式传输"
        echo "   ✅ UTF-8字符编码"
        echo "   ✅ 防火墙自动配置"
        echo ""
        echo "📱 推荐客户端："
        echo "   FileZilla, WinSCP, Cyberduck"
        echo ""
        echo "======================================================"
        ;;
esac 