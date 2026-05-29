unit MainForm;

interface

{$REGION 'uses'}
uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.Diagnostics,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.StdCtrls,
  FMX.Edit,
  FMX.Objects,
  FMX.Graphics,
  FMX.Viewport3D,
  FMX.Controls3D,
  Maze.Core,
  Maze.Scene,
  Maze.Player,
  Maze.Minimap;
{$ENDREGION}

type
  /// <summary>게임 진행 상태.</summary>
  TGameState = (
    gsReady,
    gsPlaying,
    gsWon,
    gsLost
  );

  /// <summary>플레이 시점 모드.</summary>
  TPlayMode = (
    pmFirstPerson3D,
    pmTopDown2D
  );

  /// <summary>1인칭 3D 미로 게임의 메인 폼. 3D 뷰·게임 루프·입력·HUD 를 총괄합니다.</summary>
  TfrmMain = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FViewport: TViewport3D;
    FCamera: TCamera;
    FMaze: TMazeGenerator;
    FScene: TMazeScene;
    FPlayer: TPlayerController;
    FMinimap: TMinimapRenderer;
    FMinimapBox: TPaintBox;
    FPreviewBox: TPaintBox;
    FPlay2DBox: TPaintBox;

    FTopBar: TPanel;
    FBottomBar: TPanel;
    FEditWidth: TEdit;
    FEditHeight: TEdit;
    FBtnGenerate: TButton;
    FBtnStart: TButton;
    FBtnHint: TButton;
    FBtnMode: TButton;
    FBtnSolution: TButton;
    FLblTimer: TLabel;
    FLblCoins: TLabel;
    FLblKey: TLabel;
    FLblStatus: TLabel;
    FBanner: TText;

    FTimer: TTimer;
    FStopwatch: TStopwatch;
    FLastSeconds: Double;

    FGameState: TGameState;
    FPlayMode: TPlayMode;
    FShowSolution: Boolean;
    FSolution: TArray<TPoint2D>;
    FDragActive: Boolean;
    FDragWorldX: Single;
    FDragWorldZ: Single;
    FTimeLeft: Single;
    FCoins: Integer;
    FHasKey: Boolean;
    FVisited: TVisitedGrid;
    FHintDir: TDirection;
    FHintTimeLeft: Single;

    FKeyForward: Boolean;
    FKeyBack: Boolean;
    FKeyStrafeLeft: Boolean;
    FKeyStrafeRight: Boolean;
    FKeyTurnLeft: Boolean;
    FKeyTurnRight: Boolean;

    function  CreateBarLabel(const AParent: TControl; const AX, AWidth: Single; const AText: string): TLabel;
    function  CreateBarButton(const AParent: TControl; const AX, AWidth: Single; const AText: string;
      const AOnClick: TNotifyEvent): TButton;
    function  CreateBarEdit(const AParent: TControl; const AX, AWidth: Single; const AText: string): TEdit;
    procedure BuildUI;
    procedure Build3DEnvironment;

    procedure ApplyCamera;
    procedure UpdateViewVisibility;
    procedure ToggleSolution;
    procedure ToggleMode;
    procedure BuildVisitedGrid;
    procedure MarkVisited(const AX, AY: Integer);
    procedure RevealAround;
    procedure UpdateHud;
    procedure SetStatus(const AText: string);
    procedure GenerateMaze;
    procedure StartGame;
    procedure StopGame(const AWon: Boolean);
    procedure DoHint;
    procedure SetMovementKey(const AKey: Word; const APressed: Boolean);
    function  GatherInput: TPlayerInput;
    procedure ProcessPickups;

    procedure HandleGenerateClick(Sender: TObject);
    procedure HandleStartClick(Sender: TObject);
    procedure HandleHintClick(Sender: TObject);
    procedure HandleModeClick(Sender: TObject);
    procedure HandleSolutionClick(Sender: TObject);
    procedure HandleTimer(Sender: TObject);
    procedure HandleFormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure HandleFormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure HandleFormResize(Sender: TObject);
    procedure HandleMinimapPaint(Sender: TObject; Canvas: TCanvas);
    procedure HandlePreviewPaint(Sender: TObject; Canvas: TCanvas);
    procedure HandlePlay2DPaint(Sender: TObject; Canvas: TCanvas);
    procedure SetDragTarget(const ALocalX, ALocalY: Single);
    procedure HandlePlay2DMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure HandlePlay2DMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure HandlePlay2DMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
  public
  end;

