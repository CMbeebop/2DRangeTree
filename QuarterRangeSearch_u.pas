unit QuarterRangeSearch_u;

{ Delphi Implementaion of a 2D quadrant search static DS -> TQuarterRangeSearch.
  Based on the ideas given of day 4 in the course 6.851 MIT OpenWare

  https://ocw.mit.edu/courses/electrical-engineering-and-computer-science/6-851-advanced-data-structures-spring-2012/lecture-videos/session-4-geometric-structures-ii/

  The DS is prepared for 3D applications so keys are 3D points and quarter search
  is done on (z,y) components. The DS is Build with a List of TKey3D, (x,y,z) points.
  Four different search modes are implemented for different 2D queries given an input
  key (see TQuadrant). (*)

  The problem is solved for a Third quadrant problem and the rest of search modes are
  converted to a Third quadrant search by changing the sign of y and/or z component of
  Input Points.

  Once the DS is build For a fixed Quadrant search the function queries are solved by
  getSortedListOfMembersDominatedBykey, that outputs a List of keys, a subset of the
  Initial list of keys being dominated by a new input key. Note that this List should
  be freed by TQuarterRangeSearch.Free, and it is cleared every new query. Addictionally
  we can ask if a key is dominated by another one using getSortedListOfMembersDominatedBykey.

  (*) See RangeTree2DForm_u.pas for an example of how to use DS on standard 2D points (x,y). }

interface

uses Math, System.SysUtils,DIalogs, System.Variants, System.Classes, System.Generics.collections,
     Generics.Defaults;
                            // query is : find (x,y,z) dominated by input key (x0,y0,z0) //
type TQuadrant = (First,    //                    y > y0, z > z0                        //
                  Second,   //                    y > y0, z < z0                        //
                  Third,    //                    y < y0, z < z0                        //
                  Fourth);  //                    y < y0, z > z0                        //

type TKey3D = class

  x, y, z  : Single;
  entityNo : Integer;
  constructor create(const x_, y_, z_ : Single; const entityNo_ : Integer);

end;



type TzNode = class

  pointerToKey3D    : TKey3D;

  pointerToLeft,
  pointerToRight,
  pointerToBaseNode : TzNode;

  posInsortedListOfZNodes : Integer;

  constructor create(const key : TKey3D);

end;

type TQRSNode = class

  pointerToKey3D : TKey3D;

  constructor create(const key : TKey3D);
  procedure free;

  private
  sortedListOfZNodes : TList<TzNode>;
  pointerToBaseNode  : TzNode;
  posInYList         : Integer;
end;


type TQuarterRangeSearch = class

  private
  FCount, NextYPosition,
  YPosition             : Integer;
  compareY              : TComparison<TKey3D>;
  comparerY             : IComparer<TKey3D>;
  compareZ              : TComparison<TKey3D>;
  compareZNode          : TComparison<TZNode>;
  comparerZNode         : IComparer<TZNode>;
  OutputSortedListOfKeys,
  WorkingListOfKeys,
  ListOfKeysSortedByY   : TList<TKey3D>;
  DictOfKeyToInputKey   : TDictionary<TKey3D,TKey3D>;
  DictOfkeyToTQRSNode   : TDictionary<TKey3D,TQRSNode>;
  EnteringZList         : TList<TzNode>;

  procedure LeftToRightPass;
  procedure RightToLeftPass;
  procedure cascade;
  procedure updatePosInsortedListOfZNodes;
  procedure trackListUpwards(const List : TList<TzNode>; const probeZNode : TzNode; var position : Integer);
  procedure trackListDownwards(const List : TList<TzNode>; const probeZNode : TzNode; var position : Integer);
  procedure updatePredecessor(const probeZNode : TzNode; var pred : TzNode);
  function updateSuccessorIfSuccIsNIL(const probeZNode : TzNode) : TzNode;
  procedure updateSuccessor(const probeZNode : TzNode; var succ : TzNode);
  procedure updatePredSucc(const probeZNode : TzNode; var pred, succ : TZNode);

  public
  quadrant : Tquadrant;
  constructor create;
  procedure Clear;
  procedure free;
  procedure Build(const ListOfKeys : TList<TKey3D>; const quadrant_ : TQuadrant); overload;
  procedure Build(const InitIdx, LastIdx : Integer; const ListOfKeys : TList<TKey3D>; const quadrant_ : TQuadrant); overload;
  property Count : integer read FCount;
  function isKey1DominatedByKey2(const k1, k2 : TKey3D) : Boolean;
  function getSortedListOfMembersDominatedBykey(const key_ : TKey3D) : TList<TKey3D>;



