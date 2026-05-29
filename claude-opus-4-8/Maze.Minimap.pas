unit Maze.Minimap;

interface

{$REGION 'uses'}
uses
  System.Types,
  System.UITypes,
  FMX.Graphics,
  Maze.Core;
{$ENDREGION}

type
  /// <summary>칸별 탐험 여부(fog of war)를 담는 2차원 동적 배열.</summary>
  TVisitedGrid = TArray<TArray<Boolean>>;

  /// <summary>한 프레임의 미니맵 렌더링에 필요한 입력 값.</summary>
  TMinimapState = record
    PlayerWorldX: Single;
    PlayerWorldZ: Single;
    PlayerYaw: Single;
    HintDirection: TDirection;
    HasKey: Boolean;
    ShowSolution: Boolean;
    Solution: TArray<TPoint2D>;
  end;

  /// <summary>
  /// HUD 미니맵을 FMX 캔버스에 그립니다. 탐험한 칸만 드러내는 fog of war,
  /// 플레이어 위치·방향 삼각형, 출구 마커, 힌트 방향 화살표를 표시합니다.
  /// 상태를 보유하지 않으므로 PaintBox 의 OnPaint 안에서 호출하면 됩니다.
  /// </summary>
  TMinimapRenderer = class
  private
    procedure DrawCell(const ACanvas: TCanvas; const ALeft, ATop, ASize: Single;
      const AWalls: TWalls; const AIsExit: Boolean);
    procedure DrawPlayer(const ACanvas: TCanvas; const APx, APy, AYaw, ASize: Single);
    procedure DrawCharacter(const ACanvas: TCanvas; const APx, APy, AYaw, ASize: Single);
    procedure DrawHintArrow(const ACanvas: TCanvas; const APx, APy, ASize: Single;
      const ADir: TDirection);
    procedure DrawMarker(const ACanvas: TCanvas; const ACenter: TPointF; const ASize: Single;
      const AFill: TAlphaColor; const AText: string);
    procedure DrawSolutionPath(const ACanvas: TCanvas; const AOriginX, AOriginY, ACellSize: Single;
      const ASolution: TArray<TPoint2D>);
    procedure DrawPlan(const ACanvas: TCanvas; const ABounds: TRectF; const AMaze: TMazeGenerator;
      out AOriginX, AOriginY, ACellSize: Single);
  public
    /// <summary>HUD 미니맵을 그립니다(fog of war + 플레이어/힌트/해답).</summary>
    /// <param name="ACanvas">대상 캔버스(이미 BeginScene 상태여야 함).</param>
    /// <param name="ABounds">그릴 영역.</param>
    /// <param name="AMaze">미로 데이터.</param>
    /// <param name="AVisited">칸별 탐험 여부.</param>
    /// <param name="AState">플레이어·힌트·해답 등 프레임 상태.</param>
    procedure Render(const ACanvas: TCanvas; const ABounds: TRectF;
      const AMaze: TMazeGenerator; const AVisited: TVisitedGrid;
      const AState: TMinimapState);

    /// <summary>미로 전체를 2D 평면도로 그립니다(게임 시작 전 미리보기용).</summary>
    /// <param name="ACanvas">대상 캔버스(이미 BeginScene 상태여야 함).</param>
    /// <param name="ABounds">그릴 영역.</param>
    /// <param name="AMaze">미로 데이터.</param>
    /// <param name="AShowSolution">해답 경로 표시 여부.</param>
    /// <param name="ASolution">해답 경로(표시할 경우).</param>
    procedure RenderPreview(const ACanvas: TCanvas; const ABounds: TRectF;
      const AMaze: TMazeGenerator; const AShowSolution: Boolean = False;
      const ASolution: TArray<TPoint2D> = nil);

    /// <summary>2D 탑다운 플레이 화면을 그립니다(전체 가시 + 플레이어 + 미수집 아이템 + 해답).</summary>
    /// <param name="ACanvas">대상 캔버스.</param>
    /// <param name="ABounds">그릴 영역.</param>
    /// <param name="AMaze">미로 데이터.</param>
    /// <param name="APlayerWorldX">플레이어 월드 X.</param>
    /// <param name="APlayerWorldZ">플레이어 월드 Z.</param>
    /// <param name="APlayerYaw">플레이어 시선각(라디안).</param>
    /// <param name="ACoinPts">미획득 코인의 월드 좌표(X, Z).</param>
    /// <param name="AKeyPts">미획득 열쇠의 월드 좌표(X, Z).</param>
    /// <param name="AShowSolution">해답 경로 표시 여부.</param>
    /// <param name="ASolution">해답 경로(표시할 경우).</param>
    procedure RenderPlay2D(const ACanvas: TCanvas; const ABounds: TRectF;
      const AMaze: TMazeGenerator; const APlayerWorldX, APlayerWorldZ, APlayerYaw: Single;
      const ACoinPts, AKeyPts: TArray<TPointF>;
      const AShowSolution: Boolean; const ASolution: TArray<TPoint2D>);

    /// <summary>2D 평면도/플레이 화면의 화면 좌표를 월드 좌표(X, Z)로 변환합니다(마우스 입력용).</summary>
    /// <param name="ABounds">2D 뷰 영역(RenderPlay2D 와 동일해야 함).</param>
    /// <param name="AMaze">미로 데이터.</param>
    /// <param name="APoint">화면(로컬) 좌표.</param>
    /// <param name="AWorldX">변환된 월드 X.</param>
    /// <param name="AWorldZ">변환된 월드 Z.</param>
    /// <returns>미로가 생성된 경우 True.</returns>
    function PlanToWorld(const ABounds: TRectF; const AMaze: TMazeGenerator;
      const APoint: TPointF; out AWorldX, AWorldZ: Single): Boolean;
  end;

