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

# ========= 安装 vsftpd + openssl =========
apt update && apt install -y vsftpd openssl

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

# ========= 生成 TLS 证书 =========
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/vsftpd.key \
  -out /etc/ssl/private/vsftpd.crt \
  -subj "/C=CN/ST=Example/L=FTPServer/O=MyOrg/OU=IT/CN=$(hostname)"

# ========= 配置 vsftpd 启用 TLS =========
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
ssl_enable=YES
rsa_cert_file=/etc/ssl/private/vsftpd.crt
rsa_private_key_file=/etc/ssl/private/vsftpd.key
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
pam_service_name=vsftpd
seccomp_sandbox=NO
EOF

systemctl restart vsftpd
systemctl enable vsftpd

echo
echo "🎉 FTPS 部署成功（TLS 加密已启用）"
echo "🌐 IP: $(curl -s ifconfig.me)"
echo "👤 用户名: $ftp_user"
echo "🔑 密码: $ftp_pass"
echo "📁 映射路径: $source_dir → /file"
echo "✅ 请使用 FileZilla 连接方式：[FTP over TLS - 显式加密]" 