end;


implementation


const CascadeConstant = 2;

//Begin define Methods of TKey3D
constructor TKey3D.create(const x_, y_, z_ : Single; const entityNo_ : Integer);
begin
  inherited create;
  x        := x_;
  y        := y_;
  z        := z_;
  entityNo := entityNo_;
end;
// end define methods of TKey3D

// begin define methods of TzNode<TKey3D>
constructor TzNode.create(const key : TKey3D);
begin
  pointerToKey3D    := key;
  pointerToLeft     := nil;
  pointerToRight    := nil;
  pointerToBaseNode := nil;
end;
// end define methods of TzNode<TKey3D>


// begin define methods of TQRSNode<TKey3D>  ç
constructor TQRSNode.create(const key : TKey3D);
begin
  pointerToKey3D     := key;
  pointerToBaseNode  := nil;
  sortedListOfZNodes := TList<TzNode>.create;
end;

procedure TQRSNode.free;
var i : Integer;
begin
  for i := 0 to sortedListOfZNodes.Count-1 do
    sortedListOfZNodes[i].Free;
  sortedListOfZNodes.Free;
  inherited free;
end;
// end define methods of TQRSNode<TKey3D>


// begin define methods of TQuarterRangeSearch<TKey3D>
constructor TQuarterRangeSearch.create;
begin
  inherited create;
  WorkingListOfKeys      := TList<TKey3D>.create;
  ListOfKeysSortedByY    := TList<TKey3D>.create;
  OutputSortedListOfKeys := TList<TKey3D>.create;
  DictOfkeyToTQRSNode    := TDictionary<TKey3D,TQRSNode>.create;
  DictOfKeyToInputKey    := TDictionary<TKey3D,TKey3D>.create;

  EnteringZList          := TList<TzNode>.Create;
  FCount                 := 0;

  // define compare functions
  compareY := function(const left, right: TKey3D): Integer
              begin
                RESULT := TComparer<Single>.Default.Compare(left.y,right.y);
                if RESULT = 0 then
                begin
                  RESULT := TComparer<Single>.Default.Compare(left.z,right.z);
                  if RESULT =0 then
                    RESULT := TComparer<Integer>.Default.Compare(left.entityNo,right.entityNo);
                end;
              end;
  compareZ := function(const left, right: TKey3D): Integer
              begin
                RESULT := TComparer<Single>.Default.Compare(left.z,right.z);
                if RESULT = 0 then
                begin
                  RESULT := TComparer<Single>.Default.Compare(left.y,right.y);
                  if RESULT =0 then
                    RESULT := TComparer<Integer>.Default.Compare(left.entityNo,right.entityNo);
                end;
              end;


  compareZNode := function(const left, right: TZNode): Integer
                  begin
                    RESULT := compareZ(left.pointerToKey3D,right.pointerToKey3D);
                  end;

  comparerZNode := TComparer<TzNode>.Construct(compareZNode);
  comparerY     := TComparer<TKey3D>.Construct(compareY);
end;

procedure TQuarterRangeSearch.Clear;
var key : TKey3D;
    i   : Integer;
begin
  if FCount>0 then
  begin
    for key in DictOfkeyToTQRSNode.Keys do
      DictOfkeyToTQRSNode[key].free;
    DictOfkeyToTQRSNode.Clear;

    for i := 0 to WorkingListOfKeys.Count-1 do
      WorkingListOfKeys[i].free;
    WorkingListOfKeys.Clear;
    DictOfKeyToInputKey.Clear;

    for i := 0 to EnteringZList.Count-1 do
      EnteringZList[i].Free;
    EnteringZList.Clear;

    ListOfKeysSortedByY.Clear;
    FCount := 0;
  end;
  OutputSortedListOfKeys.Clear;
