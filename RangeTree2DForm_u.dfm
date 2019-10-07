object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 617
  ClientWidth = 573
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object PaintBox1: TPaintBox
    Left = 24
    Top = 80
    Width = 521
    Height = 521
    OnMouseDown = PaintBoxMouseDown
    OnMouseMove = PaintBoxMouseMove
    OnMouseUp = PaintBoxMouseUp
  end
  object Label1: TLabel
    Left = 24
    Top = 8
    Width = 163
    Height = 25
    Caption = 'Number of Points'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -21
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object Label2: TLabel
    Left = 24
    Top = 47
    Width = 47
    Height = 23
    Caption = 'mode'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -19
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
  end
  object GenerateRandomPointsButton: TButton
    Left = 296
    Top = 8
    Width = 249
    Height = 49
    Caption = 'Generate Random Points'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -19
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
    TabOrder = 0
    OnClick = GenerateRandomPointsButtonClick
  end
  object Edit1: TEdit
    Left = 209
    Top = 8
    Width = 64
    Height = 21
    TabOrder = 1
  end
  object methodComboBox: TComboBox
    Left = 88
    Top = 53
    Width = 185
    Height = 21
    TabOrder = 2
    Text = 'methodComboBox'
    OnChange = methodComboBoxChange
  end
end