implementation

{$REGION 'uses'}
uses
  System.Math,
  FMX.Types,
  Maze.Player;
{$ENDREGION}

{$REGION 'TMinimapRenderer'}
procedure TMinimapRenderer.DrawCell(const ACanvas: TCanvas; const ALeft, ATop, ASize: Single;
  const AWalls: TWalls; const AIsExit: Boolean);
begin
  // 바닥(탐험됨)
  if AIsExit then
  begin
    ACanvas.Fill.Color := TAlphaColor($FF2E8B57);
  end
  else
  begin
    ACanvas.Fill.Color := TAlphaColor($FF3C3C46);
  end;

  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.FillRect(RectF(ALeft, ATop, ALeft + ASize, ATop + ASize), 1);

  // 벽
  ACanvas.Stroke.Kind := TBrushKind.Solid;
  ACanvas.Stroke.Color := TAlphaColor($FFE8E0C8);
  ACanvas.Stroke.Thickness := Max(1, ASize * 0.12);

  if wTop in AWalls then
  begin
    ACanvas.DrawLine(PointF(ALeft, ATop), PointF(ALeft + ASize, ATop), 1);
  end;

  if wBottom in AWalls then
  begin
    ACanvas.DrawLine(PointF(ALeft, ATop + ASize), PointF(ALeft + ASize, ATop + ASize), 1);
  end;

  if wLeft in AWalls then
  begin
    ACanvas.DrawLine(PointF(ALeft, ATop), PointF(ALeft, ATop + ASize), 1);
  end;

  if wRight in AWalls then
  begin
    ACanvas.DrawLine(PointF(ALeft + ASize, ATop), PointF(ALeft + ASize, ATop + ASize), 1);
  end;
end;

procedure TMinimapRenderer.DrawHintArrow(const ACanvas: TCanvas; const APx, APy, ASize: Single;
  const ADir: TDirection);
