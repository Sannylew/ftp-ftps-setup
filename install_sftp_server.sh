#!/bin/bash

# SFTP 服务器一键部署脚本
# 版本: 1.0

set -e  # 遇到错误立即退出

echo "======================================================"
echo "🔐 SFTP 服务器一键部署工具"
echo "======================================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
    echo "❌ 此脚本需要 root 权限，请使用 sudo 运行"
    exit 1
fi

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

echo "⚙️  开始配置 SFTP 服务器..."

# 用户输入配置
while true; do
    read -p "请输入要创建的 SFTP 用户名（默认: sftpuser，直接回车使用默认值）: " sftp_user
    sftp_user=${sftp_user:-sftpuser}  # 设置默认值
    if validate_username "$sftp_user"; then
        break
    fi
done

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
    sftp_pass=$(openssl rand -base64 12)
else
    while true; do
        read -s -p "请输入该用户的 SFTP 密码（至少8位）: " sftp_pass
        echo
        if [ ${#sftp_pass} -ge 8 ]; then
            read -s -p "请再次确认密码: " sftp_pass_confirm
            echo
            if [[ "$sftp_pass" == "$sftp_pass_confirm" ]]; then
                break
            else
                echo "❌ 两次输入的密码不一致，请重新输入"
            fi
        else
            echo "❌ 密码至少需要8个字符"
        fi
    done
fi

echo ""
echo "📦 安装 OpenSSH 服务器..."
apt update
apt install -y openssh-server

echo "👥 创建 SFTP 用户组..."
groupadd -f sftponly

echo "👤 创建 SFTP 用户..."
if id -u "$sftp_user" &>/dev/null; then
    echo "⚠️  用户 $sftp_user 已存在，将重置配置"
    usermod -g sftponly -s /bin/false "$sftp_user"
else
    useradd -g sftponly -s /bin/false -m "$sftp_user"
fi

echo "$sftp_user:$sftp_pass" | chpasswd

echo "📁 配置用户目录..."
sftp_home="/home/$sftp_user"
sftp_upload="$sftp_home/uploads"

# 设置目录权限
chown root:root "$sftp_home"
chmod 755 "$sftp_home"

# 创建上传目录
mkdir -p "$sftp_upload"
chown "$sftp_user:sftponly" "$sftp_upload"
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
chown "$sftp_user:sftponly" "$sftp_home/files"
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

# 获取服务器IP
external_ip=$(get_external_ip)

echo ""
echo "======================================================"
echo "🎉 SFTP 服务器安装完成！"
echo "======================================================"
echo ""
echo "📋 连接信息："
echo "   服务器地址: $external_ip"
echo "   端口: 22"
echo "   用户名: $sftp_user"
echo "   密码: $sftp_pass"
echo ""
echo "📁 目录结构："
echo "   /uploads/  - 专用上传目录（可读写）"
echo "   /files/    - 映射目录: $source_dir（可读写）"
echo ""
echo "🔧 客户端配置："
echo "   协议: SFTP (SSH File Transfer Protocol)"
echo "   主机: $external_ip"
echo "   端口: 22"
echo "   用户名: $sftp_user"
echo "   密码: $sftp_pass"
echo ""
echo "💡 推荐客户端："
echo "   - FileZilla (选择 SFTP 协议)"
echo "   - WinSCP (Windows)"
echo "   - Cyberduck (macOS)"
echo ""
echo "🔒 安全特性："
echo "   ✅ SSH 加密传输"
echo "   ✅ Chroot 隔离环境"
echo "   ✅ 禁用 Shell 访问"
echo "   ✅ 只允许文件传输"
echo ""
echo "======================================================" 