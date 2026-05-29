# MazeDemo — LLM 성능 비교 데모 (미로 찾기)

동일한 "미로 생성·해답·탈출 게임" 컨셉을 서로 다른 모델이 구현한 결과를 나란히 비교하는 Delphi 데모 모음입니다.

| 폴더 | 모델 | 스택 | 특징 |
|---|---|---|---|
| [`claude-opus-4-5`](claude-opus-4-5) | **Claude Opus 4.5** | VCL · Win32/64 | 위에서 내려다보는 **2D** 미로, 생성/해답(SVG 내보내기), 90초 탈출 게임 |
| [`claude-opus-4-8`](claude-opus-4-8) | **Claude Opus 4.8** | FireMonkey · Win64 | **1인칭 3D** + 2D 토글, 벽돌 텍스처, 수집품·열쇠, 안개(토치), 미니맵, 힌트, 해답 트레일, 마우스 드래그 이동 |

## 공통 컨셉

- 미로 생성: **Recursive Backtracking**
- 해답 탐색: **BFS** 최단 경로
- 게임: 입구→출구 탈출, 제한시간

## 빌드 환경

- **Delphi 13 (Studio 37.0)** / `dcc64`
- 각 폴더의 `*.dproj` 를 IDE로 열거나, `dcc64 <project>.dpr` 로 빌드
- 자세한 내용은 각 폴더의 README 참조 (`claude-opus-4-8/README.md`)

> 빌드 산출물(`*.exe`, `*.dcu`, `__dcu/`, `__bin/` 등)은 저장소에서 제외됩니다. 소스에서 빌드하세요.
