unit Maze.Scene;

interface

{$REGION 'uses'}
uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.Math.Vectors,
  System.Generics.Collections,
  FMX.Graphics,
  FMX.Types3D,
  FMX.Controls3D,
  FMX.Objects3D,
  FMX.MaterialSources,
  FMX.Viewport3D,
  Maze.Core;
{$ENDREGION}

type
  /// <summary>미로 안에 배치되는 수집품의 종류.</summary>
  TItemKind = (
    ikCoin,
    ikKey
  );

  /// <summary>배치된 수집품 한 개의 정보.</summary>
  TMazeItem = record
    Kind: TItemKind;
    WorldX: Single;
    WorldZ: Single;
    Obj: TControl3D;
    Collected: Boolean;
  end;

  /// <summary>
  /// 코어 미로 데이터로부터 1인칭 3D 씬(바닥/천장/벽/수집품/출구 포털/토치 라이트)을
  /// 구성하고 갱신합니다. 생성된 모든 FMX 오브젝트는 내부 소유자에 귀속되어
  /// <see cref="Clear"/> 한 번으로 일괄 해제됩니다.
  /// </summary>
  TMazeScene = class
  private
    FViewport: TViewport3D;
    FCamera: TCamera;
    FAssets: TComponent;
    FRoot: TDummy;
    FWallMaterial: TLightMaterialSource;
    FFloorMaterial: TLightMaterialSource;
    FCeilingMaterial: TLightMaterialSource;
    FCoinMaterial: TLightMaterialSource;
    FKeyMaterial: TLightMaterialSource;
    FExitMaterial: TLightMaterialSource;
    FFlameMaterial: TLightMaterialSource;
    FBracketMaterial: TLightMaterialSource;
    FTorch: TLight;
    FItems: TList<TMazeItem>;
    FCoinObjects: TList<TControl3D>;
    FTrailObjects: TList<TControl3D>;
    FTrailMaterial: TLightMaterialSource;
    FTrailBuilt: Boolean;
    FCoinTotal: Integer;
    FBrickBitmap: TBitmap;
    FFloorBitmap: TBitmap;

    FFlameObjects: TList<TControl3D>;
    FTorchLights: TList<TLight>;
    FTorchPoints: TList<TPoint3D>;
    FFlicker: Single;
    function  NewLightMaterial(const ADiffuse, AAmbient, AEmissive: Cardinal): TLightMaterialSource;
    procedure CreateBrickTexture;
    procedure CreateStoneFloorTexture;
    procedure CreateMaterials;
    procedure BuildFloorAndCeiling(const AMaze: TMazeGenerator);
    procedure BuildWalls(const AMaze: TMazeGenerator);
    procedure BuildExitPortal(const AMaze: TMazeGenerator);
    procedure BuildItems(const AMaze: TMazeGenerator; const ACoinCount: Integer);
    procedure BuildTorches(const AMaze: TMazeGenerator);
    procedure CreateTorch;
    procedure UpdateTorchLights(const ADt: Single);
    function  AddWallCube(const ACenterX, ACenterZ, AWidth, ADepth: Single): TCube;
  public
    constructor Create(const AViewport: TViewport3D; const ACamera: TCamera);
    destructor Destroy; override;

    /// <summary>이전 씬을 비우고 주어진 미로로 3D 씬을 새로 구성합니다.</summary>
    /// <param name="AMaze">생성이 완료된 미로.</param>
    /// <param name="ACoinCount">배치할 코인 개수.</param>
    procedure Build(const AMaze: TMazeGenerator; const ACoinCount: Integer);

    /// <summary>모든 3D 오브젝트와 자원을 해제합니다.</summary>
    procedure Clear;

    /// <summary>코인 회전 등 시간 기반 연출을 갱신합니다.</summary>
    procedure Update(const ADt: Single);

    /// <summary>플레이어 위치 근처의 미수집 아이템을 획득 처리합니다.</summary>
    /// <param name="AWorldX">플레이어 월드 X.</param>
    /// <param name="AWorldZ">플레이어 월드 Z.</param>
    /// <param name="AKind">획득한 아이템 종류(반환값이 True 일 때만 유효).</param>
    /// <returns>아이템을 획득했으면 True.</returns>
    function TryPickup(const AWorldX, AWorldZ: Single; out AKind: TItemKind): Boolean;

    /// <summary>출구 포털을 잠금 해제 상태(녹색 발광)로 바꿉니다.</summary>
    procedure UnlockExit;

    /// <summary>해답 경로를 바닥의 발광 트레일로 표시하거나 숨깁니다.</summary>
    /// <param name="APath">입구→출구 경로(좌표 배열).</param>
    /// <param name="AVisible">표시 여부.</param>
    procedure ShowSolution(const APath: TArray<TPoint2D>; const AVisible: Boolean);

    /// <summary>아직 획득하지 않은 코인·열쇠의 월드 좌표(X, Z)를 반환합니다.</summary>
    /// <param name="ACoins">미획득 코인 좌표 배열.</param>
    /// <param name="AKey">미획득 열쇠 좌표 배열(없으면 빈 배열).</param>
    procedure GetUncollected(out ACoins: TArray<TPointF>; out AKey: TArray<TPointF>);

    /// <summary>배치된 전체 코인 개수.</summary>
    property CoinTotal: Integer read FCoinTotal;
  end;

