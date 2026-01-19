# 3X-UI 全能一键安装 & 环境修复脚本

这是一个专为 **精简版 Linux 系统**（如 DMIT, Bandwagon 等 Minimal 镜像）设计的 X-UI 全自动安装工具。它可以自动解决依赖缺失、端口占用、证书申请卡死等常见痛点，实现真正的“一键躺平”安装。

## ✨ 功能特点

- 🛠 **环境自动修补**：自动检测系统版本 (Debian/CentOS) 并补全 `cron`, `socat`, `curl` 等缺失的基础依赖，彻底解决 `Pre-check failed` 报错。
- 🔒 **免邮箱证书申请**：自动安装 `acme.sh` 并强制切换 CA 为 **Let's Encrypt**，跳过 ZeroSSL 的强制邮箱注册步骤，防止安装中断。
- 🧹 **智能端口清理**：安装前自动检测 **80 端口**，若被 Nginx/Apache 占用会自动释放，确保 SSL 证书申请 100% 成功。
- ⚡ **全自动无人值守**：集成自动应答逻辑，自动确认安装提示，无需手动按回车，一杯咖啡的时间即可完成部署。

## 🚀 使用方法 (Root 用户)

直接在终端执行以下命令即可（请将命令中的地址替换为你实际的 GitHub 文件地址）：

```bash
bash <(curl -sL https://raw.githubusercontent.com/NX2406/3xui-AUTO/refs/heads/main/setup.sh)
