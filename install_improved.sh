#!/bin/bash

# FTP/FTPS 服务器一键部署脚本（改进版）
# 作者: Sannylew
# 版本: 1.1

set -e  # 遇到错误立即退出

echo "======================================================"
echo "🚀 FTP/FTPS 服务器一键部署工具（改进版）"
echo "======================================================"
echo ""

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ 此脚本需要 root 权限，请使用 sudo 运行"
        exit 1
    fi
}

# 验证用户名合法性
validate_username() {
    local username="$1"
    if [[ ! "$username" =~ ^[a-z][-a-z0-9]*$ ]]; then
        echo "❌ 用户名不合法！用户名只能包含小写字母、数字和连字符，且必须以字母开头"
        return 1
    fi
    if [ ${#username} -gt 32 ]; then
        echo "❌ 用户名过长！最多32个字符"
        return 1
    fi
    return 0
}

# 验证密码强度
validate_password() {
    local password="$1"
    if [ ${#password} -lt 8 ]; then
        echo "❌ 密码至少需要8个字符"
        return 1
    fi
    return 0
}

# 获取外网IP
get_external_ip() {
    local ip=""
    # 尝试多个服务获取IP
    ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null) || \
    ip=$(curl -s --max-time 5 ipinfo.io/ip 2>/dev/null) || \
    ip=$(curl -s --max-time 5 api.ipify.org 2>/dev/null) || \
    ip="无法获取外网IP"
    echo "$ip"
}

# 检查端口是否被占用
check_port() {
    local port="$1"
    if ss -tuln | grep -q ":$port "; then
        echo "⚠️  警告：端口 $port 已被占用"
        return 1
    fi
    return 0
}

# 检查服务状态
check_service_status() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        echo "✅ $service 服务运行正常"
        return 0
    else
        echo "❌ $service 服务启动失败"
        return 1
    fi
}

# 显示菜单
show_menu() {
    echo "请选择要部署的服务类型："
    echo ""
    echo "1️⃣  FTP 服务器 (标准文件传输)"
    echo "2️⃣  FTPS 服务器 (TLS加密传输) - 推荐"
    echo "3️⃣  退出"
    echo ""
    echo "======================================================"
}

# 通用用户输入函数
get_user_input() {
    while true; do
        read -p "请输入要创建的 FTP 用户名（例如 sunny）: " ftp_user
        if validate_username "$ftp_user"; then
            break
        fi
    done

    read -p "请输入要映射的服务器目录（默认 /root/brec/file）: " source_dir
    source_dir=${source_dir:-/root/brec/file}

    if [ ! -d "$source_dir" ]; then
        echo "❌ 路径不存在：$source_dir"
        read -p "是否创建该目录？(y/n): " create_dir
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

    read -p "是否自动生成密码？(y/n): " auto_pwd
    if [[ "$auto_pwd" == "y" ]]; then
        ftp_pass=$(openssl rand -base64 12)
    else
        while true; do
            read -s -p "请输入该用户的 FTP 密码: " ftp_pass
            echo
            if validate_password "$ftp_pass"; then
                read -s -p "请再次确认密码: " ftp_pass_confirm
                echo
                if [[ "$ftp_pass" == "$ftp_pass_confirm" ]]; then
                    break
                else
                    echo "❌ 两次输入的密码不一致，请重新输入"
                fi
            fi
        done
    fi
}

# 通用配置函数
common_setup() {
    echo ""
    echo "⚙️  开始配置基础环境..."
    
    # 检查用户是否已存在
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
    mkdir -p "$ftp_home/file" || {
        echo "❌ 创建FTP目录失败"
        exit 1
    }
    
    chown root:root "/home/$ftp_user"
    chmod 755 "/home/$ftp_user"
    chown "$ftp_user:$ftp_user" "$ftp_home"
    chmod 755 "$ftp_home"

    # 更安全的权限设置 - 避免直接开放/root权限
    if [[ "$source_dir" == /root/* ]]; then
        echo "⚠️  检测到要映射/root下的目录，正在设置必要的访问权限..."
        # 只给特定路径设置权限，而不是整个/root
        chmod o+x "$(dirname "$source_dir")" 2>/dev/null || true
    fi
    chmod o+x "$(dirname "$source_dir")" 2>/dev/null || true

    # 挂载 & fstab
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

# FTP服务器配置
setup_ftp() {
    echo ""
    echo "📡 开始部署 FTP 服务器..."
    
    # 检查端口
    check_port 21 || echo "⚠️  端口21被占用，可能影响FTP服务"
    
    # 安装 vsftpd
    echo "📦 安装 vsftpd..."
    apt update || {
        echo "❌ 更新软件包列表失败"
        exit 1
    }
    apt install -y vsftpd || {
        echo "❌ 安装 vsftpd 失败"
        exit 1
    }

    # 备份原配置
    if [ -f /etc/vsftpd.conf ]; then
        cp /etc/vsftpd.conf /etc/vsftpd.conf.backup.$(date +%Y%m%d_%H%M%S)
    fi

    # 配置 vsftpd
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
    echo "🚀 启动 FTP 服务..."
    systemctl restart vsftpd || {
        echo "❌ 启动 vsftpd 服务失败"
        exit 1
    }
    systemctl enable vsftpd

    # 检查服务状态
    if check_service_status vsftpd; then
        echo ""
        echo "🎉 FTP 部署成功！"
        echo "🌐 IP: $(get_external_ip)"
        echo "👤 用户名: $ftp_user"
        echo "🔑 密码: $ftp_pass"
        echo "📁 映射路径: $source_dir → /file"
        echo "✅ 推荐使用 FileZilla 被动模式连接端口 21"
        echo ""
        echo "🔥 防火墙提醒：请确保开放端口 21 和 40000-40100"
    else
        exit 1
    fi
}

# FTPS服务器配置
setup_ftps() {
    echo ""
    echo "🔒 开始部署 FTPS 服务器（TLS加密）..."
    
    # 检查端口
    check_port 21 || echo "⚠️  端口21被占用，可能影响FTPS服务"
    
    # 安装 vsftpd + openssl
    echo "📦 安装 vsftpd 和 openssl..."
    apt update || {
        echo "❌ 更新软件包列表失败"
        exit 1
    }
    apt install -y vsftpd openssl || {
        echo "❌ 安装软件包失败"
        exit 1
    }

    # 生成 TLS 证书
    echo "🔐 生成 TLS 证书..."
    mkdir -p /etc/ssl/private
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /etc/ssl/private/vsftpd.key \
      -out /etc/ssl/private/vsftpd.crt \
      -subj "/C=CN/ST=Example/L=FTPServer/O=MyOrg/OU=IT/CN=$(hostname)" || {
        echo "❌ 生成TLS证书失败"
        exit 1
    }

    # 设置证书权限
    chmod 600 /etc/ssl/private/vsftpd.key
    chmod 644 /etc/ssl/private/vsftpd.crt

    # 备份原配置
    if [ -f /etc/vsftpd.conf ]; then
        cp /etc/vsftpd.conf /etc/vsftpd.conf.backup.$(date +%Y%m%d_%H%M%S)
    fi

    # 配置 vsftpd 启用 TLS
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

    # 启动服务
    echo "🚀 启动 FTPS 服务..."
    systemctl restart vsftpd || {
        echo "❌ 启动 vsftpd 服务失败"
        exit 1
    }
    systemctl enable vsftpd

    # 检查服务状态
    if check_service_status vsftpd; then
        echo ""
        echo "🎉 FTPS 部署成功（TLS 加密已启用）"
        echo "🌐 IP: $(get_external_ip)"
        echo "👤 用户名: $ftp_user"
        echo "🔑 密码: $ftp_pass"
        echo "📁 映射路径: $source_dir → /file"
        echo "🔒 证书有效期: 365天"
        echo "✅ 请使用 FileZilla 连接方式：[FTP over TLS - 显式加密]"
        echo ""
        echo "🔥 防火墙提醒：请确保开放端口 21 和 40000-40100"
    else
        exit 1
    fi
}

# 主程序
main() {
    # 检查权限
    check_root

    while true; do
        show_menu
        read -p "请输入选项 (1-3): " choice

        case $choice in
            1)
                echo ""
                echo "📡 您选择了 FTP 服务器部署"
                get_user_input
                common_setup
                setup_ftp
                break
                ;;
            2)
                echo ""
                echo "🔒 您选择了 FTPS 服务器部署（推荐）"
                get_user_input
                common_setup
                setup_ftps
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
    echo "🎊 部署完成！感谢使用 FTP/FTPS 一键部署工具"
    echo "📖 更多信息请访问: https://github.com/Sannylew/ftp-ftps-setup"
}

# 运行主程序
main 