implementation

{$REGION 'uses'}
uses
  System.UITypes,
  System.Math,
  FMX.Types,
  Maze.Player;
{$ENDREGION}

{$REGION 'TMazeScene'}
constructor TMazeScene.Create(const AViewport: TViewport3D; const ACamera: TCamera);
begin
  inherited Create;
  FViewport := AViewport;
  FCamera := ACamera;
  FItems := TList<TMazeItem>.Create;
  FCoinObjects := TList<TControl3D>.Create;
  FTrailObjects := TList<TControl3D>.Create;
  FFlameObjects := TList<TControl3D>.Create;
  FTorchLights := TList<TLight>.Create;
  FTorchPoints := TList<TPoint3D>.Create;
  FBrickBitmap := TBitmap.Create;
  FFloorBitmap := TBitmap.Create;
  CreateBrickTexture;
  CreateStoneFloorTexture;
end;

destructor TMazeScene.Destroy;
begin
  Clear;
  FItems.Free;
  FCoinObjects.Free;
  FTrailObjects.Free;
  FFlameObjects.Free;
  FTorchLights.Free;
  FTorchPoints.Free;
  FBrickBitmap.Free;
  FFloorBitmap.Free;
  inherited;
end;

function TMazeScene.AddWallCube(const ACenterX, ACenterZ, AWidth, ADepth: Single): TCube;
begin
  Result := TCube.Create(FAssets);
  Result.Parent := FRoot;
  Result.Width := AWidth;
  Result.Height := WALL_HEIGHT;
  Result.Depth := ADepth;
  Result.Position.Point := Point3D(ACenterX, -WALL_HEIGHT / 2, ACenterZ);
  Result.MaterialSource := FWallMaterial;
  Result.HitTest := False;
end;

procedure TMazeScene.Build(const AMaze: TMazeGenerator; const ACoinCount: Integer);
begin
  Clear;

  FAssets := TComponent.Create(nil);

  FRoot := TDummy.Create(FAssets);
  FRoot.Parent := FViewport;

  CreateMaterials;
  BuildFloorAndCeiling(AMaze);
  BuildWalls(AMaze);
  BuildExitPortal(AMaze);
  BuildItems(AMaze, ACoinCount);
  BuildTorches(AMaze);
  CreateTorch;
end;

