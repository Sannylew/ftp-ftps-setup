#!/bin/bash

# FTP 服务器管理工具 - 交互式安装/卸载脚本
# 版本: 1.0

set -e

echo "======================================================"
echo "📡 FTP 服务器管理工具"
echo "======================================================"
echo ""

# 检测执行方式
if [ -p /dev/stdin ]; then
    echo "🔍 检测到curl管道执行"
    echo "💡 为了支持完整交互功能，正在下载脚本到本地..."
    
    # 下载脚本到临时文件
    TEMP_SCRIPT=$(mktemp /tmp/ftp_manager_XXXXXX.sh)
    
    # 设置清理函数
    cleanup() {
        [ -f "$TEMP_SCRIPT" ] && rm -f "$TEMP_SCRIPT"
    }
    trap cleanup EXIT
    
    # 下载脚本
    if curl -fsSL https://raw.githubusercontent.com/Sannylew/ftp-ftps-setup/main/ftp_manager.sh > "$TEMP_SCRIPT"; then
        chmod +x "$TEMP_SCRIPT"
        echo "✅ 脚本已下载，启动交互式模式..."
        echo ""
        
        # 重新执行脚本，这次不是管道模式
        exec "$TEMP_SCRIPT"
    else
        echo "❌ 下载失败，请检查网络连接"
        exit 1
    fi
    exit 0
fi

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

# 现在可以正常交互了
read -p "请输入选项 (0-3): " choice

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
            
            # 如果源目录在/root下，需要特殊处理
            if [[ "$source_dir" == /root/* ]]; then
                echo "⚠️  检测到root目录，设置访问权限..."
                # 设置父目录可执行权限
                chmod o+x /root 2>/dev/null || true
                dirname_path=$(dirname "$source_dir")
                while [ "$dirname_path" != "/" ] && [ "$dirname_path" != "/root" ]; do
                    chmod o+x "$dirname_path" 2>/dev/null || true
                    dirname_path=$(dirname "$dirname_path")
                done
            fi
            
            # 设置FTP挂载点权限（挂载前）
            chown "$user":"$user" "$ftp_home"
            chmod 755 "$ftp_home"
            
            echo "✅ 权限配置完成（用户拥有完整读写删除权限）"
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
# 明确启用删除和重命名权限
delete_enable=YES
rename_enable=YES
rmdir_enable=YES
# 文件权限设置
file_open_mode=0755
local_umask=022
# 禁用一些限制
deny_file={}
hide_file={}
EOF

            echo "✅ 配置文件已生成"
        }

        # 用户输入
        echo "📝 配置FTP服务器..."
        
        while true; do
            read -p "FTP用户名（默认: ftpuser）: " ftp_user
            ftp_user=${ftp_user:-ftpuser}
            if validate_username "$ftp_user"; then
                break
            fi
        done

        read -p "服务器目录（默认: /root/brec/file）: " source_dir
        source_dir=${source_dir:-/root/brec/file}

        if [ ! -d "$source_dir" ]; then
            read -p "目录不存在，是否创建？(y/n，默认: y): " create_dir
            create_dir=${create_dir:-y}
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

        read -p "自动生成密码？(y/n，默认: y): " auto_pwd
        auto_pwd=${auto_pwd:-y}

        if [[ "$auto_pwd" == "y" ]]; then
            ftp_pass=$(openssl rand -base64 12)
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
        configure_smart_permissions "$ftp_user" "$source_dir"

        # 目录挂载
        echo "🔗 配置目录映射..."
        mount --bind "$source_dir" "$ftp_home"
        if ! grep -q "$ftp_home" /etc/fstab; then
            echo "$source_dir $ftp_home none bind 0 0" >> /etc/fstab
        fi
        
        # 挂载后权限验证和修复
        echo "🔧 验证挂载后权限..."
        
        # 确保挂载后的目录权限正确
        chown "$ftp_user":"$ftp_user" "$ftp_home" 2>/dev/null || true
        
        # 检查并修复挂载目录中的文件权限
        if [ -d "$ftp_home" ]; then
            find "$ftp_home" -type f -exec chown "$ftp_user":"$ftp_user" {} \; 2>/dev/null || true
            find "$ftp_home" -type d -exec chown "$ftp_user":"$ftp_user" {} \; 2>/dev/null || true
            find "$ftp_home" -type f -exec chmod 644 {} \; 2>/dev/null || true
            find "$ftp_home" -type d -exec chmod 755 {} \; 2>/dev/null || true
        fi
        
        echo "✅ 权限验证完成"

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
        echo "   FTP根目录: / (直接可读写删除)"
        echo "   映射路径: $source_dir"
        echo ""
        echo "🔧 特性："
        echo "   ✅ 完整读写删除权限（已修复550错误）"
        echo "   ✅ 支持文件删除、重命名、创建目录"
        echo "   ✅ 自动修复权限550错误"
        echo "   ✅ 被动模式传输"
        echo "   ✅ UTF-8字符编码"
        echo "   ✅ 防火墙自动配置"
        echo ""
        echo "📱 推荐客户端："
        echo "   FileZilla, WinSCP, Cyberduck, Alist"
        echo ""
        echo "🔍 测试建议："
        echo "   连接后尝试上传、下载、删除文件验证权限"
        echo "   如仍遇到550错误，请运行状态检查功能"
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
        read -p "确认卸载FTP服务器？(y/n): " confirm
        
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
                        
                        # 检查权限问题
                        if [[ "$dir_perms" =~ $user.*$user ]]; then
                            echo "   权限状态: ✅ 正常"
                        else
                            echo "   权限状态: ⚠️  可能有问题"
                        fi
                    fi
                    
                    # 显示挂载信息
                    if mountpoint -q "/home/$user/ftp" 2>/dev/null; then
                        echo "   挂载状态: ✅ 已挂载"
                        # 显示挂载源
                        mount_source=$(mount | grep "/home/$user/ftp" | awk '{print $1}')
                        if [ -n "$mount_source" ]; then
                            echo "   映射源: $mount_source"
                            
                            # 检查源目录权限
                            if [ -d "$mount_source" ]; then
                                source_perms=$(ls -ld "$mount_source" | awk '{print $1, $3, $4}')
                                echo "   源目录权限: $source_perms"
                                if [[ "$source_perms" =~ $user.*$user ]]; then
                                    echo "   源权限状态: ✅ 正常"
                                else
                                    echo "   源权限状态: ⚠️  权限问题 - 可能导致550错误"
                                fi
                            fi
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
            echo ""
            echo "🔧 如果遇到550权限错误，请运行以下命令修复："
            echo "   sudo $0  # 重新运行脚本，选择安装选项会自动修复权限"
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
            
            if grep -q "delete_enable=YES" /etc/vsftpd.conf; then
                echo "✅ 已启用删除权限"
            else
                echo "⚠️  删除权限可能未启用"
            fi
            
            # 显示关键配置
            echo "📋 关键配置:"
            grep -E "^(local_root|pasv_min_port|pasv_max_port|chroot_local_user|delete_enable|write_enable)" /etc/vsftpd.conf 2>/dev/null | while read line; do
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
        echo "❌ 无效选项: $choice"
        echo "💡 请重新运行脚本并选择有效选项 (0-3)"
        exit 1
        ;;
esac 