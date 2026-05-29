unit MazeGenerator;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  /// <summary>셀의 벽 상태를 나타내는 집합</summary>
  TWall = (wTop, wRight, wBottom, wLeft);
  TWalls = set of TWall;

  /// <summary>미로의 각 셀 정보</summary>
  TMazeCell = record
    Walls: TWalls;
    Visited: Boolean;
    IsPath: Boolean;      // 해답 경로 여부
    IsEntrance: Boolean;  // 입구 여부
    IsExit: Boolean;      // 출구 여부
  end;

  /// <summary>좌표를 나타내는 레코드</summary>
  TPoint2D = record
    X, Y: Integer;
    class function Create(AX, AY: Integer): TPoint2D; static;
  end;

  /// <summary>이동 방향</summary>
  TDirection = (dirUp, dirDown, dirLeft, dirRight);

  /// <summary>미로 생성 및 해답 찾기를 담당하는 핵심 컴포넌트</summary>
  TMazeGenerator = class(TComponent)
  private
    FWidth: Integer;
    FHeight: Integer;
    FIsGenerated: Boolean;
    FCells: array of array of TMazeCell;
    FSolutionPath: TList<TPoint2D>;
    FOnMazeGenerated: TNotifyEvent;
    FOnSolutionFound: TNotifyEvent;
    FPlayerX: Integer;
    FPlayerY: Integer;

    procedure SetWidth(const Value: Integer);
    procedure SetHeight(const Value: Integer);
    function GetCell(X, Y: Integer): TMazeCell;
    procedure SetCell(X, Y: Integer; const Value: TMazeCell);
    function IsValidCell(X, Y: Integer): Boolean;
    procedure RemoveWall(X1, Y1, X2, Y2: Integer);
    function GetUnvisitedNeighbors(X, Y: Integer): TList<TPoint2D>;
  protected
    procedure DoMazeGenerated;
    procedure DoSolutionFound;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>미로 초기화</summary>
    procedure Initialize;

    /// <summary>Recursive Backtracking 알고리즘으로 미로 생성</summary>
    procedure Generate;

    /// <summary>BFS 알고리즘으로 해답 찾기</summary>
    function FindSolution: Boolean;

    /// <summary>해답 경로 초기화</summary>
    procedure ClearSolution;

    /// <summary>미로를 SVG 문자열로 변환</summary>
    function ToSVG(CellSize: Integer = 20; WallThickness: Integer = 2): string;

    /// <summary>SVG를 파일로 저장</summary>
    procedure SaveToSVG(const FileName: string; CellSize: Integer = 20; WallThickness: Integer = 2);

    /// <summary>플레이어 위치 초기화 (시작 위치로)</summary>
    procedure InitializePlayer;

    /// <summary>특정 방향으로 이동 가능한지 확인</summary>
    function CanMovePlayer(Direction: TDirection): Boolean;

    /// <summary>플레이어를 특정 방향으로 이동</summary>
    function MovePlayer(Direction: TDirection): Boolean;

    /// <summary>플레이어가 출구에 도달했는지 확인</summary>
    function IsPlayerAtExit: Boolean;

    /// <summary>셀 접근자</summary>
    property Cells[X, Y: Integer]: TMazeCell read GetCell write SetCell;

    /// <summary>해답 경로</summary>
    property SolutionPath: TList<TPoint2D> read FSolutionPath;

    /// <summary>미로 생성 여부</summary>
    property IsGenerated: Boolean read FIsGenerated;

    /// <summary>플레이어 X 위치</summary>
    property PlayerX: Integer read FPlayerX;

    /// <summary>플레이어 Y 위치</summary>
    property PlayerY: Integer read FPlayerY;
  published
    property Width: Integer read FWidth write SetWidth default 10;
    property Height: Integer read FHeight write SetHeight default 10;
    property OnMazeGenerated: TNotifyEvent read FOnMazeGenerated write FOnMazeGenerated;
    property OnSolutionFound: TNotifyEvent read FOnSolutionFound write FOnSolutionFound;
  end;