end;

procedure TQuarterRangeSearch.free;
var i : integer;
begin
  Clear;
  WorkingListOfKeys.Free;
  DictOfKeyToInputKey.Free;
  OutputSortedListOfKeys.Free;
  DictOfkeyToTQRSNode.Free;
  ListOfKeysSortedByY.Free;
  EnteringZList.Free;
  inherited free;
end;

procedure TQuarterRangeSearch.LeftToRightPass;
var i, j, aInteger, position : Integer;
    key                      : TKey3D;
    node                     : TQRSNode;
    BaseZNode, zNode,
    RightExtension_zNode     : TzNode;
    zNodesbeingRightExtended : TList<TzNode>;
begin

  zNodesbeingRightExtended := TList<TzNode>.create;

  for i := 0 to ListOfKeysSortedByY.Count-1 do
  begin
    key       := ListOfKeysSortedByY[i];
    node      := DictOfkeyToTQRSNode[key];
    // newZNode first on the node.sortedListOfZNodes / but there will be inserted copies that make it being not the first
    BaseZNode := TzNode.create(key);
    BaseZNode.pointerToBaseNode := BaseZNode;
    node.sortedListOfZNodes.Add(BaseZNode);
    node.pointerToBaseNode := BaseZNode;

    zNodesbeingRightExtended.BinarySearch(BaseZNode,position,comparerZNode);

    for j := position to zNodesbeingRightExtended.Count-1 do
    begin
      zNode := zNodesbeingRightExtended[j];
      // Create new zNode to be attatched in node.sortedListOfNodes
      RightExtension_zNode := TzNode.create(znode.pointerToKey3D);

      zNode.pointerToRight                   := RightExtension_zNode;
      RightExtension_zNode.pointerToLeft     := zNode;
      RightExtension_zNode.pointerToBaseNode := BaseZNode;

      node.sortedListOfZNodes.Add(RightExtension_zNode);
    end;

    for j := zNodesbeingRightExtended.Count-1 downto position do
      zNodesbeingRightExtended.Delete(j);

    zNodesbeingRightExtended.Add(BaseZNode);
  end;
  zNodesbeingRightExtended.Free;
end;

procedure TQuarterRangeSearch.RightToLeftPass;
var i, j, aInteger, position,
    position2  : Integer;
    key                      : TKey3D;
    node                     : TQRSNode;
    BaseZNode, zNode,
    LeftExtension_zNode     : TzNode;
    zNodesbeingLeftExtended : TList<TzNode>;
begin

  zNodesbeingLeftExtended := TList<TzNode>.create;

  for i := ListOfKeysSortedByY.Count-1 downto 0 do
  begin
    key       := ListOfKeysSortedByY[i];
    node      := DictOfkeyToTQRSNode[key];
    BaseZNode := node.pointerToBaseNode;

    zNodesbeingLeftExtended.BinarySearch(BaseZNode,position,comparerZNode);

    for j := position to zNodesbeingLeftExtended.Count-1 do
    begin
      zNode := zNodesbeingLeftExtended[j];
      // Create new zNode to be attatched in node.sortedListOfNodes
      LeftExtension_zNode := TzNode.create(znode.pointerToKey3D);
      zNode.pointerToLeft := LeftExtension_zNode;
      // take CONSERVATIVE leftExtension
      LeftExtension_zNode.pointerToRight    := zNode;
      LeftExtension_zNode.pointerToBaseNode := BaseZNode;

      node.sortedListOfZNodes.binarySearch(LeftExtension_zNode,position2,comparerZnode);
      node.sortedListOfZNodes.insert(position2,LeftExtension_zNode);
    end;

    for j := zNodesbeingLeftExtended.Count-1 downto position do
      zNodesbeingLeftExtended.Delete(j);

    zNodesbeingLeftExtended.Add(BaseZNode);
  end;

  // remaining Nodes in zNodesbeingLeftExtended are in -infinity
  // we get them because pointerToBaseNode = nil
  EnteringZList.Clear;
  for i := 0 to zNodesbeingLeftExtended.Count-1 do
  begin
    zNode := zNodesbeingLeftExtended[i];
    // Create new zNode to be attatched in node.sortedListOfNodes
    LeftExtension_zNode := TzNode.create(znode.pointerToKey3D);
    zNode.pointerToLeft := LeftExtension_zNode;
    LeftExtension_zNode.pointerToRight := zNode;
    EnteringZList.Add(LeftExtension_zNode);
  end;
  zNodesbeingLeftExtended.Free;
