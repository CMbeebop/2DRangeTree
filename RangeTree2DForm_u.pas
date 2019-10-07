unit RangeTree2DForm_u;

{ Constructed for the validation of TRangeTree2D<TKey> in RangeTree2D_u.pas and
  TQuarterRangeSearch in QuarterRangeSearch_u.pas.

  HOW TO USE:
  1.- Select the number of Points for the analysis.
  2.- click Generate Random Numbers Button
  3.- Select your 2D Box range by:
      � moving the cursor inside the paintBox area
      � left mouse button hold + mouse move + unhold click
  4.- Select new 2DBox range queries by repeating 3 on the same points,
      or generate new random points.
  5.- change Search mode in method ComboBox for QuarterRangeSearch mode,
      choose desired quadrant for the search.
  6.- Select your quarter range by:
      � moving the cursor inside paintBox area
      � left mouse button click on the desired point of domination.
  7.- Select new quarter Range queries on the same points or maybe switch to other
      search modes (5) or generate new Random points (1).

  VALIDATION MODE:
  For testing DS switch ON Validation conditional define which computes also a
  Naive Solution that is compared with ours. Any disagreement Point will be reported
  with a message.

  you can define a path for PointsFilename in TForm1.Create, then every time random
  points are generated their locations are saved to the file (overwriting previous content).
  you can use switch HowToObtainPoints = fromfile to recover the last data which was
  useful for debugging.  }

{.$DEFINE Validation}

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.Generics.collections, Generics.Defaults, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls, RangeTree2D_u,
  QuarterRangeSearch_u;


type TMethodForAnalysis = (BoxRange,FirstQuadrantRange,SecondQuadrantRange,ThirdQuadrantRange,FourthQuadrantRange);
Const MethodsStrings : Array[low(TMethodForAnalysis)..High(TMethodForAnalysis)] of String =
                       ('Box Range','First Quadrant Range','Second Quadrant Range','Third Quadrant Range','Fourth Quadrant Range');
type THowToObtainPoints = (fromFile, randomPoints);

type TSPt2D = record
  x, y : Single;
  ptNo : Integer;
end;

type
  TForm1 = class(TForm)
    PaintBox1                  : TPaintBox;
    GenerateRandomPointsButton : TButton;
    Label1                     : TLabel;
    Edit1                      : TEdit;
    Label2                     : TLabel;
    methodComboBox             : TComboBox;

    procedure GenerateRandomPointsButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClearData;
    procedure FormDestroy(Sender: TObject);
    procedure PaintBoxMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PaintBoxMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure methodComboBoxChange(Sender: TObject);

  private
    HowToObtainPoints  : THowToObtainPoints;
    pointsFIleName     : String;
    isPaintingRangeBox,
    isAnyThingPainted  : Boolean;
    ListOfKeys         : TList<TKey3D>;
    ListOfPoints       : TList<TSPt2D>;
    RT2D               : TRangeTree2D<TSPt2D>;
    QRS                : TQuarterRangeSearch;
    InvOfDomainOfPointsSize,
    DomainOfPointsSize : Single;
    PointRadioInPixels,
    XStart, YStart     : Integer;
    compareXYPtNo,
    compareYXPtNo      : TComparison<TSPt2D>;
    comparerXYPtNo     : IComparer<TSPt2D>;
    BitMap             : TBitMap;
    MyRect             : TRect;
    invalidTSPt2D      : TSPt2D;
    DictOfKeyToTSPt2D  : TDictionary<TKey3D,TSPt2D>;
    procedure getRandomPoints;
    procedure PaintBox1Clear;
    function ToPaintBoxCoords(const pt2D : TSPt2D) : TPoint;
    function ToPointCoords(const X, Y, PointNo : Integer) : TSPt2D;
    procedure paintPoint(const Pt : TSPt2D);
    procedure paintMarker(const X, Y, radio : Integer; const AColor : TColor);
    procedure paintPoints(const List : TList<TSPt2D>; const AColor : TColor);
    procedure getRangeBox(const X,Y : Integer; var X1,Y1,X2,Y2 : Integer);
    procedure paintQuadrilateral(const X1,Y1,X2,Y2 : Integer; const APenStyle : TPenStyle; const Acolor : TColor; const APenWidth : Integer);
    procedure paintQuarterRange(const X, Y : Integer; const APenStyle : TPenStyle; const Acolor : TColor; const APenWidth : Integer);
    procedure WritePointsFile;
    procedure readPointsFile;
    function GetNaiveSolution(const k1, k2 : TSPt2D) : TList<TSPt2D>;
    function checkLists(const LRef,L : TList<TSPt2D>) : Boolean;
    function getTKey3DFromTSPt2D(const pt2D : TSPt2D) : TKey3D;

    public
    PointsNo : Integer;

  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

