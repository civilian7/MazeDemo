object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'Maze Generator Demo'
  ClientHeight = 730
  ClientWidth = 950
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  PixelsPerInch = 96
  TextHeight = 15
  object pnlLeft: TPanel
    Left = 0
    Top = 0
    Width = 220
    Height = 710
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    object grpSettings: TGroupBox
      Left = 8
      Top = 8
      Width = 200
      Height = 200
      Caption = ' Settings '
      TabOrder = 0
      object lblWidth: TLabel
        Left = 16
        Top = 28
        Width = 54
        Height = 15
        Caption = 'Width:'
      end
      object lblHeight: TLabel
        Left = 16
        Top = 58
        Width = 54
        Height = 15
        Caption = 'Height:'
      end
      object lblCellSize: TLabel
        Left = 16
        Top = 88
        Width = 46
        Height = 15
        Caption = 'Cell Size:'
      end
      object lblWallThickness: TLabel
        Left = 16
        Top = 118
        Width = 46
        Height = 15
        Caption = 'Wall:'
      end
      object edtWidth: TEdit
        Left = 100
        Top = 25
        Width = 50
        Height = 23
        TabOrder = 0
        Text = '15'
      end
      object udWidth: TUpDown
        Left = 150
        Top = 25
        Width = 20
        Height = 23
        Associate = edtWidth
        Min = 5
        Max = 50
        Position = 15
        TabOrder = 1
      end
      object edtHeight: TEdit
        Left = 100
        Top = 55
        Width = 50
        Height = 23
        TabOrder = 2
        Text = '15'
      end
      object udHeight: TUpDown
        Left = 150
        Top = 55
        Width = 20
        Height = 23
        Associate = edtHeight
        Min = 5
        Max = 50
        Position = 15
        TabOrder = 3
      end
      object edtCellSize: TEdit
        Left = 100
        Top = 85
        Width = 50
        Height = 23
        TabOrder = 4
        Text = '30'
      end
      object udCellSize: TUpDown
        Left = 150
        Top = 85
        Width = 20
        Height = 23
        Associate = edtCellSize
        Min = 15
        Max = 60
        Position = 30
        TabOrder = 5
        OnClick = udCellSizeClick
      end
      object edtWallThickness: TEdit
        Left = 100
        Top = 115
        Width = 50
        Height = 23
        TabOrder = 6
        Text = '4'
      end
      object udWallThickness: TUpDown
        Left = 150
        Top = 115
        Width = 20
        Height = 23
        Associate = edtWallThickness
        Min = 2
        Max = 10
        Position = 4
        TabOrder = 7
        OnClick = udWallThicknessClick
      end
      object btnGenerate: TButton
        Left = 16
        Top = 156
        Width = 168
        Height = 30
        Caption = 'Generate'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 8
        OnClick = btnGenerateClick
      end
    end
    object grpSolution: TGroupBox
      Left = 8
      Top = 216
      Width = 200
      Height = 130
      Caption = ' Solution '
      TabOrder = 1
      object btnFindSolution: TButton
        Left = 16
        Top = 28
        Width = 168
        Height = 30
        Caption = 'Find Solution'
        Enabled = False
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 0
        OnClick = btnFindSolutionClick
      end
      object chkShowSolution: TCheckBox
        Left = 16
        Top = 68
        Width = 120
        Height = 17
        Caption = 'Show Solution'
        TabOrder = 1
        OnClick = chkShowSolutionClick
      end
      object btnClearSolution: TButton
        Left = 16
        Top = 91
        Width = 168
        Height = 25
        Caption = 'Clear'
        Enabled = False
        TabOrder = 2
        OnClick = btnClearSolutionClick
      end
    end
    object grpExport: TGroupBox
      Left = 8
      Top = 354
      Width = 200
      Height = 80
      Caption = ' Export '
      TabOrder = 2
      object btnExportSVG: TButton
        Left = 16
        Top = 28
        Width = 168
        Height = 35
        Caption = 'Save as SVG'
        Enabled = False
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 0
        OnClick = btnExportSVGClick
      end
    end
    object grpGame: TGroupBox
      Left = 8
      Top = 442
      Width = 200
      Height = 180
      Caption = ' Game '
      TabOrder = 3
      object lblTimer: TLabel
        Left = 16
        Top = 148
        Width = 168
        Height = 20
        Alignment = taCenter
        AutoSize = False
        Caption = 'Time: 90s'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clBlack
        Font.Height = -15
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object btnStartGame: TButton
        Left = 16
        Top = 28
        Width = 168
        Height = 35
        Caption = 'Start Game'
        Enabled = False
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 0
        OnClick = btnStartGameClick
      end
      object pnlArrowKeys: TPanel
        Left = 16
        Top = 72
        Width = 168
        Height = 70
        BevelOuter = bvNone
        TabOrder = 1
        object btnUp: TSpeedButton
          Left = 56
          Top = 0
          Width = 56
          Height = 30
          Caption = #9650
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -20
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
          OnClick = btnUpClick
        end
        object btnDown: TSpeedButton
          Left = 56
          Top = 40
          Width = 56
          Height = 30
          Caption = #9660
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -20
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
          OnClick = btnDownClick
        end
        object btnLeft: TSpeedButton
          Left = 0
          Top = 40
          Width = 56
          Height = 30
          Caption = #9664
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -20
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
          OnClick = btnLeftClick
        end
        object btnRight: TSpeedButton
          Left = 112
          Top = 40
          Width = 56
          Height = 30
          Caption = #9654
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -20
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
          OnClick = btnRightClick
        end
      end
    end
    object pnlPreview: TPanel
      Left = 8
      Top = 628
      Width = 200
      Height = 72
      BevelOuter = bvLowered
      TabOrder = 4
      object lblPreview: TLabel
        Left = 1
        Top = 1
        Width = 198
        Height = 70
        Align = alClient
        Alignment = taCenter
        AutoSize = False
        Caption = 'Info'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGray
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        Layout = tlCenter
        WordWrap = True
      end
    end
  end
  object pnlClient: TPanel
    Left = 220
    Top = 0
    Width = 730
    Height = 710
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 1
    object ScrollBox: TScrollBox
      Left = 0
      Top = 0
      Width = 730
      Height = 710
      Align = alClient
      BorderStyle = bsNone
      Color = clWhite
      ParentColor = False
      TabOrder = 0
    end
  end
  object lblStatus: TLabel
    Left = 0
    Top = 710
    Width = 950
    Height = 20
    Align = alBottom
    Alignment = taCenter
    AutoSize = False
    Caption = 'Ready'
    Color = clInfoBk
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clNavy
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentColor = False
    ParentFont = False
    Layout = tlCenter
  end
  object SaveDialog: TSaveDialog
    DefaultExt = 'svg'
    Filter = 'SVG File (*.svg)|*.svg|All Files (*.*)|*.*'
    Options = [ofOverwritePrompt, ofHideReadOnly, ofEnableSizing]
    Title = 'Save as SVG'
    Left = 440
    Top = 280
  end
  object GameTimer: TTimer
    Enabled = False
    OnTimer = GameTimerTimer
    Left = 440
    Top = 320
  end
end
