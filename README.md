# ⚠️ 免责声明

**🚨 重要提醒：此仓库仅供个人开发测试使用，请勿用于生产环境！**

**⚠️ 使用本项目可能存在安全风险，使用者需自行评估并承担相关责任。**

**🛡️ 任何因使用本项目而产生的问题、损失或法律责任，均与本仓库作者无关。**

---

# FTP 服务器管理工具

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Ubuntu%2FDebian-orange.svg)]()

一键式交互FTP服务器管理工具，支持自动安装、卸载和状态监控，完美解决权限550错误。

## ✨ 特色功能

- 🚀 **一键部署** - 单条命令完成FTP服务器部署
- 🔧 **交互式管理** - 直观的菜单界面，操作简单
- 🛡️ **自动修复** - 智能解决权限550错误和版本兼容性问题
- 📊 **状态监控** - 实时查看FTP服务器状态和用户信息
- 🗑️ **完全卸载** - 智能检测并彻底清理所有相关组件
- 🔒 **安全设计** - 用户chroot隔离，完整权限控制
- 🌐 **网络优化** - 自动配置被动模式和防火墙规则

## 🚀 快速开始

### 运行管理工具

```bash
curl -fsSL https://raw.githubusercontent.com/Sannylew/ftp-ftps-setup/main/ftp_manager.sh | bash
```

### 操作菜单

```
📡 FTP 服务器管理工具
======================================================
请选择操作：
1) 安装 FTP 服务器
2) 卸载 FTP 服务器  
3) 查看 FTP 状态
0) 退出
```

## 📋 功能详解

### 1. 安装 FTP 服务器
- 自动检测系统环境
- 智能配置vsftpd服务
- 创建FTP用户和安全权限
- 配置目录映射和挂载
- 自动开放防火墙端口
- 生成连接信息

### 2. 卸载 FTP 服务器
- 智能检测FTP用户
- 安全确认机制
- 清理服务和软件包
- 删除用户和权限
- 清理挂载和配置文件
- 恢复防火墙设置

### 3. 查看 FTP 状态
- 服务运行状态
- 端口监听状态
- 用户详细信息（ID、权限、目录）
- 挂载状态和映射源
- 配置文件检查
- 密码重置提示

## 🌐 客户端连接

### 连接参数
- **协议**: FTP
- **端口**: 21
- **模式**: 被动模式
- **编码**: UTF-8

### 推荐客户端
- [FileZilla](https://filezilla-project.org/) - 跨平台，功能强大
- [WinSCP](https://winscp.net/) - Windows专用
- [Cyberduck](https://cyberduck.io/) - macOS专用

### 目录结构
用户登录后直接在FTP根目录操作，无需进入子目录。

## 🔧 用户管理

### 查看FTP用户

```bash
# 方法1：查看包含ftp的用户
grep ftp /etc/passwd

# 方法2：查看home目录下的用户
ls /home/ | grep -E "(ftp|user)"
```

### 重置用户密码

```bash
# 交互式重置
sudo passwd ftpuser

# 生成随机密码
new_password=$(openssl rand -base64 12)
echo "ftpuser:$new_password" | sudo chpasswd
echo "新密码: $new_password"
```

### 查看配置信息

```bash
# 查看FTP根目录配置
grep local_root /etc/vsftpd.conf

# 查看用户目录结构
ls -la /home/ftpuser/
```

## 🛠️ 系统要求

- **操作系统**: Ubuntu 16.04+ / Debian 8+
- **权限**: root或sudo权限
- **网络**: 互联网连接（下载软件包）
- **端口**: 21, 40000-40100

## 🔧 技术特性

### 安全特性
- 用户chroot隔离环境
- 禁用匿名访问
- 完整的目录权限控制
- 自动配置`allow_writeable_chroot=YES`

### 网络配置
- 被动模式数据传输
- 端口范围: 40000-40100
- 自动防火墙配置
- IPv6支持可选

### 兼容性
- 自动检测vsftpd版本
- 智能处理权限550错误
- 支持新旧版本配置
- 错误自动修复

## 🚨 故障排除

### 常见问题

#### 权限550错误
脚本自动解决，如仍有问题：
```bash
# 检查配置
grep allow_writeable_chroot /etc/vsftpd.conf
```

#### 连接超时
```bash
# 检查防火墙
sudo ufw status
# 检查服务状态  
systemctl status vsftpd
```

#### 无法上传文件
使用管理工具选择"3) 查看FTP状态"检查权限配置。

## 📄 许可证

本项目采用 [MIT License](LICENSE) 开源协议。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目！

---

⭐ **如果这个项目对你有帮助，请给个Star支持一下！**