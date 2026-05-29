unit Maze.Player;

interface

{$REGION 'uses'}
uses
  Maze.Core;
{$ENDREGION}

const
  /// <summary>한 미로 셀의 월드 한 변 길이.</summary>
  CELL_SIZE = 4.0;

  /// <summary>벽 큐브의 두께.</summary>
  WALL_THICKNESS = 0.4;

  /// <summary>벽 높이.</summary>
  WALL_HEIGHT = 3.0;

  /// <summary>카메라(시점) 눈높이. FMX 3D 는 위쪽이 -Y 이므로 음수로 적용합니다.</summary>
  EYE_HEIGHT = 1.7;

  /// <summary>플레이어 충돌 반지름. 2D 캐릭터(±0.34칸)가 벽을 넘지 않도록 벽 여유를 충분히 확보.</summary>
  PLAYER_RADIUS = 1.5;

  /// <summary>아이템 획득 판정 거리.</summary>
  PICKUP_RADIUS = 1.6;

  /// <summary>이동 속도(월드단위/초).</summary>
  MOVE_SPEED = 9.5;

  /// <summary>시선 회전 속도(라디안/초).</summary>
  TURN_SPEED = 3.4;

type
  /// <summary>한 프레임 동안의 플레이어 입력. 각 값은 -1..1 범위.</summary>
  TPlayerInput = record
    MoveForward: Single;
    MoveStrafe: Single;
    Turn: Single;
  end;

  /// <summary>
  /// 1인칭 자유 이동 플레이어의 상태와 물리(이동·시선·벽 충돌)를 담당합니다.
  /// FMX 에 의존하지 않으며 월드 좌표(X, Z)와 시선각(Yaw)만 제공합니다.
  /// </summary>
  TPlayerController = class
  private
    FMaze: TMazeGenerator;
    FX: Single;
    FZ: Single;
    FYaw: Single;
    function  CellXAt(const AWorldX: Single): Integer;
    function  CellYAt(const AWorldZ: Single): Integer;
    procedure MoveAxisX(const ADelta: Single);
    procedure MoveAxisZ(const ADelta: Single);
  public
    constructor Create(const AMaze: TMazeGenerator);

    /// <summary>플레이어를 입구 칸 중앙에 놓고 미로 안쪽(+Z)을 바라보게 합니다.</summary>
    procedure Reset;

    /// <summary>경과 시간(초)과 입력에 따라 시선·위치를 갱신합니다(벽 충돌 포함).</summary>
    /// <param name="ADt">직전 프레임으로부터의 경과 시간(초).</param>
    /// <param name="AInput">이번 프레임의 입력(1인칭 3D 모드용).</param>
    procedure Update(const ADt: Single; const AInput: TPlayerInput);

    /// <summary>절대 방향으로 연속 이동합니다(2D 탑다운 모드용). 이동 시 진행 방향을 바라봅니다.</summary>
    /// <param name="ADt">경과 시간(초).</param>
    /// <param name="ADirX">-1(서) .. 1(동).</param>
    /// <param name="ADirZ">-1(북) .. 1(남).</param>
    procedure MoveContinuous(const ADt: Single; const ADirX, ADirZ: Single);

    /// <summary>현재 플레이어가 위치한 격자 좌표.</summary>
    function CurrentCell: TPoint2D;

    /// <summary>플레이어가 출구 칸에 도달했는지 여부.</summary>
    function IsAtExit: Boolean;

    /// <summary>월드 X 좌표.</summary>
    property X: Single read FX;

    /// <summary>월드 Z 좌표.</summary>
    property Z: Single read FZ;

    /// <summary>시선 회전각(라디안).</summary>
    property Yaw: Single read FYaw;
  end;

implementation

{$REGION 'uses'}
uses
  System.Math;
{$ENDREGION}

{$REGION 'TPlayerController'}
constructor TPlayerController.Create(const AMaze: TMazeGenerator);
begin
  inherited Create;
  FMaze := AMaze;
end;

function TPlayerController.CellXAt(const AWorldX: Single): Integer;
begin
  Result := EnsureRange(Floor(AWorldX / CELL_SIZE), 0, FMaze.Width - 1);
end;

function TPlayerController.CellYAt(const AWorldZ: Single): Integer;
begin
  Result := EnsureRange(Floor(AWorldZ / CELL_SIZE), 0, FMaze.Height - 1);