function TForm1.getTKey3DFromTSPt2D(const pt2D : TSPt2D) : TKey3D;
{QuarterRangeSearch structure solves queries on (y,z) rather than (x,y)}
begin
  RESULT := TKey3D.Create(0,pt2D.x,pt2D.y,pt2D.PtNo);
end;

procedure TForm1.PaintBox1Clear;
begin
  paintbox1.Canvas.Brush.Color :=clWhite;
  paintbox1.canvas.FillRect(Rect(0,0,paintbox1.Width,paintbox1.Height));
  paintbox1.canvas.Pen.Color   :=clBlack;
  isAnyThingPainted            := FALSE;
end;

procedure TForm1.PaintBoxMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  XStart := X;
  YStart := Y;
  isPaintingRangeBox := TRUE;
  if MethodComboBox.ItemIndex <> 0 then
  begin
    PaintBox1.Canvas.CopyRect(MyRect,BitMap.Canvas,MyRect);
    paintMarker(X,Y,5,clGreen);
  end;
end;

procedure TForm1.paintQuarterRange(const X, Y : Integer; const APenStyle : TPenStyle; const Acolor : TColor; const APenWidth : Integer);
begin
  PaintBox1.Canvas.pen.color := Acolor;
  PaintBox1.Canvas.pen.Style := APenStyle;
  PaintBox1.Canvas.pen.width := APenWidth;

  PaintBox1.Canvas.PenPos := point(X,Y);
  case MethodComboBox.ItemIndex of
    1 :begin
         PaintBox1.Canvas.LineTo(paintBox1.width,Y);
         PaintBox1.Canvas.PenPos := point(X,Y);
         PaintBox1.Canvas.LineTo(X,0);
       end;
    2 :begin
         PaintBox1.Canvas.LineTo(0,Y);
         PaintBox1.Canvas.PenPos := point(X,Y);
         PaintBox1.Canvas.LineTo(X,0);
       end;
    3 :begin
         PaintBox1.Canvas.LineTo(0,Y);
         PaintBox1.Canvas.PenPos := point(X,Y);
         PaintBox1.Canvas.LineTo(X,paintbox1.Height);
       end;
    4 :begin
         PaintBox1.Canvas.LineTo(paintBox1.width,Y);
         PaintBox1.Canvas.PenPos := point(X,Y);
         PaintBox1.Canvas.LineTo(X,paintBox1.height);
       end;
  end;
end;

procedure TForm1.paintQuadrilateral(const X1,Y1,X2,Y2 : Integer; const APenStyle : TPenStyle; const Acolor : TColor; const APenWidth : Integer);
begin
  PaintBox1.Canvas.pen.color := Acolor;
  PaintBox1.Canvas.pen.Style := APenStyle;
  PaintBox1.Canvas.pen.width := APenWidth;

  PaintBox1.Canvas.PenPos := point(X1,Y1);
  PaintBox1.Canvas.LineTo(X1,Y2);

  PaintBox1.Canvas.PenPos := point(X1,Y2);
  PaintBox1.Canvas.LineTo(X2,Y2);

  PaintBox1.Canvas.PenPos := point(X2,Y2);
  PaintBox1.Canvas.LineTo(X2,Y1);

  PaintBox1.Canvas.PenPos := point(X2,Y1);
  PaintBox1.Canvas.LineTo(X1,Y1);
end;

procedure TForm1.PaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var X1, X2, Y1, Y2 : Integer;
begin
  if isPaintingRangeBox then
  begin
    PaintBox1.Canvas.CopyRect(MyRect,BitMap.Canvas,MyRect);

    if MethodComboBox.ItemIndex = 0 then
    begin
      getRangeBox(X,Y,X1,Y1,X2,Y2);
      paintQuadrilateral(X1,Y1,X2,Y2,psSolid,clFuchsia,3);
    end
    else
    begin
      paintQuarterRange(X,Y,psSolid,clFuchsia,3);
      paintMarker(X,Y,5,clGreen);
    end;
  end