end;

procedure TQuarterRangeSearch.cascade;
var cascadeNodes               : TList<TzNode>;
    node                       : TQRSNode;
    promZNode, BaseNode, zNode : TzNode;
    i, j, position, position2  : Integer;
    key                        : TKey3D;
begin

  cascadeNodes := TList<TzNode>.create;
  for i := ListOfKeysSortedByY.Count-1 downto 0 do
  begin
    key       := ListOfKeysSortedByY[i];
    node      := DictOfkeyToTQRSNode[key];
    BaseNode  := node.pointerToBaseNode;

    // introduce cascadeNodes in nodes.SortedListOfNodes
    cascadeNodes.BinarySearch(BaseNode,position,comparerZNode);
    // ensure repetitions of BaseNode dont go farther left
    while (position > 0) AND (compareZNode(cascadeNodes[position-1], BaseNode) <> -1) do
      dec(position);

    for j := position to cascadeNodes.Count-1 do
    begin
      zNode                   := cascadeNodes[j];
      zNode.pointerToBaseNode := BaseNode;

      node.sortedListOfZNodes.binarySearch(znode,position2,comparerZNode);
      node.sortedListOfZNodes.insert(position2, zNode);
    end;

    for j := cascadeNodes.Count-1 downto position do
      cascadeNodes.Delete(j);

    // update cascadeNodes
    for j := 0 to node.sortedListOfZNodes.Count-1 do
    begin
      if (j mod cascadeConstant) = 0 then
      begin
        znode     := node.sortedListOfZNodes[j];

        promZNode := TzNode.create(znode.pointerToKey3D);
        promZNode.pointerToRight    := zNode;
        promZNode.pointerToBaseNode := BaseNode;

        cascadeNodes.Add(promZNode);
      end;
    end;
  end;

  // remaining Nodes in cascadeNodes goesto EnteringZList
  for i := 0 to cascadeNodes.Count-1 do
  begin
    zNode := cascadeNodes[i];
    EnteringZList.binarySearch(zNode,position,comparerZNode);
    EnteringZList.insert(position,zNode);
  end;

  cascadeNodes.Free;

end;

procedure TQuarterRangeSearch.updateposInsortedListOfZNodes;
var i, j : Integer;
    key  : TKey3D;
    node : TQRSNode;
begin
  for i := 0 to ListOfKeysSortedByY.Count-1 do
  begin
    key  := ListOfKeysSortedByY[i];
    node := DictOfkeyToTQRSNode[key];
    node.posInYList := i;

    for j := 0 to node.sortedListOfZNodes.Count-1 do
      node.sortedListOfZNodes[j].posInsortedListOfZNodes := j;
  end;
end;

procedure TQuarterRangeSearch.Build(const ListOfKeys : TList<TKey3D>; const quadrant_ : TQuadrant);
begin
  Build(0,ListOfKeys.Count-1,ListOfKeys,quadrant_);
end;

procedure TQuarterRangeSearch.Build(const InitIdx, LastIdx : Integer; const ListOfKeys : TList<TKey3D>; const quadrant_ : TQuadrant);
var node     : TQRSNode;
    i        : Integer;
    key, WorkingKey : TKey3D;
    znode : TZNode;
