# Elden kernel

独立构建 Elden 的 BakaSU + SUSFS 内核，默认使用 BBRv3 拥塞控制，生成 Image、AVB2 签名 boot 和 AnyKernel3 ZIP。

## 构建

使用 Linux x86-64 主机，安装宿主依赖后运行构建入口：

```sh
sudo apt-get install repo git python3 zip unzip rsync bc flex bison build-essential libssl-dev libelf-dev zlib1g-dev zstd openssl
JOBS=8 ./build-bakasu-elden.sh
```

`JOBS` 控制同步和编译并发，默认值为 8。脚本通过 ACK 官方 manifest 获取配套的 Kleaf、LLVM、Rust 和构建工具。

构建流程：

```text
同步源码 → 应用集成补丁 → 配置 → Kleaf 编译 → AVB2 签名 → AnyKernel3 打包
```

## 源码

每次构建同步以下上游分支：

| 项目 | 上游 | 分支 |
|---|---|---|
| ACK manifest | android.googlesource.com/kernel/manifest | common-android16-6.12 |
| BakaSU | github.com/Baka-SU/BakaSU | main |
| SUSFS | gitlab.com/simonpunk/susfs4ksu | gki-android16-6.12 |
| AnyKernel3 安装框架 | github.com/osm0sis/AnyKernel3 | master |
| AnyKernel3 arm64 工具 | github.com/osm0sis/AnyKernel3 | arm64-tools |

BakaSU 获取完整历史和标签。构建前从实际 Git checkout 生成提交数、标签、短 SHA 和分支信息，Kbuild 使用上游公式计算版本码。Kleaf 在 sandbox 中读取生成的版本元数据，版本标识使用 `-dirty` 标记本地构建适配。

SUSFS 接入使用上游 6.12 补丁和补充源码，`patches/` 保存 Kleaf 和接口兼容适配。补丁应用失败时脚本退出并显示错误。

BBRv3 使用 `patches/bbr3-android16-6.12.patch` 接入，基于 [WildKernels/kernel_patches](https://github.com/WildKernels/kernel_patches/tree/main/common/bbrv3) 的 Android 16 / 6.12 回移适配 ACK，保留 CUBIC 和 ACK 原有的 BBR 算法。

## 配置和打包

`kernel.fragment` 选择内置 BakaSU 和 SUSFS，并清空 `MODULE_SIG_PROTECT_LIST`，关闭派生的 `MODULE_SIG_PROTECT`。其他配置继承上游默认值。

`boot.conf` 保存设备签名参数：

| 参数 | 值 |
|---|---|
| boot 分区大小 | 96 MiB |
| 签名算法 | SHA256_RSA4096 |
| 密钥 | AOSP `external/avb/test/data/testkey_rsa4096.pem` 公开测试私钥 |
| OS version 属性 | 17 |
| security_patch 属性 | 2026-08-01 |
| rollback index | 1790812800 |

签名阶段复用 ACK 的 `avbtool`，为 Kleaf 生成的完整 boot 重建 96 MiB AVB footer、写入上述属性并签名。`verify_image` 校验签名和 boot 哈希。

打包使用 AnyKernel3 `master` 安装框架，并将官方 `arm64-tools` 分支的 AArch64 二进制放入 `tools/`。BusyBox applet 使用原生硬链接模式安装。

`anykernel.sh` 配置 Elden、A/B 和 boot 分区，调用 AnyKernel3 的 `flash_generic boot` 写入包内完整签名镜像。

## 工作目录和产物

- `.work/`：上游源码、编译缓存和临时打包目录。每次构建会重置前一轮源码集成结果。
- `out/<UTC时间>-<BakaSU短SHA>/`：完成构建后的产物目录。

```text
Image
boot.img
elden-kernel.zip
kernel.config
sources.txt
manifest.xml
avb-info.txt
SHA256SUMS
```

`sources.txt` 记录本次上游提交、版本元数据、签名配置和本地补丁哈希。`manifest.xml` 记录 ACK 工作区的实际源码版本，`avb-info.txt` 记录签名镜像的 AVB 参数，`SHA256SUMS` 包含产物校验和。

## GitHub Actions

在 Actions 中手动运行 **Build Elden kernel**。工作流安装依赖、调用同一个构建脚本，并将 `out/` 上传为 `elden-kernel` artifact。