procedure TMazeScene.BuildExitPortal(const AMaze: TMazeGenerator);
begin
  var LExit := AMaze.ExitPoint;
  var LCx := LExit.X * CELL_SIZE + CELL_SIZE / 2;
  var LCz := LExit.Y * CELL_SIZE + CELL_SIZE / 2;

  var LPortal := TCylinder.Create(FAssets);
  LPortal.Parent := FRoot;
  LPortal.Width := CELL_SIZE * 0.5;
  LPortal.Depth := CELL_SIZE * 0.5;
  LPortal.Height := WALL_HEIGHT * 0.9;
  LPortal.Position.Point := Point3D(LCx, -WALL_HEIGHT * 0.45, LCz);
  LPortal.MaterialSource := FExitMaterial;
  LPortal.HitTest := False;
end;

procedure TMazeScene.BuildFloorAndCeiling(const AMaze: TMazeGenerator);
begin
  var LWorldW := AMaze.Width * CELL_SIZE;
  var LWorldD := AMaze.Height * CELL_SIZE;
  var LCx := LWorldW / 2;
  var LCz := LWorldD / 2;

  var LFloor := TCube.Create(FAssets);
  LFloor.Parent := FRoot;
  LFloor.Width := LWorldW;
  LFloor.Height := 0.2;
  LFloor.Depth := LWorldD;
  LFloor.Position.Point := Point3D(LCx, 0.1, LCz);
  LFloor.MaterialSource := FFloorMaterial;
  LFloor.HitTest := False;

  var LCeiling := TCube.Create(FAssets);
  LCeiling.Parent := FRoot;
  LCeiling.Width := LWorldW;
  LCeiling.Height := 0.2;
  LCeiling.Depth := LWorldD;
  LCeiling.Position.Point := Point3D(LCx, -WALL_HEIGHT - 0.1, LCz);
  LCeiling.MaterialSource := FCeilingMaterial;
  LCeiling.HitTest := False;
end;

procedure TMazeScene.BuildItems(const AMaze: TMazeGenerator; const ACoinCount: Integer);
begin
  // 입구·출구를 제외한 가용 칸 목록 구성 후 섞기
  var LAvailable := TList<TPoint2D>.Create;
  try
    var LEntrance := AMaze.EntrancePoint;
    var LExit := AMaze.ExitPoint;

    for var Y := 0 to AMaze.Height - 1 do
    begin
      for var X := 0 to AMaze.Width - 1 do
      begin
        var LIsEntrance := (X = LEntrance.X) and (Y = LEntrance.Y);
        var LIsExit := (X = LExit.X) and (Y = LExit.Y);

        if not LIsEntrance and not LIsExit then
        begin
          LAvailable.Add(TPoint2D.Create(X, Y));
        end;
      end;
    end;

    // Fisher-Yates 셔플
    for var I: Integer := Integer(LAvailable.Count) - 1 downto 1 do
    begin
      var LJ := RandomRange(0, I + 1);
      var LTmp := LAvailable[I];
      LAvailable[I] := LAvailable[LJ];
      LAvailable[LJ] := LTmp;
    end;

    var LCoinTarget := ACoinCount;

    if LCoinTarget > Integer(LAvailable.Count) - 1 then
    begin
      LCoinTarget := Integer(LAvailable.Count) - 1;
    end;

    if LCoinTarget < 0 then
    begin
      LCoinTarget := 0;
    end;

    FCoinTotal := LCoinTarget;

    var LPlaced := 0;

    // 코인 배치
    for var I := 0 to LCoinTarget - 1 do
    begin
      var LCellPt := LAvailable[LPlaced];
      Inc(LPlaced);

      var LWx := LCellPt.X * CELL_SIZE + CELL_SIZE / 2;
      var LWz := LCellPt.Y * CELL_SIZE + CELL_SIZE / 2;

      var LCoin := TSphere.Create(FAssets);
      LCoin.Parent := FRoot;
      LCoin.Width := 0.9;
      LCoin.Height := 0.9;
      LCoin.Depth := 0.9;
      LCoin.Position.Point := Point3D(LWx, -1.1, LWz);
      LCoin.MaterialSource := FCoinMaterial;
      LCoin.HitTest := False;

      FCoinObjects.Add(LCoin);

      var LItem: TMazeItem;
      LItem.Kind := ikCoin;
      LItem.WorldX := LWx;
      LItem.WorldZ := LWz;
      LItem.Obj := LCoin;
      LItem.Collected := False;
      FItems.Add(LItem);
    end;

    // 열쇠 1개 배치
    if LPlaced < LAvailable.Count then
    begin
      var LCellPt := LAvailable[LPlaced];
      var LWx := LCellPt.X * CELL_SIZE + CELL_SIZE / 2;
      var LWz := LCellPt.Y * CELL_SIZE + CELL_SIZE / 2;

      var LKey := TCylinder.Create(FAssets);
      LKey.Parent := FRoot;
      LKey.Width := 0.8;
      LKey.Depth := 0.8;
      LKey.Height := 1.4;
      LKey.Position.Point := Point3D(LWx, -1.2, LWz);
      LKey.MaterialSource := FKeyMaterial;
      LKey.HitTest := False;

      FCoinObjects.Add(LKey);

      var LItem: TMazeItem;
      LItem.Kind := ikKey;
      LItem.WorldX := LWx;
      LItem.WorldZ := LWz;
      LItem.Obj := LKey;
      LItem.Collected := False;
      FItems.Add(LItem);
    end;
  finally
    LAvailable.Free;
  end;