begin
  if ADir = dirNone then
  begin
    Exit;
  end;

  var LDx := 0.0;
  var LDy := 0.0;

  case ADir of
    dirUp:
    begin
      LDy := -1;
    end;
    dirDown:
    begin
      LDy := 1;
    end;
    dirLeft:
    begin
      LDx := -1;
    end;
    dirRight:
    begin
      LDx := 1;
    end;
  end;

  var LLen := ASize * 0.9;
  var LEndX := APx + LDx * LLen;
  var LEndY := APy + LDy * LLen;

  ACanvas.Stroke.Kind := TBrushKind.Solid;
  ACanvas.Stroke.Color := TAlphaColor($FF6CE0FF);
  ACanvas.Stroke.Thickness := Max(2, ASize * 0.18);
  ACanvas.DrawLine(PointF(APx, APy), PointF(LEndX, LEndY), 1);

  // 화살촉
  var LHead := TPathData.Create;
  try
    var LBackX := LEndX - LDx * ASize * 0.4;
    var LBackY := LEndY - LDy * ASize * 0.4;
    var LPerpX := -LDy * ASize * 0.28;
    var LPerpY := LDx * ASize * 0.28;

    LHead.MoveTo(PointF(LEndX, LEndY));
    LHead.LineTo(PointF(LBackX + LPerpX, LBackY + LPerpY));
    LHead.LineTo(PointF(LBackX - LPerpX, LBackY - LPerpY));
    LHead.ClosePath;

    ACanvas.Fill.Kind := TBrushKind.Solid;
    ACanvas.Fill.Color := TAlphaColor($FF6CE0FF);
    ACanvas.FillPath(LHead, 1);
  finally
    LHead.Free;
  end;
end;

procedure TMinimapRenderer.DrawPlayer(const ACanvas: TCanvas; const APx, APy, AYaw, ASize: Single);
begin
  var LForwardX := Sin(AYaw);
  var LForwardY := Cos(AYaw);
  var LRightX := Cos(AYaw);
  var LRightY := -Sin(AYaw);

  var LTip := ASize * 0.55;
  var LBack := ASize * 0.4;

  var LTriangle := TPathData.Create;
  try
    // 시선 방향 꼭짓점
    LTriangle.MoveTo(PointF(APx + LForwardX * LTip, APy + LForwardY * LTip));
    // 뒤 좌/우
    LTriangle.LineTo(PointF(APx - LForwardX * LBack + LRightX * LBack,
      APy - LForwardY * LBack + LRightY * LBack));
    LTriangle.LineTo(PointF(APx - LForwardX * LBack - LRightX * LBack,
      APy - LForwardY * LBack - LRightY * LBack));
    LTriangle.ClosePath;

    ACanvas.Fill.Kind := TBrushKind.Solid;
    ACanvas.Fill.Color := TAlphaColor($FFFFC83C);
    ACanvas.FillPath(LTriangle, 1);
  finally
    LTriangle.Free;
  end;
end;

procedure TMinimapRenderer.DrawMarker(const ACanvas: TCanvas; const ACenter: TPointF;
  const ASize: Single; const AFill: TAlphaColor; const AText: string);
begin
  var LRect := RectF(ACenter.X - ASize / 2, ACenter.Y - ASize / 2,
    ACenter.X + ASize / 2, ACenter.Y + ASize / 2);

  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := AFill;
  ACanvas.FillEllipse(LRect, 1);

  if AText <> '' then
  begin
    ACanvas.Fill.Color := TAlphaColor($FFFFFFFF);
    ACanvas.Font.Size := ASize * 0.7;
    ACanvas.FillText(LRect, AText, False, 1, [], TTextAlign.Center, TTextAlign.Center);
  end;
end;

procedure TMinimapRenderer.DrawSolutionPath(const ACanvas: TCanvas;
  const AOriginX, AOriginY, ACellSize: Single; const ASolution: TArray<TPoint2D>);
begin
  if Length(ASolution) < 2 then
  begin
    Exit;
  end;

  ACanvas.Stroke.Kind := TBrushKind.Solid;
  ACanvas.Stroke.Color := TAlphaColor($FFFF6B3C);
  ACanvas.Stroke.Thickness := Max(2, ACellSize * 0.22);

  for var I := 0 to High(ASolution) - 1 do
  begin
    var LAx := AOriginX + (ASolution[I].X + 0.5) * ACellSize;
    var LAy := AOriginY + (ASolution[I].Y + 0.5) * ACellSize;
    var LBx := AOriginX + (ASolution[I + 1].X + 0.5) * ACellSize;
    var LBy := AOriginY + (ASolution[I + 1].Y + 0.5) * ACellSize;
    ACanvas.DrawLine(PointF(LAx, LAy), PointF(LBx, LBy), 1);
  end;
end;

procedure TMinimapRenderer.DrawPlan(const ACanvas: TCanvas; const ABounds: TRectF;
  const AMaze: TMazeGenerator; out AOriginX, AOriginY, ACellSize: Single);