implementation

{ TPoint2D }

class function TPoint2D.Create(AX, AY: Integer): TPoint2D;
begin
  Result.X := AX;
  Result.Y := AY;
end;

{ TMazeGenerator }

constructor TMazeGenerator.Create(AOwner: TComponent);
begin
  inherited;
  FWidth := 10;
  FHeight := 10;
  FIsGenerated := False;
  FSolutionPath := TList<TPoint2D>.Create;
end;

destructor TMazeGenerator.Destroy;
begin
  FSolutionPath.Free;
  inherited;
end;

procedure TMazeGenerator.SetWidth(const Value: Integer);
begin
  if (Value >= 3) and (Value <= 100) then
  begin
    FWidth := Value;
    FIsGenerated := False;  // 크기 변경 시 재생성 필요
  end;
end;

procedure TMazeGenerator.SetHeight(const Value: Integer);
begin
  if (Value >= 3) and (Value <= 100) then
  begin
    FHeight := Value;
    FIsGenerated := False;  // 크기 변경 시 재생성 필요
  end;
end;

function TMazeGenerator.GetCell(X, Y: Integer): TMazeCell;
begin
  if not FIsGenerated then
    raise EInvalidOperation.Create('Maze not generated. Call Generate() first.');

  if IsValidCell(X, Y) then
    Result := FCells[Y, X]
  else
    raise ERangeError.CreateFmt('Invalid cell position: (%d, %d)', [X, Y]);
end;

procedure TMazeGenerator.SetCell(X, Y: Integer; const Value: TMazeCell);
begin
  if not FIsGenerated then
    raise EInvalidOperation.Create('Maze not generated. Call Generate() first.');

  if IsValidCell(X, Y) then
    FCells[Y, X] := Value
  else
    raise ERangeError.CreateFmt('Invalid cell position: (%d, %d)', [X, Y]);
end;

function TMazeGenerator.IsValidCell(X, Y: Integer): Boolean;
begin
  // 배열이 할당되었는지와 범위가 유효한지 확인
  Result := FIsGenerated and
            (Length(FCells) > 0) and
            (Y >= 0) and (Y < Length(FCells)) and
            (X >= 0) and (X < Length(FCells[0]));
end;

procedure TMazeGenerator.Initialize;
var
  X, Y: Integer;
begin
  // 2차원 배열 초기화
  SetLength(FCells, FHeight, FWidth);

  for Y := 0 to FHeight - 1 do
  begin
    for X := 0 to FWidth - 1 do
    begin
      FCells[Y, X].Walls := [wTop, wRight, wBottom, wLeft];
      FCells[Y, X].Visited := False;
      FCells[Y, X].IsPath := False;
      FCells[Y, X].IsEntrance := False;
      FCells[Y, X].IsExit := False;
    end;
  end;

  // 입구 설정 (좌상단)
  FCells[0, 0].IsEntrance := True;
  Exclude(FCells[0, 0].Walls, wLeft);  // 입구 벽 제거

  // 출구 설정 (우하단)
  FCells[FHeight - 1, FWidth - 1].IsExit := True;
  Exclude(FCells[FHeight - 1, FWidth - 1].Walls, wRight);  // 출구 벽 제거

  FSolutionPath.Clear;
end;

procedure TMazeGenerator.RemoveWall(X1, Y1, X2, Y2: Integer);
begin
  // X2, Y2가 X1, Y1의 어느 방향에 있는지 확인하고 벽 제거
  if X2 > X1 then  // 오른쪽
  begin
    Exclude(FCells[Y1, X1].Walls, wRight);
    Exclude(FCells[Y2, X2].Walls, wLeft);
  end
  else if X2 < X1 then  // 왼쪽
  begin
    Exclude(FCells[Y1, X1].Walls, wLeft);
    Exclude(FCells[Y2, X2].Walls, wRight);
  end
  else if Y2 > Y1 then  // 아래
  begin
    Exclude(FCells[Y1, X1].Walls, wBottom);
    Exclude(FCells[Y2, X2].Walls, wTop);
  end
  else if Y2 < Y1 then  // 위
  begin
    Exclude(FCells[Y1, X1].Walls, wTop);
    Exclude(FCells[Y2, X2].Walls, wBottom);
  end;