end;

procedure TMazeScene.BuildTorches(const AMaze: TMazeGenerator);
const
  TORCH_Y = -WALL_HEIGHT * 0.62;   // 벽 중상단 높이
  MOUNT_OFFSET = CELL_SIZE / 2 - 0.35;
  LIGHT_POOL = 6;
begin
  for var Y := 0 to AMaze.Height - 1 do
  begin
    for var X := 0 to AMaze.Width - 1 do
    begin
      // 2칸 간격으로만 배치
      if Odd(X) or Odd(Y) then
      begin
        Continue;
      end;

      var LWalls := AMaze.WallsAt(X, Y);
      var LCenterX := X * CELL_SIZE + CELL_SIZE / 2;
      var LCenterZ := Y * CELL_SIZE + CELL_SIZE / 2;

      // 벽 우선순위: 남(wBottom) → 동(wRight) → 북(wTop) → 서(wLeft)
      // 불꽃은 항상 열린 칸(셀 중심) 쪽으로 약간 돌출시킨다.
      var LFx := LCenterX;
      var LFz := LCenterZ;
      var LFound := False;

      if wBottom in LWalls then
      begin
        LFx := LCenterX;
        LFz := LCenterZ + MOUNT_OFFSET;
        LFound := True;
      end
      else
      if wRight in LWalls then
      begin
        LFx := LCenterX + MOUNT_OFFSET;
        LFz := LCenterZ;
        LFound := True;
      end
      else
      if (Y = 0) and (wTop in LWalls) then
      begin
        LFx := LCenterX;
        LFz := LCenterZ - MOUNT_OFFSET;
        LFound := True;
      end
      else
      if (X = 0) and (wLeft in LWalls) then
      begin
        LFx := LCenterX - MOUNT_OFFSET;
        LFz := LCenterZ;
        LFound := True;
      end;

      if not LFound then
      begin
        Continue;
      end;

      // 브래킷(벽에서 살짝 튀어나온 어두운 받침)
      var LBracket := TCube.Create(FAssets);
      LBracket.Parent := FRoot;
      LBracket.Width := 0.25;
      LBracket.Height := 0.5;
      LBracket.Depth := 0.25;
      LBracket.Position.Point := Point3D(LFx, TORCH_Y + 0.35, LFz);
      LBracket.MaterialSource := FBracketMaterial;
      LBracket.HitTest := False;

      // 불꽃(주황 발광 구체)
      var LFlame := TSphere.Create(FAssets);
      LFlame.Parent := FRoot;
      LFlame.Width := 0.55;
      LFlame.Height := 0.75;
      LFlame.Depth := 0.55;
      LFlame.Position.Point := Point3D(LFx, TORCH_Y, LFz);
      LFlame.MaterialSource := FFlameMaterial;
      LFlame.HitTest := False;

      FFlameObjects.Add(LFlame);
      FTorchPoints.Add(Point3D(LFx, TORCH_Y, LFz));
    end;
  end;

  // 실제 조명 풀 생성(가까운 횃불로 매 프레임 재배치)
  var LPool := LIGHT_POOL;

  if LPool > FTorchPoints.Count then
  begin
    LPool := FTorchPoints.Count;
  end;

  for var I := 0 to LPool - 1 do
  begin
    var LLight := TLight.Create(FAssets);
    LLight.Parent := FRoot;
    LLight.LightType := TLightType.Point;
    LLight.Color := $FFFF9633;

    if I < FTorchPoints.Count then
    begin
      LLight.Position.Point := FTorchPoints[I];
    end;

    FTorchLights.Add(LLight);
  end;