begin
  // 배경(설계도 느낌)
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := TAlphaColor($FF15171E);
  ACanvas.FillRect(ABounds, 1);

  ACellSize := Min((ABounds.Width - 40) / AMaze.Width, (ABounds.Height - 40) / AMaze.Height);
  var LGridW := ACellSize * AMaze.Width;
  var LGridH := ACellSize * AMaze.Height;
  AOriginX := ABounds.Left + (ABounds.Width - LGridW) / 2;
  AOriginY := ABounds.Top + (ABounds.Height - LGridH) / 2;

  // 통로 바닥
  ACanvas.Fill.Color := TAlphaColor($FF2A2E38);
  ACanvas.FillRect(RectF(AOriginX, AOriginY, AOriginX + LGridW, AOriginY + LGridH), 1);

  // 벽
  ACanvas.Stroke.Kind := TBrushKind.Solid;
  ACanvas.Stroke.Color := TAlphaColor($FFE8D8B0);
  ACanvas.Stroke.Thickness := Max(1.5, ACellSize * 0.16);

  for var Y := 0 to AMaze.Height - 1 do
  begin
    for var X := 0 to AMaze.Width - 1 do
    begin
      var LWalls := AMaze.WallsAt(X, Y);
      var LLeft := AOriginX + X * ACellSize;
      var LTop := AOriginY + Y * ACellSize;

      if wTop in LWalls then
      begin
        ACanvas.DrawLine(PointF(LLeft, LTop), PointF(LLeft + ACellSize, LTop), 1);
      end;

      if wBottom in LWalls then
      begin
        ACanvas.DrawLine(PointF(LLeft, LTop + ACellSize), PointF(LLeft + ACellSize, LTop + ACellSize), 1);
      end;

      if wLeft in LWalls then
      begin
        ACanvas.DrawLine(PointF(LLeft, LTop), PointF(LLeft, LTop + ACellSize), 1);
      end;

      if wRight in LWalls then
      begin
        ACanvas.DrawLine(PointF(LLeft + ACellSize, LTop), PointF(LLeft + ACellSize, LTop + ACellSize), 1);
      end;
    end;
  end;

  // 입구(S)·출구(E) 마커
  var LEntrance := AMaze.EntrancePoint;
  var LExit := AMaze.ExitPoint;
  var LMarkerSize := ACellSize * 0.72;

  DrawMarker(ACanvas, PointF(AOriginX + (LEntrance.X + 0.5) * ACellSize, AOriginY + (LEntrance.Y + 0.5) * ACellSize),
    LMarkerSize, TAlphaColor($FF2E9E54), 'S');
  DrawMarker(ACanvas, PointF(AOriginX + (LExit.X + 0.5) * ACellSize, AOriginY + (LExit.Y + 0.5) * ACellSize),
    LMarkerSize, TAlphaColor($FFC0392B), 'E');
end;

