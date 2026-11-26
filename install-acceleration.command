#!/bin/zsh
# Iris Xe 加速一键安装（NootedGreen / macOS 26.7 build 25G325）
# 用法：在 macOS 里双击本文件，然后什么都不用管。
# 所有输出会同时写进 U 盘的 install-log.txt，失败也能带回来。

set -e

# ---------- 0) 找一个有 EFI 的卷，日志写在那里 ----------
LOG="/tmp/macos-install.log"
for v in /Volumes/*; do
  if [ -d "$v/EFI-accel" ] || [ -d "$v/EFI" ]; then
    LOG="$v/install-log.txt"
    break
  fi
done

# 之后所有输出同时进终端和日志
exec > >(tee "$LOG") 2>&1

echo "=================================================================="
echo " Iris Xe 加速安装 (NootedGreen)"
echo " 日志: $LOG"
echo "=================================================================="
echo ""

# ---------- 1) 命令行工具 ----------
if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
  echo "需要苹果的“命令行工具”（编译器，约 1 GB）。"
  echo "马上会弹窗，请点 Install。这个窗口别关，脚本会自己等它装完。"
  echo ""
  /usr/bin/xcode-select --install || true

  echo "等待命令行工具安装完成（每 20 秒检查，最多 90 分钟）..."
  n=0
  while ! /usr/bin/xcode-select -p >/dev/null 2>&1; do
    sleep 20
    n=$((n+1))
    if [ $((n % 15)) -eq 0 ]; then
      echo "  还在等…（已等 $((n*20/60)) 分钟）"
    fi
    if [ $n -gt 270 ]; then
      echo ">>> FAIL: 等命令行工具超时，可能下载卡住或弹窗被关掉了。"
      echo "按回车关闭。"; read -r _; exit 1
    fi
  done
  echo "命令行工具 OK。"
else
  echo "[1/4] 命令行工具已就绪: $(/usr/bin/xcode-select -p)"
fi

/usr/bin/clang --version | head -2

# ---------- 2) 下载源码到 APFS ----------
cd "$HOME/Desktop"
if [ ! -d nootedgreen-src ]; then
  echo "[2/4] 下载源码到 ~/Desktop/nootedgreen-src ..."
  /usr/bin/git clone --depth 1 https://github.com/dssoftx/Hackintosh-X1Carbon-G11-IrisXe-Tahoe.git nootedgreen-src
else
  echo "[2/4] 源码已在，跳过下载"
fi
cd nootedgreen-src

echo "仓库内容:"; ls -la | head -30

# ---------- 3) 编译 + 安装 ----------
echo "[3/4] 系统: $(/usr/bin/sw_vers -productVersion) (build $(/usr/bin/sw_vers -buildVersion))"
echo "脚本内置要求 25G241，用 XE_FORCE=1 放宽"
export XE_FORCE=1
echo "开始编译并安装（会要一次开机密码）"
echo ""
set +e
/bin/zsh ./install.sh
RC=$?
set -e
echo ""
echo "install.sh 退出码: $RC"
if [ $RC -ne 0 ]; then
  echo ">>> FAIL: 编译或安装失败，日志见 $HOME/Desktop/nootedgreen-src/build/install.log"
  echo "--- 最后 40 行 ---"
  tail -40 "$HOME/Desktop/nootedgreen-src/build/install.log" 2>&1
  echo "按回车关闭。"; read -r _; exit $RC
fi

# ---------- 4) 把编译好的 kext 放进 U 盘的 EFI-accel ----------
echo "[4/4] 把编译好的 NootedGreen.kext 放进 U 盘..."
KEXT=""
for p in ./build/NootedGreen.kext ./build/*/NootedGreen.kext; do
  [ -d "$p" ] && KEXT="$p" && break
done
echo "找到的 kext: ${KEXT:-(无)}"
if [ -n "$KEXT" ]; then
  for v in /Volumes/*; do
    if [ -d "$v/EFI-accel/OC/Kexts" ]; then
      rm -rf "$v/EFI-accel/OC/Kexts/NootedGreen.kext"
      cp -R "$KEXT" "$v/EFI-accel/OC/Kexts/NootedGreen.kext"
      echo "已更新: $v/EFI-accel/OC/Kexts/NootedGreen.kext"
    fi
    [ -d "$v/EFI" ] && cp -R "$KEXT" "$v/" 2>/dev/null && echo "备份到: $v/NootedGreen.kext"
  done
else
  echo ">>> 警告: 没找到 build/NootedGreen.kext，检查 build 目录:"
  ls -la ./build 2>&1 | head -40
fi

echo ""
echo "=== DONE ==="
echo "当前 /Library/Extensions 里与本项目相关的:"
ls -la /Library/Extensions 2>&1 | grep -Ei "nooted|hookcase|xe" || echo "(没有)"
echo ""
echo "现在长按电源键关机，回 Windows 叫我。"
echo "按回车关闭本窗口。"
read -r _