var
  frmMain: TfrmMain;

const
  GAME_SECONDS = 90;
  TOP_BAR_HEIGHT = 60;
  BOTTOM_BAR_HEIGHT = 34;
  MINIMAP_SIZE = 220;

implementation

{$R *.fmx}

{$REGION 'uses'}
uses
  System.Math,
  System.Math.Vectors,
  FMX.Types3D;
{$ENDREGION}

{$REGION 'TfrmMain'}
procedure TfrmMain.ApplyCamera;
begin
  if not Assigned(FPlayer) then
  begin
    Exit;
  end;

  FCamera.Position.Point := Point3D(FPlayer.X, -EYE_HEIGHT, FPlayer.Z);
  FCamera.RotationAngle.Y := RadToDeg(FPlayer.Yaw);
end;

procedure TfrmMain.UpdateViewVisibility;
begin
  // 게임 시작 전(ready)에는 2D 평면도 미리보기를 띄운다
  var LPreview := (FGameState = gsReady) and FMaze.IsGenerated;

  if LPreview then
  begin
    FViewport.Visible := False;
    FPlay2DBox.Visible := False;
    FMinimapBox.Visible := False;
    FPreviewBox.Visible := True;
  end
  else
  begin
    var LIs3D := FPlayMode = pmFirstPerson3D;
    FPreviewBox.Visible := False;
    FViewport.Visible := LIs3D;
    FPlay2DBox.Visible := not LIs3D;
    FMinimapBox.Visible := LIs3D;
  end;

  if FPreviewBox.Visible then
  begin
    FPreviewBox.Repaint;
  end;

  if FPlay2DBox.Visible then
  begin
    FPlay2DBox.Repaint;
  end;

  if FViewport.Visible then
  begin
    FViewport.Repaint;
  end;
end;

procedure TfrmMain.ToggleMode;
begin
  if FPlayMode = pmFirstPerson3D then
  begin
    FPlayMode := pmTopDown2D;
    FBtnMode.Text := '모드: 2D';
  end
  else
  begin
    FPlayMode := pmFirstPerson3D;
    FBtnMode.Text := '모드: 3D';
  end;

  FDragActive := False;

  // 3D 트레일 표시 상태 동기화
  if FMaze.IsGenerated then
  begin
    FScene.ShowSolution(FSolution, FShowSolution);
  end;

  UpdateViewVisibility;

  if (FPlayMode = pmFirstPerson3D) and FViewport.Visible and FViewport.CanFocus then
  begin
    FViewport.SetFocus;
  end;
end;

procedure TfrmMain.ToggleSolution;
begin
  FShowSolution := not FShowSolution;

  if FShowSolution then
  begin
    FBtnSolution.Text := '해답 숨기기';
  end
  else
  begin
    FBtnSolution.Text := '해답 보기';
  end;

  if FMaze.IsGenerated then
  begin
    FScene.ShowSolution(FSolution, FShowSolution);
  end;

  // 보이는 2D 뷰 즉시 갱신
  if FPreviewBox.Visible then
  begin
    FPreviewBox.Repaint;
  end;

  if FPlay2DBox.Visible then
  begin
    FPlay2DBox.Repaint;
  end;
end;

