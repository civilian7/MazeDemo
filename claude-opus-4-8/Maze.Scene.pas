unit Maze.Scene;

interface

{$REGION 'uses'}
uses
  System.SysUtils,
  System.Classes,
  System.Types,
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
    FTorch: TLight;
    FItems: TList<TMazeItem>;
    FCoinObjects: TList<TControl3D>;
    FTrailObjects: TList<TControl3D>;
    FTrailMaterial: TLightMaterialSource;
    FTrailBuilt: Boolean;
    FCoinTotal: Integer;
    FBrickBitmap: TBitmap;
    function  NewLightMaterial(const ADiffuse, AAmbient, AEmissive: Cardinal): TLightMaterialSource;
    procedure CreateBrickTexture;
    procedure CreateMaterials;
    procedure BuildFloorAndCeiling(const AMaze: TMazeGenerator);
    procedure BuildWalls(const AMaze: TMazeGenerator);
    procedure BuildExitPortal(const AMaze: TMazeGenerator);
    procedure BuildItems(const AMaze: TMazeGenerator; const ACoinCount: Integer);
    procedure CreateTorch;
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
  System.Math.Vectors,
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
  FBrickBitmap := TBitmap.Create;
  CreateBrickTexture;
end;

destructor TMazeScene.Destroy;
begin
  Clear;
  FItems.Free;
  FCoinObjects.Free;
  FTrailObjects.Free;
  FBrickBitmap.Free;
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
  FFloorMaterial := NewLightMaterial($FF4A4640, $FF0A0A0A, $FF000000);
  FCeilingMaterial := NewLightMaterial($FF26242A, $FF050505, $FF000000);
  FCoinMaterial := NewLightMaterial($FFFFD54A, $FF000000, $FF8A6A00);
  FKeyMaterial := NewLightMaterial($FF6CE0FF, $FF000000, $FF0A6A8A);
  FExitMaterial := NewLightMaterial($FFFF5050, $FF000000, $FF8A0000);
end;

procedure TMazeScene.CreateTorch;
begin
  FTorch := TLight.Create(FAssets);
  FTorch.Parent := FCamera;
  FTorch.LightType := TLightType.Point;
  FTorch.Color := $FFFFF0D0;
  FTorch.Position.Point := Point3D(0, -0.2, 0);
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
end;
{$ENDREGION}

end.
