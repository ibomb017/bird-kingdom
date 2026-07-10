#!/bin/bash
# ⚠️ DEPRECATED: 此脚本已被 systemd 服务 (birdkingdom-admin.service) 替代
# 请使用: systemctl start birdkingdom-admin
# 保留此文件仅供参考，请勿直接执行

echo "⚠️  此脚本已弃用！请使用 systemd 管理服务："
echo "    systemctl start birdkingdom-admin"
echo "    systemctl status birdkingdom-admin"
echo "    journalctl -u birdkingdom-admin -f"
exit 1