end;

procedure TForm1.getRangeBox(const X,Y : Integer; var X1,Y1,X2,Y2 : Integer);
begin
  if XStart < X then
  begin   X1 := XStart;  X2 := X;   end
  else
  begin   X1 := X;  X2 := XStart;   end;

  if YStart < Y then
  begin   Y1 := YStart;   Y2 := Y   end
  else
  begin   Y1 := Y;  Y2 := YStart;   end;
end;



procedure TForm1.methodComboBoxChange(Sender: TObject);
begin
  RT2D.Clear;
  QRS.Clear;

  if ListOfPoints.Count > 0 then
  begin
    PaintBox1.Canvas.CopyRect(MyRect,BitMap.Canvas,MyRect);
    case MethodComboBox.ItemIndex of
      0 : RT2D.BuildTree(ListOfPoints);
      1 : QRS.Build(ListOfKeys,First);
      2 : QRS.Build(ListOfKeys,Second);
      3 : QRS.Build(ListOfKeys,Third);
      4 : QRS.Build(ListOfKeys,Fourth);
    end;
  end;
end;

function TForm1.checkLists(const LRef,L : TList<TSPt2D>) : Boolean;
var i : Integer;
begin
  if LRef.Count <> L.Count then
    RESULT := FALSE
  else
  begin
    for i := 0 to LRef.Count-1 do
    begin
      if compareXYPtNo(LRef[i],L[i]) <> 0 then
      begin  RESULT := FALSE; EXIT;  end;
    end;
    // Reached this line result = TRUE
    RESULT := TRUE;
  end;
end;


function TForm1.GetNaiveSolution(const k1, k2 : TSPt2D) : TList<TSPt2D>;
var i        : Integer;
    pt       : TSPt2D;
    kx1, kx2,
    ky1, ky2 : Single;
begin
  RESULT := TList<TSPt2D>.create;
  case MethodComboBox.ItemIndex of
    0 : begin
          // prepare Box Range
          if k2.x < k1.x then
          begin kx1 := k2.x; kx2 := k1.x; end
          else
          begin kx1 := k1.x; kx2 := k2.x; end;

          if k2.y < k1.y then
          begin ky1 := k2.y; ky2 := k1.y; end
          else
          begin ky1 := k1.y; ky2 := k2.y; end;

          for i := 0 to ListOfPoints.Count-1 do
          begin
            pt := ListOfPoints[i];
            // Exclude points out of the box
            if (pt.x < kx1) OR (pt.x > kx2) OR
               (pt.y < ky1) OR (pt.y > ky2) then continue;
            RESULT.Add(pt);
          end;
        end;
    1 : begin
          for i := 0 to ListOfPoints.Count-1 do
          begin
            pt := ListOfPoints[i];
            // Exclude points out of First Quadrant
            if (pt.x < k1.x) OR (pt.y < k1.y) then continue;
            RESULT.Add(pt);
          end;
        end;
    2 : begin
          for i := 0 to ListOfPoints.Count-1 do
          begin
            pt := ListOfPoints[i];
            // Exclude points out of Second Quadrant
            if (pt.x > k1.x) OR (pt.y < k1.y) then continue;
            RESULT.Add(pt);
          end;
        end;
    3 : begin
          for i := 0 to ListOfPoints.Count-1 do
          begin
            pt := ListOfPoints[i];
            // Exclude points out of Third Quadrant
            if (pt.x > k1.x) OR (pt.y > k1.y) then continue;
            RESULT.Add(pt);
          end;
        end;
    4 : begin
          for i := 0 to ListOfPoints.Count-1 do
          begin
            pt := ListOfPoints[i];
            // Exclude points out of Fourth Quadrant
            if (pt.x < k1.x) OR (pt.y > k1.y) then continue;
            RESULT.Add(pt);
          end;
        end;
  end;
  // sort the output
  RESULT.Sort(comparerXYPtNo);
end;

