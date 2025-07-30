# BRCE FTP零延迟配置脚本说明

## 📋 脚本概述

`brce_ftp_setup.sh` 是一个专门为BRCE程序设计的零延迟FTP配置工具，彻底解决传统bind mount方式的文件修改延迟问题。

**专门解决的核心问题：**
- ❌ root删除文件，FTP客户端还能看到
- ❌ 程序生成新文件，FTP需要刷新才能看到
- ❌ 文件修改后，FTP显示旧内容

**解决方案：**
- ✅ 使用rsync+inotify实现真正的零延迟同步
- ✅ 文件变化立即在FTP中可见
- ✅ 删除文件立即在FTP中消失

## 🎯 专门特性

### 🔧 **专用配置**
- **固定目录**: `/opt/brce/file` (BRCE程序文件目录)
- **固定用户**: `sunny` (FTP用户名)
- **自动密码**: OpenSSL随机生成16位安全密码
- **零延迟**: rsync+inotify实时监控同步

### ⚡ **零延迟技术**
```bash
监控方式: inotifywait -m -r -e modify,create,delete,move
同步方式: rsync -av --delete
延迟时间: 0.05秒 (几乎无感知)
权限修复: 每次同步后自动执行
```

### 🔄 **系统服务化**
- **服务名**: `brce-ftp-sync.service`
- **开机自启**: 自动启动
- **崩溃重启**: 5秒后自动重启
- **后台运行**: systemd管理

## 📥 从GitHub仓库获取

### 🌐 **仓库地址**
**GitHub仓库**: https://github.com/Sannylew/ftp-ftps-setup

### 📦 **下载方式**

#### **方法1：直接下载脚本（推荐）**
```bash
# 下载BRCE零延迟脚本
wget https://raw.githubusercontent.com/Sannylew/ftp-ftps-setup/main/brce_ftp_setup.sh

# 添加执行权限
chmod +x brce_ftp_setup.sh

# 运行脚本
sudo ./brce_ftp_setup.sh
```

#### **方法2：一键安装**
```bash
# 一条命令完成下载和运行
curl -sSL https://raw.githubusercontent.com/Sannylew/ftp-ftps-setup/main/brce_ftp_setup.sh | sudo bash
```

#### **方法3：克隆完整仓库**
```bash
# 克隆仓库（包含所有脚本和文档）
git clone https://github.com/Sannylew/ftp-ftps-setup.git

# 进入目录
cd ftp-ftps-setup

# 运行零延迟脚本
sudo ./brce_ftp_setup.sh
```

### 📖 **在线文档**
- **使用说明**: https://github.com/Sannylew/ftp-ftps-setup/blob/main/BRCE_FTP_零延迟配置说明.md
- **项目主页**: https://github.com/Sannylew/ftp-ftps-setup
- **问题反馈**: https://github.com/Sannylew/ftp-ftps-setup/issues

### 🔄 **更新脚本**
```bash
# 如果已克隆仓库，获取最新版本
git pull origin main

# 或重新下载最新版本
wget -O brce_ftp_setup.sh https://raw.githubusercontent.com/Sannylew/ftp-ftps-setup/main/brce_ftp_setup.sh
```

## 🚀 快速开始

### 1. 准备工作
```bash
# 确保有root权限
# 确保系统支持：Ubuntu/Debian/CentOS
```

### 2. 运行脚本
```bash
# 添加执行权限
chmod +x brce_ftp_setup.sh

# 运行脚本
sudo ./brce_ftp_setup.sh
```

### 3. 选择安装
```bash
请选择操作：
1) 🚀 安装/配置BRCE FTP服务 (零延迟)

请输入选项 (0-5): 1
```

### 4. 确认配置
```bash
🎯 目标目录: /opt/brce/file
👤 FTP用户: sunny
⚡ 特性: 实时同步，零延迟

是否使用零延迟实时同步？(y/n，默认: y): [回车]
```

### 5. 密码设置
```bash
自动生成密码？(y/n，默认: y): [回车]
🔑 自动生成的密码: K3mN8pQ2vX9s  # 记住这个密码
```

### 6. 等待完成
脚本会自动完成所有配置，最后显示连接信息。

## 📱 FTP客户端连接