end;

procedure TMazeScene.BuildWalls(const AMaze: TMazeGenerator);
begin
  for var Y := 0 to AMaze.Height - 1 do
  begin
    for var X := 0 to AMaze.Width - 1 do
    begin
      var LWalls := AMaze.WallsAt(X, Y);
      var LCenterX := X * CELL_SIZE + CELL_SIZE / 2;
      var LCenterZ := Y * CELL_SIZE + CELL_SIZE / 2;

      // 아래쪽 가로 벽(내부 가로 벽은 항상 이 분기에서 한 번만 생성)
      if wBottom in LWalls then
      begin
        AddWallCube(LCenterX, (Y + 1) * CELL_SIZE, CELL_SIZE + WALL_THICKNESS, WALL_THICKNESS);
      end;

      // 최상단 외곽 가로 벽
      if (Y = 0) and (wTop in LWalls) then
      begin
        AddWallCube(LCenterX, 0, CELL_SIZE + WALL_THICKNESS, WALL_THICKNESS);
      end;

      // 오른쪽 세로 벽
      if wRight in LWalls then
      begin
        AddWallCube((X + 1) * CELL_SIZE, LCenterZ, WALL_THICKNESS, CELL_SIZE + WALL_THICKNESS);
      end;

      // 최좌단 외곽 세로 벽
      if (X = 0) and (wLeft in LWalls) then
      begin
        AddWallCube(0, LCenterZ, WALL_THICKNESS, CELL_SIZE + WALL_THICKNESS);
      end;
    end;
  end;
end;

procedure TMazeScene.Clear;
begin
  FItems.Clear;
  FCoinObjects.Clear;
  FTrailObjects.Clear;
  FFlameObjects.Clear;
  FTorchLights.Clear;
  FTorchPoints.Clear;
  FFlicker := 0;
  FTrailMaterial := nil;
  FTrailBuilt := False;
  FCoinTotal := 0;
  FTorch := nil;
  FRoot := nil;
  FWallMaterial := nil;
  FFloorMaterial := nil;
  FCeilingMaterial := nil;
  FCoinMaterial := nil;
  FKeyMaterial := nil;
  FExitMaterial := nil;
  FFlameMaterial := nil;
  FBracketMaterial := nil;

  // 모든 FMX 오브젝트는 FAssets 소유 → 한 번에 해제
  FreeAndNil(FAssets);
end;

procedure TMazeScene.CreateBrickTexture;
const
  TEX_SIZE = 256;
  BRICK_COLS = 4;
  BRICK_ROWS = 8;
