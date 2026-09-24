# Road Rage

公路摩托竞速与格斗游戏，暂定名。使用 Godot 4，面向 Apple Silicon Mac。

## 当前状态

仅初始化项目骨架和本地 Git 仓库。未实现游戏玩法、画面或音效；2D/3D 方向待确认。

## 打开项目

1. 启动 Godot 4 标准版。
2. 在项目管理器点击「导入」，选择本仓库根目录下的 `project.godot`。
3. 导入并编辑。主场景为 `scenes/main.tscn`；目前运行会显示空白背景，这是预期行为。

暂用 Compatibility 渲染器，后续根据美术方向调整。

## 目录

- `assets/`：原创或具有适当许可的美术、音效、字体等资源。
- `scenes/`：Godot 场景。
- `scripts/`：GDScript 脚本。
- `docs/`：设计与开发文档。

Godot 自动生成的 `.godot/` 缓存不纳入版本控制；Godot `.uid` 文件应提交。
构建产物放入 `builds/` 或 `exports/`，这些目录已被忽略。

## 待确认

- 复古 2D / 伪 3D，或现代 3D。
- 操作方式、战斗机制与首个可玩版本范围。
- 美术风格与资源来源。
