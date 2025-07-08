#!/bin/bash

# FTP/FTPS 服务器一键部署脚本 - 优化版
# 作者: Sannylew
# 版本: 2.0

set -e  # 遇到错误立即退出

echo "======================================================"
echo "🚀 FTP/FTPS 服务器一键部署工具"
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
    echo "2️⃣  FTPS 服务器 (TLS加密传输) - 推荐"
    echo "3️⃣  退出"
    echo ""
    echo "======================================================"
}

# 用户输入配置
get_user_config() {
    # 用户名输入和验证
    while true; do
        read -p "请输入要创建的 FTP 用户名（例如 sunny）: " ftp_user
        if validate_username "$ftp_user"; then
            break
        fi
    done

    # 目录设置
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

    # 密码设置
    read -p "是否自动生成密码？(y/n): " auto_pwd
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
}

# 通用配置
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

# 安装软件包
install_packages() {
    local install_ssl="$1"
    
    echo "📦 安装软件包..."
    apt update || {
        echo "❌ 更新软件包列表失败"
        exit 1
    }
    
    if [[ "$install_ssl" == "yes" ]]; then
        apt install -y vsftpd openssl || {
            echo "❌ 安装软件包失败"
            exit 1
        }
    else
        apt install -y vsftpd || {
            echo "❌ 安装 vsftpd 失败"
            exit 1
        }
    fi
}

# 配置FTP
setup_ftp() {
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
    echo "✅ 推荐使用 FileZilla 被动模式连接端口 21"
}

# 配置FTPS
setup_ftps() {
    echo "🔒 配置 FTPS 服务器（TLS加密）..."
    
    # 生成TLS证书
    echo "🔐 生成 TLS 证书..."
    mkdir -p /etc/ssl/private
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /etc/ssl/private/vsftpd.key \
      -out /etc/ssl/private/vsftpd.crt \
      -subj "/C=CN/ST=Example/L=FTPServer/O=MyOrg/OU=IT/CN=$(hostname)" || {
        echo "❌ 生成TLS证书失败"
        exit 1
    }

    chmod 600 /etc/ssl/private/vsftpd.key
    chmod 644 /etc/ssl/private/vsftpd.crt

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
    systemctl restart vsftpd && systemctl enable vsftpd || {
        echo "❌ 启动 vsftpd 服务失败"
        exit 1
    }

    echo ""
    echo "🎉 FTPS 部署成功（TLS 加密已启用）"
    echo "🌐 IP: $(get_external_ip)"
    echo "👤 用户名: $ftp_user"
    echo "🔑 密码: $ftp_pass"
    echo "📁 映射路径: $source_dir → /file"
    echo "🔒 证书有效期: 365天"
    echo "✅ 请使用 FileZilla 连接方式：[FTP over TLS - 显式加密]"
}

# 主程序
main() {
    check_requirements
    
    while true; do
        show_menu
        read -p "请输入选项 (1-3): " choice

        case $choice in
            1)
                echo ""
                echo "📡 您选择了 FTP 服务器部署"
                get_user_config
                install_packages "no"
                setup_common
                setup_ftp
                break
                ;;
            2)
                echo ""
                echo "🔒 您选择了 FTPS 服务器部署（推荐）"
                get_user_config
                install_packages "yes"
                setup_common
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