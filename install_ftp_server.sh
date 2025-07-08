#!/bin/bash

# FTP 服务器一键部署脚本
# 版本: 2.0

set -e  # 遇到错误立即退出

echo "======================================================"
echo "📡 FTP 服务器一键部署工具"
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

# ========= 用户输入 =========
while true; do
    read -p "请输入要创建的 FTP 用户名（默认: ftpuser，直接回车使用默认值）: " ftp_user
    ftp_user=${ftp_user:-ftpuser}  # 设置默认值
    if validate_username "$ftp_user"; then
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

read -p "是否自动生成密码？(默认: y，直接回车使用默认值) [y/n]: " auto_pwd
auto_pwd=${auto_pwd:-y}  # 设置默认值为y
if [[ "$auto_pwd" == "y" ]]; then
    ftp_pass=$(openssl rand -base64 12)
else
    while true; do
        read -s -p "请输入该用户的 FTP 密码（至少8位）: " ftp_pass
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

echo ""
echo "⚙️  开始配置 FTP 服务器..."

# ========= 安装 vsftpd =========
echo "📦 安装软件包..."
apt update && apt install -y vsftpd

# ========= 创建用户 =========
echo "👤 创建 FTP 用户..."
if id -u "$ftp_user" &>/dev/null; then
    echo "⚠️  用户 $ftp_user 已存在，将重置密码"
else
    adduser "$ftp_user" --disabled-password --gecos ""
fi
echo "$ftp_user:$ftp_pass" | chpasswd

# ========= 配置目录 =========
echo "📁 配置用户目录..."
ftp_home="/home/$ftp_user/ftp"
mkdir -p "$ftp_home/file"
chown root:root "/home/$ftp_user"
chmod 755 "/home/$ftp_user"
chown "$ftp_user:$ftp_user" "$ftp_home"
chmod 755 "$ftp_home"

# ========= 授权访问 =========
echo "⚠️  设置访问权限..."
if [[ "$source_dir" == /root/* ]]; then
    chmod o+x "$(dirname "$source_dir")" 2>/dev/null || true
fi

# ========= 挂载 & fstab =========
echo "🔗 配置目录映射..."
mount --bind "$source_dir" "$ftp_home/file"
if ! grep -q "$ftp_home/file" /etc/fstab; then
    echo "$source_dir $ftp_home/file none bind 0 0" >> /etc/fstab
    echo "✅ 已添加到 /etc/fstab，重启后自动挂载"
fi

# ========= 配置 vsftpd =========
echo "📡 配置 FTP 服务器..."
# 备份原配置
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
EOF

echo "🔄 启动 FTP 服务..."
systemctl restart vsftpd
systemctl enable vsftpd

# 获取外网IP
external_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "无法获取外网IP")

echo ""
echo "======================================================"
echo "🎉 FTP 服务器安装完成！"
echo "======================================================"
echo ""
echo "📋 连接信息："
echo "   服务器地址: $external_ip"
echo "   端口: 21"
echo "   用户名: $ftp_user"
echo "   密码: $ftp_pass"
echo ""
echo "📁 映射路径: $source_dir → /file"
echo "📡 数据端口: 40000-40100"
echo "✅ 推荐使用 FileZilla 被动模式连接"
echo ""
echo "======================================================" 