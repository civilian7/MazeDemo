program MazeDemo;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {frmMain},
  MazeGenerator in 'MazeGenerator.pas',
  MazeView in 'MazeView.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := '미로찾기 데모';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
