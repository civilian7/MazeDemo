unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI,
  System.SysUtils, System.Variants, System.Classes, System.DateUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Buttons,
  MazeGenerator, MazeView;

type
  TGameState = (gsReady, gsPlaying, gsWon, gsLost);
  TfrmMain = class(TForm)
    pnlLeft: TPanel;
    pnlClient: TPanel;
    grpSettings: TGroupBox;
    lblWidth: TLabel;
    lblHeight: TLabel;
    lblCellSize: TLabel;
    edtWidth: TEdit;
    udWidth: TUpDown;
    edtHeight: TEdit;
    udHeight: TUpDown;
    edtCellSize: TEdit;
    udCellSize: TUpDown;
    btnGenerate: TButton;
    grpSolution: TGroupBox;
    btnFindSolution: TButton;
    chkShowSolution: TCheckBox;
    grpExport: TGroupBox;
    btnExportSVG: TButton;
    lblStatus: TLabel;
    ScrollBox: TScrollBox;
    SaveDialog: TSaveDialog;
    btnClearSolution: TButton;
    lblWallThickness: TLabel;
    edtWallThickness: TEdit;
    udWallThickness: TUpDown;
    pnlPreview: TPanel;
    lblPreview: TLabel;
    grpGame: TGroupBox;
    btnStartGame: TButton;
    lblTimer: TLabel;
    GameTimer: TTimer;
    pnlArrowKeys: TPanel;
    btnUp: TSpeedButton;
    btnDown: TSpeedButton;
    btnLeft: TSpeedButton;
    btnRight: TSpeedButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnGenerateClick(Sender: TObject);
    procedure btnFindSolutionClick(Sender: TObject);
    procedure chkShowSolutionClick(Sender: TObject);
    procedure btnExportSVGClick(Sender: TObject);
    procedure btnClearSolutionClick(Sender: TObject);
    procedure udCellSizeClick(Sender: TObject; Button: TUDBtnType);
    procedure udWallThicknessClick(Sender: TObject; Button: TUDBtnType);
    procedure btnStartGameClick(Sender: TObject);
    procedure GameTimerTimer(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnUpClick(Sender: TObject);
    procedure btnDownClick(Sender: TObject);
    procedure btnLeftClick(Sender: TObject);
    procedure btnRightClick(Sender: TObject);
  private
    FMazeGenerator: TMazeGenerator;
    FMazeView: TMazeView;
    FGameState: TGameState;
    FGameTimeLeft: Integer;
    procedure InitializeKoreanCaptions;
    procedure UpdateStatus(const Msg: string);
    procedure OnMazeGenerated(Sender: TObject);
    procedure OnSolutionFound(Sender: TObject);
    procedure OnPlayerMoved(Sender: TObject);
    procedure StartGame;
    procedure StopGame(Won: Boolean);
    procedure UpdateTimerDisplay;
    procedure MovePlayerInDirection(Direction: TDirection);
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

procedure TfrmMain.InitializeKoreanCaptions;
begin
  // 폼 타이틀
  Caption := '미로찾기 - Maze Generator Demo';

  // 설정 그룹
  grpSettings.Caption := ' 미로 설정 ';
  lblWidth.Caption := '가로 크기:';
  lblHeight.Caption := '세로 크기:';
  lblCellSize.Caption := '셀 크기:';
  lblWallThickness.Caption := '벽 두께:';
  btnGenerate.Caption := '미로 생성';

  // 해답 그룹
  grpSolution.Caption := ' 해답 찾기 ';
  btnFindSolution.Caption := '해답 찾기';
  chkShowSolution.Caption := '해답 표시';
  btnClearSolution.Caption := '해답 지우기';

  // 내보내기 그룹
  grpExport.Caption := ' 내보내기 ';
  btnExportSVG.Caption := 'SVG로 저장';

  // 게임 그룹
  grpGame.Caption := ' 미로 게임 ';
  btnStartGame.Caption := '게임 시작';
  lblTimer.Caption := '시간: 90초';

  // 저장 다이얼로그
  SaveDialog.Title := 'SVG 파일로 저장';
  SaveDialog.Filter := 'SVG 파일 (*.svg)|*.svg|모든 파일 (*.*)|*.*';

  // 설명 레이블
  lblPreview.Caption :=
    '게임 방법:'#13#10 +
    '화살표 키로 이동'#13#10 +
    '제한시간: 90초';
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  // 한글 캡션 설정
  InitializeKoreanCaptions;

  // 미로 생성기 컴포넌트 생성
  FMazeGenerator := TMazeGenerator.Create(Self);
  FMazeGenerator.Width := 15;
  FMazeGenerator.Height := 15;
  FMazeGenerator.OnMazeGenerated := OnMazeGenerated;
  FMazeGenerator.OnSolutionFound := OnSolutionFound;

  // 미로 뷰 컴포넌트 생성
  FMazeView := TMazeView.Create(Self);
  FMazeView.Parent := ScrollBox;
  FMazeView.MazeGenerator := FMazeGenerator;
  FMazeView.CellSize := 30;
  FMazeView.WallThickness := 4;
  FMazeView.OnPlayerMoved := OnPlayerMoved;

  // UI 초기값 설정
  udWidth.Position := FMazeGenerator.Width;
  udHeight.Position := FMazeGenerator.Height;
  udCellSize.Position := FMazeView.CellSize;
  udWallThickness.Position := FMazeView.WallThickness;

  // 게임 관련 초기화
  FGameState := gsReady;
  FGameTimeLeft := 90;
  GameTimer.Enabled := False;
  GameTimer.Interval := 1000; // 1초
  btnStartGame.Enabled := False;

  // 화살표 버튼 초기 비활성화
  btnUp.Enabled := False;
  btnDown.Enabled := False;
  btnLeft.Enabled := False;
  btnRight.Enabled := False;

  UpdateStatus('프로그램이 시작되었습니다. "미로 생성" 버튼을 클릭하세요.');
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  // 컴포넌트는 Self가 Owner이므로 자동 해제됨
end;

procedure TfrmMain.btnGenerateClick(Sender: TObject);
var
  StartTime: TDateTime;
begin
  Screen.Cursor := crHourGlass;
  try
    // 설정 적용
    FMazeGenerator.Width := udWidth.Position;
    FMazeGenerator.Height := udHeight.Position;

    UpdateStatus('미로를 생성하고 있습니다...');
    Application.ProcessMessages;

    StartTime := Now;

    // 미로 생성
    FMazeGenerator.Generate;

    // 뷰 업데이트
    FMazeView.CellSize := udCellSize.Position;
    FMazeView.WallThickness := udWallThickness.Position;
    FMazeView.ShowSolution := False;
    chkShowSolution.Checked := False;
    FMazeView.RefreshMaze;

    UpdateStatus(Format('미로 생성 완료! (%d x %d) - 소요시간: %d ms',
      [FMazeGenerator.Width, FMazeGenerator.Height,
       MilliSecondsBetween(Now, StartTime)]));

    // 버튼 활성화
    btnFindSolution.Enabled := True;
    btnExportSVG.Enabled := True;
    btnClearSolution.Enabled := False;
    btnStartGame.Enabled := True;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmMain.btnFindSolutionClick(Sender: TObject);
var
  StartTime: TDateTime;
  Found: Boolean;
begin
  Screen.Cursor := crHourGlass;
  try
    UpdateStatus('해답을 찾고 있습니다...');
    Application.ProcessMessages;

    StartTime := Now;
    Found := FMazeGenerator.FindSolution;

    if Found then
    begin
      chkShowSolution.Checked := True;
      FMazeView.ShowSolution := True;
      btnClearSolution.Enabled := True;

      UpdateStatus(Format('해답을 찾았습니다! 경로 길이: %d 칸, 소요시간: %d ms',
        [FMazeGenerator.SolutionPath.Count,
         MilliSecondsBetween(Now, StartTime)]));
    end
    else
    begin
      UpdateStatus('해답을 찾을 수 없습니다.');
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmMain.btnClearSolutionClick(Sender: TObject);
begin
  FMazeGenerator.ClearSolution;
  chkShowSolution.Checked := False;
  FMazeView.ShowSolution := False;
  btnClearSolution.Enabled := False;
  UpdateStatus('해답이 지워졌습니다.');
end;

procedure TfrmMain.chkShowSolutionClick(Sender: TObject);
begin
  FMazeView.ShowSolution := chkShowSolution.Checked;
end;

procedure TfrmMain.btnExportSVGClick(Sender: TObject);
var
  FileName: string;
begin
  SaveDialog.FileName := Format('Maze_%dx%d', [FMazeGenerator.Width, FMazeGenerator.Height]);

  if SaveDialog.Execute then
  begin
    FileName := SaveDialog.FileName;

    // 확장자가 없으면 추가
    if not FileName.EndsWith('.svg', True) then
      FileName := FileName + '.svg';

    try
      FMazeGenerator.SaveToSVG(FileName, udCellSize.Position, udWallThickness.Position);
      UpdateStatus(Format('SVG 파일로 저장되었습니다: %s', [FileName]));

      // 파일 열기 여부 확인
      if MessageDlg('SVG 파일이 저장되었습니다.'#13#10 +
                    '파일을 기본 프로그램으로 열어보시겠습니까?',
                    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
      begin
        ShellExecute(Handle, 'open', PChar(FileName), nil, nil, SW_SHOWNORMAL);
      end;
    except
      on E: Exception do
      begin
        UpdateStatus('SVG 저장 실패: ' + E.Message);
        MessageDlg('파일 저장 중 오류가 발생했습니다:'#13#10 + E.Message,
                   mtError, [mbOK], 0);
      end;
    end;
  end;
end;

procedure TfrmMain.udCellSizeClick(Sender: TObject; Button: TUDBtnType);
begin
  FMazeView.CellSize := udCellSize.Position;
  FMazeView.RefreshMaze;
end;

procedure TfrmMain.udWallThicknessClick(Sender: TObject; Button: TUDBtnType);
begin
  FMazeView.WallThickness := udWallThickness.Position;
  FMazeView.RefreshMaze;
end;

procedure TfrmMain.UpdateStatus(const Msg: string);
begin
  lblStatus.Caption := Msg;
  Application.ProcessMessages;
end;

procedure TfrmMain.OnMazeGenerated(Sender: TObject);
begin
  // 미로 생성 완료 이벤트 핸들러
end;

procedure TfrmMain.OnSolutionFound(Sender: TObject);
begin
  // 해답 찾기 완료 이벤트 핸들러
end;

procedure TfrmMain.btnStartGameClick(Sender: TObject);
begin
  if FGameState = gsPlaying then
  begin
    // 게임 중지
    StopGame(False);
  end
  else
  begin
    // 게임 시작
    StartGame;
  end;
end;

procedure TfrmMain.StartGame;
begin
  // 미로가 생성되지 않았으면 먼저 생성
  if not FMazeGenerator.IsGenerated then
  begin
    UpdateStatus('먼저 미로를 생성해주세요.');
    Exit;
  end;

  // 게임 상태 초기화
  FGameState := gsPlaying;
  FGameTimeLeft := 90;

  // 플레이어 초기화
  FMazeGenerator.InitializePlayer;

  // 해답 숨기기
  FMazeView.ShowSolution := False;
  chkShowSolution.Checked := False;

  // 게임 모드 활성화
  FMazeView.GameMode := True;

  // 타이머 시작
  GameTimer.Enabled := True;
  UpdateTimerDisplay;

  // 미로 뷰 갱신
  FMazeView.Invalidate;

  // UI 업데이트
  btnStartGame.Caption := '게임 중지';
  btnGenerate.Enabled := False;
  btnFindSolution.Enabled := False;
  chkShowSolution.Enabled := False;

  // 화살표 버튼 활성화
  btnUp.Enabled := True;
  btnDown.Enabled := True;
  btnLeft.Enabled := True;
  btnRight.Enabled := True;

  UpdateStatus('게임 시작! 화살표 버튼 또는 키보드로 플레이어를 이동시켜 출구(우하단)로 가세요!');
end;

procedure TfrmMain.StopGame(Won: Boolean);
begin
  // 타이머 중지
  GameTimer.Enabled := False;

  // 게임 모드 비활성화
  FMazeView.GameMode := False;

  // UI 업데이트
  btnStartGame.Caption := '게임 시작';
  btnGenerate.Enabled := True;
  btnFindSolution.Enabled := True;
  chkShowSolution.Enabled := True;

  // 화살표 버튼 비활성화
  btnUp.Enabled := False;
  btnDown.Enabled := False;
  btnLeft.Enabled := False;
  btnRight.Enabled := False;

  if Won then
  begin
    FGameState := gsWon;
    UpdateStatus(Format('축하합니다! 미로를 탈출했습니다! (남은 시간: %d초)', [FGameTimeLeft]));
    MessageDlg('축하합니다!'#13#10'미로 탈출에 성공했습니다!', mtInformation, [mbOK], 0);
  end
  else
  begin
    if FGameState = gsPlaying then
    begin
      FGameState := gsLost;
      UpdateStatus('시간 초과! 게임에서 패배했습니다.');
      MessageDlg('시간 초과!'#13#10'미로 탈출에 실패했습니다.', mtWarning, [mbOK], 0);
    end
    else
    begin
      FGameState := gsReady;
      UpdateStatus('게임이 중지되었습니다.');
    end;
  end;
end;

procedure TfrmMain.GameTimerTimer(Sender: TObject);
begin
  if FGameState <> gsPlaying then
  begin
    GameTimer.Enabled := False;
    Exit;
  end;

  Dec(FGameTimeLeft);
  UpdateTimerDisplay;

  if FGameTimeLeft <= 0 then
  begin
    StopGame(False);
  end;
end;

procedure TfrmMain.UpdateTimerDisplay;
begin
  lblTimer.Caption := Format('시간: %d초', [FGameTimeLeft]);

  // 시간이 10초 이하면 빨간색으로 표시
  if FGameTimeLeft <= 10 then
    lblTimer.Font.Color := clRed
  else
    lblTimer.Font.Color := clBlack;
end;

procedure TfrmMain.OnPlayerMoved(Sender: TObject);
begin
  if FGameState <> gsPlaying then
    Exit;

  // 플레이어가 출구에 도달했는지 확인
  if FMazeGenerator.IsPlayerAtExit then
  begin
    StopGame(True);
  end;
end;

procedure TfrmMain.MovePlayerInDirection(Direction: TDirection);
var
  Moved: Boolean;
begin
  // 게임이 플레이 중일 때만 이동 처리
  if FGameState <> gsPlaying then
    Exit;

  Moved := FMazeGenerator.MovePlayer(Direction);

  if Moved then
  begin
    FMazeView.Invalidate; // 화면 갱신
    OnPlayerMoved(Self);   // 출구 도달 확인
  end;
end;

procedure TfrmMain.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  Direction: TDirection;
begin
  // 게임이 플레이 중일 때만 키 입력 처리
  if FGameState <> gsPlaying then
    Exit;

  case Key of
    VK_UP:
      begin
        MovePlayerInDirection(dirUp);
        Key := 0; // 키 이벤트 소비
      end;
    VK_DOWN:
      begin
        MovePlayerInDirection(dirDown);
        Key := 0;
      end;
    VK_LEFT:
      begin
        MovePlayerInDirection(dirLeft);
        Key := 0;
      end;
    VK_RIGHT:
      begin
        MovePlayerInDirection(dirRight);
        Key := 0;
      end;
  end;
end;

procedure TfrmMain.btnUpClick(Sender: TObject);
begin
  MovePlayerInDirection(dirUp);
end;

procedure TfrmMain.btnDownClick(Sender: TObject);
begin
  MovePlayerInDirection(dirDown);
end;

procedure TfrmMain.btnLeftClick(Sender: TObject);
begin
  MovePlayerInDirection(dirLeft);
end;

procedure TfrmMain.btnRightClick(Sender: TObject);
begin
  MovePlayerInDirection(dirRight);
end;

end.
