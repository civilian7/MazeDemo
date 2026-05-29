unit Maze.Core;

interface

{$REGION 'uses'}
uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;
{$ENDREGION}

type
  /// <summary>셀의 한 변(벽)을 식별하는 열거형.</summary>
  TWall = (
    wTop,
    wRight,
    wBottom,
    wLeft
  );

  /// <summary>한 셀이 가진 벽들의 집합.</summary>
  TWalls = set of TWall;

  /// <summary>미로 격자 안의 진행 방향.</summary>
  TDirection = (
    dirNone,
    dirUp,
    dirRight,
    dirDown,
    dirLeft
  );

  /// <summary>미로의 각 셀 정보.</summary>
  TMazeCell = record
    Walls: TWalls;
    Visited: Boolean;
    IsEntrance: Boolean;
    IsExit: Boolean;
  end;

  /// <summary>정수 격자 좌표.</summary>
  TPoint2D = record
    X: Integer;
    Y: Integer;
    class function Create(const AX, AY: Integer): TPoint2D; static;
  end;

  /// <summary>
  /// 미로 생성(Recursive Backtracking)과 경로 탐색(BFS)을 담당하는 순수 데이터 컴포넌트.
  /// UI 에 의존하지 않으므로 VCL/FMX 어느 쪽에서도 그대로 재사용할 수 있습니다.
  /// </summary>
  TMazeGenerator = class(TComponent)
  private
    FWidth: Integer;
    FHeight: Integer;
    FIsGenerated: Boolean;
    FCells: array of array of TMazeCell;
    FOnMazeGenerated: TNotifyEvent;
    procedure SetWidth(const AValue: Integer);
    procedure SetHeight(const AValue: Integer);
    function  GetCell(const AX, AY: Integer): TMazeCell;
    function  IsValidCell(const AX, AY: Integer): Boolean;
    procedure RemoveWallBetween(const AX1, AY1, AX2, AY2: Integer);
    function  CollectUnvisitedNeighbors(const AX, AY: Integer): TList<TPoint2D>;
  protected
    procedure DoMazeGenerated;
  public
    constructor Create(AOwner: TComponent); override;

    /// <summary>현재 크기에 맞춰 격자를 초기화하고 모든 벽을 세웁니다.</summary>
    procedure Initialize;

    /// <summary>Recursive Backtracking 알고리즘으로 미로를 생성합니다.</summary>
    procedure Generate;

    /// <summary>임의의 두 칸 사이 최단 경로를 BFS 로 구합니다. 경로가 없으면 빈 배열.</summary>
    /// <param name="AStart">시작 칸 좌표.</param>
    /// <param name="AGoal">목표 칸 좌표.</param>
    /// <returns>시작→목표 순서의 좌표 배열(시작·목표 포함).</returns>
    function FindPath(const AStart, AGoal: TPoint2D): TArray<TPoint2D>;

    /// <summary>입구(좌상단)에서 출구(우하단)까지의 최단 경로를 구합니다.</summary>
    function FindSolution: TArray<TPoint2D>;

    /// <summary>특정 칸에서 한 방향으로 이동할 때 벽에 막히지 않는지 확인합니다.</summary>
    function CanMove(const AX, AY: Integer; const ADirection: TDirection): Boolean;

    /// <summary>지정한 칸의 벽 집합. 범위를 벗어나면 사방이 막힌 것으로 간주합니다.</summary>
    function WallsAt(const AX, AY: Integer): TWalls;

    /// <summary>입구 칸 좌표(좌상단).</summary>
    function EntrancePoint: TPoint2D;

    /// <summary>출구 칸 좌표(우하단).</summary>
    function ExitPoint: TPoint2D;

    /// <summary>셀 접근자.</summary>
    property Cells[const AX, AY: Integer]: TMazeCell read GetCell;

    /// <summary>미로 생성 여부.</summary>
    property IsGenerated: Boolean read FIsGenerated;
  published
    property Width: Integer read FWidth write SetWidth default 15;
    property Height: Integer read FHeight write SetHeight default 15;
    property OnMazeGenerated: TNotifyEvent read FOnMazeGenerated write FOnMazeGenerated;
  end;

const
  MIN_MAZE_SIZE = 3;
  MAX_MAZE_SIZE = 60;

implementation

{$REGION 'uses'}
uses
  System.Math;
{$ENDREGION}

{$REGION 'TPoint2D'}
class function TPoint2D.Create(const AX, AY: Integer): TPoint2D;
begin
  Result.X := AX;
  Result.Y := AY;
end;
{$ENDREGION}

{$REGION 'TMazeGenerator'}
constructor TMazeGenerator.Create(AOwner: TComponent);
begin
  inherited;
  FWidth := 15;
  FHeight := 15;
  FIsGenerated := False;