begin
  FBrickBitmap.SetSize(TEX_SIZE, TEX_SIZE);

  var LBrickW := TEX_SIZE / BRICK_COLS;
  var LBrickH := TEX_SIZE / BRICK_ROWS;
  var LCanvas := FBrickBitmap.Canvas;

  LCanvas.BeginScene;
  try
    // 줄눈(모르타르) 배경
    LCanvas.Clear(TAlphaColor($FF3A2A20));

    LCanvas.Fill.Kind := TBrushKind.Solid;
    LCanvas.Stroke.Kind := TBrushKind.Solid;
    LCanvas.Stroke.Color := TAlphaColor($FF24160E);
    LCanvas.Stroke.Thickness := 1;

    for var R := 0 to BRICK_ROWS - 1 do
    begin
      var LOffset := 0.0;

      // 한 줄 걸러 반 벽돌만큼 어긋나게(러닝 본드)
      if Odd(R) then
      begin
        LOffset := LBrickW / 2;
      end;

      for var C := -1 to BRICK_COLS - 1 do
      begin
        var LX := C * LBrickW + LOffset + 1.5;
        var LY := R * LBrickH + 1.5;
        var LRect := RectF(LX, LY, LX + LBrickW - 3, LY + LBrickH - 3);

        // 벽돌 색을 약간씩 다르게
        if ((R + C) and 1) = 0 then
        begin
          LCanvas.Fill.Color := TAlphaColor($FFA0522D);
        end
        else
        begin
          LCanvas.Fill.Color := TAlphaColor($FF8B4A28);
        end;

        LCanvas.FillRect(LRect, 1);
        LCanvas.DrawRect(LRect, 0, 0, AllCorners, 1);
      end;
    end;
  finally
    LCanvas.EndScene;
  end;
end;

procedure TMazeScene.CreateMaterials;
begin
  FWallMaterial := NewLightMaterial($FFFFFFFF, $FF1A1410, $FF000000);
  FWallMaterial.Texture := FBrickBitmap;
  FFloorMaterial := NewLightMaterial($FFFFFFFF, $FF0C0C0E, $FF000000);
  FFloorMaterial.Texture := FFloorBitmap;
  FCeilingMaterial := NewLightMaterial($FF26242A, $FF050505, $FF000000);
  FCoinMaterial := NewLightMaterial($FFFFD54A, $FF000000, $FF8A6A00);
  FKeyMaterial := NewLightMaterial($FF6CE0FF, $FF000000, $FF0A6A8A);
  FExitMaterial := NewLightMaterial($FFFF5050, $FF000000, $FF8A0000);

  // 횃불 불꽃: 강한 주황색 발광으로 항상 빛나 보이게
  FFlameMaterial := NewLightMaterial($FFFF8A1E, $FF000000, $FFFF7A14);
  // 횃불 브래킷: 어두운 금속/목재 느낌
  FBracketMaterial := NewLightMaterial($FF2A2018, $FF050402, $FF000000);
end;

procedure TMazeScene.CreateStoneFloorTexture;
const
  TEX_SIZE = 256;
  TILES = 6;
begin
  FFloorBitmap.SetSize(TEX_SIZE, TEX_SIZE);

  var LTile := TEX_SIZE / TILES;
  var LCanvas := FFloorBitmap.Canvas;

  LCanvas.BeginScene;
  try
    // 줄눈(타일 사이 어두운 틈) 배경
    LCanvas.Clear(TAlphaColor($FF15151A));

    LCanvas.Fill.Kind := TBrushKind.Solid;
    LCanvas.Stroke.Kind := TBrushKind.Solid;
    LCanvas.Stroke.Color := TAlphaColor($FF101014);
    LCanvas.Stroke.Thickness := 1;

    for var R := 0 to TILES - 1 do
    begin
      for var C := 0 to TILES - 1 do
      begin
        var LX := C * LTile + 1.5;
        var LY := R * LTile + 1.5;
        var LRect := RectF(LX, LY, LX + LTile - 3, LY + LTile - 3);

        // 타일마다 회색 명도를 약간씩 다르게(석재 얼룩)
        var LShade := 60 + RandomRange(0, 26);
        var LColor := TAlphaColor($FF000000) or (Cardinal(LShade) shl 16) or
          (Cardinal(LShade) shl 8) or Cardinal(LShade);

        LCanvas.Fill.Color := LColor;
        LCanvas.FillRect(LRect, 2);
        LCanvas.DrawRect(LRect, 2, 2, AllCorners, 1);

        // 점 노이즈로 거친 질감
        for var N := 0 to 14 do
        begin
          var LNx := LX + RandomRange(0, Round(LTile - 4));
          var LNy := LY + RandomRange(0, Round(LTile - 4));
          var LSpeck := LShade + RandomRange(-18, 18);

          if LSpeck < 0 then
          begin
            LSpeck := 0;
          end;

          if LSpeck > 255 then
          begin
            LSpeck := 255;
          end;

          LCanvas.Fill.Color := TAlphaColor($FF000000) or (Cardinal(LSpeck) shl 16) or
            (Cardinal(LSpeck) shl 8) or Cardinal(LSpeck);
          LCanvas.FillRect(RectF(LNx, LNy, LNx + 2, LNy + 2), 0);
        end;
      end;
    end;
  finally
    LCanvas.EndScene;
  end;
