# MazeDemo3D — FMX 1인칭 3D 미로 게임 설계서

작성일: 2026-05-29
대상: Win64 / Delphi 13 (Studio 37.0) / FireMonkey(FMX)

## 1. 배경 & 목적

기존 `claude-opus-4-5` 폴더(Opus 4.5)의 VCL 2D 미로 데모와 동일한 컨셉(미로 생성·해답·탈출 게임)을
유지하되, **1인칭 시점 실제 3D**로 재구성하여 Opus 4.8의 구현 성능을 비교한다.

- 미로 생성/해답(BFS) 코어 로직은 UI 비의존이므로 **재사용**한다.
- 3D 렌더링(FMX `TViewport3D`), 자유 이동(FPS) 조작, 게임 요소를 새로 구현한다.
- 결과물 위치: `D:\PROJECTS\MazeDemo\claude-opus-4-8`

## 2. 확정된 요구사항

- **렌더링**: FireMonkey 실제 3D (큐브 메쉬 벽 + 카메라 + 조명).
- **조작**: 자유 이동 FPS — `W/S` 전후진, `A/D` 스트레이프, `←/→`(또는 마우스) 시선 회전.
- **게임 요소**(모두 포함):
  - 미니맵 HUD (fog of war)
  - 수집품/열쇠 (열쇠로 출구 잠금 해제, 코인은 점수)
  - 안개/제한 시야 (카메라 토치 라이트 + 어두운 ambient)
  - 자동 힌트 (`H` 키, BFS 다음 방향 표시)
  - 제한시간 타이머(기본 90초) + 출구 도달 승리(클리어 타임 기록)

## 3. 아키텍처 (유닛별 단일 책임)

| 유닛 | 책임 | 의존 |
|---|---|---|
| `Maze.Core.pas` | `TMazeGenerator` — 미로 생성(Recursive Backtracking), BFS 해답(입구→출구), **임의 칸→출구 BFS**(힌트용). 순수 데이터 | RTL only |
| `Maze.Scene.pas` | `TMazeScene` — 코어 미로로부터 3D 씬 구성: 바닥/천장/벽 큐브, 코인·열쇠 3D 오브젝트, 카메라 토치 라이트. `Build`/`Clear`/`Update(dt)`(코인 회전) | FMX 3D |
| `Maze.Player.pas` | `TPlayerController` — 월드 좌표(X,Z)·시선각(Yaw)·눈높이, `Update(dt, Input)` 이동 적분 + **벽 충돌 판정**(축 분리, 반지름 기반), `ApplyToCamera` | Maze.Core |
| `Maze.Minimap.pas` | `TMinimapRenderer` — HUD 미니맵을 `TCanvas`에 렌더: 탐험 칸(fog of war), 플레이어 위치·방향 삼각형, 코인·열쇠·출구 마커, 힌트 방향 화살표 | FMX Canvas |
| `MainForm.pas/.fmx` | 게임 오케스트레이션: `TViewport3D`·`TCamera`·게임 루프 타이머(~60fps)·입력 상태·게임 상태머신·설정 UI·HUD 라벨 | 위 전부 |

### 좌표계 규약
- 미로 격자 `(cx, cy)` → 월드 `(x, z)`: `x = cx * CELL + CELL/2`, `z = cy * CELL + CELL/2`.
- Y축은 높이. 바닥 y=0, 벽 높이 `WALL_H`, 카메라 눈높이 `EYE_H`.
- 셀 크기 `CELL = 4.0`, 벽 두께 `WALL_T = 0.4`, 벽 높이 `WALL_H = 3.0`, 눈높이 `EYE_H = 1.6`, 플레이어 반지름 `R = 0.9`.

## 4. 3D 씬 구성 (`Maze.Scene`)

- 루트 `TDummy`(SceneRoot) 아래 모든 오브젝트를 두어 재생성 시 일괄 정리.
- **바닥**: `TPlane`(또는 큰 `TCube`), 어두운 톤 머티리얼.
- **천장**: `TPlane`, 바닥과 다른 톤(선택). 폐쇄감 부여.
- **벽**: 셀의 각 벽(`wTop/wRight/wBottom/wLeft`)이 존재하면 얇은 `TCube` 생성.
  - 중복 방지: `wRight`/`wBottom`만 명시 생성 + 외곽(`x=0`의 `wLeft`, `y=0`의 `wTop`) 처리. 또는 단순히 모든 벽을 그리되 인접 셀과 공유되는 내부 벽은 한 번만 생성하도록 `wTop`,`wLeft`는 경계에서만, `wRight`,`wBottom`은 항상 생성.
- **입구/출구 마커**: 출구 칸에 빛나는 발광 머티리얼 기둥/포털.
- **수집품**: 코인 `TSphere`(금색, 회전 애니메이션), 열쇠 1개(`TCylinder`+`TCube` 조합 또는 단순 발광 오브젝트).
- **조명**:
  - 약한 ambient(`TLight` 비활성 또는 매우 낮은 환경광).
  - 카메라 자식 `TLight ltPoint`(토치) — 먼 벽은 자연 감쇠로 어두워져 시야 제한 효과.