end;

function TMazeGenerator.CanMove(const AX, AY: Integer; const ADirection: TDirection): Boolean;
begin
  var LWalls := WallsAt(AX, AY);

  case ADirection of
    dirUp:
    begin
      Result := not (wTop in LWalls);
    end;
    dirRight:
    begin
      Result := not (wRight in LWalls);
    end;
    dirDown:
    begin
      Result := not (wBottom in LWalls);
    end;
    dirLeft:
    begin
      Result := not (wLeft in LWalls);
    end;
  else
    Result := False;
  end;
end;

function TMazeGenerator.CollectUnvisitedNeighbors(const AX, AY: Integer): TList<TPoint2D>;
begin
  Result := TList<TPoint2D>.Create;

  // 상
  if (AY - 1 >= 0) and not FCells[AY - 1, AX].Visited then
  begin
    Result.Add(TPoint2D.Create(AX, AY - 1));
  end;

  // 우
  if (AX + 1 < FWidth) and not FCells[AY, AX + 1].Visited then
  begin
    Result.Add(TPoint2D.Create(AX + 1, AY));
  end;

  // 하
  if (AY + 1 < FHeight) and not FCells[AY + 1, AX].Visited then
  begin
    Result.Add(TPoint2D.Create(AX, AY + 1));
  end;

  // 좌
  if (AX - 1 >= 0) and not FCells[AY, AX - 1].Visited then
  begin
    Result.Add(TPoint2D.Create(AX - 1, AY));
  end;
end;

procedure TMazeGenerator.DoMazeGenerated;
begin
  if Assigned(FOnMazeGenerated) then
  begin
    FOnMazeGenerated(Self);
  end;
end;

function TMazeGenerator.EntrancePoint: TPoint2D;
begin
  Result := TPoint2D.Create(0, 0);
end;

function TMazeGenerator.ExitPoint: TPoint2D;
begin
  Result := TPoint2D.Create(FWidth - 1, FHeight - 1);
end;

function TMazeGenerator.FindPath(const AStart, AGoal: TPoint2D): TArray<TPoint2D>;

  function PointToKey(const AP: TPoint2D): string;
  begin
    Result := Format('%d,%d', [AP.X, AP.Y]);
  end;

begin
  Result := [];

  if not FIsGenerated then
  begin
    Exit;
  end;

  if not IsValidCell(AStart.X, AStart.Y) or not IsValidCell(AGoal.X, AGoal.Y) then
  begin
    Exit;
  end;

  var LQueue := TQueue<TPoint2D>.Create;
  var LParent := TDictionary<string, TPoint2D>.Create;
  try
    LQueue.Enqueue(AStart);
    LParent.Add(PointToKey(AStart), TPoint2D.Create(-1, -1));

    var LFound := False;

    while LQueue.Count > 0 do
    begin
      var LCurrent := LQueue.Dequeue;

      if (LCurrent.X = AGoal.X) and (LCurrent.Y = AGoal.Y) then
      begin
        LFound := True;
        Break;
      end;

      // 네 방향 후보
      var LCandidates: TArray<TPoint2D> := [
        TPoint2D.Create(LCurrent.X, LCurrent.Y - 1),
        TPoint2D.Create(LCurrent.X + 1, LCurrent.Y),
        TPoint2D.Create(LCurrent.X, LCurrent.Y + 1),
        TPoint2D.Create(LCurrent.X - 1, LCurrent.Y)
      ];

      var LDirs: TArray<TDirection> := [dirUp, dirRight, dirDown, dirLeft];

      for var I := 0 to High(LCandidates) do
      begin
        if not CanMove(LCurrent.X, LCurrent.Y, LDirs[I]) then
        begin
          Continue;
        end;

        var LNext := LCandidates[I];
        var LKey := PointToKey(LNext);

        if not LParent.ContainsKey(LKey) then
        begin
          LParent.Add(LKey, LCurrent);
          LQueue.Enqueue(LNext);
        end;
      end;
    end;

    if not LFound then
    begin
      Exit;
    end;

    // 목표에서 시작으로 역추적
    var LReverse := TList<TPoint2D>.Create;
    try
      var LTrace := AGoal;

      while (LTrace.X >= 0) and (LTrace.Y >= 0) do
      begin
        LReverse.Add(LTrace);

        var LKey := PointToKey(LTrace);

        if LParent.ContainsKey(LKey) then
        begin
          LTrace := LParent[LKey];
        end
        else
        begin
          Break;
        end;
      end;

      // 시작→목표 순서로 뒤집어 반환
      SetLength(Result, LReverse.Count);

      for var I := 0 to LReverse.Count - 1 do
      begin
        Result[I] := LReverse[LReverse.Count - 1 - I];
      end;
    finally
      LReverse.Free;
    end;
  finally
    LQueue.Free;
    LParent.Free;
  end;
