#!/bin/bash

# FTP/SFTP 服务器一键部署脚本
# 版本: 3.0

set -e  # 遇到错误立即退出

echo "======================================================"
echo "🚀 FTP/SFTP 服务器一键部署工具"
echo "======================================================"
echo ""

# 检查权限和系统
check_requirements() {
    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        echo "❌ 此脚本需要 root 权限，请使用 sudo 运行"
        exit 1
    fi
    
    # 检查系统支持
    if ! command -v apt &> /dev/null; then
        echo "❌ 此脚本专为 Ubuntu/Debian 系统设计"
        echo "💡 支持的系统：Ubuntu、Debian、Linux Mint、Elementary OS"
        echo ""
        read -p "是否仍要继续？(y/n): " continue_anyway
        if [[ "$continue_anyway" != "y" ]]; then
            exit 1
        fi
    fi
}

# 验证用户名
validate_username() {
    local username="$1"
    if [[ ! "$username" =~ ^[a-z][-a-z0-9]*$ ]] || [ ${#username} -gt 32 ]; then
        echo "❌ 用户名不合法！只能包含小写字母、数字和连字符，最多32字符"
        return 1
    fi
    return 0
}

# 获取外网IP
get_external_ip() {
    local ip=""
    ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null) || \
    ip=$(curl -s --max-time 5 ipinfo.io/ip 2>/dev/null) || \
    ip="无法获取外网IP"
    echo "$ip"
}

# 显示菜单
show_menu() {
    echo "请选择要部署的服务类型："
    echo ""
    echo "1️⃣  FTP 服务器 (标准文件传输)"
    echo "2️⃣  SFTP 服务器 (SSH文件传输) - 推荐"
    echo "3️⃣  退出"
    echo ""
    echo "======================================================"
}

# 用户输入配置
get_user_config() {
    # 用户名输入和验证
    while true; do
        read -p "请输入要创建的用户名（默认: ftpuser，直接回车使用默认值）: " ftp_user
        ftp_user=${ftp_user:-ftpuser}  # 设置默认值
        if validate_username "$ftp_user"; then
            break
        fi
    done

    # 目录设置
    read -p "请输入要映射的服务器目录（默认: /root/brec/file，直接回车使用默认值）: " source_dir
    source_dir=${source_dir:-/root/brec/file}

    if [ ! -d "$source_dir" ]; then
        echo "❌ 路径不存在：$source_dir"
        read -p "是否创建该目录？(默认: y，直接回车使用默认值) [y/n]: " create_dir
        create_dir=${create_dir:-y}  # 设置默认值为y
        if [[ "$create_dir" == "y" ]]; then
            mkdir -p "$source_dir" || {
                echo "❌ 创建目录失败"
                exit 1
            }
            echo "✅ 目录创建成功：$source_dir"
        else
            exit 1
        fi
    fi

    # 密码设置
    read -p "是否自动生成密码？(默认: y，直接回车使用默认值) [y/n]: " auto_pwd
    auto_pwd=${auto_pwd:-y}  # 设置默认值为y
    if [[ "$auto_pwd" == "y" ]]; then
        ftp_pass=$(openssl rand -base64 12)
    else
        while true; do
            read -s -p "请输入该用户的密码（至少8位）: " ftp_pass
            echo
            if [ ${#ftp_pass} -ge 8 ]; then
                read -s -p "请再次确认密码: " ftp_pass_confirm
                echo
                if [[ "$ftp_pass" == "$ftp_pass_confirm" ]]; then
                    break
                else
                    echo "❌ 两次输入的密码不一致，请重新输入"
                fi
            else
                echo "❌ 密码至少需要8个字符"
            fi
        done
    fi
}

# 通用配置（仅用于FTP）
setup_common() {
    echo ""
    echo "⚙️  开始配置基础环境..."
    
    # 创建或更新用户
    if id -u "$ftp_user" &>/dev/null; then
        echo "⚠️  用户 $ftp_user 已存在，将重置密码"
    else
        echo "📝 创建新用户：$ftp_user"
        adduser "$ftp_user" --disabled-password --gecos "" || {
            echo "❌ 创建用户失败"
            exit 1
        }
    fi
    
    echo "$ftp_user:$ftp_pass" | chpasswd || {
        echo "❌ 设置密码失败"
        exit 1
    }

    # 配置目录
    ftp_home="/home/$ftp_user/ftp"
    mkdir -p "$ftp_home/file"
    chown root:root "/home/$ftp_user"
    chmod 755 "/home/$ftp_user"
    chown "$ftp_user:$ftp_user" "$ftp_home"
    chmod 755 "$ftp_home"

    # 安全的权限设置
    if [[ "$source_dir" == /root/* ]]; then
        echo "⚠️  设置访问权限..."
        chmod o+x "$(dirname "$source_dir")" 2>/dev/null || true
    fi

    # 目录挂载
    echo "🔗 配置目录映射..."
    mount --bind "$source_dir" "$ftp_home/file" || {
        echo "❌ 目录挂载失败"
        exit 1
    }
    
    if ! grep -q "$ftp_home/file" /etc/fstab; then
        echo "$source_dir $ftp_home/file none bind 0 0" >> /etc/fstab
        echo "✅ 已添加到 /etc/fstab，重启后自动挂载"
    fi
}

# 配置FTP
setup_ftp() {
    echo "📦 安装软件包..."
    apt update || {
        echo "❌ 更新软件包列表失败"
        exit 1
    }
    
    apt install -y vsftpd || {
        echo "❌ 安装 vsftpd 失败"
        exit 1
    }

    echo "📡 配置 FTP 服务器..."
    
    # 备份原配置
    [ -f /etc/vsftpd.conf ] && cp /etc/vsftpd.conf /etc/vsftpd.conf.backup.$(date +%Y%m%d_%H%M%S)

    # 生成配置
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
EOF

    # 启动服务
    systemctl restart vsftpd && systemctl enable vsftpd || {
        echo "❌ 启动 vsftpd 服务失败"
        exit 1
    }

    echo ""
    echo "🎉 FTP 部署成功！"
    echo "🌐 IP: $(get_external_ip)"
    echo "👤 用户名: $ftp_user"
    echo "🔑 密码: $ftp_pass"
    echo "📁 映射路径: $source_dir → /file"
    echo "📡 端口: 21"
    echo "✅ 推荐使用 FileZilla 被动模式连接"
}

# 配置SFTP
setup_sftp() {
    echo "🔐 配置 SFTP 服务器（SSH文件传输）..."
    
    echo "📦 安装 OpenSSH 服务器..."
    apt update
    apt install -y openssh-server
    
    echo "👥 创建 SFTP 用户组..."
    groupadd -f sftponly
    
    echo "👤 配置 SFTP 用户..."
    if id -u "$ftp_user" &>/dev/null; then
        echo "⚠️  用户 $ftp_user 已存在，将重置配置"
        usermod -g sftponly -s /bin/false "$ftp_user"
    else
        useradd -g sftponly -s /bin/false -m "$ftp_user"
    fi
    
    echo "$ftp_user:$ftp_pass" | chpasswd
    
    echo "📁 配置用户目录..."
    sftp_home="/home/$ftp_user"
    sftp_upload="$sftp_home/uploads"
    
    # 设置目录权限
    chown root:root "$sftp_home"
    chmod 755 "$sftp_home"
    
    # 创建上传目录
    mkdir -p "$sftp_upload"
    chown "$ftp_user:sftponly" "$sftp_upload"
    chmod 755 "$sftp_upload"
    
    # 设置源目录访问权限
    if [[ "$source_dir" == /root/* ]]; then
        echo "⚠️  设置源目录访问权限..."
        chmod o+x "$(dirname "$source_dir")" 2>/dev/null || true
        # 确保源目录对用户组有读写权限
        chgrp sftponly "$source_dir" 2>/dev/null || true
        chmod g+rwx "$source_dir" 2>/dev/null || true
    fi
    
    # 创建文件目录并挂载
    mkdir -p "$sftp_home/files"
    mount --bind "$source_dir" "$sftp_home/files"
    
    # 设置files目录权限 - 确保可读写
    chown "$ftp_user:sftponly" "$sftp_home/files"
    chmod 755 "$sftp_home/files"  # 确保目录可读写执行
    
    # 如果源目录权限设置成功，files目录继承读写权限
    echo "✅ 已配置 /files/ 目录为可读写权限"
    
    echo "🔗 配置自动挂载..."
    if ! grep -q "$sftp_home/files" /etc/fstab; then
        echo "$source_dir $sftp_home/files none bind 0 0" >> /etc/fstab
    fi
    
    echo "🔧 配置 SSH 服务..."
    # 备份原配置
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
    
    # 检查并添加SFTP配置
    if ! grep -q "Match Group sftponly" /etc/ssh/sshd_config; then
        cat >> /etc/ssh/sshd_config <<EOF

# SFTP Configuration
Match Group sftponly
    ChrootDirectory %h
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
    PasswordAuthentication yes
EOF
    fi
    
    echo "🔄 重启 SSH 服务..."
    systemctl restart ssh
    systemctl enable ssh
    
    # 配置防火墙
    if command -v ufw &> /dev/null; then
        echo "🔥 配置防火墙..."
        ufw allow ssh
        ufw --force enable
    fi
    
    echo ""
    echo "🎉 SFTP 部署成功（SSH 加密传输）"
    echo "🌐 IP: $(get_external_ip)"
    echo "👤 用户名: $ftp_user"
    echo "🔑 密码: $ftp_pass"
    echo "📁 目录结构："
    echo "   /uploads/  - 专用上传目录（可读写）"
    echo "   /files/    - 映射目录: $source_dir（可读写）"
    echo "📡 端口: 22"
    echo "✅ 请使用 FileZilla 选择 SFTP 协议连接"
}

# 主程序
main() {
    check_requirements
    
    while true; do
        show_menu
        read -p "请输入选项 (默认: 2=SFTP，直接回车使用默认值) [1-3]: " choice
        choice=${choice:-2}  # 设置默认值为2（SFTP）

        case $choice in
            1)
                echo ""
                echo "📡 您选择了 FTP 服务器部署"
                get_user_config
                setup_common
                setup_ftp
                break
                ;;
            2)
                echo ""
                echo "🔐 您选择了 SFTP 服务器部署（推荐）"
                get_user_config
                setup_sftp
                break
                ;;
            3)
                echo ""
                echo "👋 退出安装程序"
                exit 0
                ;;
            *)
                echo ""
                echo "❌ 无效选项，请输入 1、2 或 3"
                echo ""
                ;;
        esac
    done

    echo ""
    echo "🎊 部署完成！感谢使用 FTP/SFTP 一键部署工具"
    echo "📖 更多信息请访问: https://github.com/Sannylew/ftp-ftps-setup"
}

# 运行主程序
main 