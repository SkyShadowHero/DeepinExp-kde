#!/usr/bin/env bash
#
# DeepinExp-kde 一键安装脚本
#
# fcitx5 主题和图标主题不再在仓库里存副本，而是以 git submodule 引用上游仓库：
#   fcitx5            -> https://github.com/SkyShadowHero/deepinlike-fcitx5-theme
#   icons/DeepinYouth -> https://github.com/SkyShadowHero/DeepinYouth-icons
#
# 子模块没初始化过（例如用 ZIP 下载的仓库）时，脚本会自动克隆到缓存目录再安装。
#
# 用法:
#   bash install.sh

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/deepinexp-kde"

FCITX_URL="https://github.com/SkyShadowHero/deepinlike-fcitx5-theme.git"
ICONS_URL="https://github.com/SkyShadowHero/DeepinYouth-icons.git"

SHARE="$HOME/.local/share"
FCITX_DEST="$SHARE/fcitx5/themes"
ICON_DEST="$SHARE/icons"
PLASMA_DEST="$SHARE/plasma/desktoptheme"
COLOR_DEST="$SHARE/color-schemes"

# 图标主题安装后的目录名，也是系统设置里识别主题用的名字
ICON_NAME="DeepinYouth"

info() { printf '  %s\n' "$*"; }
warn() { printf '  注意：%s\n' "$*" >&2; }
die()  { printf '错误：%s\n' "$*" >&2; exit 1; }

# 解析内容来源：优先用仓库里的子模块，为空则回落到缓存目录中的克隆
# 用法: src=$(ensure_source 本地路径 仓库地址 缓存目录名)
ensure_source() {
    local local_path="$1" url="$2" cache_name="$3"
    local cache="$CACHE_DIR/$cache_name"

    if [ -d "$local_path" ] && [ -n "$(ls -A "$local_path" 2>/dev/null)" ]; then
        printf '%s\n' "$local_path"
        return 0
    fi

    printf '  · 子模块 %s 为空，改用缓存副本\n' "${local_path#"$REPO_DIR"/}" >&2
    if [ ! -d "$cache/.git" ]; then
        printf '  · 正在克隆 %s\n' "$url" >&2
        mkdir -p "$CACHE_DIR"
        git clone --depth 1 --quiet "$url" "$cache" >&2 || die "克隆失败：$url"
    else
        printf '  · 更新缓存 %s\n' "$cache" >&2
        if git -C "$cache" fetch --depth 1 --quiet origin HEAD >&2; then
            git -C "$cache" reset --hard --quiet FETCH_HEAD >&2 || true
        else
            warn "缓存更新失败，继续使用现有内容"
        fi
    fi
    printf '%s\n' "$cache"
}

printf 'DeepinExp-kde 安装\n\n'

printf '› 解析组件来源\n'
FCITX_SRC="$(ensure_source "$REPO_DIR/fcitx5" "$FCITX_URL" deepinlike-fcitx5-theme)"
ICONS_SRC="$(ensure_source "$REPO_DIR/icons/DeepinYouth" "$ICONS_URL" DeepinYouth-icons)"

mkdir -p "$FCITX_DEST" "$ICON_DEST" "$PLASMA_DEST" "$COLOR_DEST"

printf '\n› Fcitx5 主题\n'
fcitx_themes=()
for theme_dir in "$FCITX_SRC"/*/; do
    [ -f "$theme_dir/theme.conf" ] || continue
    theme_name="$(basename "$theme_dir")"
    rm -rf "$FCITX_DEST/$theme_name"
    cp -r "$theme_dir" "$FCITX_DEST/"
    fcitx_themes+=("$theme_name")
    info "$theme_name"
done
[ ${#fcitx_themes[@]} -gt 0 ] || die "$FCITX_SRC 里没有找到任何 fcitx5 主题"

printf '\n› 图标主题\n'
rm -rf "$ICON_DEST/$ICON_NAME"
cp -r "$ICONS_SRC" "$ICON_DEST/$ICON_NAME"
info "$ICON_NAME"

# 本地补丁层：上游还没有收录的图标，装完主主题后覆盖上去
if [ -d "$REPO_DIR/overlay/icons" ]; then
    cp -r "$REPO_DIR/overlay/icons/." "$ICON_DEST/$ICON_NAME/"
    info "已叠加 overlay/icons（本地新增图标）"
fi

# 图标缓存必须重建，否则叠加进去的图标不会被 GTK 程序看到
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$ICON_DEST/$ICON_NAME" >/dev/null 2>&1 || true
fi

printf '\n› Plasma 桌面主题\n'
for theme_dir in "$REPO_DIR"/desktoptheme/*/; do
    [ -f "$theme_dir/metadata.desktop" ] || continue
    theme_name="$(basename "$theme_dir")"
    rm -rf "$PLASMA_DEST/$theme_name"
    cp -r "$theme_dir" "$PLASMA_DEST/"
    info "$theme_name"
done

printf '\n› 鼠标指针\n'
rm -rf "$ICON_DEST/material_light_cursors"
cp -r "$REPO_DIR/cursors/material_light_cursors" "$ICON_DEST/"
info "material_light_cursors"

printf '\n› 配色方案\n'
cp "$REPO_DIR/color-schemes/"*.colors "$COLOR_DEST/"
info "DeepinExpLight.colors / DeepinExpDark.colors"

printf '\n› Klassy 窗口装饰器\n'
info "需在 Klassy 设置 → Presets → Add → Import From File 手动导入："
info "  $REPO_DIR/Klassy/DeepinExp.klpw"
info "  $REPO_DIR/Klassy/DeepinExpDark.klpw"

printf '\n完成。\n'
printf '可用的 fcitx5 主题：%s\n' "${fcitx_themes[*]}"
printf '在 ~/.config/fcitx5/conf/classicui.conf 中设置 Theme=<主题名> 后重启 fcitx5。\n'

if [ -d "$ICON_DEST/DeepinExp-icons" ]; then
    printf '\n'
    warn "检测到旧版图标目录 $ICON_DEST/DeepinExp-icons"
    printf '  新版已安装为 %s。请到「系统设置 → 外观 → 图标」重新选择，\n' "$ICON_NAME"
    printf '  确认显示正常后再删除旧目录，避免残留旧图标继续被使用。\n'
fi