end;

function TMazeGenerator.FindSolution: TArray<TPoint2D>;
begin
  Result := FindPath(EntrancePoint, ExitPoint);
end;

procedure TMazeGenerator.Generate;
begin
  Initialize;
  Randomize;

  var LStack := TStack<TPoint2D>.Create;
  try
    var LCurrent := TPoint2D.Create(0, 0);
    FCells[LCurrent.Y, LCurrent.X].Visited := True;
    LStack.Push(LCurrent);

    while LStack.Count > 0 do
    begin
      LCurrent := LStack.Pop;

      var LNeighbors := CollectUnvisitedNeighbors(LCurrent.X, LCurrent.Y);
      try
        if LNeighbors.Count > 0 then
        begin
          LStack.Push(LCurrent);

          var LIndex := RandomRange(0, Integer(LNeighbors.Count));
          var LNext := LNeighbors[LIndex];
          RemoveWallBetween(LCurrent.X, LCurrent.Y, LNext.X, LNext.Y);

          FCells[LNext.Y, LNext.X].Visited := True;
          LStack.Push(LNext);
        end;
      finally
        LNeighbors.Free;
      end;
    end;

    FIsGenerated := True;
    DoMazeGenerated;
  finally
    LStack.Free;
  end;
end;

function TMazeGenerator.GetCell(const AX, AY: Integer): TMazeCell;
begin
  if not IsValidCell(AX, AY) then
  begin
    raise ERangeError.CreateFmt('잘못된 셀 좌표 접근: (%d, %d)', [AX, AY]);
  end;

  Result := FCells[AY, AX];
end;

procedure TMazeGenerator.Initialize;
begin
  SetLength(FCells, FHeight, FWidth);

  for var Y := 0 to FHeight - 1 do
  begin
    for var X := 0 to FWidth - 1 do
    begin
      FCells[Y, X].Walls := [wTop, wRight, wBottom, wLeft];
      FCells[Y, X].Visited := False;
      FCells[Y, X].IsEntrance := False;
      FCells[Y, X].IsExit := False;
    end;
  end;

  // 입구(좌상단): 왼쪽 벽 개방
  FCells[0, 0].IsEntrance := True;
  Exclude(FCells[0, 0].Walls, wLeft);

  // 출구(우하단): 오른쪽 벽 개방
  FCells[FHeight - 1, FWidth - 1].IsExit := True;
  Exclude(FCells[FHeight - 1, FWidth - 1].Walls, wRight);
end;

function TMazeGenerator.IsValidCell(const AX, AY: Integer): Boolean;
begin
  Result := FIsGenerated and
            (Length(FCells) > 0) and
            (AY >= 0) and (AY < Length(FCells)) and
            (AX >= 0) and (AX < Length(FCells[0]));
end;

procedure TMazeGenerator.RemoveWallBetween(const AX1, AY1, AX2, AY2: Integer);
begin
  if AX2 > AX1 then
  begin
    Exclude(FCells[AY1, AX1].Walls, wRight);
    Exclude(FCells[AY2, AX2].Walls, wLeft);
  end
  else
  if AX2 < AX1 then
  begin
    Exclude(FCells[AY1, AX1].Walls, wLeft);
    Exclude(FCells[AY2, AX2].Walls, wRight);
  end
  else
  if AY2 > AY1 then
  begin
    Exclude(FCells[AY1, AX1].Walls, wBottom);
    Exclude(FCells[AY2, AX2].Walls, wTop);
  end
  else
  if AY2 < AY1 then
  begin
    Exclude(FCells[AY1, AX1].Walls, wTop);
    Exclude(FCells[AY2, AX2].Walls, wBottom);
  end;
end;

procedure TMazeGenerator.SetHeight(const AValue: Integer);
begin
  if (AValue >= MIN_MAZE_SIZE) and (AValue <= MAX_MAZE_SIZE) then
  begin
    FHeight := AValue;
    FIsGenerated := False;
  end;
end;

procedure TMazeGenerator.SetWidth(const AValue: Integer);
begin
  if (AValue >= MIN_MAZE_SIZE) and (AValue <= MAX_MAZE_SIZE) then
  begin
    FWidth := AValue;
    FIsGenerated := False;
  end;
end;

function TMazeGenerator.WallsAt(const AX, AY: Integer): TWalls;
begin
  if IsValidCell(AX, AY) then
  begin
    Result := FCells[AY, AX].Walls;
  end
  else
  begin
    Result := [wTop, wRight, wBottom, wLeft];
  end;
end;
{$ENDREGION}

end.
