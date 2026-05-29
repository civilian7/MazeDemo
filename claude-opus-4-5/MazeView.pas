unit MazeView;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.ExtCtrls,
  MazeGenerator;

type
  /// <summary>미로를 시각적으로 표시하는 컴포넌트</summary>
  TMazeView = class(TCustomControl)
  private
    FMazeGenerator: TMazeGenerator;
    FCellSize: Integer;
    FWallThickness: Integer;
    FShowSolution: Boolean;
    FBrickBitmap: TBitmap;
    FPathColor: TColor;
    FEntranceColor: TColor;
    FExitColor: TColor;
    FBackgroundColor: TColor;
    FGameMode: Boolean;
    FOnPlayerMoved: TNotifyEvent;

    procedure SetMazeGenerator(const Value: TMazeGenerator);
    procedure SetCellSize(const Value: Integer);
    procedure SetWallThickness(const Value: Integer);
    procedure SetShowSolution(const Value: Boolean);
    procedure SetPathColor(const Value: TColor);
    procedure SetEntranceColor(const Value: TColor);
    procedure SetExitColor(const Value: TColor);
    procedure SetBackgroundColor(const Value: TColor);
    procedure SetGameMode(const Value: Boolean);

    procedure CreateBrickPattern;
    procedure DrawWall(Canvas: TCanvas; X1, Y1, X2, Y2: Integer);
    procedure DrawCell(Canvas: TCanvas; X, Y: Integer);
    procedure DrawEntrance(Canvas: TCanvas);
    procedure DrawExit(Canvas: TCanvas);
    procedure DrawSolutionPath(Canvas: TCanvas);
    procedure DrawPlayer(Canvas: TCanvas);
    procedure UpdateSize;
    function IsMazeReady: Boolean;
  protected
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>미로 다시 그리기</summary>
    procedure RefreshMaze;
  published
    property Align;
    property Anchors;
    property Visible;
    property Enabled;

    property MazeGenerator: TMazeGenerator read FMazeGenerator write SetMazeGenerator;
    property CellSize: Integer read FCellSize write SetCellSize default 30;
    property WallThickness: Integer read FWallThickness write SetWallThickness default 4;
    property ShowSolution: Boolean read FShowSolution write SetShowSolution default False;
    property PathColor: TColor read FPathColor write SetPathColor default clRed;
    property EntranceColor: TColor read FEntranceColor write SetEntranceColor default clGreen;
    property ExitColor: TColor read FExitColor write SetExitColor default clMaroon;
    property BackgroundColor: TColor read FBackgroundColor write SetBackgroundColor default clCream;
    property GameMode: Boolean read FGameMode write SetGameMode default False;

    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnPlayerMoved: TNotifyEvent read FOnPlayerMoved write FOnPlayerMoved;
  end;

implementation

uses
  Vcl.GraphUtil;

{ TMazeView }

constructor TMazeView.Create(AOwner: TComponent);
begin
  inherited;
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  TabStop := True;  // 키보드 입력을 받을 수 있도록 설정

  FCellSize := 30;
  FWallThickness := 4;
  FShowSolution := False;
  FPathColor := clRed;
  FEntranceColor := clGreen;
  FExitColor := clMaroon;
  FBackgroundColor := clCream;
  FGameMode := False;

  FBrickBitmap := TBitmap.Create;
  CreateBrickPattern;

  Width := 320;
  Height := 320;
end;

destructor TMazeView.Destroy;
begin
  FBrickBitmap.Free;
  inherited;
end;

function TMazeView.IsMazeReady: Boolean;
begin
  Result := Assigned(FMazeGenerator) and FMazeGenerator.IsGenerated;
end;

procedure TMazeView.CreateBrickPattern;
const
  BrickWidth = 16;
  BrickHeight = 8;
  PatternWidth = BrickWidth * 2;
  PatternHeight = BrickHeight * 2;
var
  X, Y: Integer;
  BrickColor, MortarColor, HighlightColor, ShadowColor: TColor;
