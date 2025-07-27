# ⚠️ 免责声明

**🚨 重要提醒：此仓库仅供个人开发测试使用，请勿用于生产环境！**

**⚠️ 使用本项目可能存在安全风险，使用者需自行评估并承担相关责任。**

**🛡️ 任何因使用本项目而产生的问题、损失或法律责任，均与本仓库作者无关。**

---

# FTP 服务器管理工具

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/Platform-Ubuntu%2FDebian-orange.svg)]()

交互式FTP服务器管理工具，支持安装、卸载和状态监控，**彻底解决权限550错误和文件删除问题**。

## ✨ 特色功能

- 🚀 **简单部署** - 下载即用，完成FTP服务器部署
- 🔧 **交互式管理** - 直观的菜单界面，操作简单
- 🛡️ **权限修复** - 智能解决权限550错误，支持文件删除、重命名、创建
- 📊 **状态监控** - 实时查看FTP服务器状态和用户信息
- 🗑️ **完全卸载** - 智能检测并彻底清理所有相关组件，可选删除脚本
- 🔄 **服务管理** - 启动、重启、修复功能

## 🚀 快速开始

```bash
# 下载脚本
wget https://raw.githubusercontent.com/Sannylew/ftp-ftps-setup/main/ftp_manager.sh

# 添加执行权限
chmod +x ftp_manager.sh

# 运行交互式管理工具
sudo ./ftp_manager.sh
```

## 📋 交互式菜单

```
请选择操作：
1) 安装 FTP 服务器
2) 卸载 FTP 服务器  
3) 查看 FTP 状态
4) 启动 FTP 服务
5) 重启 FTP 服务
6) 修复挂载和权限
0) 退出
```

## 📱 连接信息

安装完成后使用以下信息连接：
- **协议**: FTP
- **端口**: 21
- **模式**: 被动模式

推荐客户端：FileZilla、WinSCP、Cyberduck、Alist

## 🔧 常见问题

### 权限550错误
重新运行脚本，选择"1) 安装FTP服务器"会自动修复权限。

### 服务未启动
使用脚本选择"4) 启动FTP服务"或"5) 重启FTP服务"。

### 挂载丢失
使用脚本选择"6) 修复挂载和权限"。

## 📄 许可证

本项目采用 [MIT License](LICENSE) 开源协议。

---

⭐ **如果这个项目对你有帮助，请给个Star支持一下！**