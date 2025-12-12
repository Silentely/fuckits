# 安全规则文档 (Security Rules)

## 概览

fuckits 内置三级安全引擎，通过 21 条精心设计的安全规则保护用户免受危险命令的侵害。安全引擎采用 **正则表达式匹配 + 结构分析** 的混合策略，在命令执行前进行风险评估。

**三级防护体系**：
- 🚫 **Block（绝对禁止）**：8 条规则，检测到后立即阻止执行
- ⚠️ **Challenge（二次确认）**：9 条规则，要求用户输入确认短语
- 💡 **Warn（风险提示）**：4 条规则，显示警告但允许继续

**设计原则**：
- 安全优先：默认拦截潜在危险操作
- 可配置性：支持 strict/balanced/off 三种模式
- 白名单机制：允许信任命令绕过检测
- 结构分析：识别命令链、管道等复杂结构

---

## 安全等级说明

### Block（绝对禁止）

**触发行为**：
- 立即拦截，不允许执行
- 显示红色错误信息
- 返回退出码 1

**适用场景**：
- 破坏性操作（删除根目录、格式化磁盘）
- 资源耗尽攻击（Fork 炸弹）
- 无法撤销的系统破坏

**用户选项**：
- 无法通过确认执行
- 必须使用白名单绕过（`FUCK_SECURITY_WHITELIST`）
- 或关闭安全引擎（`FUCK_SECURITY_MODE=off`，不推荐）

---

### Challenge（二次确认）

**触发行为**：
- 显示黄色警告信息
- 要求用户输入确认短语（默认：`I accept the risk`）
- 输入正确后允许执行

**适用场景**：
- 高风险但有合理使用场景的操作
- 涉及关键系统文件/路径的修改
- 远程脚本执行、动态代码执行

**用户选项**：
- 输入确认短语后执行
- 可自定义确认短语（`FUCK_SECURITY_CHALLENGE_TEXT`）
- 添加到白名单永久信任
- 使用 strict 模式升级为 block

---

### Warn（风险提示）

**触发行为**：
- 显示黄色警告信息
- 询问用户是否继续（y/n）
- 用户确认后允许执行

**适用场景**：
- 潜在风险但常见的操作
- 需要用户注意但不致命
- 权限变更、批量删除等

**用户选项**：
- 直接输入 y 继续
- 添加到白名单避免重复警告
- 使用 strict 模式升级为 challenge

---

## Block 规则详解（8 条）

### 1. 递归删除根目录（rm -rf /）

**规则 ID**: BLOCK-001
**严重性**: 🔴 Critical
**正则表达式**:
```regex
(^|[;&|[:space:]])rm[[:space:]]+-rf[[:space:]]+/([[:space:]]|$)
```

**匹配示例**:
```bash
rm -rf /           # ✅ 匹配
sudo rm -rf /      # ✅ 匹配
rm -rf / && echo   # ✅ 匹配
rm -rf /home       # ❌ 不匹配（不是根目录）
```

**风险说明**:
- 递归删除整个根文件系统
- 导致系统完全无法使用
- 无法恢复，需要重装系统

**错误信息**:
```
🚫 BLOCKED: Recursive delete targeting root filesystem
This command could destroy your entire system. Use --no-preserve-root explicitly if intended.
```

---

### 2. 通配符删除根下所有文件（rm -rf /*）

**规则 ID**: BLOCK-002
**严重性**: 🔴 Critical
**正则表达式**:
```regex
rm[[:space:]]+-rf[[:space:]]+/\*
```

**匹配示例**:
```bash
rm -rf /*          # ✅ 匹配
sudo rm -rf /*     # ✅ 匹配
rm -rf /* > log    # ✅ 匹配
rm -rf /home/*     # ❌ 不匹配（非根级通配符）
```

**风险说明**:
- 通配符展开后删除根下所有目录/文件
- 等同于删除根目录，系统崩溃
- 某些 shell 会自动展开 `/*`

**与规则 1 的区别**:
- 规则 1 针对 `rm -rf /`（根目录本身）
- 规则 2 针对 `rm -rf /*`（根下所有内容）
- 两种写法效果相同，都需要拦截