## 5. 플레이어 & 충돌 (`Maze.Player`)

- 상태: `FX, FZ: Single`(월드), `FYaw: Single`(라디안), 입구 칸 중심에서 시작.
- 입력 구조체 `TPlayerInput`: `Forward, Strafe: Single`(-1..1), `Turn: Single`(-1..1).
- `Update(dt)`:
  1. `FYaw += Turn * TURN_SPEED * dt`.
  2. 전진/스트레이프 벡터를 Yaw로 회전해 이동량 `dx, dz` 계산.
  3. **축 분리 충돌**: X축 먼저 시도→충돌이면 X 취소, 이어서 Z축 시도→충돌이면 Z 취소. 모서리 미끄러짐 자연 처리.
- 충돌 판정 `CanOccupy(x, z)`: 플레이어 반지름 R 원이 인접 벽(셀 경계의 큐브)과 겹치지 않는지 검사. 현재 칸 및 이웃 칸의 존재하는 벽 세그먼트에 대해 원-사각형 근접 검사.
- `ApplyToCamera(cam)`: 카메라 위치 `(FX, EYE_H, FZ)`, 회전 `RotationAngle.Y = FYaw(도)`.

## 6. 게임 요소 상세

- **열쇠/출구**: 열쇠 미획득 시 출구 포털은 잠금(붉은 톤), 도달해도 승리 안 됨. 획득 시 녹색으로 변하고 통과 시 승리.
- **코인**: 점수. 전부 모을 필요 없음(보너스). HUD `코인 N/Total`.
- **획득 판정**: 매 틱 플레이어-아이템 수평거리 < `PICK_R`이면 획득, 씬에서 제거.
- **미니맵 fog of war**: 플레이어가 방문한 칸 + 인접 가시 칸만 그린다. 방문 집합을 유지.
- **힌트**: `H` 키 → `Maze.Core`의 임의 칸 BFS로 현재 칸→출구 경로 → 첫 진행 방향을 미니맵에 화살표로 3초간 표시. (열쇠 미획득 시 열쇠 위치로 안내하는 것도 가능하나 1차는 출구 방향.)
- **상태머신** `TGameState = (gsReady, gsPlaying, gsWon, gsLost)`.
- **타이머**: 기본 90초. `gsPlaying`에서 1초마다 감소, 0이면 `gsLost`. 10초 이하 빨간 표시.

## 7. 게임 루프 & 데이터 흐름

```
설정(가로/세로) → Generate → Core 격자 생성 → Scene.Build → Player.Reset(입구)
→ 상태 gsPlaying, 타이머 시작
게임 루프 타이머(~16ms):
  dt 계산 → 눌린 키로 TPlayerInput 구성 → Player.Update(dt) (충돌 포함)
  → Player.ApplyToCamera → Scene.Update(dt)(코인 회전)
  → 아이템 획득 체크 → 방문칸 갱신 → HUD/미니맵 갱신
  → 출구(잠금해제) 도달? gsWon : 타이머 0? gsLost
```

- dt: `TStopwatch`로 프레임 간 경과(초). 게임 루프는 `TTimer`(Interval 16) 사용.
- 1초 타이머는 별도 `TTimer`(Interval 1000) 또는 누적 dt로 처리. → 누적 dt 방식 채택(타이머 1개).

## 8. UI / 화면

- 상단 도구 패널: 가로/세로 입력(`TSpinBox`/`TEdit`+버튼), `미로 생성`, `게임 시작/중지`, 타이머·코인·열쇠 상태 라벨, `힌트(H)` 안내.
- 중앙: `TViewport3D`(Align=Client) — 3D 뷰.
- 우상단 오버레이: `TPaintBox` 미니맵.
- 하단: 상태/안내 라벨(기존 데모처럼 생성·소요시간 로깅).

## 9. 빌드 / 규약

- **FMX, Win64, Delphi 13(dcc64 37.0)**.
- `.fmx`는 최소 빈 폼. 모든 컨트롤·3D 오브젝트는 런타임 코드 생성(생성 직후 `Parent` 우선 설정).
- 글로벌 Delphi 컨벤션 전면 적용: 인라인 변수 우선·`L`/`A`/`F` 접두어·Allman·dot-namespace 유닛명·1행 1변수·`{$REGION}` 클래스 단위 등.
- `.pas`/`.dpr`/`.dproj` UTF-8 BOM+CRLF, `.fmx` UTF-8.
- 컴파일 검증: `dcc64`로 빌드해 에러/힌트 제거.

## 10. 비교 포인트 (성능 데모)

- 동일 미로 생성 알고리즘으로 생성 시간 측정·표시(기존 데모와 비교).
- 2D→3D 전환에 따른 코드 규모·구조·게임성 차이를 한눈에 비교.

## 11. YAGNI (이번 범위 제외)

- 적(추격 AI), 멀티 레벨, 사운드, 세이브/로드, SVG 내보내기(2D 전용 기능)는 제외.
- 마우스 룩은 키보드 시선 회전을 기본으로 하고, 여유 시 보조로만 추가.