end;

procedure TMazeScene.CreateTorch;
begin
  FTorch := TLight.Create(FAssets);
  FTorch.Parent := FCamera;
  FTorch.LightType := TLightType.Point;
  // 벽 횃불이 분위기를 주도하도록 헤드램프는 은은하게
  FTorch.Color := $FF8A7A55;
  FTorch.Position.Point := Point3D(0, -0.2, 0);
end;

procedure TMazeScene.UpdateTorchLights(const ADt: Single);
begin
  if (FTorchLights.Count = 0) or (FTorchPoints.Count = 0) then
  begin
    Exit;
  end;

  FFlicker := FFlicker + ADt;

  // 불꽃 발광 깜빡임(전체 공유 머티리얼) — 두 주황 사이를 진동
  if Assigned(FFlameMaterial) then
  begin
    var LPulse := 0.5 + 0.5 * Sin(FFlicker * 9.0);
    var LR := 220 + Round(LPulse * 35);
    var LG := 90 + Round(LPulse * 45);
    FFlameMaterial.Emissive := TAlphaColor($FF000000) or (Cardinal(LR) shl 16) or
      (Cardinal(LG) shl 8) or Cardinal(20);
  end;

  // 플레이어(카메라) 위치 기준 가장 가까운 횃불로 풀 라이트 재배치
  var LCam := FCamera.Position.Point;

  var LUsed: TArray<Boolean>;
  SetLength(LUsed, FTorchPoints.Count);

  for var Slot := 0 to FTorchLights.Count - 1 do
  begin
    var LBest := -1;
    var LBestDist := MaxSingle;

    for var I := 0 to FTorchPoints.Count - 1 do
    begin
      if LUsed[I] then
      begin
        Continue;
      end;

      var LDx := FTorchPoints[I].X - LCam.X;
      var LDz := FTorchPoints[I].Z - LCam.Z;
      var LDist := LDx * LDx + LDz * LDz;

      if LDist < LBestDist then
      begin
        LBestDist := LDist;
        LBest := I;
      end;
    end;

    if LBest < 0 then
    begin
      Break;
    end;

    LUsed[LBest] := True;

    var LLight := FTorchLights[Slot];
    LLight.Position.Point := FTorchPoints[LBest];

    // 횃불마다 위상 다른 깜빡임으로 자연스러운 흔들림
    var LFlk := 0.7 + 0.3 * Sin(FFlicker * 11.0 + Slot * 1.7);
    var LR := Round(255 * LFlk);
    var LG := Round(150 * LFlk);
    var LB := Round(51 * LFlk);
    LLight.Color := TAlphaColor($FF000000) or (Cardinal(LR) shl 16) or
      (Cardinal(LG) shl 8) or Cardinal(LB);
  end;
end;