procedure TfrmMain.Build3DEnvironment;
begin
  FViewport := TViewport3D.Create(Self);
  FViewport.Parent := Self;
  FViewport.Align := TAlignLayout.Client;
  FViewport.Color := TAlphaColor($FF05060A);
  FViewport.UsingDesignCamera := False;
  FViewport.OnKeyDown := HandleFormKeyDown;
  FViewport.OnKeyUp := HandleFormKeyUp;

  FCamera := TCamera.Create(Self);
  FCamera.Parent := FViewport;
  FCamera.AngleOfView := 75;
  FViewport.Camera := FCamera;

  // 미니맵은 뷰포트 위에 떠 있는 2D 오버레이
  FMinimapBox := TPaintBox.Create(Self);
  FMinimapBox.Parent := Self;
  FMinimapBox.HitTest := False;
  FMinimapBox.OnPaint := HandleMinimapPaint;

  // 승리/패배 안내 배너 (최상단 오버레이)
  FBanner := TText.Create(Self);
  FBanner.Parent := Self;
  FBanner.HitTest := False;
  FBanner.Font.Size := 48;
  FBanner.Color := TAlphaColor($FFFFD24A);
  FBanner.Visible := False;

  // 2D 탑다운 플레이 뷰 (3D 뷰 위를 덮음, 마우스 드래그 이동 지원)
  FPlay2DBox := TPaintBox.Create(Self);
  FPlay2DBox.Parent := Self;
  FPlay2DBox.Align := TAlignLayout.Client;
  FPlay2DBox.HitTest := True;
  FPlay2DBox.Visible := False;
  FPlay2DBox.OnPaint := HandlePlay2DPaint;
  FPlay2DBox.OnMouseDown := HandlePlay2DMouseDown;
  FPlay2DBox.OnMouseMove := HandlePlay2DMouseMove;
  FPlay2DBox.OnMouseUp := HandlePlay2DMouseUp;

  // 게임 시작 전 2D 평면도 미리보기 (가장 위)
  FPreviewBox := TPaintBox.Create(Self);
  FPreviewBox.Parent := Self;
  FPreviewBox.Align := TAlignLayout.Client;
  FPreviewBox.HitTest := False;
  FPreviewBox.Visible := False;
  FPreviewBox.OnPaint := HandlePreviewPaint;
end;

procedure TfrmMain.BuildUI;
begin
  FTopBar := TPanel.Create(Self);
  FTopBar.Parent := Self;
  FTopBar.Align := TAlignLayout.Top;
  FTopBar.Height := TOP_BAR_HEIGHT;

  CreateBarLabel(FTopBar, 12, 60, '가로');
  FEditWidth := CreateBarEdit(FTopBar, 12, 60, '15');

  CreateBarLabel(FTopBar, 80, 60, '세로');
  FEditHeight := CreateBarEdit(FTopBar, 80, 60, '15');

  FBtnGenerate := CreateBarButton(FTopBar, 150, 88, '미로 생성', HandleGenerateClick);
  FBtnStart := CreateBarButton(FTopBar, 242, 88, '게임 시작', HandleStartClick);
  FBtnHint := CreateBarButton(FTopBar, 334, 80, '힌트 (H)', HandleHintClick);
  FBtnMode := CreateBarButton(FTopBar, 418, 92, '모드: 3D', HandleModeClick);
  FBtnSolution := CreateBarButton(FTopBar, 514, 96, '해답 보기', HandleSolutionClick);

  FLblTimer := CreateBarLabel(FTopBar, 620, 120, '시간: --');
  FLblCoins := CreateBarLabel(FTopBar, 744, 120, '코인: 0 / 0');
  FLblKey := CreateBarLabel(FTopBar, 868, 130, '열쇠: 없음');

  FBottomBar := TPanel.Create(Self);
  FBottomBar.Parent := Self;
  FBottomBar.Align := TAlignLayout.Bottom;
  FBottomBar.Height := BOTTOM_BAR_HEIGHT;

  FLblStatus := TLabel.Create(Self);
  FLblStatus.Parent := FBottomBar;
  FLblStatus.Align := TAlignLayout.Client;
  FLblStatus.Margins.Left := 12;
  FLblStatus.Text := '미로를 생성한 뒤 게임을 시작하세요.';

  FBtnStart.Enabled := False;
  FBtnHint.Enabled := False;
  FBtnSolution.Enabled := False;
end;

procedure TfrmMain.BuildVisitedGrid;
begin
  SetLength(FVisited, FMaze.Height, FMaze.Width);

  for var Y := 0 to FMaze.Height - 1 do
  begin
    for var X := 0 to FMaze.Width - 1 do
    begin
      FVisited[Y, X] := False;
    end;
  end;
end;

