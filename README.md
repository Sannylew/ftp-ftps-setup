# FTP/FTPS 服务器一键部署脚本

🚀 **快速部署FTP和FTPS服务器的自动化脚本**

## 📝 简介

本项目提供多种自动化脚本，帮助你快速在Linux服务器上部署FTP和FTPS服务：

- **FTP服务器** - 标准的文件传输协议
- **FTPS服务器** - 带TLS加密的安全文件传输协议

## 📁 文件说明

| 文件名 | 类型 | 推荐度 | 描述 |
|--------|------|--------|------|
| `install_improved.sh` | **🔥 改进版** | ⭐⭐⭐⭐⭐ | **强烈推荐！** 增强版一键部署脚本 |
| `install.sh` | 一键脚本 | ⭐⭐⭐⭐ | 基础版一键部署脚本 |
| `install_ftp_server.sh` | 原始脚本 | ⭐⭐⭐ | FTP服务器单独部署脚本 |
| `install_ftps_server.sh` | 原始脚本 | ⭐⭐⭐ | FTPS服务器单独部署脚本 |

## ⚡ 快速开始

### 🔥 方法一：改进版一键部署（强烈推荐）

```bash
# 下载并运行改进版一键部署脚本
wget https://raw.githubusercontent.com/Sannylew/ftp-ftps-setup/main/install_improved.sh
chmod +x install_improved.sh
sudo ./install_improved.sh
```

**改进版特色：**
- ✅ **完善的错误处理和权限检查**
- ✅ **用户名和密码验证**
- ✅ **端口占用检查**
- ✅ **服务状态监控**
- ✅ **配置文件自动备份**
- ✅ **更安全的权限设置**

### 🎯 方法二：基础版一键部署

```bash
# 下载并运行基础版一键部署脚本
wget https://raw.githubusercontent.com/Sannylew/ftp-ftps-setup/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

### 📡 方法三：单独部署

#### FTP服务器部署

```bash
# 下载并运行FTP部署脚本
wget https://raw.githubusercontent.com/Sannylew/ftp-ftps-setup/main/install_ftp_server.sh
chmod +x install_ftp_server.sh
sudo ./install_ftp_server.sh
```

#### FTPS服务器部署

```bash
# 下载并运行FTPS部署脚本
wget https://raw.githubusercontent.com/Sannylew/ftp-ftps-setup/main/install_ftps_server.sh
chmod +x install_ftps_server.sh
sudo ./install_ftps_server.sh
```

## 🔧 功能特性

### 🔥 一键部署脚本特色
- ✅ **交互式菜单选择** - 清晰的界面引导
- ✅ **权限检查** - 自动检测root权限
- ✅ **统一配置流程** - 避免重复输入
- ✅ **错误处理** - 完善的错误提示和退出机制

### FTP服务器功能
- ✅ 自动安装vsftpd服务
- ✅ 创建FTP用户和密码
- ✅ 配置用户主目录和文件权限
- ✅ 设置被动模式端口范围（40000-40100）
- ✅ 支持目录映射和自动挂载
- ✅ 支持自动生成随机密码

### FTPS服务器功能
- ✅ 包含所有FTP功能
- 🔒 **自动生成TLS证书**
- 🔒 **强制SSL/TLS加密传输**
- 🔒 **禁用不安全的SSLv2/SSLv3**
- 🔒 **支持TLSv1加密协议**

## 📋 使用说明

### 运行时的交互式配置

1. **输入FTP用户名**（如：sunny）
2. **设置映射目录**（默认：/root/brec/file）
3. **选择密码方式**：
   - `y` - 自动生成随机密码
   - `n` - 手动输入密码

### 端口配置

- **FTP控制端口**：21
- **被动模式数据端口**：40000-40100

⚠️ **防火墙设置**：确保开放端口21和40000-40100

## 🌐 客户端连接

### FTP连接
- **服务器**：你的服务器IP
- **端口**：21
- **用户名**：脚本中设置的用户名
- **密码**：脚本中设置的密码
- **连接模式**：被动模式

### FTPS连接（推荐）
- **服务器**：你的服务器IP
- **端口**：21
- **加密方式**：`FTP over TLS (显式加密)`
- **用户名**：脚本中设置的用户名
- **密码**：脚本中设置的密码

### 推荐客户端
- **FileZilla** - 跨平台，支持FTP/FTPS
- **WinSCP** - Windows平台
- **Cyberduck** - macOS平台

## 🔒 安全建议

1. **优先使用FTPS**：具有TLS加密，数据传输更安全
2. **使用强密码**：建议选择自动生成随机密码
3. **定期更换密码**：提高安全性
4. **防火墙配置**：只开放必要的端口
5. **定期更新证书**：FTPS证书有效期为365天

## 🛠️ 系统要求

- **操作系统**：Ubuntu/Debian/CentOS等Linux发行版
- **权限要求**：需要sudo或root权限
- **网络要求**：服务器需要公网IP或内网访问

## 📚 故障排除

### 常见问题

1. **连接被拒绝**
   - 检查防火墙设置
   - 确认vsftpd服务是否启动：`systemctl status vsftpd`

2. **无法进入目录**
   - 检查目录权限设置
   - 确认目录映射是否正确

3. **FTPS证书错误**
   - 客户端选择"接受证书"
   - 或重新生成证书

### 日志查看
```bash
# 查看vsftpd日志
sudo tail -f /var/log/vsftpd.log

# 查看系统日志
sudo journalctl -u vsftpd -f
```

## 🤝 贡献指南

欢迎提交Issue和Pull Request来改进这个项目！

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🔗 相关链接

- [vsftpd官方文档](https://security.appspot.com/vsftpd.html)
- [FileZilla下载](https://filezilla-project.org/)
- [OpenSSL文档](https://www.openssl.org/docs/)

---

⭐ **如果这个项目对你有帮助，请给个Star支持一下！**