procedure TForm1.PaintBoxMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var x1, x2, y1, y2 : Integer;
    k1, k2 : TSPt2D;
    key1   : TKey3D;
    L, LN  : TList<TSPt2D>;
    Lkeys  : TList<TKey3D>;
  i: Integer;
begin
  if MethodComboBox.ItemIndex = 0 then
  begin
    getRangeBox(X,Y,X1,Y1,X2,Y2);
    // Draw FInal RangeBox in a different Color
    paintQuadrilateral(X1,Y1,X2,Y2,psSolid,clgreen,3);

    // Solve RangeProblem
    k1 := ToPointCoords(X1,Y1,-1);
    k2 := ToPointCoords(X2,Y2,High(Integer));

    L := RT2D.getSortedListOfMembersInRange(k1,k2);
  end
  else  // then Quarter Range
  begin
    PaintBox1.Canvas.CopyRect(MyRect,BitMap.Canvas,MyRect);
    paintQuarterRange(X,Y,psSolid,clgreen,3);

    k1 := ToPointCoords(X,Y,-1);

    case MethodComboBox.ItemIndex of
      1: begin k1.x := -k1.x; k1.y := -k1.y; end;
      2: k1.y := -k1.y;
      4: k1.x := -k1.x;
    end;

    key1 := getTKey3DFromTSPt2D(k1);

    Lkeys := QRS.getSortedListOfMembersDominatedBykey(key1);
    key1.free;

    L := TList<TSPt2D>.Create;
    for i := 0 to Lkeys.Count-1 do
      L.Add(DictOfKeyToTSPt2D[LKeys[i]]);
    {$IFDEF Validation}
    L.Sort(comparerXYPtNo);
    {$ENDIF}
  end;
  paintPoints(L,clRed);
  isPaintingRangeBox := FALSE;
  {$IFDEF Validation}
  if MethodComboBox.ItemIndex <> 0 then
  begin
    case MethodComboBox.ItemIndex of
      1: begin k1.x := -k1.x; k1.y := -k1.y; end;
      2: k1.y := -k1.y;
      4: k1.x := -k1.x;
    end;
    k2 := invalidTSPt2D;
  end;
  LN := GetNaiveSolution(k1,k2);
  if checkLists(LN,L) then  //showmessage('2DRangeTree agrees Naive solution')
  else                      showmessage('Solution Does not agree Naive aproach');
  LN.Free;
  {$ENDIF}
  if MethodComboBox.ItemIndex <> 0 then
    L.Free;
end;

procedure TFOrm1.getRandomPoints;
var i    : Integer;
    pt2D : TSPt2D;
    t    : SIngle;
    label repeatPoint;
begin
  // ensure x, y in Open Interval so it can be painted with a ball of radio PointsRadioInPixels
  t := (PointRadioInPixels/PaintBox1.Width)*DomainOfPointsSize;
  for i := 0 to PointsNo-1 do
  begin
    repeatPoint:

    with pt2D do
    begin
      x    := random*DomainOfPointsSize;
      y    := random*DomainOfPointsSize;

      if (x<t) OR ((DomainOfPointsSize-x)<t) OR
         (y<t) OR ((DomainOfPointsSize-y)<t) then
        goto repeatPoint;

      ptNo := i;
    end;
    ListOfPoints.Add(pt2D);
  end;
end;

function TForm1.ToPaintBoxCoords(const pt2D : TSPt2D) : TPoint;
{ensure pt +/- PointRadioInPixels is inside PaintBox}
begin
  RESULT.X := round(pt2D.x * InvOfDomainOfPointsSize * PaintBox1.Width);
  RESULT.Y := round((DomainOfPointsSize - pt2D.y) * InvOfDomainOfPointsSize * PaintBox1.Height);
end;

function TForm1.ToPointCoords(const X, Y, PointNo : Integer) : TSPt2D;
{ensure pt +/- PointRadioInPixels is inside PaintBox}
begin
  RESULT.X    :=  X/PaintBox1.Width  * DomainOfPointsSize;
  RESULT.Y    := (PaintBox1.Height-Y)/PaintBox1.Height * DomainOfPointsSize;
  RESULT.PtNo := PointNo;
end;