begin
  FBrickBitmap.SetSize(PatternWidth, PatternHeight);
  FBrickBitmap.PixelFormat := pf24bit;

  BrickColor := RGB(160, 82, 45);      // Sienna
  MortarColor := RGB(101, 67, 33);     // Dark brown
  HighlightColor := RGB(180, 102, 65); // Lighter brick
  ShadowColor := RGB(120, 62, 35);     // Darker brick

  // 모르타르(줄눈) 배경
  FBrickBitmap.Canvas.Brush.Color := MortarColor;
  FBrickBitmap.Canvas.FillRect(Rect(0, 0, PatternWidth, PatternHeight));

  // 첫 번째 줄 벽돌 (오프셋 없음)
  for X := 0 to 1 do
  begin
    // 벽돌 본체
    FBrickBitmap.Canvas.Brush.Color := BrickColor;
    FBrickBitmap.Canvas.FillRect(Rect(
      X * BrickWidth + 1,
      1,
      (X + 1) * BrickWidth - 1,
      BrickHeight - 1
    ));

    // 하이라이트 (상단, 좌측)
    FBrickBitmap.Canvas.Pen.Color := HighlightColor;
    FBrickBitmap.Canvas.MoveTo(X * BrickWidth + 1, BrickHeight - 2);
    FBrickBitmap.Canvas.LineTo(X * BrickWidth + 1, 1);
    FBrickBitmap.Canvas.LineTo((X + 1) * BrickWidth - 1, 1);

    // 그림자 (하단, 우측)
    FBrickBitmap.Canvas.Pen.Color := ShadowColor;
    FBrickBitmap.Canvas.MoveTo((X + 1) * BrickWidth - 2, 1);
    FBrickBitmap.Canvas.LineTo((X + 1) * BrickWidth - 2, BrickHeight - 2);
    FBrickBitmap.Canvas.LineTo(X * BrickWidth + 1, BrickHeight - 2);
  end;

  // 두 번째 줄 벽돌 (반 벽돌 오프셋)
  for X := -1 to 1 do
  begin
    // 벽돌 본체
    FBrickBitmap.Canvas.Brush.Color := BrickColor;
    FBrickBitmap.Canvas.FillRect(Rect(
      X * BrickWidth + BrickWidth div 2 + 1,
      BrickHeight + 1,
      (X + 1) * BrickWidth + BrickWidth div 2 - 1,
      BrickHeight * 2 - 1
    ));

    // 하이라이트
    FBrickBitmap.Canvas.Pen.Color := HighlightColor;
    FBrickBitmap.Canvas.MoveTo(X * BrickWidth + BrickWidth div 2 + 1, BrickHeight * 2 - 2);
    FBrickBitmap.Canvas.LineTo(X * BrickWidth + BrickWidth div 2 + 1, BrickHeight + 1);
    FBrickBitmap.Canvas.LineTo((X + 1) * BrickWidth + BrickWidth div 2 - 1, BrickHeight + 1);

    // 그림자
    FBrickBitmap.Canvas.Pen.Color := ShadowColor;
    FBrickBitmap.Canvas.MoveTo((X + 1) * BrickWidth + BrickWidth div 2 - 2, BrickHeight + 1);
    FBrickBitmap.Canvas.LineTo((X + 1) * BrickWidth + BrickWidth div 2 - 2, BrickHeight * 2 - 2);
    FBrickBitmap.Canvas.LineTo(X * BrickWidth + BrickWidth div 2 + 1, BrickHeight * 2 - 2);
  end;
end;

procedure TMazeView.SetMazeGenerator(const Value: TMazeGenerator);
begin
  if FMazeGenerator <> Value then
  begin
    if Assigned(FMazeGenerator) then
      FMazeGenerator.RemoveFreeNotification(Self);

    FMazeGenerator := Value;

    if Assigned(FMazeGenerator) then
      FMazeGenerator.FreeNotification(Self);

    UpdateSize;
    Invalidate;
  end;
end;

procedure TMazeView.SetCellSize(const Value: Integer);
begin
  if (Value >= 10) and (Value <= 100) and (FCellSize <> Value) then
  begin
    FCellSize := Value;
    UpdateSize;
    Invalidate;
  end;
end;

procedure TMazeView.SetWallThickness(const Value: Integer);
begin
  if (Value >= 1) and (Value <= 10) and (FWallThickness <> Value) then
  begin
    FWallThickness := Value;
    Invalidate;
  end;
end;

procedure TMazeView.SetShowSolution(const Value: Boolean);
begin
  if FShowSolution <> Value then
  begin
    FShowSolution := Value;
    Invalidate;
  end;
end;

procedure TMazeView.SetPathColor(const Value: TColor);
begin
  if FPathColor <> Value then
  begin
    FPathColor := Value;
    Invalidate;
  end;
end;

procedure TMazeView.SetEntranceColor(const Value: TColor);
begin
  if FEntranceColor <> Value then
  begin
    FEntranceColor := Value;
    Invalidate;
  end;
end;

procedure TMazeView.SetExitColor(const Value: TColor);
begin
  if FExitColor <> Value then
  begin
    FExitColor := Value;
    Invalidate;
  end;
end;

procedure TMazeView.SetBackgroundColor(const Value: TColor);
begin
  if FBackgroundColor <> Value then
  begin
    FBackgroundColor := Value;
    Invalidate;
  end;
end;

procedure TMazeView.SetGameMode(const Value: Boolean);
begin
  if FGameMode <> Value then
  begin
    FGameMode := Value;
    Invalidate;
  end;
end;

procedure TMazeView.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FMazeGenerator) then
    FMazeGenerator := nil;