---

### 3. 禁用 preserve-root 保护（rm --no-preserve-root）

**规则 ID**: BLOCK-003
**严重性**: 🔴 Critical
**正则表达式**:
```regex
rm[[:space:]]+-rf[[:space:]]+--no-preserve-root
```

**匹配示例**:
```bash
rm -rf --no-preserve-root /      # ✅ 匹配
rm -rf --no-preserve-root /*     # ✅ 匹配
rm --no-preserve-root -rf /      # ❌ 不匹配（参数顺序）
```

**风险说明**:
- 现代 `rm` 命令默认保护根目录（`--preserve-root`）
- `--no-preserve-root` 显式禁用此保护
- 明确表示用户意图删除根目录

**设计考量**:
- 即使用户显式使用 `--no-preserve-root`，仍然拦截
- 避免误操作或恶意脚本绕过保护
- 真正需要时可通过白名单

---

### 4. 递归删除隐藏/系统文件（rm -rf .*）

**规则 ID**: BLOCK-004
**严重性**: 🔴 Critical
**正则表达式**:
```regex
rm[[:space:]]+-rf[[:space:]]+\.\*
```

**匹配示例**:
```bash
rm -rf .*          # ✅ 匹配
rm -rf ~/.*        # ✅ 匹配
rm -rf .git        # ❌ 不匹配（单个隐藏目录）
rm -rf ./* ../*    # ❌ 不匹配（非通配符模式）
```

**风险说明**:
- `.*` 匹配所有以 `.` 开头的文件/目录
- 包括 `.bashrc`, `.ssh`, `.config` 等关键配置
- 可能匹配 `..`（父目录），导致递归删除

**真实案例**:
```bash
cd /home/user
rm -rf .*          # 删除所有配置文件，包括可能递归到 ..
                    # 结果：/home 目录被删除
```

---

### 5. 原始磁盘写入（dd 操作 /dev 设备）

**规则 ID**: BLOCK-005
**严重性**: 🔴 Critical
**正则表达式**:
```regex
\bdd\b[^#\n]*\b(of|if)=/dev/
```

**匹配示例**:
```bash
dd if=/dev/zero of=/dev/sda       # ✅ 匹配（擦除磁盘）
dd if=image.iso of=/dev/sdb       # ✅ 匹配（写入 USB）
dd if=/dev/sda of=backup.img      # ✅ 匹配（读取磁盘）
dd if=file of=output              # ❌ 不匹配（非 /dev）
```

**风险说明**:
- `dd` 直接操作块设备，绕过文件系统
- 写入错误设备（如系统盘）导致数据丢失
- 无法撤销，硬盘数据被覆盖

**合法使用场景**:
- 制作启动 USB（`dd if=ubuntu.iso of=/dev/sdb`）
- 磁盘备份/恢复
- 建议：使用更安全的工具（`balenaEtcher`, `Rufus`）

---

### 6. 文件系统格式化（mkfs 系列命令）

**规则 ID**: BLOCK-006
**严重性**: 🔴 Critical
**正则表达式**:
```regex
\bmkfs(\.\w+)?\b
```

**匹配示例**:
```bash
mkfs /dev/sdb1         # ✅ 匹配
mkfs.ext4 /dev/sdc     # ✅ 匹配
mkfs.ntfs /dev/sda1    # ✅ 匹配
mkswap /dev/sda2       # ❌ 不匹配（不是 mkfs）
```

**风险说明**:
- 格式化分区会清空所有数据
- 误操作系统分区导致无法启动
- 数据恢复困难且不完整

**相关命令**:
- `mkfs`, `mkfs.ext4`, `mkfs.xfs`, `mkfs.btrfs` 等
- 所有文件系统格式化工具都会被拦截

---

### 7. 分区/磁盘擦除工具（fdisk/parted/wipefs/shred）

**规则 ID**: BLOCK-007
**严重性**: 🔴 Critical
**正则表达式**:
```regex
\bfdisk\b|\bparted\b|\bformat\b|\bwipefs\b|\bshred\b
```