procedure TForm1.paintPoint(const Pt : TSPt2D);
{an X marks the position}
var o : TPoint;
begin
  o := ToPaintBoxCoords(Pt);
  paintbox1.Canvas.Ellipse(o.X-PointRadioInPixels,o.Y-PointRadioInPixels,
                           o.X+PointRadioInPixels,o.Y+PointRadioInPixels);
end;

procedure TForm1.paintPoints(const List : TList<TSPt2D>; const AColor : TColor);
var  i    : Integer;
     pt2D : TSPt2D;
begin
  paintbox1.canvas.brush.Color := Acolor;
  paintbox1.canvas.pen.Color   := AColor;
  paintbox1.canvas.pen.width   := 2;
  for i := 0 to List.Count-1 do
  begin
    pt2D := List[i];
    paintPoint(pt2D);
  end;
end;

procedure TForm1.paintMarker(const X, Y, radio : Integer; const AColor : TColor);
var  pt2D : TSPt2D;
begin
  paintbox1.canvas.brush.Color := Acolor;
  paintbox1.canvas.pen.Color   := AColor;
  paintbox1.canvas.pen.width   := 2;
  paintbox1.Canvas.Ellipse(X-radio,Y-radio,X+radio,Y+radio);
end;

procedure TForm1.FormCreate(Sender: TObject);
var methodCounter : TMethodForAnalysis;
begin
  ListOfPoints      := TList<TSPt2D>.create;
  ListOfKeys        := TList<TKey3D>.create;
  DictOfKeyToTSPt2D := TDictionary<TKey3D,TSPt2D>.create;

  compareXYPtNo := function(const left, right: TSPt2D): Integer
                   begin
                     RESULT := TComparer<Single>.Default.Compare(left.x,right.x);
                     if RESULT = 0 then
                     begin
                       RESULT := TComparer<Single>.Default.Compare(left.y,right.y);
                       if RESULT =0 then
                         RESULT := TComparer<Integer>.Default.Compare(left.PtNo,right.PtNo);
                     end;
                   end;

  comparerXYPtNo :=  TComparer<TSPt2D>.Construct(compareXYPtNo);

  compareYXPtNo := function(const left, right: TSPt2D): Integer
                   begin
                     RESULT := TComparer<Single>.Default.Compare(left.y,right.y);
                     if RESULT = 0 then
                     begin
                       RESULT := TComparer<Single>.Default.Compare(left.x,right.x);
                       if RESULT =0 then
                         RESULT := TComparer<Integer>.Default.Compare(left.PtNo,right.PtNo);
                     end;
                   end;

  RT2D := TRangeTree2D<TSPt2D>.Create(compareXYPtNo,compareYXPtNo);
  QRS  := TQuarterRangeSearch.create;

  DomainOfPointsSize      := 1;
  InvOfDomainOfPointsSize := 1/DomainOfPointsSize;
  PointRadioInPixels      := 3;

  Bitmap        := TBitmap.Create;
  BitMap.Width  := PaintBox1.Width;
  BitMap.Height := PaintBox1.Height;

  MyRect := Rect(0,0,PaintBox1.Width,PaintBox1.Height);

  // initiallize MethodComboBox
  for methodCounter := Low(TMethodForAnalysis) to High(TMethodForAnalysis) do
    MethodComboBox.Items.Add(MethodsStrings[methodCounter]);
  MethodComboBox.ItemIndex := 0;

  HowToObtainPoints := randomPoints; {fromFile;}
  PointsFileName    := '';
//  PointsFileName    := ' WRITE HERE A PATH \pointsFile.txt';
  invalidTSPt2D.x   := -300000;
  invalidTSPt2D.y   := -300000;
end;

procedure TForm1.FormClearData;
var i : Integer;
begin
  ListOfPoints.Clear;
  for i := 0 to ListOfKeys.Count-1 do
    ListOfKeys[i].Free;
  ListOfKeys.Clear;
  DictOfKeyToTSPt2D.Clear;
  RT2D.Clear;
  QRS.Clear;
end;

procedure TForm1.FormDestroy(Sender: TObject);
var  i: Integer;
begin
  FormClearData;

  ListOfPoints.Free;
  ListOfKeys.Free;
  DictOfKeyToTSPt2D.Free;
  RT2D.free;
  QRS.free;
  BitMap.Free;
  BitMap := nil;
end;