procedure TMinimapRenderer.DrawCharacter(const ACanvas: TCanvas; const APx, APy, AYaw, ASize: Single);
begin
  // 진행 방향 표시(셀 안에 들어오도록 작게) — 발 밑 화살표
  var LFwdX := Sin(AYaw);
  var LFwdY := Cos(AYaw);
  var LRightX := Cos(AYaw);
  var LRightY := -Sin(AYaw);

  var LPointer := TPathData.Create;
  try
    var LTipX := APx + LFwdX * ASize * 0.34;
    var LTipY := APy + LFwdY * ASize * 0.34;
    var LBaseX := APx + LFwdX * ASize * 0.12;
    var LBaseY := APy + LFwdY * ASize * 0.12;

    LPointer.MoveTo(PointF(LTipX, LTipY));
    LPointer.LineTo(PointF(LBaseX + LRightX * ASize * 0.12, LBaseY + LRightY * ASize * 0.12));
    LPointer.LineTo(PointF(LBaseX - LRightX * ASize * 0.12, LBaseY - LRightY * ASize * 0.12));
    LPointer.ClosePath;

    ACanvas.Fill.Kind := TBrushKind.Solid;
    ACanvas.Fill.Color := TAlphaColor($FFFFC83C);
    ACanvas.FillPath(LPointer, 0.85);
  finally
    LPointer.Free;
  end;

  // 델파이 1.0 여신을 단순화한 캐릭터 (정면, 흐르는 가운)
  // 가운(로브) 사다리꼴
  var LRobe := TPathData.Create;
  try
    LRobe.MoveTo(PointF(APx - ASize * 0.10, APy - ASize * 0.12));
    LRobe.LineTo(PointF(APx + ASize * 0.10, APy - ASize * 0.12));
    LRobe.LineTo(PointF(APx + ASize * 0.22, APy + ASize * 0.30));
    LRobe.LineTo(PointF(APx - ASize * 0.22, APy + ASize * 0.30));
    LRobe.ClosePath;

    ACanvas.Fill.Kind := TBrushKind.Solid;
    ACanvas.Fill.Color := TAlphaColor($FFF0E8D2);
    ACanvas.FillPath(LRobe, 1);
  finally
    LRobe.Free;
  end;

  // 허리 띠(골드)
  ACanvas.Stroke.Kind := TBrushKind.Solid;
  ACanvas.Stroke.Color := TAlphaColor($FFC9A227);
  ACanvas.Stroke.Thickness := Max(1.5, ASize * 0.05);
  ACanvas.DrawLine(PointF(APx - ASize * 0.11, APy + ASize * 0.02),
    PointF(APx + ASize * 0.11, APy + ASize * 0.02), 1);

  // 머리카락(갈색)
  ACanvas.Fill.Color := TAlphaColor($FF6B4A2B);
  ACanvas.FillEllipse(RectF(APx - ASize * 0.13, APy - ASize * 0.32,
    APx + ASize * 0.13, APy - ASize * 0.08), 1);

  // 얼굴(살색)
  ACanvas.Fill.Color := TAlphaColor($FFF1C9A0);
  ACanvas.FillEllipse(RectF(APx - ASize * 0.095, APy - ASize * 0.29,
    APx + ASize * 0.095, APy - ASize * 0.10), 1);

  // 월계관(골드 아치)
  ACanvas.Stroke.Color := TAlphaColor($FFD9B23A);
  ACanvas.Stroke.Thickness := Max(1.5, ASize * 0.045);
  ACanvas.DrawLine(PointF(APx - ASize * 0.12, APy - ASize * 0.26),
    PointF(APx + ASize * 0.12, APy - ASize * 0.26), 1);
end;

procedure TMinimapRenderer.Render(const ACanvas: TCanvas; const ABounds: TRectF;
  const AMaze: TMazeGenerator; const AVisited: TVisitedGrid; const AState: TMinimapState);
begin
  // 배경 패널
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := TAlphaColor($C0101018);
  ACanvas.FillRect(ABounds, 1);

  if not AMaze.IsGenerated then
  begin
    Exit;
  end;

  // 정사각 셀 크기와 중앙 정렬 오프셋
  var LCellSize := Min((ABounds.Width - 8) / AMaze.Width, (ABounds.Height - 8) / AMaze.Height);
  var LGridW := LCellSize * AMaze.Width;
  var LGridH := LCellSize * AMaze.Height;
  var LOriginX := ABounds.Left + (ABounds.Width - LGridW) / 2;
  var LOriginY := ABounds.Top + (ABounds.Height - LGridH) / 2;

  var LExit := AMaze.ExitPoint;

  // 탐험한 칸만 렌더(fog of war)
  for var Y := 0 to AMaze.Height - 1 do
  begin
    for var X := 0 to AMaze.Width - 1 do
    begin
      if (Length(AVisited) > Y) and (Length(AVisited[Y]) > X) and AVisited[Y, X] then
      begin
        var LIsExit := (X = LExit.X) and (Y = LExit.Y);
        DrawCell(ACanvas, LOriginX + X * LCellSize, LOriginY + Y * LCellSize, LCellSize,
          AMaze.WallsAt(X, Y), LIsExit);
      end;
    end;
  end;

  // 해답 경로(켜진 경우)
  if AState.ShowSolution then
  begin
    DrawSolutionPath(ACanvas, LOriginX, LOriginY, LCellSize, AState.Solution);
  end;

  // 플레이어 위치(월드→미니맵)
  var LPx := LOriginX + (AState.PlayerWorldX / CELL_SIZE) * LCellSize;
  var LPy := LOriginY + (AState.PlayerWorldZ / CELL_SIZE) * LCellSize;

  DrawHintArrow(ACanvas, LPx, LPy, LCellSize, AState.HintDirection);
  DrawPlayer(ACanvas, LPx, LPy, AState.PlayerYaw, LCellSize);