begin
  Clear;
  // Build Working list according to quadrant
  quadrant := quadrant_;
  case quadrant of
    First: begin
             for i := InitIdx to LastIdx do
             begin
               key := ListOfKeys[i];
               with key do
               begin  WorkingKey := TKey3D.create(x,-y,-z,entityNo); end;
               DictOfKeyToInputKey.Add(WorkingKey,Key);
               WorkingListOfKeys.Add(workingKey);
             end;

           end;
    Second:begin
             for i := InitIdx to LastIdx do
             begin
               key := ListOfKeys[i];
               with key do
               begin  WorkingKey := TKey3D.create(x,y,-z,entityNo); end;

               DictOfKeyToInputKey.Add(WorkingKey,Key);
               WorkingListOfKeys.Add(workingKey);
             end;
           end;
    Third: begin
             for i := InitIdx to LastIdx do
             begin
               key := ListOfKeys[i];
               with key do
               begin  WorkingKey := TKey3D.create(x,y,z,entityNo); end;

               DictOfKeyToInputKey.Add(WorkingKey,Key);
               WorkingListOfKeys.Add(workingKey);
             end;
           end;
    Fourth:begin
             for i := InitIdx to LastIdx do
             begin
               key := ListOfKeys[i];
               with key do
               begin  WorkingKey := TKey3D.create(x,-y,z,entityNo); end;

               DictOfKeyToInputKey.Add(WorkingKey,Key);
               WorkingListOfKeys.Add(workingKey);
             end;
           end;
  end;

  // Build QRSNodes and Store ListOfKeys and DicTKey3DToNode
  for i := 0 to WorkingListOfKeys.Count-1 do
  begin
    key  := WorkingListOfKeys[i];
    node := TQRSNode.create(key);

    ListOfKeysSortedByY.Add(key);
    DictOfkeyToTQRSNode.Add(key,node);
  end;
  ListOfKeysSortedByY.sort(comparerY);

//    //Inspect sorted LIst
//    for i := 0 to ListOfKeysSortedByY.count-1 do
//      key := ListOfKeysSortedByY[i];

  // Build Nodes
  LeftToRightPass;
  RightToLeftPass;
  cascade;
  updateposInsortedListOfZNodes;
  FCount := WorkingListOfKeys.Count;

//  // inspect
//  for i := 0 to EnteringZList.Count-1 do
//    znode := EnteringZList[i];
end;

procedure TQuarterRangeSearch.trackListUpwards(const List : TList<TZNode>; const probeZNode : TzNode; var position : Integer);
var StartPosition, LastPosWithPointerToRight : Integer;
begin
  StartPosition := position;
  LastPosWithPointerToRight := -1;
  while (position < List.Count-1) AND (compareZNode(probeZNode,List[position+1]) = 1) do
  begin
    Inc(position);
    if Assigned(List[position].pointerToRight) then
      LastPosWithPointerToRight := position;
  end;

  if LastPosWithPointerToRight = -1 then  position := StartPosition
  else                                    position := LastPosWithPointerToRight;
end;

procedure TQuarterRangeSearch.trackListDownwards(const List : TList<TZNode>; const probeZNode : TzNode; var position : Integer);
var StartPosition, LastPosWithPointerToRight : Integer;
begin
  StartPosition := position;
  LastPosWithPointerToRight := -1;
  while (position > 0) AND (compareZNode(probeZNode,List[position-1]) = -1) do
  begin
    Dec(position);
    if Assigned(List[position].pointerToRight) then
      LastPosWithPointerToRight := position;
  end;

  if LastPosWithPointerToRight = -1 then  position := StartPosition
  else                                    position := LastPosWithPointerToRight;
end;

procedure TQuarterRangeSearch.updatePredecessor(const probeZNode : TzNode; var pred : TzNode);
var NextPred             : TzNode;
    QRSNode, NextQRSNode : TQRSNode;
    position             : Integer;