end;

procedure TMazeView.UpdateSize;
begin
  if IsMazeReady then
  begin
    Width := FMazeGenerator.Width * FCellSize + FWallThickness;
    Height := FMazeGenerator.Height * FCellSize + FWallThickness;
  end;
end;

procedure TMazeView.DrawWall(Canvas: TCanvas; X1, Y1, X2, Y2: Integer);
var
  WallRect: TRect;
begin
  // 벽 영역 계산
  if X1 = X2 then  // 수직 벽
  begin
    WallRect := Rect(
      X1 - FWallThickness div 2,
      Min(Y1, Y2),
      X1 + FWallThickness div 2 + FWallThickness mod 2,
      Max(Y1, Y2)
    );
  end
  else  // 수평 벽
  begin
    WallRect := Rect(
      Min(X1, X2),
      Y1 - FWallThickness div 2,
      Max(X1, X2),
      Y1 + FWallThickness div 2 + FWallThickness mod 2
    );
  end;

  // 벽돌 패턴으로 채우기
  Canvas.Brush.Bitmap := FBrickBitmap;
  Canvas.FillRect(WallRect);
  Canvas.Brush.Bitmap := nil;

  // 테두리
  Canvas.Pen.Color := RGB(80, 50, 25);
  Canvas.Pen.Width := 1;
  Canvas.Brush.Style := bsClear;
  Canvas.Rectangle(WallRect);
  Canvas.Brush.Style := bsSolid;
end;

procedure TMazeView.DrawCell(Canvas: TCanvas; X, Y: Integer);
var
  Cell: TMazeCell;
  CellX, CellY: Integer;
begin
  Cell := FMazeGenerator.Cells[X, Y];
  CellX := X * FCellSize;
  CellY := Y * FCellSize;

  // 상단 벽
  if wTop in Cell.Walls then
    DrawWall(Canvas, CellX, CellY, CellX + FCellSize, CellY);

  // 우측 벽
  if wRight in Cell.Walls then
    DrawWall(Canvas, CellX + FCellSize, CellY, CellX + FCellSize, CellY + FCellSize);

  // 하단 벽
  if wBottom in Cell.Walls then
    DrawWall(Canvas, CellX, CellY + FCellSize, CellX + FCellSize, CellY + FCellSize);

  // 좌측 벽
  if wLeft in Cell.Walls then
    DrawWall(Canvas, CellX, CellY, CellX, CellY + FCellSize);
end;

procedure TMazeView.DrawEntrance(Canvas: TCanvas);
var
  CenterX, CenterY, Radius: Integer;
begin
  CenterX := FCellSize div 2;
  CenterY := FCellSize div 2;
  Radius := FCellSize div 3;

  // 배경 원
  Canvas.Brush.Color := FEntranceColor;
  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Width := 2;
  Canvas.Ellipse(
    CenterX - Radius,
    CenterY - Radius,
    CenterX + Radius,
    CenterY + Radius
  );

  // 텍스트 "S" (Start)
  Canvas.Font.Size := Radius;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := clWhite;
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(
    CenterX - Canvas.TextWidth('S') div 2,
    CenterY - Canvas.TextHeight('S') div 2,
    'S'
  );
  Canvas.Brush.Style := bsSolid;
end;

procedure TMazeView.DrawExit(Canvas: TCanvas);
var
  CenterX, CenterY, Radius: Integer;
begin
  CenterX := (FMazeGenerator.Width - 1) * FCellSize + FCellSize div 2;
  CenterY := (FMazeGenerator.Height - 1) * FCellSize + FCellSize div 2;
  Radius := FCellSize div 3;

  // 배경 원
  Canvas.Brush.Color := FExitColor;
  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Width := 2;
  Canvas.Ellipse(
    CenterX - Radius,
    CenterY - Radius,
    CenterX + Radius,
    CenterY + Radius
  );

  // 텍스트 "E" (End)
  Canvas.Font.Size := Radius;
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Color := clWhite;
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(
    CenterX - Canvas.TextWidth('E') div 2,
    CenterY - Canvas.TextHeight('E') div 2,
    'E'
  );
  Canvas.Brush.Style := bsSolid;
end;

procedure TMazeView.DrawSolutionPath(Canvas: TCanvas);
var
  I: Integer;
  P1: TPoint2D;
  Points: array of TPoint;
begin
  if (not FShowSolution) or (FMazeGenerator.SolutionPath.Count < 2) then
    Exit;

  // 경로를 폴리라인으로 그리기
  SetLength(Points, FMazeGenerator.SolutionPath.Count);

  for I := 0 to FMazeGenerator.SolutionPath.Count - 1 do
  begin
    P1 := FMazeGenerator.SolutionPath[I];
    Points[I].X := P1.X * FCellSize + FCellSize div 2;
    Points[I].Y := P1.Y * FCellSize + FCellSize div 2;
  end;

  // 외곽선 (두꺼운 검은색)
  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Width := FCellSize div 4 + 2;
  Canvas.Pen.Style := psSolid;
  Canvas.Polyline(Points);

  // 내부선 (경로 색상)
  Canvas.Pen.Color := FPathColor;
  Canvas.Pen.Width := FCellSize div 4;
  Canvas.Polyline(Points);
