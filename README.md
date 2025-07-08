> **⚠️ 本仓库仅供个人调试使用**

# FTP/SFTP 服务器一键部署脚本

🚀 **快速部署FTP和SFTP服务器的自动化脚本**

## 📝 简介

本项目提供高效的自动化脚本，帮助你快速在Linux服务器上部署文件传输服务：

- **FTP服务器** - 标准文件传输协议
- **SFTP服务器** - 基于SSH的安全文件传输协议（推荐）

## 📁 文件说明

| 文件名 | 描述 |
|--------|------|
| `install_auto.sh` | **推荐** 二合一部署工具，支持FTP/SFTP选择 |
| `install_sftp_server.sh` | SFTP服务器单独部署脚本 |
| `install_ftp_server.sh` | FTP服务器单独部署脚本 |

## ⚡ 快速开始

### 🔥 方法一：一键部署（推荐）

```bash
wget https://raw.githubusercontent.com/Sannylew/ftp-ftps-setup/main/install_auto.sh
chmod +x install_auto.sh
sudo ./install_auto.sh
```

### 📡 方法二：单独部署

```bash
# SFTP部署（推荐）
wget https://raw.githubusercontent.com/Sannylew/ftp-ftps-setup/main/install_sftp_server.sh
chmod +x install_sftp_server.sh
sudo ./install_sftp_server.sh

# FTP部署
wget https://raw.githubusercontent.com/Sannylew/ftp-ftps-setup/main/install_ftp_server.sh
chmod +x install_ftp_server.sh
sudo ./install_ftp_server.sh
```

## 🔧 功能特性

### 脚本特色
- ✅ 支持FTP/SFTP两种协议
- ✅ 完善的错误处理和权限检查
- ✅ 自动创建用户和目录
- ✅ 配置文件自动备份
- ✅ 交互式配置界面

### SFTP服务器（推荐）
- ✅ SSH加密传输，安全性高
- ✅ 只需要22端口，防火墙配置简单
- ✅ Chroot隔离环境
- ✅ 禁用Shell访问，只允许文件传输

### FTP服务器
- ✅ 兼容性好，支持各种客户端
- ✅ 被动模式传输
- ✅ 用户隔离环境
- ✅ 支持目录映射

## 📋 使用说明

运行脚本后按提示操作，**支持直接按回车使用默认值**：

1. **选择协议**：默认选择 SFTP（推荐），直接回车即可
2. **输入用户名**：默认 `ftpuser`（FTP）或 `sftpuser`（SFTP）
3. **设置目录**：默认 `/root/brec/file`
4. **创建目录**：默认自动创建不存在的目录
5. **设置密码**：默认自动生成安全密码

### 快速部署示例

```bash
# 下载脚本
wget https://raw.githubusercontent.com/Sannylew/ftp-ftps-setup/main/install_auto.sh
sudo bash install_auto.sh

# 全程按回车使用默认值，即可完成SFTP部署：
# - 协议：SFTP
# - 用户名：sftpuser  
# - 目录：/root/brec/file
# - 密码：自动生成
```

## 🌐 客户端连接

### SFTP连接（推荐）
- **协议**：SFTP
- **端口**：22
- **优势**：安全加密，只需一个端口
- **目录结构**：
  - `/uploads/` - 专用上传目录（可读写）
  - `/files/` - 映射服务器目录（可读写）

### FTP连接
- **协议**：FTP
- **端口**：21（数据端口：40000-40100）
- **模式**：被动模式

### 推荐客户端
- **FileZilla** - 跨平台，支持FTP/SFTP
- **WinSCP** - Windows平台
- **Cyberduck** - macOS平台

## 🛠️ 系统要求

- **操作系统**：Ubuntu/Debian
- **权限**：需要sudo或root权限
- **网络**：服务器需要公网IP或内网访问

## 📚 故障排除

### 常见问题

**SFTP连接问题**
```bash
# 检查SSH服务
systemctl status ssh
# 检查端口
ufw status
```

**FTP连接问题**
```bash
# 检查FTP服务
systemctl status vsftpd
# 查看日志
tail -f /var/log/vsftpd.log
```

## 🔒 安全建议

1. **优先使用SFTP** - 更安全，配置更简单
2. **使用强密码** - 建议自动生成
3. **防火墙配置** - 只开放必要端口
4. **定期更新** - 保持系统最新

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

⭐ **如果这个项目对你有帮助，请给个Star支持一下！**