procedure TForm1.GenerateRandomPointsButtonClick(Sender: TObject);
var oldSize, i : Integer;
    key        : TKey3D;
    pt2D       : TSPt2D;
begin
  FormClearData;
  PaintBox1Clear;

  if HowToObtainPoints = randomPoints then
  begin
    PointsNo := strToInt(Edit1.text);
    getRandomPoints;
    if PointsFileName <> '' {AND ListOfPoints.Count < 1001} then WritePointsFile;
  end
  else
  begin
    if pointsFileName = '' then showmessage('pointsFileName has not been specified in the code')
    else                        readPointsFile;
  end;
  // Build ListOfKeys
  for i := 0 to ListOfPoints.Count-1 do
  begin
    pt2D         := ListOfPoints[i];
    key          := getTKey3DFromTSPt2D(pt2D);
    ListOfKeys.Add(key);
    DictOfKeyToTSPt2D.Add(key,pt2D);
  end;

  // Build Data structures
  case MethodComboBox.ItemIndex of
    0 : RT2D.BuildTree(ListOfPoints);
    1 : QRS.Build(ListOfKeys,First);
    2 : QRS.Build(ListOfKeys,Second);
    3 : QRS.Build(ListOfKeys,Third);
    4 : QRS.Build(ListOfKeys,Fourth);
  end;

  paintPoints(ListOfPoints,clBlack);

  BitMap.Canvas.CopyRect(MyRect,PaintBox1.Canvas,MyRect);
  isAnyThingPainted := TRUE;
end;

procedure TForm1.writePointsFile;
var StringLine : String;
    FileString : TStringList;
    counter    : Integer;
    pt         : TSPt2D;
begin
  // write to Par File
  FileString := TStringList.Create;
  for counter := 0 to ListOfPoints.Count-1 do
  begin
    pt := ListOfPoints[counter];
    StringLine := pt.x.ToString + #9 + pt.y.ToString;
    FileString.Add(StringLine);
  end;
  // Save to File
  FileString.SaveToFile(pointsFileName);
  // Free memory
  FileString.Free;
end;


procedure TForm1.readPointsFile;

    type CharSet = set of Char;

    function ExtractWord(N : Integer; S : string; WordDelims : CharSet) : string;
      {-Given a set of word delimiters, return the N'th word in S}
    var
      StringLength:Integer;
      NBegin,I, Count:Integer;
    begin
      Count := 0;
      I := 1;
      RESULT := '';
      StringLength := Length(S);
      while (I <= StringLength) and (Count <> N) do begin
        {skip over delimiters}
        while (I <= StringLength) and (S[I] in WordDelims) do
          Inc(I);
        {if we're not beyond end of S, we're at the start of a word}
        if I <= StringLength then
          Inc(Count);//we have found the Count word
        {find the end of the current word}

        NBegin := I;//faster because miltiple realloc is avoided
        while (I <= StringLength) and not(S[I] in WordDelims) do //reading then Count'th word
          Inc(I);
        if Count = N then	RESULT := Copy(S,NBegin,I-NBegin);
      end;
    end;

    FUNCTION ExtractSingle(N: Integer; s: string; var Code :Integer; Delims : CharSet; VAR v: Single): Boolean;
    { Evaluates the Single value of the N'th word in string s.
      Does NOT check whether s contains that many words.
      Code contains the position in s of the offending character. }
    begin
      s := ExtractWord(N, s, Delims);
      Val(s, V, Code);
      ExtractSingle := (Code = 0);
    end;

var myFile      : TextFile;
    AString     : String;
    pt          : TSPt2D;
    code,
    PointCounter : Integer;
begin
  AssignFile(myFile,pointsFileName);
  FileMode := 0;
  reset(myFile);

  ListOfPoints.Clear;
  PointCounter := -1;
  while (NOT EOF(MyFile)) do
  begin
    ReadLn(myFile,AString);
    // extract edge data
    ExtractSingle(1,Astring,Code,[#9],Pt.x);
    ExtractSingle(2,Astring,Code,[#9],Pt.y);
    // contruct an edge with this two points
    Inc(PointCounter);
    pt.PtNo := PointCounter;
    ListOfPoints.Add(pt);
  end;
  CloseFile(myFile);
  PointsNo := ListOfPoints.Count;
end;


end.