begin
  if Assigned(pred.pointerToRight) then
    Nextpred := pred.pointerToRight
  else
  begin
    // Look for a pred with rightPointer in YPosition Node
    QRSNode  := DictOfkeyToTQRSNode[pred.pointerToBaseNode.pointerToKey3D];
    position := pred.posInsortedListOfZNodes;

  // BaseNodePoints To right so we are save
    while (position>0) AND NOT Assigned(QRSNode.sortedListOfZNodes[position].pointerToRight) do
      dec(position);

    if position = 0 then // use BaseNode always have a pointerTORight
      NextPred := pred.pointerToBaseNode.pointerToRight
    else
      NextPred := QRSNode.sortedListOfZNodes[position].pointerToRight;
  end;
  // at NextYposition track upward ZList for a tighter predecesor
  if Assigned(NextPred) then
  begin
    NextQRSNode := DictOfkeyToTQRSNode[Nextpred.pointerToBaseNode.pointerToKey3D];
    position    := Nextpred.posInsortedListOfZNodes;

    trackListUpwards(NextQRSNode.sortedListOfZNodes,probeZNode,position);

    Nextpred      := NextQRSNode.sortedListOfZNodes[position];
    NextYPosition := NextQRSNode.posInYList;
  end;
  // output
  pred := NextPred;
end;

function TQuarterRangeSearch.updateSuccessorIfSuccIsNIL(const probeZNode : TzNode) : TzNode;
var NextQRSNode, QRSNode : TQRSNode;
    position, i,
    FinalPosition,
    StartPosition        : Integer;
    key                  : TKey3D;
begin
  NextQRSNode := DictOfkeyToTQRSNode[ListOfKeysSortedByY[NextYPosition]];
  // We need to account here every Edge crossed from posInYListOfOldQRSNode To Next Pred
  StartPosition := YPosition + 1;
  FinalPosition := NextYPosition-1;
  for i := StartPosition to FinalPosition do
  begin
    YPosition := i;
    key       := ListOfKeysSortedByY[i];
    QRSNode   := DictOfkeyToTQRSNode[key];
    // At every QRSNodelook for a valid successor
    position := QRSNode.sortedListOfZNodes.Count;
    trackListDownwards(QRSNode.sortedListOfZNodes,probeZNode,position);

    if position <> QRSNode.sortedListOfZNodes.Count then
    begin
      RESULT := QRSNode.sortedListOfZNodes[position];
      Exit;
    end
    else
    begin
      if compareY(key,probeZNode.pointerToKey3D) = -1 then
        OutputSortedListOfKeys.Add(DictOfKeyToInputKey[ListOfKeysSortedByY[i]]);
    end;
  end;

  // if no valid successor is found in all those nodes inspect NextQRSNode
  position := NextQRSNode.sortedListOfZNodes.Count;

  while comparezNode(probeZNode,NextQRSNode.sortedListOfZNodes[position-1]) = -1 do
    dec(position);

  if position < NextQRSNode.sortedListOfZNodes.Count then
    RESULT := NextQRSNode.sortedListOfZNodes[position]
  else
    RESULT := nil;
end;

procedure TQuarterRangeSearch.updateSuccessor(const probeZNode : TzNode; var succ : TzNode);
var NextSucc             : TzNode;
    QRSNode, NextQRSNode : TQRSNode;
    position             : Integer;
begin
  if Assigned(succ) then
  begin
    if Assigned(succ.pointerToRight) then
    begin
      NextSucc    := succ.pointerToRight;
      NextQRSNode := DictOfkeyToTQRSNode[NextSucc.pointerToBaseNode.pointerToKey3D];
      position    := NextSucc.posInsortedListOfZNodes;

      trackListDownwards(NextQRSNode.sortedListOfZNodes,probeZNode,position);

      NextSucc := NextQRSNode.sortedListOfZNodes[position];
    end
    else
    begin
      QRSNode  := DictOfkeyToTQRSNode[succ.pointerToBaseNode.pointerToKey3D];
      position := succ.posInsortedListOfZNodes;

      while (position < QRSNode.sortedListOfZNodes.Count) AND (NOT Assigned(QRSNode.sortedListOfZNodes[position].pointerToRight)) do
        Inc(position);

      if position < QRSNode.sortedListOfZNodes.Count then
        Nextsucc := QRSNode.sortedListOfZNodes[position].pointerToRight
      else
        NextSucc := updateSuccessorIfSuccIsNIL(probeZNode);
    end;
  end
  else
    NextSucc := updateSuccessorIfSuccIsNIL(probeZNode);
  // output
  succ   := NextSucc;