function TfrmMain.CreateBarButton(const AParent: TControl; const AX, AWidth: Single;
  const AText: string; const AOnClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := AParent;
  Result.Position.X := AX;
  Result.Position.Y := 16;
  Result.Width := AWidth;
  Result.Height := 30;
  Result.Text := AText;
  Result.OnClick := AOnClick;
end;

function TfrmMain.CreateBarEdit(const AParent: TControl; const AX, AWidth: Single;
  const AText: string): TEdit;
begin
  Result := TEdit.Create(Self);
  Result.Parent := AParent;
  Result.Position.X := AX;
  Result.Position.Y := 30;
  Result.Width := AWidth - 4;
  Result.Height := 24;
  Result.Text := AText;
end;

function TfrmMain.CreateBarLabel(const AParent: TControl; const AX, AWidth: Single;
  const AText: string): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := AParent;
  Result.Position.X := AX;
  Result.Position.Y := 6;
  Result.Width := AWidth;
  Result.Height := 22;
  Result.Text := AText;
end;

procedure TfrmMain.DoHint;
begin
  if FGameState <> gsPlaying then
  begin
    Exit;
  end;

  var LPath := FMaze.FindPath(FPlayer.CurrentCell, FMaze.ExitPoint);

  if Length(LPath) < 2 then
  begin
    Exit;
  end;

  var LFrom := LPath[0];
  var LTo := LPath[1];

  if LTo.Y < LFrom.Y then
  begin
    FHintDir := dirUp;
  end
  else
  if LTo.Y > LFrom.Y then
  begin
    FHintDir := dirDown;
  end
  else
  if LTo.X < LFrom.X then
  begin
    FHintDir := dirLeft;
  end
  else
  begin
    FHintDir := dirRight;
  end;

  FHintTimeLeft := 3;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Caption := '미로찾기 3D - 1인칭 시점 (Opus 4.8)';

  BuildUI;
  Build3DEnvironment;

  FMaze := TMazeGenerator.Create(Self);
  FMaze.Width := 15;
  FMaze.Height := 15;

  FPlayer := TPlayerController.Create(FMaze);
  FScene := TMazeScene.Create(FViewport, FCamera);
  FMinimap := TMinimapRenderer.Create;

  FGameState := gsReady;
  FPlayMode := pmFirstPerson3D;
  FShowSolution := False;
  FHintDir := dirNone;

  FStopwatch := TStopwatch.StartNew;
  FLastSeconds := FStopwatch.Elapsed.TotalSeconds;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 16;
  FTimer.Enabled := False;
  FTimer.OnTimer := HandleTimer;

  OnKeyDown := HandleFormKeyDown;
  OnKeyUp := HandleFormKeyUp;
  OnResize := HandleFormResize;

  HandleFormResize(Self);
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FScene.Free;
  FPlayer.Free;
  FMinimap.Free;
end;

function TfrmMain.GatherInput: TPlayerInput;
begin
  Result.MoveForward := 0;
  Result.MoveStrafe := 0;
  Result.Turn := 0;

  if FKeyForward then
  begin
    Result.MoveForward := Result.MoveForward + 1;
  end;

  if FKeyBack then
  begin
    Result.MoveForward := Result.MoveForward - 1;
  end;

  if FKeyStrafeRight then
  begin
    Result.MoveStrafe := Result.MoveStrafe + 1;
  end;

  if FKeyStrafeLeft then
  begin
    Result.MoveStrafe := Result.MoveStrafe - 1;
  end;

  if FKeyTurnRight then
  begin
    Result.Turn := Result.Turn + 1;
  end;

  if FKeyTurnLeft then
  begin
    Result.Turn := Result.Turn - 1;
  end;
end;

procedure TfrmMain.GenerateMaze;
begin
  var LWidth := EnsureRange(StrToIntDef(FEditWidth.Text, 15), 5, 40);
  var LHeight := EnsureRange(StrToIntDef(FEditHeight.Text, 15), 5, 40);
  FEditWidth.Text := LWidth.ToString;
  FEditHeight.Text := LHeight.ToString;

  FMaze.Width := LWidth;
  FMaze.Height := LHeight;

  var LSw := TStopwatch.StartNew;
  FMaze.Generate;
  LSw.Stop;

  var LCoinCount := Max(3, (FMaze.Width * FMaze.Height) div 24);
  FScene.Build(FMaze, LCoinCount);

  // 해답 경로 미리 계산 후 3D 트레일 준비
  FSolution := FMaze.FindSolution;
  FScene.ShowSolution(FSolution, FShowSolution);

  FPlayer.Reset;
  ApplyCamera;

  BuildVisitedGrid;
  RevealAround;

  FGameState := gsReady;
  FCoins := 0;
  FHasKey := False;
  FHintDir := dirNone;
  FTimeLeft := GAME_SECONDS;

  FBanner.Visible := False;
  FBtnStart.Enabled := True;
  FBtnStart.Text := '게임 시작';
  FBtnHint.Enabled := True;
  FBtnSolution.Enabled := True;

  FLastSeconds := FStopwatch.Elapsed.TotalSeconds;
  FTimer.Enabled := True;

  // 게임 시작 전 2D 평면도 미리보기 모드
  UpdateViewVisibility;

  UpdateHud;
  SetStatus(Format('미로 생성 완료 (%d x %d) - 소요 %d ms. 평면도를 확인하고 "게임 시작"을 누르세요.',
    [FMaze.Width, FMaze.Height, LSw.ElapsedMilliseconds]));
end;

procedure TfrmMain.HandleFormKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar;
  Shift: TShiftState);
