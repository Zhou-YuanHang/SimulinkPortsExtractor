# PortExtractor — Simulink 端口提取工具

提取 Simulink 模型的 Inport / Outport 端口信息，输出到 Excel 文件，为 CodeMapping 预留指定数据类型 / StorageClass / Identifier 列。

## 文件结构

| 文件 | 说明 |
|------|------|
| `PortExtractor.m` | 核心函数，命令行调用 |
| `PortExtractorGUI.m` | 图形界面，交互式操作 |
| `README.md` | 本文件 |

## 函数用法

```matlab
load_system('myModel')

% 提取根模型层的端口
PortExtractor('myModel', 1)

% 提取根模型 + 下一级子系统层
PortExtractor('myModel', 2)

% 含 Trigger/Enable 端口
PortExtractor('myModel', 1, true)

% 从指定子系统开始提取
PortExtractor('myModel', 1, false, 'Subsys1/Subsys2')
```

### 参数说明

| 参数 | 必选 | 说明 |
|------|:----:|------|
| `modelName` | ✅ | 模型名称（不含 .slx），需已加载 |
| `searchDepth` | ✅ | 正整数。1=仅指定层，2=指定层+下一层… |
| `includeTriggerEnable` | ❌ | 是否提取 TriggerPort / EnablePort（默认 false） |
| `startSubsystem` | ❌ | 起始子系统路径，留空=根模型 |

### 输出

在当前目录生成 `ports_<modelName>.xlsx`，包含两个 Sheet：

**Inputs** — 所有 Inport（及可选的 Trigger/Enable）

**Outputs** — 所有 Outport

| 序号 | 端口名称 | 数据类型 | StorageClass | Identifier | HeaderFile | DefinitionFile |
|:---:|:--------:|:--------:|:-----------:|:---------:|:---------:|:-------------:|
| 1 | In1 | double | (留空) | (留空) | (留空) | (留空) |
| 2 | In2 | uint8 | (留空) | (留空) | (留空) | (留空) |

> "StorageClass"、"Identifier"、"HeaderFile"、"DefinitionFile" 四列留空，供 CodeMapping 手动填写。

## GUI 用法

```matlab
PortExtractorGUI
```

界面布局：

```
┌──────────────────────────────────────────────┐
│  PortExtractor — Simulink 端口提取工具        │
│                                              │
│  模型名称:  [________________________] [浏览] │
│                                              │
│  起始子系统: [________________] [选择子系统]   │
│                          (留空=根模型)        │
│  搜索深度:  [1]  (1=仅当前层)                 │
│                          ☐ 包含触发/使能      │
│                                              │
│  ☐ 文件名添加时间戳                           │
│                                              │
│  [========== 提  取  端  口 ==========]       │
│                                              │
│  状态: 等待操作...                            │
│                                              │
│  ─ 结果摘要 ─                                │
│  输入端口: -- 个    输出端口: -- 个           │
│  输出文件: --                                │
└──────────────────────────────────────────────┘
```

操作步骤：

1. 输入模型名，或点「浏览」选择 `.slx` 文件
2. （可选）点「选择子系统」选取起始子系统；留空=从根模型开始
3. 设置搜索深度（1=仅当前层，2=当前+下一层…）
4. （可选）勾选「包含触发/使能」
5. 点「提取端口」

## 提取逻辑

直接使用 `find_system` 按 `BlockType` 精准搜索，无需手动数深度：

```matlab
% 系统选项必须放在 BlockType 之前
sysOpts = {'SearchDepth', searchDepth, 'FollowLinks', 'on'};

find_system(searchRoot, sysOpts{:}, 'BlockType', 'Inport')
find_system(searchRoot, sysOpts{:}, 'BlockType', 'Outport')
% 可选：
find_system(searchRoot, sysOpts{:}, 'BlockType', 'TriggerPort')
find_system(searchRoot, sysOpts{:}, 'BlockType', 'EnablePort')
```

子系统列表使用 `'Mask', 'off'` 排除 Compare To Constant 等掩码块：

```matlab
find_system(modelStr, 'BlockType', 'SubSystem', 'Mask', 'off')
```

## 依赖

- MATLAB R2019b 或更高版本（`writetable` 多 Sheet 支持）
- Simulink 模块

## 注意事项

- 模型必须已加载（GUI 自动处理）
- 总线信号当作整体提取，不展平
- 不考虑 Model Reference 的内部结构