end;

procedure TMinimapRenderer.RenderPreview(const ACanvas: TCanvas; const ABounds: TRectF;
  const AMaze: TMazeGenerator; const AShowSolution: Boolean; const ASolution: TArray<TPoint2D>);
begin
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := TAlphaColor($FF15171E);
  ACanvas.FillRect(ABounds, 1);

  if not AMaze.IsGenerated then
  begin
    Exit;
  end;

  var LOriginX: Single;
  var LOriginY: Single;
  var LCellSize: Single;
  DrawPlan(ACanvas, ABounds, AMaze, LOriginX, LOriginY, LCellSize);

  if AShowSolution then
  begin
    DrawSolutionPath(ACanvas, LOriginX, LOriginY, LCellSize, ASolution);
  end;
end;

procedure TMinimapRenderer.RenderPlay2D(const ACanvas: TCanvas; const ABounds: TRectF;
  const AMaze: TMazeGenerator; const APlayerWorldX, APlayerWorldZ, APlayerYaw: Single;
  const ACoinPts, AKeyPts: TArray<TPointF>;
  const AShowSolution: Boolean; const ASolution: TArray<TPoint2D>);
begin
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := TAlphaColor($FF15171E);
  ACanvas.FillRect(ABounds, 1);

  if not AMaze.IsGenerated then
  begin
    Exit;
  end;

  var LOriginX: Single;
  var LOriginY: Single;
  var LCellSize: Single;
  DrawPlan(ACanvas, ABounds, AMaze, LOriginX, LOriginY, LCellSize);

  if AShowSolution then
  begin
    DrawSolutionPath(ACanvas, LOriginX, LOriginY, LCellSize, ASolution);
  end;

  // 미획득 코인
  for var LPt in ACoinPts do
  begin
    DrawMarker(ACanvas, PointF(LOriginX + (LPt.X / CELL_SIZE) * LCellSize,
      LOriginY + (LPt.Y / CELL_SIZE) * LCellSize), LCellSize * 0.4, TAlphaColor($FFFFD54A), '');
  end;

  // 미획득 열쇠
  for var LPt in AKeyPts do
  begin
    DrawMarker(ACanvas, PointF(LOriginX + (LPt.X / CELL_SIZE) * LCellSize,
      LOriginY + (LPt.Y / CELL_SIZE) * LCellSize), LCellSize * 0.5, TAlphaColor($FF6CE0FF), '');
  end;

  // 플레이어(델파이 여신 캐릭터)
  var LPx := LOriginX + (APlayerWorldX / CELL_SIZE) * LCellSize;
  var LPy := LOriginY + (APlayerWorldZ / CELL_SIZE) * LCellSize;
  DrawCharacter(ACanvas, LPx, LPy, APlayerYaw, LCellSize);
end;

function TMinimapRenderer.PlanToWorld(const ABounds: TRectF; const AMaze: TMazeGenerator;
  const APoint: TPointF; out AWorldX, AWorldZ: Single): Boolean;
begin
  Result := False;
  AWorldX := 0;
  AWorldZ := 0;

  if not AMaze.IsGenerated then
  begin
    Exit;
  end;

  // DrawPlan 과 동일한 기하(여백 40, 중앙 정렬)
  var LCellSize := Min((ABounds.Width - 40) / AMaze.Width, (ABounds.Height - 40) / AMaze.Height);
  var LGridW := LCellSize * AMaze.Width;
  var LGridH := LCellSize * AMaze.Height;
  var LOriginX := ABounds.Left + (ABounds.Width - LGridW) / 2;
  var LOriginY := ABounds.Top + (ABounds.Height - LGridH) / 2;

  AWorldX := (APoint.X - LOriginX) / LCellSize * CELL_SIZE;
  AWorldZ := (APoint.Y - LOriginY) / LCellSize * CELL_SIZE;
  Result := True;
end;
{$ENDREGION}

end.