begin
  if Key = vkH then
  begin
    DoHint;
    Exit;
  end;

  SetMovementKey(Key, True);
end;

procedure TfrmMain.HandleFormKeyUp(Sender: TObject; var Key: Word; var KeyChar: WideChar;
  Shift: TShiftState);
begin
  SetMovementKey(Key, False);
end;

procedure TfrmMain.HandleFormResize(Sender: TObject);
begin
  if not Assigned(FMinimapBox) then
  begin
    Exit;
  end;

  FMinimapBox.SetBounds(ClientWidth - MINIMAP_SIZE - 12, TOP_BAR_HEIGHT + 12,
    MINIMAP_SIZE, MINIMAP_SIZE);

  if Assigned(FBanner) then
  begin
    FBanner.SetBounds(0, ClientHeight / 2 - 60, ClientWidth, 120);
  end;
end;

procedure TfrmMain.HandleGenerateClick(Sender: TObject);
begin
  GenerateMaze;
end;

procedure TfrmMain.HandleHintClick(Sender: TObject);
begin
  DoHint;

  if Assigned(FViewport) and FViewport.Visible and FViewport.CanFocus then
  begin
    FViewport.SetFocus;
  end;
end;

procedure TfrmMain.HandleModeClick(Sender: TObject);
begin
  ToggleMode;
end;

procedure TfrmMain.HandleSolutionClick(Sender: TObject);
begin
  ToggleSolution;

  if Assigned(FViewport) and FViewport.Visible and FViewport.CanFocus then
  begin
    FViewport.SetFocus;
  end;
end;

procedure TfrmMain.HandleMinimapPaint(Sender: TObject; Canvas: TCanvas);
begin
  if not Assigned(FMaze) or not FMaze.IsGenerated then
  begin
    Exit;
  end;

  var LState: TMinimapState;
  LState.PlayerWorldX := FPlayer.X;
  LState.PlayerWorldZ := FPlayer.Z;
  LState.PlayerYaw := FPlayer.Yaw;
  LState.HintDirection := FHintDir;
  LState.HasKey := FHasKey;
  LState.ShowSolution := FShowSolution;
  LState.Solution := FSolution;

  FMinimap.Render(Canvas, FMinimapBox.LocalRect, FMaze, FVisited, LState);
end;

procedure TfrmMain.HandlePreviewPaint(Sender: TObject; Canvas: TCanvas);
begin
  if not Assigned(FMaze) or not FMaze.IsGenerated then
  begin
    Exit;
  end;

  FMinimap.RenderPreview(Canvas, FPreviewBox.LocalRect, FMaze, FShowSolution, FSolution);
end;

procedure TfrmMain.HandlePlay2DPaint(Sender: TObject; Canvas: TCanvas);
begin
  if not Assigned(FMaze) or not FMaze.IsGenerated then
  begin
    Exit;
  end;

  var LCoins: TArray<TPointF>;
  var LKeys: TArray<TPointF>;
  FScene.GetUncollected(LCoins, LKeys);

  FMinimap.RenderPlay2D(Canvas, FPlay2DBox.LocalRect, FMaze,
    FPlayer.X, FPlayer.Z, FPlayer.Yaw, LCoins, LKeys, FShowSolution, FSolution);
end;

procedure TfrmMain.SetDragTarget(const ALocalX, ALocalY: Single);
begin
  var LWorldX: Single;
  var LWorldZ: Single;

  if FMinimap.PlanToWorld(FPlay2DBox.LocalRect, FMaze, PointF(ALocalX, ALocalY), LWorldX, LWorldZ) then
  begin
    FDragWorldX := LWorldX;
    FDragWorldZ := LWorldZ;
    FDragActive := True;
  end;
end;

