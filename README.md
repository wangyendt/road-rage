# ROAD RAGE · 极限狂飙 v2.0

可从菜单玩到结算的 **3D 单机摩托竞速格斗游戏**。原创程序化模型、合成音效和电子配乐；Godot 4，面向 Apple Silicon Mac。

## 立即开玩

- 双击 `启动游戏.command`，或 `builds/Road Rage.app`；独立应用内含运行时，无需联网或打开 Godot。
- 开发时导入 `project.godot`，按 F5。
- 本机目录：`/Users/wayne/Documents/work/code/game/road-rage`。
- 构建目标 macOS 13+ / arm64；验证机器为 M1 Max、macOS 26.6、Godot 4.7.2。

开始游戏后先选择场景、1–15 名 AI 和 1–5 级难度，再开始竞赛。

## v2 新功能

| 场景 | 长度 | 风格 |
|---|---|---|
| 港湾高架 | 5.4 km | 落日海湾、城市、跨海桥梁 |
| 赤岩峡谷 | 4.8 km | 砂岩山脊、仙人掌、连续弯道 |
| 雪岭林道 | 5.2 km | 针叶林、雪峰、冷色山地 |
| 霓虹都市 | 6.2 km | 夜间都市、灯光隧廊、密集车流 |

- 最多 16 人同场：玩家加 15 名原创 AI，具有头像、姓名、年龄、城市、座驾、风格和不同驾驶属性。
- 点击实时排行榜中的车手，或按 Tab 查看档案；资料页暂停比赛。
- 全程路线小地图显示所有车手；真实 3D 后视镜显示身后的道路与追兵。
- 5 级难度调整反应、预判、操控、进攻、氮气和速度；最高级主动避让攻击、抓失误、末段冲刺。
- 双向非线性追赶：落后 AI 加速、领先 AI 适度收速，落后玩家获得有限引擎及氮气恢复帮助；不瞬移、不锁死名次，也不保送胜利。
- 玩家和 AI 均有完整恢复动画：撞飞、翻滚落地、起身、跑回摩托、扶车上车。恢复期间比赛继续。
- 11 项键盘动作支持改键、冲突交换、恢复默认和自动保存；HUD 提示同步变化。

保留氮气尾焰、速度线、挥击弧光、火花、命中停顿、震动、分层冲击音；交通碰撞、极限擦身、补给、连击、计分、结算和重开。

## 操作

| 动作 | 默认键盘 | 手柄映射 |
|---|---|---|
| 转向 | A / D 或左右方向键 | 左摇杆 |
| 刹车 | S / 下方向键 | LT |
| 氮气 | 按住空格 | RT / A |
| 左 / 右攻击 | J / K | LB / RB |
| 自动选边攻击 | Shift | — |
| 暂停 / 继续 | Esc / P | Start |
| 车手信息 | Tab | Back |
| 小地图 / 后视镜 | V / B | — |
| 重开（结算） | R | 菜单选择 |
| 全屏 / 静音 | F11 / M | — |
| 菜单 | 鼠标或方向键 + Enter | 十字键 / A |

改键入口：主菜单或暂停 → 游戏设置 → 快捷键设置。支持单键；方向键、Esc、Enter、F11、M、R 为保留键。手柄暂为固定映射，未用实体手柄验证。Mac 上 F11 可能需要同时按 Fn。

自动油门，无需持续按前进键。靠近对手左右出击，连续两次命中可击倒。橙色攻击预警出现时拉开距离或先出手打断。绿色十字修复车体，青色圆环补充氮气；氮气耗尽后需松开按键重新蓄力。

## 开发与测试

```text
scripts/main.gd           状态机、比赛、碰撞、攻击、存档
scripts/world.gd          四场景、循环道路、光照、交通
scripts/bike.gd           摩托、关节角色、攻击与恢复动画
scripts/hud.gd            菜单、档案、改键、地图、排行榜
scripts/game_data.gd      赛道、人物与难度数据
scripts/race_director.gd  有上限的双向非线性追赶
scripts/controls.gd       InputMap、按键交换与保存
scripts/audio.gd          音效、引擎、电子配乐
scripts/fx.gd             火花与挥击弧光
shaders/                 路面、窗户、屏幕效果
assets/                  原创音频、纹理、图标及许可
```

```bash
./tools/test.sh
./tools/build_macos.sh
# 满员最高难度自动驾驶，仅供回归验证，不写入个人成绩：
/Applications/Godot.app/Contents/MacOS/Godot --path . -- \
  --autoplay --ai=15 --level=5 --course=3 --quit-after=110
```

测试脚本覆盖 111 项逻辑和真实渲染输入断言。详情见 `docs/QA.md`；策略说明见 `docs/DESIGN.md`。`--course=0..3` 对应上表顺序。

构建需要已安装 Godot 与 Xcode 命令行工具，可用 `GODOT_BIN` 指定引擎。输出 `builds/Road Rage.app` 和 `builds/RoadRage-macOS-AppleSilicon.zip`。

构建将本机 Godot arm64 引擎与 PCK 打包，免下载导出模板。编辑器运行时比正式 release template 大，游戏仍以独立游戏模式启动。使用 ad-hoc 本地签名，未进行 Apple Developer ID 公证。

音频再生成：`python3 tools/generate_audio.py`，仅再生成需要 NumPy；游玩无需 Python。含引擎、挥击、碰撞、氮气、补给、倒计时、结算和 132 BPM 原创电子配乐。

## 范围

原创风格化街机实现，并非原版资产逐项复制。包含一台玩家摩托、四种场景和十五名 AI；尚无联网多人、车辆商店、开放世界、锦标赛生涯或真实驾驶物理。

无账号、联网服务、广告或内购。Godot 及第三方许可见 `assets/GODOT_LICENSES.txt`。
