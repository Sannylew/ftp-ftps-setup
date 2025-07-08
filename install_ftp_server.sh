#!/bin/bash

# ========= 用户输入 =========
read -p "请输入要创建的 FTP 用户名（例如 sunny）: " ftp_user
read -p "请输入要映射的服务器目录（默认 /root/brec/file）: " source_dir
source_dir=${source_dir:-/root/brec/file}

if [ ! -d "$source_dir" ]; then
    echo "❌ 路径不存在：$source_dir"
    exit 1
fi

read -p "是否自动生成密码？(y/n): " auto_pwd
if [[ "$auto_pwd" == "y" ]]; then
    ftp_pass=$(openssl rand -base64 12)
else
    read -s -p "请输入该用户的 FTP 密码: " ftp_pass
    echo
fi

# ========= 安装 vsftpd =========
apt update && apt install -y vsftpd

# ========= 创建用户 =========
id -u "$ftp_user" &>/dev/null || adduser "$ftp_user" --disabled-password --gecos ""
echo "$ftp_user:$ftp_pass" | chpasswd

# ========= 配置目录 =========
ftp_home="/home/$ftp_user/ftp"
mkdir -p "$ftp_home/file"
chown root:root "/home/$ftp_user"
chmod 755 "/home/$ftp_user"
chown "$ftp_user:$ftp_user" "$ftp_home"
chmod 755 "$ftp_home"

# ========= 授权访问 =========
chmod o+x /root
chmod o+x "$(dirname "$source_dir")"

# ========= 挂载 & fstab =========
mount --bind "$source_dir" "$ftp_home/file"
grep -q "$ftp_home/file" /etc/fstab || echo "$source_dir $ftp_home/file none bind 0 0" >> /etc/fstab

# ========= 配置 vsftpd =========
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

systemctl restart vsftpd
systemctl enable vsftpd

echo
echo "🎉 FTP 部署成功！"
echo "🌐 IP: $(curl -s ifconfig.me)"
echo "👤 用户名: $ftp_user"
echo "🔑 密码: $ftp_pass"
echo "📁 映射路径: $source_dir → /file"
echo "✅ 推荐使用 FileZilla 被动模式连接端口 21" 