function TMazeScene.NewLightMaterial(const ADiffuse, AAmbient, AEmissive: Cardinal): TLightMaterialSource;
begin
  Result := TLightMaterialSource.Create(FAssets);
  Result.Diffuse := TAlphaColor(ADiffuse);
  Result.Ambient := TAlphaColor(AAmbient);
  Result.Emissive := TAlphaColor(AEmissive);
  Result.Specular := TAlphaColor($FF202020);
  Result.Shininess := 24;
end;

function TMazeScene.TryPickup(const AWorldX, AWorldZ: Single; out AKind: TItemKind): Boolean;
begin
  Result := False;

  for var I := 0 to FItems.Count - 1 do
  begin
    var LItem := FItems[I];

    if LItem.Collected then
    begin
      Continue;
    end;

    var LDx := LItem.WorldX - AWorldX;
    var LDz := LItem.WorldZ - AWorldZ;

    if (LDx * LDx + LDz * LDz) <= (PICKUP_RADIUS * PICKUP_RADIUS) then
    begin
      LItem.Collected := True;

      if Assigned(LItem.Obj) then
      begin
        LItem.Obj.Visible := False;
      end;

      FItems[I] := LItem;
      AKind := LItem.Kind;
      Result := True;
      Exit;
    end;
  end;
end;

procedure TMazeScene.UnlockExit;
begin
  if Assigned(FExitMaterial) then
  begin
    FExitMaterial.Diffuse := TAlphaColor($FF50FF78);
    FExitMaterial.Emissive := TAlphaColor($FF0A8A30);
  end;
end;

procedure TMazeScene.ShowSolution(const APath: TArray<TPoint2D>; const AVisible: Boolean);
begin
  if not Assigned(FRoot) then
  begin
    Exit;
  end;

  // 최초 표시 요청 시 한 번만 트레일을 생성
  if AVisible and not FTrailBuilt then
  begin
    if FTrailMaterial = nil then
    begin
      FTrailMaterial := NewLightMaterial($FFFFFFFF, $FF000000, $FFFF5A3C);
    end;

    for var I := 0 to High(APath) do
    begin
      var LWx := APath[I].X * CELL_SIZE + CELL_SIZE / 2;
      var LWz := APath[I].Y * CELL_SIZE + CELL_SIZE / 2;

      var LDot := TSphere.Create(FAssets);
      LDot.Parent := FRoot;
      LDot.Width := 0.5;
      LDot.Height := 0.5;
      LDot.Depth := 0.5;
      LDot.Position.Point := Point3D(LWx, -0.35, LWz);
      LDot.MaterialSource := FTrailMaterial;
      LDot.HitTest := False;
      FTrailObjects.Add(LDot);
    end;

    FTrailBuilt := True;
  end;

  for var LObj in FTrailObjects do
  begin
    if Assigned(LObj) then
    begin
      LObj.Visible := AVisible;
    end;
  end;
end;

procedure TMazeScene.GetUncollected(out ACoins: TArray<TPointF>; out AKey: TArray<TPointF>);
begin
  var LCoins := TList<TPointF>.Create;
  var LKeys := TList<TPointF>.Create;
  try
    for var LItem in FItems do
    begin
      if LItem.Collected then
      begin
        Continue;
      end;

      if LItem.Kind = ikCoin then
      begin
        LCoins.Add(PointF(LItem.WorldX, LItem.WorldZ));
      end
      else
      begin
        LKeys.Add(PointF(LItem.WorldX, LItem.WorldZ));
      end;
    end;

    ACoins := LCoins.ToArray;
    AKey := LKeys.ToArray;
  finally
    LCoins.Free;
    LKeys.Free;
  end;
end;

procedure TMazeScene.Update(const ADt: Single);
begin
  var LSpin := 90 * ADt;

  for var LObj in FCoinObjects do
  begin
    if Assigned(LObj) and LObj.Visible then
    begin
      LObj.RotationAngle.Y := LObj.RotationAngle.Y + LSpin;
    end;
  end;

  UpdateTorchLights(ADt);
end;
{$ENDREGION}

end.