end;

procedure TQuarterRangeSearch.updatePredSucc(const probeZNode : TzNode; var pred, succ : TZNode);
{Assumed inputs belong to the same QRSNode, outputs must satisfy this condition to}
var position, anInteger : Integer;
begin
  updatePredecessor(probeZNode,pred);
  if Assigned(pred) then
  begin
    updateSuccessor(probeZNode,succ);
    // update succesor until pred and Succ live in the same QRSNode or Succ is nil
    if Assigned(Succ) then
    begin
      anInteger := compareY(pred.pointerToBaseNode.pointerToKey3D,succ.pointerToBaseNode.pointerToKey3D);
      while anInteger <> 0 do
      begin
        if anInteger = 1 then
        begin

          // Stop if succ beyond y mark -> no more keys to OutputSortedListOfKeys
          anInteger := compareY(succ.pointerToBaseNode.pointerToKey3D,probeZNode.pointerToKey3D);
          if anInteger = 1 then Exit;

          if compareZNode(probeZNode,succ.pointerToBaseNode) = 1 then
            OutputSortedListOfKeys.Add(DictOfKeyToInputKey[succ.pointerToBaseNode.pointerToKey3D]);

          YPosition := DictOfkeyToTQRSNode[succ.pointerToBaseNode.pointerToKey3D].posInYList;
          updateSuccessor(probeZNode,succ);
          if NOT Assigned(succ) then break;
        end
        else
          showmessage('This should not happen');
        //update
        anInteger := compareY(pred.pointerToBaseNode.pointerToKey3D,succ.pointerToBaseNode.pointerToKey3D);
      end;
      // update
      YPosition := NextYPosition;
    end
  end
end;

function TQuarterRangeSearch.isKey1DominatedByKey2(const k1, k2 : TKey3D) : Boolean;
var key : TKey3D;
begin
  // transform k1 into key
  case quadrant of
    First  : key := TKey3D.create(100000,-k1.y,-k1.z,k1.entityNo);
    Second : key := TKey3D.create(100000,k1.y,-k1.z,k1.entityNo);
    Third  : key := TKey3D.create(100000,k1.y,k1.z,k1.entityNo);
    Fourth : key := TKey3D.create(100000,-k1.y,k1.z,k1.entityNo);
  end;

  RESULT := (compareY(key,k2) <> 1) AND (compareZ(key,k2) <> 1);
  key.Free;
end;

function TQuarterRangeSearch.getSortedListOfMembersDominatedBykey(const key_ : TKey3D) : TList<TKey3D>;
var probeZNode, pred, succ : TzNode;
    position, i            : Integer;
label FreeAndExit;
begin
  OutputSortedListOfKeys.Clear;
  RESULT := OutputSortedListOfKeys;

  probeZNode := TzNode.create(key_);

  // BinarySearch in EnteringZList Just once
  EnteringZList.BinarySearch(probeZnode,position,comparerZNode);

  if position = 0 then goto FreeAndExit
  else
  begin
    pred := EnteringZList[position-1];
    if position = EnteringZList.Count then
      succ := nil
    else
      succ := EnteringZList[position];
  end;

  // Walk right storing output every edgeCrossed
  YPosition := -1;
  updatePredSucc(probeZNode,pred,succ);
  while Assigned(pred) AND (compareY(key_,pred.pointerToBaseNode.pointerToKey3D) = 1)  do
  begin
    OutputSortedListOfKeys.Add(DictOfKeyToInputKey[pred.pointerToBaseNode.pointerToKey3D]);
    YPosition := DictOfkeyToTQRSNode[pred.pointerToBaseNode.pointerToKey3D].posInYList;
    updatePredSucc(probeZNode,pred,succ);
  end;

  FreeAndExit:
  probeZNode.Free;
end;

// end define methods of TQuarterRangeSearch<TKey3D>


end.