end;

function TMazeGenerator.GetUnvisitedNeighbors(X, Y: Integer): TList<TPoint2D>;
begin
  Result := TList<TPoint2D>.Create;

  // 상
  if (Y - 1 >= 0) and not FCells[Y - 1, X].Visited then
    Result.Add(TPoint2D.Create(X, Y - 1));
  // 우
  if (X + 1 < FWidth) and not FCells[Y, X + 1].Visited then
    Result.Add(TPoint2D.Create(X + 1, Y));
  // 하
  if (Y + 1 < FHeight) and not FCells[Y + 1, X].Visited then
    Result.Add(TPoint2D.Create(X, Y + 1));
  // 좌
  if (X - 1 >= 0) and not FCells[Y, X - 1].Visited then
    Result.Add(TPoint2D.Create(X - 1, Y));
end;

procedure TMazeGenerator.Generate;
var
  Stack: TStack<TPoint2D>;
  Current, Next: TPoint2D;
  Neighbors: TList<TPoint2D>;
  RandomIndex: Integer;
begin
  Initialize;
  Randomize;

  Stack := TStack<TPoint2D>.Create;
  try
    // 시작점 (0, 0)
    Current := TPoint2D.Create(0, 0);
    FCells[Current.Y, Current.X].Visited := True;
    Stack.Push(Current);

    while Stack.Count > 0 do
    begin
      Current := Stack.Pop;
      Neighbors := GetUnvisitedNeighbors(Current.X, Current.Y);
      try
        if Neighbors.Count > 0 then
        begin
          Stack.Push(Current);

          // 랜덤하게 이웃 선택
          RandomIndex := Random(Neighbors.Count);
          Next := Neighbors[RandomIndex];

          // 벽 제거
          RemoveWall(Current.X, Current.Y, Next.X, Next.Y);

          // 방문 표시
          FCells[Next.Y, Next.X].Visited := True;
          Stack.Push(Next);
        end;
      finally
        Neighbors.Free;
      end;
    end;

    FIsGenerated := True;  // 생성 완료 플래그 설정
    DoMazeGenerated;
  finally
    Stack.Free;
  end;
end;

function TMazeGenerator.FindSolution: Boolean;
var
  Queue: TQueue<TPoint2D>;
  Parent: TDictionary<string, TPoint2D>;
  Current, Next: TPoint2D;
  Key: string;

  function PointToKey(P: TPoint2D): string;
  begin
    Result := Format('%d,%d', [P.X, P.Y]);
  end;

  function CanMove(FromX, FromY, ToX, ToY: Integer): Boolean;
  var
    FromCell: TMazeCell;
  begin
    Result := False;
    if (ToX < 0) or (ToX >= FWidth) or (ToY < 0) or (ToY >= FHeight) then
      Exit;

    FromCell := FCells[FromY, FromX];

    if ToX > FromX then  // 오른쪽으로 이동
      Result := not (wRight in FromCell.Walls)
    else if ToX < FromX then  // 왼쪽으로 이동
      Result := not (wLeft in FromCell.Walls)
    else if ToY > FromY then  // 아래로 이동
      Result := not (wBottom in FromCell.Walls)
    else if ToY < FromY then  // 위로 이동
      Result := not (wTop in FromCell.Walls);
  end;