end;

function TPlayerController.CurrentCell: TPoint2D;
begin
  Result := TPoint2D.Create(CellXAt(FX), CellYAt(FZ));
end;

procedure TPlayerController.MoveContinuous(const ADt: Single; const ADirX, ADirZ: Single);
begin
  // 진행 방향을 바라보도록 시선각 갱신(마커가 이동 방향을 가리키게)
  if (ADirX <> 0) or (ADirZ <> 0) then
  begin
    FYaw := ArcTan2(ADirX, ADirZ);
  end;

  var LStep := MOVE_SPEED * ADt;
  MoveAxisX(ADirX * LStep);
  MoveAxisZ(ADirZ * LStep);
end;

function TPlayerController.IsAtExit: Boolean;
begin
  var LCell := CurrentCell;
  var LExit := FMaze.ExitPoint;
  Result := (LCell.X = LExit.X) and (LCell.Y = LExit.Y);
end;

procedure TPlayerController.MoveAxisX(const ADelta: Single);
begin
  if ADelta = 0 then
  begin
    Exit;
  end;

  var LNewX := FX + ADelta;

  // 현재 칸 기준으로 좌/우 벽에 막히는지 검사
  var LCx := CellXAt(FX);
  var LCy := CellYAt(FZ);
  var LWalls := FMaze.WallsAt(LCx, LCy);

  if (ADelta > 0) and (wRight in LWalls) then
  begin
    var LMax := (LCx + 1) * CELL_SIZE - PLAYER_RADIUS;

    if LNewX > LMax then
    begin
      LNewX := LMax;
    end;
  end;

  if (ADelta < 0) and (wLeft in LWalls) then
  begin
    var LMin := LCx * CELL_SIZE + PLAYER_RADIUS;

    if LNewX < LMin then
    begin
      LNewX := LMin;
    end;
  end;

  // 미로 바깥으로 이탈 방지(입구/출구 개방부 포함)
  FX := EnsureRange(LNewX, PLAYER_RADIUS, FMaze.Width * CELL_SIZE - PLAYER_RADIUS);
end;

procedure TPlayerController.MoveAxisZ(const ADelta: Single);
begin
  if ADelta = 0 then
  begin
    Exit;
  end;

  var LNewZ := FZ + ADelta;

  var LCx := CellXAt(FX);
  var LCy := CellYAt(FZ);
  var LWalls := FMaze.WallsAt(LCx, LCy);

  if (ADelta > 0) and (wBottom in LWalls) then
  begin
    var LMax := (LCy + 1) * CELL_SIZE - PLAYER_RADIUS;

    if LNewZ > LMax then
    begin
      LNewZ := LMax;
    end;
  end;

  if (ADelta < 0) and (wTop in LWalls) then
  begin
    var LMin := LCy * CELL_SIZE + PLAYER_RADIUS;

    if LNewZ < LMin then
    begin
      LNewZ := LMin;
    end;
  end;

  FZ := EnsureRange(LNewZ, PLAYER_RADIUS, FMaze.Height * CELL_SIZE - PLAYER_RADIUS);
end;

procedure TPlayerController.Reset;
begin
  var LEntrance := FMaze.EntrancePoint;
  FX := LEntrance.X * CELL_SIZE + CELL_SIZE / 2;
  FZ := LEntrance.Y * CELL_SIZE + CELL_SIZE / 2;
  FYaw := 0;
end;

procedure TPlayerController.Update(const ADt: Single; const AInput: TPlayerInput);
begin
  // 시선 회전
  FYaw := FYaw + AInput.Turn * TURN_SPEED * ADt;

  // 전진/스트레이프 벡터를 시선각으로 회전
  var LForwardX := Sin(FYaw);
  var LForwardZ := Cos(FYaw);
  var LRightX := Cos(FYaw);
  var LRightZ := -Sin(FYaw);

  var LStep := MOVE_SPEED * ADt;
  var LDeltaX := (AInput.MoveForward * LForwardX + AInput.MoveStrafe * LRightX) * LStep;
  var LDeltaZ := (AInput.MoveForward * LForwardZ + AInput.MoveStrafe * LRightZ) * LStep;

  // 축을 분리해 처리하면 모서리에서 자연스럽게 미끄러집니다.
  MoveAxisX(LDeltaX);
  MoveAxisZ(LDeltaZ);
end;
{$ENDREGION}

end.
