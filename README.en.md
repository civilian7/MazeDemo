# MazeDemo — Opus Model Performance Comparison (Maze Game)

🌐 **[한국어 README](README.md)**

> **Purpose**: **Every time a new Claude Opus model is released**, the same
> "maze generation · solving · escape game" concept is re-implemented from scratch
> with that model, so the **capability and performance of each model can be compared**
> side by side. When a new Opus model ships, a new `claude-opus-<version>` folder is
> added and the comparison continues the same way.

## Implementations

| Folder | Model | Stack | Highlights |
|---|---|---|---|
| [`claude-opus-4-5`](claude-opus-4-5) | **Claude Opus 4.5** | VCL · Win32/64 | Top-down **2D** maze, generate/solve (SVG export), 90s escape game |
| [`claude-opus-4-8`](claude-opus-4-8) | **Claude Opus 4.8** | FireMonkey · Win64 | **First-person 3D** + 2D toggle, brick-textured walls, collectibles/key, torch fog, minimap, hints, solution trail, mouse-drag movement |

The folder name denotes the **model used to implement it**. Every implementation starts from the same requirements (see Shared Concept below).

## Shared Concept

- Maze generation: **Recursive Backtracking**
- Path finding: **BFS** shortest path
- Game: escape from entrance to exit within a time limit

## Build

- **Delphi 13 (Studio 37.0)** / `dcc64`
- Open each folder's `*.dproj` in the IDE, or build with `dcc64 <project>.dpr`
- See each folder's README for details (`claude-opus-4-8/README.md`)

> Build artifacts (`*.exe`, `*.dcu`, `__dcu/`, `__bin/`, etc.) are excluded from the
> repository. Build from source.