end;

procedure TMazeView.DrawPlayer(Canvas: TCanvas);
var
  CenterX, CenterY, HeadRadius, BodyHeight, ArmWidth, LegWidth: Integer;
  HeadY, BodyY, BodyBottom, ArmY, LegY: Integer;
begin
  if not FGameMode then
    Exit;

  // 플레이어 중심 좌표
  CenterX := FMazeGenerator.PlayerX * FCellSize + FCellSize div 2;
  CenterY := FMazeGenerator.PlayerY * FCellSize + FCellSize div 2;

  // 크기 계산
  HeadRadius := FCellSize div 6;
  BodyHeight := FCellSize div 3;
  ArmWidth := FCellSize div 3;
  LegWidth := FCellSize div 4;

  // Y 좌표 계산
  HeadY := CenterY - BodyHeight div 2;
  BodyY := HeadY + HeadRadius;
  BodyBottom := BodyY + BodyHeight;
  ArmY := BodyY + BodyHeight div 4;
  LegY := BodyBottom + LegWidth;

  // 머리
  Canvas.Brush.Color := RGB(255, 220, 177); // 살색
  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Width := 2;
  Canvas.Ellipse(
    CenterX - HeadRadius,
    HeadY - HeadRadius,
    CenterX + HeadRadius,
    HeadY + HeadRadius
  );

  // 몸통
  Canvas.Pen.Width := 3;
  Canvas.MoveTo(CenterX, BodyY);
  Canvas.LineTo(CenterX, BodyBottom);

  // 팔
  Canvas.Pen.Width := 2;
  Canvas.MoveTo(CenterX - ArmWidth div 2, ArmY);
  Canvas.LineTo(CenterX + ArmWidth div 2, ArmY);

  // 다리
  Canvas.MoveTo(CenterX, BodyBottom);
  Canvas.LineTo(CenterX - LegWidth div 2, LegY);
  Canvas.MoveTo(CenterX, BodyBottom);
  Canvas.LineTo(CenterX + LegWidth div 2, LegY);
end;

procedure TMazeView.KeyDown(var Key: Word; Shift: TShiftState);
var
  Direction: TDirection;
  Moved: Boolean;
begin
  inherited;

  if not FGameMode or not IsMazeReady then
    Exit;

  Moved := False;

  case Key of
    VK_UP:
      begin
        Direction := dirUp;
        Moved := FMazeGenerator.MovePlayer(Direction);
      end;
    VK_DOWN:
      begin
        Direction := dirDown;
        Moved := FMazeGenerator.MovePlayer(Direction);
      end;
    VK_LEFT:
      begin
        Direction := dirLeft;
        Moved := FMazeGenerator.MovePlayer(Direction);
      end;
    VK_RIGHT:
      begin
        Direction := dirRight;
        Moved := FMazeGenerator.MovePlayer(Direction);
      end;
  end;

  if Moved then
  begin
    Invalidate;
    if Assigned(FOnPlayerMoved) then
      FOnPlayerMoved(Self);
  end;
end;

procedure TMazeView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;

  // 클릭 시 포커스를 받아서 키보드 입력 가능하도록 설정
  if CanFocus then
    SetFocus;
end;

procedure TMazeView.Paint;
var
  X, Y: Integer;
begin
  inherited;

  // 배경
  Canvas.Brush.Color := FBackgroundColor;
  Canvas.FillRect(ClientRect);

  // 미로가 준비되지 않았으면 안내 메시지 표시
  if not IsMazeReady then
  begin
    Canvas.Font.Size := 12;
    Canvas.Font.Color := clGray;
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(10, 10, 'Maze not generated.');
    Canvas.TextOut(10, 30, 'Click "Generate" button to create a maze.');
    Exit;
  end;

  // 해답 경로 먼저 그리기 (벽 아래에 표시)
  DrawSolutionPath(Canvas);

  // 모든 셀의 벽 그리기
  for Y := 0 to FMazeGenerator.Height - 1 do
    for X := 0 to FMazeGenerator.Width - 1 do
      DrawCell(Canvas, X, Y);

  // 입구 표시
  DrawEntrance(Canvas);

  // 출구 표시
  DrawExit(Canvas);

  // 플레이어 표시 (게임 모드일 때)
  DrawPlayer(Canvas);
end;

procedure TMazeView.RefreshMaze;
begin
  UpdateSize;
  Invalidate;
end;

end.