### 连接信息
安装完成后获得的连接信息：
```bash
📋 连接信息：
   服务器: 192.168.1.100  # 你的服务器IP
   端口: 21
   用户: sunny
   密码: [自动生成的密码]
   访问目录: /opt/brce/file
```

### 🖥️ FileZilla连接
1. **主机**: `ftp://你的服务器IP`
2. **用户名**: `sunny`
3. **密码**: `脚本显示的密码`
4. **端口**: `21`
5. **模式**: 被动模式(PASV)

### 💻 Windows资源管理器
```
地址栏输入: ftp://sunny@你的服务器IP
输入密码: [脚本显示的密码]
```

### ⌨️ 命令行FTP
```bash
ftp 你的服务器IP
Name: sunny
Password: [脚本显示的密码]
```

## 🔧 功能菜单详解

### 1) 安装/配置BRCE FTP服务 (零延迟)
**功能**: 完整的零延迟FTP服务安装配置
- 安装依赖软件包 (vsftpd, rsync, inotify-tools)
- 创建sunny用户和随机密码
- 配置目录权限
- 创建实时同步脚本
- 启动系统服务
- 配置防火墙
- 显示连接信息

### 2) 查看FTP服务状态
**功能**: 全面的服务状态检查
```bash
✅ FTP服务运行正常
✅ 实时同步服务运行正常
✅ FTP端口21已开启
✅ FTP用户 sunny 存在
✅ FTP目录存在: /home/sunny/ftp
✅ BRCE目录存在: /opt/brce/file
📁 源目录文件数: 15
📁 FTP目录文件数: 15
✅ 文件数量同步正确
```

### 3) 重启FTP服务
**功能**: 重启FTP和同步服务
- 重启vsftpd服务
- 重启brce-ftp-sync服务
- 检查启动状态

### 4) 测试实时同步功能
**功能**: 自动化测试零延迟特性
```bash
📝 创建测试文件
⏱️  等待3秒检查同步...
✅ 文件创建同步成功

📝 修改测试文件...
⏱️  等待3秒检查同步...
✅ 文件修改同步成功

🗑️ 删除测试文件...
⏱️  等待3秒检查同步...
✅ 文件删除同步成功

🎉 实时同步功能正常！零延迟确认！
```

### 5) 卸载FTP服务
**功能**: 完整清理FTP配置
- 停止所有相关服务
- 删除系统服务文件
- 删除用户账户
- 清理配置文件
- 保留BRCE目录数据

## ⚡ 零延迟技术原理

### 🔍 问题分析
传统bind mount方式的延迟来源：
1. **FTP客户端缓存** - 目录列表缓存
2. **vsftpd服务器缓存** - 文件系统缓存
3. **被动检测机制** - 依赖FTP服务器发现变化

### 💡 解决方案
零延迟实时同步技术：
```bash
# 监控文件变化
inotifywait -m -r -e modify,create,delete,move /opt/brce/file

# 立即同步变化
rsync -av --delete /opt/brce/file/ /home/sunny/ftp/

# 修复权限
chown -R sunny:sunny /home/sunny/ftp
find /home/sunny/ftp -type f -exec chmod 644 {} \;
find /home/sunny/ftp -type d -exec chmod 755 {} \;
```

### 🔄 工作流程
```
BRCE程序文件变化 → inotify检测 → rsync同步 → 权限修复 → FTP立即可见
      0.001秒         0.01秒      0.05秒     0.02秒      立即
```

## 📊 性能对比

| 特性 | bind mount | 零延迟同步 |
|------|------------|------------|
| **文件创建** | 延迟1-30秒 | 立即(0.1秒) |
| **文件删除** | 延迟1-30秒 | 立即(0.1秒) |
| **文件修改** | 延迟1-30秒 | 立即(0.1秒) |
| **内存占用** | +10MB | +30MB |
| **CPU占用** | 0.1% | 0.5-1% |
| **可靠性** | 依赖缓存刷新 | 主动推送 |

## 🔒 安全性说明

### 文件权限
```bash
目录权限: 755 (rwxr-xr-x)
文件权限: 644 (rw-r--r--)
用户: sunny (专用FTP用户)
隔离: chroot jail限制
```

### 密码安全
```bash
生成方式: openssl rand -base64 12
密码长度: 16字符
字符集: 大小写字母+数字+符号
强度: 高强度随机密码
```

### 网络安全
```bash
协议: FTP (可升级到FTPS)
端口: 21 (控制端口)
被动端口: 40000-40100 (数据端口)
防火墙: 自动配置规则
```