**匹配示例**:
```bash
fdisk /dev/sda         # ✅ 匹配（分区编辑）
parted /dev/sdb        # ✅ 匹配（分区管理）
wipefs -a /dev/sdc     # ✅ 匹配（擦除签名）
shred -vfz /dev/sda    # ✅ 匹配（安全擦除）
format C:              # ✅ 匹配（Windows 格式化）
gparted                # ❌ 不匹配（GUI 工具，shell 无法执行）
```

**风险说明**:
- 分区操作可能意外删除数据
- `wipefs` 擦除文件系统签名，数据无法识别
- `shred` 多次覆写，数据无法恢复

---

### 8. Fork 炸弹（资源耗尽攻击）

**规则 ID**: BLOCK-008
**严重性**: 🔴 Critical
**正则表达式**:
```regex
:\(\)[[:space:]]*\{[[:space:]]*:[[:space:]]*\|[[:space:]]*:[[:space:]]*&[[:space:]]*\}[[:space:]]*;[[:space:]]*:
```

**匹配示例**:
```bash
:(){ :|:& };:          # ✅ 匹配（经典 Fork 炸弹）
: () { : | : & } ; :   # ✅ 匹配（带空格）
bomb(){ bomb|bomb& };bomb  # ❌ 不匹配（不同名称）
```

**风险说明**:
- 递归创建进程直到系统资源耗尽
- CPU 100%，内存溢出，系统无响应
- 需要强制重启或 `kill -9` 父进程

**工作原理**:
```bash
:()     # 定义函数 ":"
{
  :|:&  # 调用自己两次（管道 + 后台）
}
;:      # 执行函数
```

**防护措施**:
- ulimit 限制进程数（`ulimit -u 1000`）
- cgroup 资源控制
- 本规则在源头拦截

---

## Challenge 规则详解（9 条）

### 1. 远程脚本执行（curl | bash）

**规则 ID**: CHALLENGE-001
**严重性**: 🟠 High
**正则表达式**:
```regex
curl[^|]*\|\s*(bash|sh)
```

**匹配示例**:
```bash
curl https://example.com/script.sh | bash    # ✅ 匹配
curl -sSL https://get.docker.com | sh        # ✅ 匹配
curl -o script.sh example.com; bash script.sh  # ❌ 不匹配（非管道）
```

**风险说明**:
- 直接执行未审查的远程脚本
- 无法提前检查脚本内容
- 常见的恶意软件传播方式

**安全建议**:
```bash
# 不推荐（Challenge）
curl https://example.com/install.sh | bash

# 推荐（分步审查）
curl -O https://example.com/install.sh
less install.sh       # 审查内容
bash install.sh       # 确认后执行
```

---

### 2. 远程脚本执行（wget | sh）

**规则 ID**: CHALLENGE-002
**严重性**: 🟠 High
**正则表达式**:
```regex
wget[^|]*\|\s*(bash|sh)
```

**匹配示例**:
```bash
wget -qO- https://example.com/setup.sh | sh   # ✅ 匹配
wget https://get.k3s.io | bash                # ✅ 匹配
wget -O script.sh example.com; sh script.sh   # ❌ 不匹配（非管道）
```

**与规则 1 的区别**:
- 工具不同（`wget` vs `curl`）
- 风险相同，检测逻辑类似

---

### 3. 远程文件导入（source https://）

**规则 ID**: CHALLENGE-003
**严重性**: 🟠 High
**正则表达式**:
```regex
\bsource\s+https?://
```

**匹配示例**:
```bash
source https://example.com/config.sh    # ✅ 匹配
. https://cdn.example.com/lib.sh        # ❌ 不匹配（未检测 `.` 简写）
source /local/file.sh                   # ❌ 不匹配（本地文件）
```

**风险说明**:
- `source` 在当前 shell 执行脚本
- 影响当前环境变量和函数
- 远程脚本可能包含恶意代码

---

### 4. 显式动态执行（eval/exec）

**规则 ID**: CHALLENGE-004
**严重性**: 🟠 High
**正则表达式**:
```regex
\beval\b|\bexec\b
```