procedure TfrmMain.HandlePlay2DMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Single);
begin
  if (FGameState = gsPlaying) and (FPlayMode = pmTopDown2D) then
  begin
    SetDragTarget(X, Y);
  end;
end;

procedure TfrmMain.HandlePlay2DMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
begin
  if FDragActive and (FGameState = gsPlaying) and (FPlayMode = pmTopDown2D) then
  begin
    SetDragTarget(X, Y);
  end;
end;

procedure TfrmMain.HandlePlay2DMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Single);
begin
  FDragActive := False;
end;

procedure TfrmMain.HandleStartClick(Sender: TObject);
begin
  if FGameState = gsPlaying then
  begin
    StopGame(False);
  end
  else
  begin
    StartGame;
  end;
end;

procedure TfrmMain.HandleTimer(Sender: TObject);
begin
  var LNow := FStopwatch.Elapsed.TotalSeconds;
  var LDt := LNow - FLastSeconds;
  FLastSeconds := LNow;

  if LDt > 0.1 then
  begin
    LDt := 0.1;
  end;

  if FGameState = gsPlaying then
  begin
    if FPlayMode = pmFirstPerson3D then
    begin
      FPlayer.Update(LDt, GatherInput);
    end
    else
    begin
      // 2D 탑다운: 절대 방향 이동(시선 회전 없음)
      var LDirX := 0.0;
      var LDirZ := 0.0;

      if FKeyForward then
      begin
        LDirZ := LDirZ - 1;
      end;

      if FKeyBack then
      begin
        LDirZ := LDirZ + 1;
      end;

      if FKeyStrafeLeft or FKeyTurnLeft then
      begin
        LDirX := LDirX - 1;
      end;

      if FKeyStrafeRight or FKeyTurnRight then
      begin
        LDirX := LDirX + 1;
      end;

      // 키 입력이 없고 드래그 중이면 마우스 목표 지점으로 이동
      if (LDirX = 0) and (LDirZ = 0) and FDragActive then
      begin
        var LToX := FDragWorldX - FPlayer.X;
        var LToZ := FDragWorldZ - FPlayer.Z;
        var LDist := Sqrt(LToX * LToX + LToZ * LToZ);

        if LDist > 0.15 then
        begin
          LDirX := LToX / LDist;
          LDirZ := LToZ / LDist;
        end;
      end;

      FPlayer.MoveContinuous(LDt, LDirX, LDirZ);
    end;

    FTimeLeft := FTimeLeft - LDt;
    RevealAround;
    ProcessPickups;

    if FHintTimeLeft > 0 then
    begin
      FHintTimeLeft := FHintTimeLeft - LDt;

      if FHintTimeLeft <= 0 then
      begin
        FHintDir := dirNone;
      end;
    end;

    if FHasKey and FPlayer.IsAtExit then
    begin
      StopGame(True);
    end
    else
    if FTimeLeft <= 0 then
    begin
      FTimeLeft := 0;
      StopGame(False);
    end;

    UpdateHud;
  end;

  ApplyCamera;

  if Assigned(FScene) then
  begin
    FScene.Update(LDt);
  end;

  // 현재 보이는 뷰만 다시 렌더
  if FViewport.Visible then
  begin
    FViewport.Repaint;
  end;

  if FPlay2DBox.Visible then
  begin
    FPlay2DBox.Repaint;
  end;

  if FMinimapBox.Visible then
  begin
    FMinimapBox.Repaint;
  end;
end;

procedure TfrmMain.MarkVisited(const AX, AY: Integer);
begin
  if (AY >= 0) and (AY < Length(FVisited)) and (AX >= 0) and (AX < Length(FVisited[AY])) then
  begin
    FVisited[AY, AX] := True;
  end;
end;

procedure TfrmMain.ProcessPickups;
begin
  var LKind: TItemKind;

  while FScene.TryPickup(FPlayer.X, FPlayer.Z, LKind) do
  begin
    if LKind = ikCoin then
    begin
      Inc(FCoins);
    end
    else
    begin
      FHasKey := True;
      FScene.UnlockExit;
      SetStatus('열쇠를 획득했습니다! 출구가 열렸습니다.');
    end;
  end;
end;