begin
  Result := False;

  if not FIsGenerated then
    Exit;

  ClearSolution;

  Queue := TQueue<TPoint2D>.Create;
  Parent := TDictionary<string, TPoint2D>.Create;
  try
    // 시작점
    Current := TPoint2D.Create(0, 0);
    Queue.Enqueue(Current);
    Parent.Add(PointToKey(Current), TPoint2D.Create(-1, -1));

    while Queue.Count > 0 do
    begin
      Current := Queue.Dequeue;

      // 목표 도달 확인
      if (Current.X = FWidth - 1) and (Current.Y = FHeight - 1) then
      begin
        Result := True;
        Break;
      end;

      // 네 방향 탐색
      // 상
      if CanMove(Current.X, Current.Y, Current.X, Current.Y - 1) then
      begin
        Next := TPoint2D.Create(Current.X, Current.Y - 1);
        Key := PointToKey(Next);
        if not Parent.ContainsKey(Key) then
        begin
          Parent.Add(Key, Current);
          Queue.Enqueue(Next);
        end;
      end;

      // 우
      if CanMove(Current.X, Current.Y, Current.X + 1, Current.Y) then
      begin
        Next := TPoint2D.Create(Current.X + 1, Current.Y);
        Key := PointToKey(Next);
        if not Parent.ContainsKey(Key) then
        begin
          Parent.Add(Key, Current);
          Queue.Enqueue(Next);
        end;
      end;

      // 하
      if CanMove(Current.X, Current.Y, Current.X, Current.Y + 1) then
      begin
        Next := TPoint2D.Create(Current.X, Current.Y + 1);
        Key := PointToKey(Next);
        if not Parent.ContainsKey(Key) then
        begin
          Parent.Add(Key, Current);
          Queue.Enqueue(Next);
        end;
      end;

      // 좌
      if CanMove(Current.X, Current.Y, Current.X - 1, Current.Y) then
      begin
        Next := TPoint2D.Create(Current.X - 1, Current.Y);
        Key := PointToKey(Next);
        if not Parent.ContainsKey(Key) then
        begin
          Parent.Add(Key, Current);
          Queue.Enqueue(Next);
        end;
      end;
    end;

    // 경로 역추적
    if Result then
    begin
      Current := TPoint2D.Create(FWidth - 1, FHeight - 1);
      while (Current.X >= 0) and (Current.Y >= 0) do
      begin
        FSolutionPath.Insert(0, Current);
        FCells[Current.Y, Current.X].IsPath := True;
        Key := PointToKey(Current);
        if Parent.ContainsKey(Key) then
          Current := Parent[Key]
        else
          Break;
      end;

      DoSolutionFound;
    end;
  finally
    Queue.Free;
    Parent.Free;
  end;
end;

procedure TMazeGenerator.ClearSolution;
var
  X, Y: Integer;
begin
  FSolutionPath.Clear;

  if not FIsGenerated then
    Exit;

  for Y := 0 to FHeight - 1 do
    for X := 0 to FWidth - 1 do
      FCells[Y, X].IsPath := False;
end;

procedure TMazeGenerator.DoMazeGenerated;
begin
  if Assigned(FOnMazeGenerated) then
    FOnMazeGenerated(Self);
end;

procedure TMazeGenerator.DoSolutionFound;
begin
  if Assigned(FOnSolutionFound) then
    FOnSolutionFound(Self);
end;

function TMazeGenerator.ToSVG(CellSize, WallThickness: Integer): string;
var
  SB: TStringBuilder;
  X, Y: Integer;
  Cell: TMazeCell;
  TotalWidth, TotalHeight: Integer;
  CellX, CellY: Integer;
  PathStr: string;
  I: Integer;
  P: TPoint2D;