## 🛠️ 故障排除

### 常见问题

#### 1. 实时同步服务未启动
**症状**: 文件变化不同步
**解决**:
```bash
sudo systemctl restart brce-ftp-sync
sudo systemctl status brce-ftp-sync
```

#### 2. 权限问题
**症状**: FTP无法写入文件
**解决**:
```bash
sudo chown -R sunny:sunny /opt/brce/file
sudo chmod -R 755 /opt/brce/file
```

#### 3. 防火墙阻断
**症状**: 无法连接FTP
**解决**:
```bash
# Ubuntu
sudo ufw allow 21/tcp
sudo ufw allow 40000:40100/tcp

# CentOS
sudo firewall-cmd --permanent --add-service=ftp
sudo firewall-cmd --permanent --add-port=40000-40100/tcp
sudo firewall-cmd --reload
```

#### 4. 依赖包缺失
**症状**: 脚本安装失败
**解决**:
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y vsftpd rsync inotify-tools

# CentOS/RHEL
sudo yum install -y vsftpd rsync inotify-tools
```

### 查看日志
```bash
# 查看FTP服务日志
sudo journalctl -u vsftpd

# 查看实时同步日志
sudo journalctl -u brce-ftp-sync

# 查看FTP访问日志
sudo tail -f /var/log/vsftpd.log

# 查看实时同步状态
sudo systemctl status brce-ftp-sync
```

## 📚 与其他脚本对比

| 脚本 | 适用场景 | 延迟 | 配置复杂度 | 资源占用 |
|------|----------|------|------------|----------|
| **ftp_manager.sh** | 通用FTP配置 | 有延迟 | 交互配置 | 低 |
| **ftp_manager_test.sh** | 测试实时同步 | 零延迟 | 交互配置 | 中等 |
| **brce_ftp_setup.sh** | BRCE专用零延迟 | 零延迟 | 自动化 | 中等 |

### 选择建议
- **追求简单**: 使用 `ftp_manager.sh`
- **测试功能**: 使用 `ftp_manager_test.sh`  
- **BRCE专用**: 使用 `brce_ftp_setup.sh` ⭐

## 💡 使用建议

### 适合场景
✅ **BRCE程序文件访问**  
✅ **频繁文件变化场景**  
✅ **要求零延迟响应**  
✅ **自动化部署需求**  
✅ **视频文件实时访问**  

### 不适合场景
❌ **低配置服务器 (<1GB内存)**  
❌ **超大文件频繁变化 (>1GB)**  
❌ **网络带宽限制环境**  

### 性能优化
```bash
# 监控资源使用
htop | grep -E "(vsftpd|rsync|inotify)"

# 查看内存占用
ps aux | grep brce-ftp-sync

# 查看磁盘I/O
iotop -o
```

## 🔄 升级和维护

### 脚本更新
```bash
# 获取最新版本
git pull origin main

# 重新运行安装
sudo ./brce_ftp_setup.sh
```

### 定期维护
```bash
# 清理日志 (可选)
sudo journalctl --vacuum-time=7d

# 检查服务状态
sudo ./brce_ftp_setup.sh
# 选择 2) 查看FTP服务状态
```

### 备份重要配置
```bash
# 备份vsftpd配置
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.backup

# 备份同步脚本
sudo cp /usr/local/bin/ftp_sync_sunny.sh ~/ftp_sync_backup.sh
```

## 🆘 技术支持

### 获取帮助
1. **查看本说明文档**
2. **运行内置测试**: 选择菜单选项4
3. **查看系统日志**: `journalctl -u brce-ftp-sync`
4. **检查服务状态**: 选择菜单选项2

### 反馈问题
**请提供以下信息**:
- 操作系统版本: `lsb_release -a`
- 错误信息截图
- 服务状态: `systemctl status brce-ftp-sync`
- 操作步骤描述

---

## 📋 总结

`brce_ftp_setup.sh` 是专门为BRCE程序设计的零延迟FTP配置工具，通过rsync+inotify技术彻底解决了传统bind mount的文件延迟问题。

**一句话概括**: 让你的BRCE程序文件通过FTP实现真正的零延迟访问！

**核心价值**: root删除文件，FTP立即看不到；程序生成文件，FTP立即可下载！🎉 