**匹配示例**:
```bash
eval "rm -rf $dir"     # ✅ 匹配
exec bash              # ✅ 匹配
evaluate=$(echo test)  # ❌ 不匹配（包含但非命令）
```

**风险说明**:
- `eval` 执行字符串作为代码
- 可能导致命令注入攻击
- 难以静态分析和审计

**危险示例**:
```bash
user_input="test; rm -rf /"
eval "echo $user_input"   # 注入！
```

---

### 5. 命令替换（$() 形式）

**规则 ID**: CHALLENGE-005
**严重性**: 🟠 High
**正则表达式**:
```regex
\$\([^)]*\)
```

**匹配示例**:
```bash
echo $(cat /etc/passwd)    # ✅ 匹配
dir=$(pwd)                 # ✅ 匹配
echo "Price: $10"          # ❌ 不匹配（非命令替换）
```

**风险说明**:
- 命令替换可能执行恶意命令
- 难以预测替换结果
- 常见于代码注入

---

### 6. 命令替换（反引号形式）

**规则 ID**: CHALLENGE-006
**严重性**: 🟠 High
**正则表达式**:
```regex
`[^`]*`
```

**匹配示例**:
```bash
echo `whoami`          # ✅ 匹配
file=`ls -1 | head`    # ✅ 匹配
echo "test"            # ❌ 不匹配（双引号）
```

**与规则 5 的区别**:
- 旧式语法（`反引号` vs `$(...)`）
- 功能相同，都执行命令替换

---

### 7. 嵌套 shell 调用（bash -c）

**规则 ID**: CHALLENGE-007
**严重性**: 🟠 High
**正则表达式**:
```regex
\b(sh|bash|env)\s+-c\b
```

**匹配示例**:
```bash
bash -c "echo test"    # ✅ 匹配
sh -c 'rm -rf /tmp/*'  # ✅ 匹配
env -c command         # ✅ 匹配
bash script.sh         # ❌ 不匹配（非 -c）
```

**风险说明**:
- `-c` 执行字符串命令
- 常见于远程执行和注入攻击
- 难以审计命令内容

---

### 8. 内联解释器执行（python -c）

**规则 ID**: CHALLENGE-008
**严重性**: 🟠 High
**正则表达式**:
```regex
\bpython[0-9.]*\s+-c\b
```

**匹配示例**:
```bash
python -c "import os; os.system('ls')"    # ✅ 匹配
python3.11 -c "print(1+1)"                # ✅ 匹配
python script.py                          # ❌ 不匹配（非 -c）
```

**风险说明**:
- 执行任意 Python 代码
- 可能导入危险模块（`os`, `subprocess`）
- 绕过文件审查机制

---

### 9. 操作关键系统路径

**规则 ID**: CHALLENGE-009
**严重性**: 🟠 High
**正则表达式**:
```regex
(^|[;&|[:space:]])(cp|mv|rm|chmod|chown|sed|tee|cat)[^;&|]*/(etc|boot|sys|proc|dev)\b
```

**匹配示例**:
```bash
rm /etc/hosts              # ✅ 匹配
chmod 777 /etc/sudoers     # ✅ 匹配
mv /boot/vmlinuz /tmp      # ✅ 匹配
cat /proc/cpuinfo          # ✅ 匹配（读取也拦截，保守策略）
rm /home/user/etc          # ❌ 不匹配（非系统路径）
```

**关键系统路径**:
- `/etc` - 系统配置文件
- `/boot` - 启动文件（内核、initramfs）
- `/sys` - 内核接口（虚拟文件系统）
- `/proc` - 进程信息（虚拟文件系统）
- `/dev` - 设备文件

**风险说明**:
- 修改配置可能导致系统无法启动
- 删除启动文件需要重装系统
- 写入 `/dev` 可能破坏硬件

---

## Warn 规则详解（4 条）

### 1. sudo 递归删除（sudo rm -rf）

**规则 ID**: WARN-001
**严重性**: 🟡 Medium
**正则表达式**:
```regex
sudo[[:space:]]+[^;&|]*rm[[:space:]]+-rf
```

**匹配示例**:
```bash
sudo rm -rf /tmp/old         # ✅ 匹配
sudo apt remove && rm -rf    # ❌ 不匹配（rm 不在 sudo 参数中）
rm -rf /tmp                  # ❌ 不匹配（无 sudo）
```

**风险说明**:
- `sudo` 提权后删除风险增大
- 可能影响系统文件和其他用户数据
- 常见于清理操作，但需谨慎

**设计考量**:
- Warn 而非 Challenge/Block
- 常见场景：`sudo rm -rf /var/cache/*`
- 用户通常知道自己在做什么

---

### 2. 一般递归删除（rm -rf）

**规则 ID**: WARN-002
**严重性**: 🟡 Medium
**正则表达式**:
```regex
rm[[:space:]]+-rf\b
```

**匹配示例**:
```bash
rm -rf build           # ✅ 匹配
rm -rf node_modules    # ✅ 匹配
rm -rf /               # ❌ 已被 BLOCK-001 拦截（优先级更高）
```

**风险说明**:
- 递归删除可能误删重要文件
- 无法撤销
- 常见于开发清理操作

**与 Block 规则的区别**:
- Block 规则针对根目录/系统文件
- 本规则针对一般路径
- 优先级：Block > Challenge > Warn

---

### 3. 全局可写权限（chmod 777）

**规则 ID**: WARN-003
**严重性**: 🟡 Medium
**正则表达式**:
```regex
chmod[[:space:]]+.*777\b
```

**匹配示例**:
```bash
chmod 777 file.txt         # ✅ 匹配
chmod -R 777 /var/www      # ✅ 匹配
chmod 755 script.sh        # ❌ 不匹配（非 777）
```

**风险说明**:
- 777 权限允许所有用户读写执行
- 可能被恶意用户利用
- 不符合最小权限原则

**安全建议**:
```bash
# 不推荐
chmod 777 /var/www/uploads

# 推荐
chmod 755 /var/www/uploads  # 目录
chmod 644 /var/www/file.txt # 文件
```

---

### 4. 重定向到敏感系统文件

**规则 ID**: WARN-004
**严重性**: 🟡 Medium
**正则表达式**:
```regex
>[[:space:]]*/(etc/(passwd|shadow|sudoers)|dev/sd[a-z]+)
```

**匹配示例**:
```bash
echo "test" > /etc/passwd      # ✅ 匹配
cat data > /dev/sda            # ✅ 匹配
echo 0 > /dev/sda1             # ✅ 匹配
echo "log" > /var/log/app.log  # ❌ 不匹配（非敏感文件）
```

**敏感文件**:
- `/etc/passwd` - 用户账户信息
- `/etc/shadow` - 密码哈希（需 root）
- `/etc/sudoers` - sudo 权限配置
- `/dev/sda*` - 块设备（硬盘）

**风险说明**:
- 覆盖 `/etc/passwd` 导致无法登录
- 写入 `/dev/sda` 破坏磁盘数据
- 修改 `/etc/sudoers` 可能导致权限混乱

---

## 安全模式配置

### Balanced（均衡模式，默认）

**配置**:
```bash
export FUCK_SECURITY_MODE="balanced"
```

**行为**:
- Block 规则：立即拦截
- Challenge 规则：要求确认短语
- Warn 规则：询问是否继续

**适用场景**:
- 日常使用
- 开发环境
- 平衡安全性和便利性

---

### Strict（严格模式）

**配置**:
```bash
export FUCK_SECURITY_MODE="strict"
```

**行为**:
- Block 规则：立即拦截
- Challenge 规则：**升级为 Block**
- Warn 规则：**升级为 Challenge**

**适用场景**:
- 生产服务器
- 新手用户
- 高安全需求环境

**示例**:
```bash
# Balanced 模式：
curl https://example.com/install.sh | bash
# → Challenge（输入确认短语）

# Strict 模式：
curl https://example.com/install.sh | bash
# → Block（拒绝执行）
```

---

### Off（关闭安全引擎）

**配置**:
```bash
export FUCK_SECURITY_MODE="off"
```

**行为**:
- 所有规则禁用
- 不进行任何检测
- 直接执行 AI 生成的命令

**⚠️ 警告**:
- 极度危险，不推荐使用
- 仅用于测试或完全信任的环境
- 建议使用白名单代替

---

## 白名单机制

### 配置白名单

**环境变量**:
```bash
export FUCK_SECURITY_WHITELIST="npm install,git push,docker run"
```

**配置文件**:
```bash
# ~/.fuck/config.sh
export FUCK_SECURITY_WHITELIST="
npm install
pip install
cargo build
git push
"
```

**匹配逻辑**:
- 子字符串匹配（非正则）
- 包含白名单项即放行
- 优先级最高（高于 Block）

---

### 使用场景

**场景 1: CI/CD 流水线**
```bash
# 允许远程脚本（安装工具）
export FUCK_SECURITY_WHITELIST="curl https://sh.rustup.rs | sh"
```

**场景 2: 开发脚本**
```bash
# 允许 eval 用于动态加载配置
export FUCK_SECURITY_WHITELIST="eval \$(ssh-agent)"
```

**场景 3: 批量删除**
```bash
# 允许清理构建产物
export FUCK_SECURITY_WHITELIST="rm -rf node_modules,rm -rf target"
```

---

### 安全建议

1. **最小化白名单**：仅添加真正需要的命令
2. **精确匹配**：使用完整命令而非通配符
3. **定期审查**：删除不再需要的白名单项
4. **避免通用模式**：不要添加 `rm`, `sudo` 等通用关键字

---

## 结构分析增强

### 命令链检测

**触发条件**:
- 命令包含 `&&`, `||`, `;`, `|` 等操作符

**行为**:
- 单个命令安全级别为 Warn
- 检测到链式操作 → 提升到 Challenge

**示例**:
```bash
# 单独命令
rm -rf build
# → Warn（WARN-002）

# 链式命令
rm -rf build && npm install
# → Challenge（结构分析提升）
```

**设计理由**:
- 链式命令复杂度更高
- 错误可能级联传播
- 难以预测最终效果

---

## 测试覆盖

所有 21 条规则均有对应的单元测试：
- 位置：`tests/unit/bash/security.bats`
- 测试数量：27 个（21 规则 + 3 模式 + 3 白名单）
- 覆盖率：100%

**测试命令**:
```bash
npm run test:bash
```

**示例测试**:
```bash
@test "Security Block: rm -rf / " {
    run _fuck_security_evaluate_command "rm -rf /"
    severity=$(extract_severity "$output")
    [ "$severity" = "block" ]
    echo "$output" | grep -q "Recursive delete targeting root"
}
```

---

## 扩展规则建议

### 未来可能添加的规则

1. **网络攻击工具** (Challenge)
   - `nmap`, `masscan`, `sqlmap`
   - 渗透测试工具

2. **加密货币挖矿** (Block)
   - `xmrig`, `cpuminer`
   - CPU 资源耗尽

3. **隐蔽后门** (Block)
   - `nc -l -p` (监听端口)
   - `ssh -R` (反向隧道)

4. **容器逃逸** (Challenge)
   - `docker run --privileged`
   - `kubectl exec`

5. **环境变量注入** (Warn)
   - `export LD_PRELOAD`
   - `export PATH=/tmp:$PATH`

---

## 相关文档

- **测试架构**：[../tests/CLAUDE.md](../tests/CLAUDE.md)
- **测试设计**：[TEST_ARCHITECTURE.md](TEST_ARCHITECTURE.md)
- **主脚本实现**：[../main.sh](../main.sh) (line 787-1099)
- **配置说明**：[../CLAUDE.md](../CLAUDE.md#配置系统)

---

## 参考资源

- [OWASP Command Injection](https://owasp.org/www-community/attacks/Command_Injection)
- [CWE-78: OS Command Injection](https://cwe.mitre.org/data/definitions/78.html)
- [Bash Security Pitfalls](https://mywiki.wooledge.org/BashPitfalls)
- [Linux Security Hardening](https://www.kernel.org/doc/html/latest/admin-guide/LSM/)

---

_本小姐的安全引擎确保每一个命令都经过严格审查！(￣ω￣)ノ_