begin
  if not FIsGenerated then
  begin
    Result := '';
    Exit;
  end;

  TotalWidth := FWidth * CellSize + WallThickness;
  TotalHeight := FHeight * CellSize + WallThickness;

  SB := TStringBuilder.Create;
  try
    // SVG 헤더
    SB.AppendLine('<?xml version="1.0" encoding="UTF-8"?>');
    SB.AppendFormat('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">',
      [TotalWidth, TotalHeight, TotalWidth, TotalHeight]);
    SB.AppendLine;

    // 스타일 정의
    SB.AppendLine('  <defs>');

    // 벽돌 패턴 정의
    SB.AppendLine('    <pattern id="brickPattern" patternUnits="userSpaceOnUse" width="20" height="10">');
    SB.AppendLine('      <rect width="20" height="10" fill="#8B4513"/>');
    SB.AppendLine('      <rect x="0" y="0" width="9" height="4" fill="#A0522D" stroke="#654321" stroke-width="0.5"/>');
    SB.AppendLine('      <rect x="10" y="0" width="10" height="4" fill="#A0522D" stroke="#654321" stroke-width="0.5"/>');
    SB.AppendLine('      <rect x="-5" y="5" width="10" height="4" fill="#A0522D" stroke="#654321" stroke-width="0.5"/>');
    SB.AppendLine('      <rect x="5" y="5" width="10" height="4" fill="#A0522D" stroke="#654321" stroke-width="0.5"/>');
    SB.AppendLine('      <rect x="15" y="5" width="10" height="4" fill="#A0522D" stroke="#654321" stroke-width="0.5"/>');
    SB.AppendLine('    </pattern>');

    SB.AppendLine('  </defs>');

    // 배경
    SB.AppendFormat('  <rect width="%d" height="%d" fill="#F5F5DC"/>', [TotalWidth, TotalHeight]);
    SB.AppendLine;

    // 벽 그리기
    SB.AppendLine('  <g stroke-linecap="square">');

    for Y := 0 to FHeight - 1 do
    begin
      for X := 0 to FWidth - 1 do
      begin
        Cell := FCells[Y, X];
        CellX := X * CellSize;
        CellY := Y * CellSize;

        // 상단 벽
        if wTop in Cell.Walls then
        begin
          SB.AppendFormat('    <line x1="%d" y1="%d" x2="%d" y2="%d" stroke-width="%d" stroke="#8B4513"/>',
            [CellX, CellY, CellX + CellSize, CellY, WallThickness]);
          SB.AppendLine;
        end;

        // 우측 벽
        if wRight in Cell.Walls then
        begin
          SB.AppendFormat('    <line x1="%d" y1="%d" x2="%d" y2="%d" stroke-width="%d" stroke="#8B4513"/>',
            [CellX + CellSize, CellY, CellX + CellSize, CellY + CellSize, WallThickness]);
          SB.AppendLine;
        end;

        // 하단 벽
        if wBottom in Cell.Walls then
        begin
          SB.AppendFormat('    <line x1="%d" y1="%d" x2="%d" y2="%d" stroke-width="%d" stroke="#8B4513"/>',
            [CellX, CellY + CellSize, CellX + CellSize, CellY + CellSize, WallThickness]);
          SB.AppendLine;
        end;

        // 좌측 벽
        if wLeft in Cell.Walls then
        begin
          SB.AppendFormat('    <line x1="%d" y1="%d" x2="%d" y2="%d" stroke-width="%d" stroke="#8B4513"/>',
            [CellX, CellY, CellX, CellY + CellSize, WallThickness]);
          SB.AppendLine;
        end;
      end;
    end;

    SB.AppendLine('  </g>');

    // 해답 경로 그리기
    if FSolutionPath.Count > 0 then
    begin
      PathStr := '';
      for I := 0 to FSolutionPath.Count - 1 do
      begin
        P := FSolutionPath[I];
        CellX := P.X * CellSize + CellSize div 2;
        CellY := P.Y * CellSize + CellSize div 2;
        if I = 0 then
          PathStr := Format('M%d,%d', [CellX, CellY])
        else
          PathStr := PathStr + Format(' L%d,%d', [CellX, CellY]);
      end;

      SB.AppendFormat('  <path d="%s" fill="none" stroke="#FF6B6B" stroke-width="3" ' +
        'stroke-linecap="round" stroke-linejoin="round" opacity="0.8"/>', [PathStr]);
      SB.AppendLine;
    end;

    // 입구 표시
    SB.AppendFormat('  <circle cx="%d" cy="%d" r="%d" fill="#00AA00" stroke="#006600" stroke-width="2"/>',
      [CellSize div 2, CellSize div 2, CellSize div 3]);
    SB.AppendLine;
    SB.AppendFormat('  <text x="%d" y="%d" text-anchor="middle" font-size="%d" font-weight="bold" fill="white">S</text>',
      [CellSize div 2, CellSize div 2 + CellSize div 8, CellSize div 3]);
    SB.AppendLine;

    // 출구 표시
    CellX := (FWidth - 1) * CellSize + CellSize div 2;
    CellY := (FHeight - 1) * CellSize + CellSize div 2;
    SB.AppendFormat('  <circle cx="%d" cy="%d" r="%d" fill="#AA0000" stroke="#660000" stroke-width="2"/>',
      [CellX, CellY, CellSize div 3]);
    SB.AppendLine;
    SB.AppendFormat('  <text x="%d" y="%d" text-anchor="middle" font-size="%d" font-weight="bold" fill="white">E</text>',
      [CellX, CellY + CellSize div 8, CellSize div 3]);
    SB.AppendLine;

    SB.AppendLine('</svg>');

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