procedure TfrmMain.RevealAround;
begin
  var LCell := FPlayer.CurrentCell;
  MarkVisited(LCell.X, LCell.Y);

  if FMaze.CanMove(LCell.X, LCell.Y, dirUp) then
  begin
    MarkVisited(LCell.X, LCell.Y - 1);
  end;

  if FMaze.CanMove(LCell.X, LCell.Y, dirDown) then
  begin
    MarkVisited(LCell.X, LCell.Y + 1);
  end;

  if FMaze.CanMove(LCell.X, LCell.Y, dirLeft) then
  begin
    MarkVisited(LCell.X - 1, LCell.Y);
  end;

  if FMaze.CanMove(LCell.X, LCell.Y, dirRight) then
  begin
    MarkVisited(LCell.X + 1, LCell.Y);
  end;
end;

procedure TfrmMain.SetMovementKey(const AKey: Word; const APressed: Boolean);
begin
  case AKey of
    vkW, vkUp:
    begin
      FKeyForward := APressed;
    end;
    vkS, vkDown:
    begin
      FKeyBack := APressed;
    end;
    vkA:
    begin
      FKeyStrafeLeft := APressed;
    end;
    vkD:
    begin
      FKeyStrafeRight := APressed;
    end;
    vkLeft, vkQ:
    begin
      FKeyTurnLeft := APressed;
    end;
    vkRight, vkE:
    begin
      FKeyTurnRight := APressed;
    end;
  end;
end;

procedure TfrmMain.SetStatus(const AText: string);
begin
  FLblStatus.Text := AText;
end;

procedure TfrmMain.StartGame;
begin
  if not FMaze.IsGenerated then
  begin
    SetStatus('먼저 미로를 생성하세요.');
    Exit;
  end;

  FPlayer.Reset;
  FCoins := 0;
  FHasKey := False;
  FTimeLeft := GAME_SECONDS;
  FHintDir := dirNone;
  FDragActive := False;
  FGameState := gsPlaying;

  BuildVisitedGrid;
  RevealAround;
  ApplyCamera;

  FBanner.Visible := False;
  FBtnStart.Text := '게임 중지';

  FLastSeconds := FStopwatch.Elapsed.TotalSeconds;
  FTimer.Enabled := True;

  // 선택한 모드(2D/3D)에 맞는 뷰로 전환
  UpdateViewVisibility;

  if (FPlayMode = pmFirstPerson3D) and FViewport.Visible and FViewport.CanFocus then
  begin
    FViewport.SetFocus;
  end;

  UpdateHud;

  if FPlayMode = pmFirstPerson3D then
  begin
    SetStatus('출발! WASD 이동 · ←/→(Q/E) 시선 회전 · H 힌트. 열쇠를 찾아 출구로!');
  end
  else
  begin
    SetStatus('출발! 화살표/WASD 로 이동(위에서 내려다보기) · H 힌트. 열쇠를 찾아 출구로!');
  end;
end;

procedure TfrmMain.StopGame(const AWon: Boolean);
begin
  FBtnStart.Text := '게임 시작';

  if AWon then
  begin
    FGameState := gsWon;
    FBanner.Text := '탈출 성공!';
    FBanner.Visible := True;
    SetStatus(Format('축하합니다! 미로를 탈출했습니다. (사용 시간 %.1f초, 코인 %d/%d)',
      [GAME_SECONDS - FTimeLeft, FCoins, FScene.CoinTotal]));
  end
  else
  begin
    if FGameState = gsPlaying then
    begin
      if FTimeLeft <= 0 then
      begin
        FGameState := gsLost;
        FBanner.Text := '시간 초과!';
        FBanner.Visible := True;
        SetStatus('시간이 초과되어 게임에서 패배했습니다.');
      end
      else
      begin
        FGameState := gsReady;
        SetStatus('게임을 중지했습니다.');
      end;
    end;
  end;

  UpdateHud;
end;

procedure TfrmMain.UpdateHud;
begin
  if FTimeLeft <= 0 then
  begin
    FLblTimer.Text := '시간: 0초';
  end
  else
  begin
    FLblTimer.Text := Format('시간: %d초', [Ceil(FTimeLeft)]);
  end;

  FLblCoins.Text := Format('코인: %d / %d', [FCoins, FScene.CoinTotal]);

  if FHasKey then
  begin
    FLblKey.Text := '열쇠: 획득 ✓';
  end
  else
  begin
    FLblKey.Text := '열쇠: 없음';
  end;
end;
{$ENDREGION}

end.
