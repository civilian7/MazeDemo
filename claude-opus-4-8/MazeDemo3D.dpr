program MazeDemo3D;

uses
  System.StartUpCopy,
  FMX.Forms,
  MainForm in 'MainForm.pas' {frmMain},
  Maze.Core in 'Maze.Core.pas',
  Maze.Player in 'Maze.Player.pas',
  Maze.Scene in 'Maze.Scene.pas',
  Maze.Minimap in 'Maze.Minimap.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := '미로찾기 3D';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