procedure TMazeGenerator.SaveToSVG(const FileName: string; CellSize, WallThickness: Integer);
var
  SVGContent: string;
  FileStream: TStringList;
begin
  SVGContent := ToSVG(CellSize, WallThickness);
  if SVGContent = '' then
    raise EInvalidOperation.Create('Maze not generated. Call Generate() first.');

  FileStream := TStringList.Create;
  try
    FileStream.Text := SVGContent;
    FileStream.SaveToFile(FileName, TEncoding.UTF8);
  finally
    FileStream.Free;
  end;
end;

procedure TMazeGenerator.InitializePlayer;
begin
  FPlayerX := 0;
  FPlayerY := 0;
end;

function TMazeGenerator.CanMovePlayer(Direction: TDirection): Boolean;
var
  NewX, NewY: Integer;
  CurrentCell: TMazeCell;
begin
  Result := False;

  if not FIsGenerated then
    Exit;

  NewX := FPlayerX;
  NewY := FPlayerY;

  // 새로운 위치 계산
  case Direction of
    dirUp:    Dec(NewY);
    dirDown:  Inc(NewY);
    dirLeft:  Dec(NewX);
    dirRight: Inc(NewX);
  end;

  // 범위 체크
  if (NewX < 0) or (NewX >= FWidth) or (NewY < 0) or (NewY >= FHeight) then
    Exit;

  // 벽 체크
  CurrentCell := FCells[FPlayerY, FPlayerX];
  case Direction of
    dirUp:    Result := not (wTop in CurrentCell.Walls);
    dirDown:  Result := not (wBottom in CurrentCell.Walls);
    dirLeft:  Result := not (wLeft in CurrentCell.Walls);
    dirRight: Result := not (wRight in CurrentCell.Walls);
  end;
end;

function TMazeGenerator.MovePlayer(Direction: TDirection): Boolean;
begin
  Result := False;

  if not CanMovePlayer(Direction) then
    Exit;

  // 이동 실행
  case Direction of
    dirUp:    Dec(FPlayerY);
    dirDown:  Inc(FPlayerY);
    dirLeft:  Dec(FPlayerX);
    dirRight: Inc(FPlayerX);
  end;

  Result := True;
end;

function TMazeGenerator.IsPlayerAtExit: Boolean;
begin
  Result := (FPlayerX = FWidth - 1) and (FPlayerY = FHeight - 1);
end;

end.
