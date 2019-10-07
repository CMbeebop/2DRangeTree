unit RangeTree2D_u;
{ generic 2D Range Tree -> TRangeTree2D<TKey>

  Based on Ideas given in Session 3 of the course 6.851 MIT OpenWare
  https://ocw.mit.edu/courses/electrical-engineering-and-computer-science/6-851-advanced-data-structures-spring-2012/lecture-videos/

  HOW TO USE:
  TKey is a userdefined class that allows for relational operators  <_x and <_y.
  These operators are defined through two comparison functions that must be
  provided by the user in the constructor.

  Then the DS TRangeTree2D<TKey> is built (statically) with an input list Of keys,
  being ready to perform report queries on the form:

  given a set of keys S, find the subset Sm with the keys that lie inside the rage [k1,k2],
  where k1, k2 are some bounding keys that can be seen as the bottomLeft and topRight corners
  of 2D interval [k1.x,k2.x]x[k1.y,k2.y]. The expected scaling time is O(|Sm| + log |S|).

  See HowToUseExample at the end of the unit, were TKey = TSPt2D, a record (x,y,PtNo),
  is used along with standard <_x, <_y comparison functions.

  OVERVIEW:
  There is a Balanced Tree with the data at the leafs sorted by X.
  Each node contains a Sorted List with the keys living in node's subtree sorted by Y.
  Fractional Cascading is employed to track nodes in YRange while XTree is navigated
  for XRange.

  TODO : upgrade to Dynamic see RangeTree1D_u.pas   }

interface

uses Math, System.SysUtils,DIalogs, System.Variants, System.Classes, System.Generics.collections,
     Generics.Defaults;

type TyNode<TKey> = class

  key                             : TKey;
  isPromoted                      : Boolean;

  PromotedSucc, PromotedPred,
  NoPromotedSucc, NoPromotedPred,
  PromotedInLeftList,
  PromotedInRightList,
  PromotedInParentList            : TYNode<TKey>;
  posInList                       : Integer;

  constructor create(const key_ : TKey);

end;

type TRangeTree2DNode<TKey> = class

    parent, left, right : TRangeTree2DNode<TKey>;
    isLeftChild         : Boolean;
    key                 : TKey;
    compareX            : TComparison<TKey>;
    compareY            : TComparison<TyNode<TKey>>;
    comparerY           : IComparer<TyNode<TKey>>;  // needded for binarySearch
    SortedListOfyNodes  : TList<TyNode<TKey>>;


    public
    constructor create(const compareX_ : TComparison<TKey>; const compareY_ : TComparison<TyNode<TKey>>; const comparerY_ : IComparer<TyNode<TKey>>);
    procedure free;
    procedure initNode(const key_: TKey; const parent_: TRangeTree2DNode<TKey>);
    function find(const key : TKey) : TRangeTree2DNode<TKey>;
    protected
    procedure DeleteSubTreeAndGetSortedObjects(var List : TList<TRangeTree2DNode<TKey>>);

    protected
    function updatePosInYRange(const ky1,ky2 : TyNode<Tkey>) : Boolean;

    private
    posOfFirstInYRange,
    posOfLastInYRange           : Integer;
    isLeaf                      : Boolean;

    procedure SplitNode(const idxStart, idxEnd : Integer;const SortedList : TList<TKey>; const DictOfKeyToPosInSortedList : TDictionary<TKey,Integer>); {overload;}
    procedure buildSortedListOfyNodes(const idxStart, idxEnd : Integer;const PrevSortedListOfyNodes : TList<TyNode<TKey>>; const DictOfKeyToPosInSortedList : TDictionary<TKey,Integer>);
    procedure updatePosInListOfyNodes;
    procedure cascade;
    procedure cascadeNodes(const PrevSortedListOfyNodes : TList<TyNode<TKey>>);
    function updatePosOfFirstInYRange(const PromPred, ky1 : TyNode<TKey>) : Boolean;
    function updatePosOfLastInYRange(const PromSucc, ky2 : TyNode<TKey>) : Boolean;
    function IsLeafInYRange : Boolean;

end;

type TRangeTree2D<TKey> = Class(TObject)

    compareX               : TComparison<TKey>;
    compareY               : TComparison<TKey>;
    private
    root                   : TRangeTree2DNode<TKey>;
    compareYNode           : TComparison<TyNode<TKey>>;
    OutputSortedListOfKeys : TList<TKey>;
    FCount                 : Integer;    // number of objects in the tree
    procedure FractionalCascading;
    procedure CollectSortedKeysOfSubtree(const node : TRangeTree2DNode<TKey>; const ky1, ky2 : TyNode<TKey>);
    procedure CollectSortedKeysGTk1(const node : TRangeTree2DNode<TKey>; const kx1 : TKey; const ky1, ky2 : TyNode<TKey>);
    procedure CollectSortedKeysLTk2(const node : TRangeTree2DNode<TKey>; const kx2 : TKey; const ky1, ky2 : TyNode<TKey>);
    function getBifurcationNode(const kx1,kx2 : TKey; const ky1, ky2 : TyNode<TKey>) : TRangeTree2DNode<TKey>;

    public
    constructor create(const compareX_ : TComparison<TKey>; const compareY_ : TComparison<TKey>);
    procedure BuildTree(const ListOfKeys : TList<TKey>);
    procedure Clear;
    procedure free;
    function find(const key : TKey): TRangeTree2DNode<TKey>;
    property Count : integer read FCount;
    function getSortedListOfMembersInRange(const key1, key2 : TKey) : TList<TKey>;

end;


implementation

const CascadeConstant = 2;

// Begin define methods of TYNode<TKey>
constructor TyNode<TKey>.create(const key_ : TKey);
begin
  inherited create;
  key        := key_;
  isPromoted := FALSE;
  // initiallize pointers
  PromotedSucc         := nil;
  PromotedPred         := nil;
  NoPromotedSucc       := nil;
  NoPromotedPred       := nil;
  PromotedInLeftList   := nil;
  PromotedInRIghtList  := nil;
  PromotedInParentList := nil;
end;
// End define methods of TyNode<TKey>

// begin define methods of TRangeTree2DNode<TKey>
constructor TRangeTree2DNode<TKey>.create(const compareX_ : TComparison<TKey>; const compareY_ : TComparison<TyNode<TKey>>; const comparerY_ : IComparer<TyNode<TKey>>);
{}
begin
  inherited create;
  compareX  := compareX_;
  compareY  := compareY_;
  comparerY := comparerY_;
  SortedListOfyNodes := TList<TyNode<TKey>>.create;
end;

procedure TRangeTree2DNode<TKey>.free;
var i: Integer;
begin
  for i := 0 to SortedListOfyNodes.Count-1 do
    SortedListOfyNodes[i].Free;
  SortedListOfyNodes.Free;
  inherited Free;
end;

procedure TRangeTree2DNode<TKey>.initNode(const key_: TKey; const parent_: TRangeTree2DNode<TKey>);
begin
  key        := key_;
  right      := nil;
  left       := nil;
  parent     := parent_;
  isLeaf     := TRUE;
end;

function TRangeTree2DNode<TKey>.find(const key : TKey) : TRangeTree2DNode<TKey>;
(* returns the node containing the key in calling Node's subtree or nil if not found *)
var anInteger : Integer;
begin
  anInteger := compareX(Self.key,key);
  if anInteger = 0 then
  begin
    RESULT := Self;
    Exit;
  end
  else if anInteger >0 then
  begin  // look for key in left subtree
    if NOT Assigned(Self.left) then
     begin RESULT := nil; Exit; end;
     RESULT := Self.left.find(key);
  end
  else  //then key > RESULT.key
  begin  // look for key in right subtree
    if NOT Assigned(Self.right) then
    begin  RESULT := nil; Exit; end;
    RESULT := Self.right.find(key);
  end;
end;

procedure TRangeTree2DNode<TKey>.DeleteSubTreeAndGetSortedObjects(var List : TList<TRangeTree2DNode<TKey>>);
begin
  if isLeaf then
    List.Add(Self)
  else
  begin
    Self.left.DeleteSubTreeAndGetSortedObjects(List);
    Self.right.DeleteSubTreeAndGetSortedObjects(List);
    Self.Free;
  end;
end;

procedure TRangeTree2DNode<TKey>.buildSortedListOfyNodes(const idxStart, idxEnd : Integer;const PrevSortedListOfyNodes : TList<TyNode<TKey>>; const DictOfKeyToPosInSortedList : TDictionary<TKey,Integer>);
var  i, posInXList   : Integer;
     yNode, newINode : TyNode<TKey>;
begin
  for i := 0 to PrevSortedListOfyNodes.Count-1 do
  begin
    yNode      := PrevSortedListOfyNodes[i];
    posInXList := DictOfKeyToPosInSortedList[yNode.key];

    if (posInXList < idxStart) OR (posInXList > idxEnd) then continue;

    newINode := TyNode<TKey>.create(yNode.key);
    SortedListOfyNodes.Add(newINode);
  end;
end;

procedure TRangeTree2DNode<TKey>.updatePosInListOfyNodes;
var i : Integer;
begin
  for i := 0 to SortedListOfyNodes.Count-1 do
    SortedListOfyNodes[i].posInList := i;
end;

procedure TRangeTree2DNode<TKey>.cascade;
begin
  updatePosInListOfyNodes;
  if NOT isLeaf then
  begin      // cascade next level
     left.cascadeNodes(SortedListOfyNodes);
     left.cascade;
     right.cascadeNodes(SortedListOfyNodes);
     right.cascade;
  end;
end;

procedure TRangeTree2DNode<TKey>.cascadeNodes(const PrevSortedListOfyNodes : TList<TyNode<TKey>>);
var  i, j, posInList, counter  : Integer;
     yNode, NewyNode,
     NoPromPred, NoPromSucc,
     LastPromoted, LastNoPromoted : TyNode<TKey>;
     ListOfNPNotAssignedSuccesor,
     ListOfPNotAssignedSuccesor : TList<TyNode<TKey>>;
begin
  {Avoid analysis of PrevSortedListOfYNodes twice, we only do when left.child}
  if isLeftChild then
  begin
    LastPromoted := nil;  LastNoPromoted := nil;
    ListOfNPNotAssignedSuccesor := TList<TyNode<TKey>>.create;
    ListOfPNotAssignedSuccesor  := TList<TyNode<TKey>>.create;
    for i := 0 to PrevSortedListOfyNodes.Count-1 do
    begin

      yNode := PrevSortedListOfyNodes[i];

      if (i mod CascadeConstant) = 0 then
      begin
        yNode.isPromoted := TRUE;
        // revise left/right connections in prevSortedList
        yNode.NoPromotedPred := LastNoPromoted;
        ListOfPNotAssignedSuccesor.add(ynode);
        // asses PromSucc of Previuous NPNodes
        for j := 0 to ListOfNPNotAssignedSuccesor.Count-1 do
          ListOfNPNotAssignedSuccesor[j].PromotedSucc := yNode;
        ListOfNPNotAssignedSuccesor.Clear;
        // update
        LastPromoted := yNode;

        // promote yNode to next List
        NewyNode := TyNode<TKey>.create(yNode.key);
        // revise up/Down Conections
        yNode.PromotedInLeftList      := NewyNode;
        NewyNode.PromotedInParentList := yNode;
        // search position for yNode and insert
        SortedListOfyNodes.BinarySearch(NewyNode,posInList,comparerY);
        SortedListOfyNodes.insert(posInList,NewYNode);
      end
      else
      begin
        yNode.isPromoted   := FALSE;
        yNode.PromotedPred := LastPromoted;
        ListOfNPNotAssignedSuccesor.add(yNode);

        // revise NPSucc of Previous PromotedNodes
        for j := 0 to ListOfPNotAssignedSuccesor.Count-1 do
          ListOfPNotAssignedSuccesor[j].NoPromotedSucc := yNode;
        ListOfPNotAssignedSuccesor.Clear;

        // update
        LastNoPromoted := yNode;
      end;
    end;
    ListOfNPNotAssignedSuccesor.Free;
    ListOfPNotAssignedSuccesor.Free;
  end
  else  // then rightChild, we just promote to next List
  begin
    for i := 0 to PrevSortedListOfyNodes.Count-1 do
    begin

      yNode := PrevSortedListOfyNodes[i];

      if (i mod CascadeConstant) = 0 then
      begin
        NewyNode := TyNode<TKey>.create(yNode.key);
        // revise up/Down Conections
        yNode.PromotedInRightList     := NewyNode;
        NewyNode.PromotedInParentList := yNode;
        // search position for yNode
        SortedListOfyNodes.BinarySearch(NewyNode,posInList,comparerY);
        SortedListOfyNodes.insert(posInList,NewYNode);
      end
    end;
  end;
end;

procedure TRangeTree2DNode<TKey>.SplitNode(const idxStart, idxEnd : Integer; const SortedList : TList<TKey>; const DictOfKeyToPosInSortedList : TDictionary<TKey,Integer>);
var idxEndLeft, n, no2 : Integer;
    leafKey            : TKey;
begin
  n := idxEnd-idxStart;
  if n = 0 then
  begin
    leafkey    := SortedList[idxStart];
    key        := leafkey;
    isLeaf     := TRUE;
  end
  else
  begin
    no2 := Trunc(0.5*n);
    idxEndLeft := idxStart + no2;
    // revise CurrentNode
    key        := SortedList[idxEndLeft];
    isLeaf     := FALSE;
    // Create New Left Node
    left             := TRangeTree2DNode<TKey>.create(compareX,compareY,comparerY);
    left.parent      := self;
    left.isLeftChild := TRUE;
    left.buildSortedListOfyNodes(idxStart,idxEndLeft,SortedListOfyNodes,DictOfKeyToPosInSortedList);
    left.SplitNode(idxStart,idxEndLeft,SortedList,DictOfKeyToPosInSortedList);
    // Create New Left Node
    right := TRangeTree2DNode<TKey>.create(compareX,compareY,comparerY);
    right.parent := self;
    right.isLeftChild := FALSE;
    right.buildSortedListOfyNodes(idxEndLeft+1,idxEnd,SortedListOfyNodes,DictOfKeyToPosInSortedList);
    right.SplitNode(idxEndLeft+1,idxEnd,SortedList,DictOfKeyToPosInSortedList);
  end;
end;

function TRangeTree2DNode<TKey>.updatePosOfFirstInYRange(const PromPred, ky1 : TyNode<TKey>) : Boolean;
begin
  RESULT := TRUE;
  if Assigned(PromPred) then
    posOfFirstInYRange := promPred.posInList
  else
    posOfFirstInYRange := 0;
  // Trak ListUp for a sharper predecessor
  while compareY(ky1,SortedListOfyNodes[max(posOfFirstInYRange,0)]) = 1 do
  begin
    Inc(posOfFirstInYRange);
    if posOfFirstInYRange = SortedListOfyNodes.Count then
    begin  RESULT := FALSE; EXIT end;
  end;
end;

function TRangeTree2DNode<TKey>.updatePosOfLastInYRange(const PromSucc, ky2 : TyNode<TKey>) : Boolean;
begin
  RESULT := TRUE;
  if Assigned(promSucc) then
    posOfLastInYRange := promSucc.posInList
  else
    posOfLastInYRange := SortedListOfyNodes.Count-1;
  // Trak ListDown for a sharper successor
  while compareY(ky2,SortedListOfyNodes[min(posOfLastInYRange,SortedListOfyNodes.Count-1)]) = -1 do
  begin
    Dec(posOfLastInYRange);
    if posOfLastInYRange = 0 then
    begin  RESULT := FALSE; EXIT end;
  end;
end;

function TRangeTree2DNode<TKey>.updatePosInYRange(const ky1,ky2 : TyNode<Tkey>) : Boolean;
{Assumed node is not the root}
var y1Node, y2Node,
    promSucc, promPred : TyNode<TKey>;
begin
  // look for promoted Predecessor and successor yNodes in node's Y list
  // Find PromotedPredecessor In parent Node
  if parent.posOfFirstInYRange = 0 then
    promPred := nil
  else
  begin
    y1Node := parent.SortedListOfyNodes[parent.posOfFirstInYRange-1];
    if y1Node.isPromoted then promPred := y1Node
    else                      promPred := y1Node.PromotedPred;
  end;
  // Find PromotedSuccessor In parent Node
  if (parent.posOfLastInYRange = parent.SortedListOfyNodes.Count-1) then
    PromSucc := nil
  else
  begin
    y2Node := parent.SortedListOfyNodes[parent.posOfLastInYRange+1];
    if y2Node.isPromoted then promSucc := y2Node
    else                      promSucc := y2Node.PromotedSucc;
  end;
  // track promoted parent nodes to nodes Level and Solve Yrange problem
  if isLeftChild then
  begin
    if Assigned(promPred) then
      PromPred := PromPred.PromotedInLeftList;

    if updatePosOfFirstInYRange(PromPred,ky1) then
    begin
      if Assigned(promSucc) then
        PromSucc  := promSucc.PromotedInLeftList;

      if NOT updatePosOfLastInYRange(PromSucc,ky2) then
      begin RESULT := FALSE; Exit; end;
    end
    else
    begin RESULT := FALSE; Exit; end;
  end
  else  // Then RightChild
  begin
    if Assigned(promPred) then
      PromPred := PromPred.PromotedInRightList;

    if updatePosOfFirstInYRange(PromPred,ky1) then
    begin
      if Assigned(promSucc) then
        PromSucc  := promSucc.PromotedInRightList;

      if NOT updatePosOfLastInYRange(PromSucc,ky2) then
      begin RESULT := FALSE; Exit; end;
    end
    else
    begin RESULT := FALSE; Exit; end;
  end;

  if posOfFirstInYRange > posOfLastInYRange then RESULT := FALSE
  else                                           RESULT := TRUE;

end;

function TRangeTree2DNode<TKey>.IsLeafInYRange : Boolean;
var i : Integer;
    yNode : TyNode<TKey>;
begin
  for i := posOfFirstInYRange to posOfLastInYRange do
  begin
    yNode := SortedListOfyNodes[i];
    if NOT Assigned(yNode.PromotedInParentList) then
    begin  RESULT := TRUE; Exit; end;
  end;
  // reached this line all yNodes in [PosOfFrst,PosOfLast] have been promoted from parent
  RESULT := FALSE;
end;
// End Define methods of TRangeTree2DNode<TKey>

// Begin define methods of TRangeTree2D
constructor TRangeTree2D<TKey>.create(const compareX_ : TComparison<TKey>; const  compareY_ : TComparison<TKey>);
begin
  inherited create;
  root         := nil;
  compareX     := compareX_;
  compareY     := compareY_;
  compareYNode := function(const left, right: TyNode<TKey>): Integer
                  begin
                    RESULT := compareY(left.key,right.key);
                  end;
  OutputSortedListOfKeys := TList<TKey>.create;
end;

procedure TRangeTree2D<TKey>.Clear;
var ListOfNodes : TList<TRangeTree2DNode<TKey>>;
    node        : TRangeTree2DNode<TKey>;
    i           : Integer;
begin
  if Assigned(root) then
  begin
    ListOfNodes := TList<TRangeTree2DNode<TKey>>.create;
    root.DeleteSubTreeAndGetSortedObjects(ListOfNodes);
    for i := 0 to ListOfNodes.Count-1 do
    begin
      node := ListOfNodes[i];
      node.free;
    end;
    ListOfNodes.free;

    root := nil;
  end;
  OutputSortedListOfKeys.Clear;
end;

procedure TRangeTree2D<TKey>.free;
begin
  Clear;
  OutputSortedListOfKeys.Free;
  inherited free;
end;

function TRangeTree2D<TKey>.find(const key : TKey) : TRangeTree2DNode<TKey>;
 (* returns node containing key or nil if it is not there *)
begin
  RESULT := Self.root.find(key);
end;

procedure TRangeTree2D<TKey>.BuildTree(const ListOfKeys : TList<TKey>);
var compareXFun           : IComparer<TKey>;
    compareYFun           : IComparer<TyNode<TKey>>;
    ListOfKeysSortedByX   : TList<TKey>;
    i                     : Integer;
    tmpKey                : TKey;
    yNode                 : TyNode<TKey>;
    DictOfKeyToPosInXList : TDictionary<TKey,Integer>;
    node                  : TRangeTree2DNode<TKey>;
begin
  Clear;
  // construct comparers
  compareXFun := TComparer<TKey>.Construct(compareX);
  compareYFun := TComparer<TyNode<TKey>>.Construct(compareYNode);
  // XSorted List of Keys
  ListOfKeysSortedByX := TList<TKey>.create;
  for i := 0 to ListOfKeys.Count-1 do
    ListOfKeysSortedByX.Add(ListOfKeys[i]);
  ListOfKeysSortedByX.Sort(compareXFun);
  // Build root Node
  root := TRangeTree2DNode<TKey>.Create(compareX,compareYNode,compareYFun);
  DictOfKeyToPosInXList := TDictionary<TKey,Integer>.create;
  for i := 0 to ListOfKeysSortedByX.Count-1 do
  begin
    tmpKey := ListOfKeysSortedByX[i];
    // Build yNode
    yNode := TyNode<TKey>.create(tmpkey);

    DictOfKeyToPosInXList.Add(yNode.key,i);

    root.SortedListOfYNodes.Add(yNode);
  end;
  root.SortedListOfYNodes.Sort(compareYFun);

  root.splitNode(0,ListOfKeysSortedByX.Count-1,ListOfKeysSortedByX,DictOfKeyToPosInXList);
  FractionalCascading;

  FCount := ListOfKeys.Count;
  // Free memory
  DictOfKeyToPosInXList.Free;
  ListOfKeysSortedByX.Free;
end;

procedure TRangeTree2D<TKey>.FractionalCascading;
begin
  if NOT Assigned(root) then Exit;
  root.cascade;
end;


function TRangeTree2D<TKey>.getBifurcationNode(const kx1,kx2 : TKey; const ky1, ky2 : TyNode<TKey>) : TRangeTree2DNode<TKey>;
{assumed kx1<kx2, ky1<ky2}
var node       : TRangeTree2DNode<TKey>;
    int1, int2,
    posky1, posky2 : Integer;
    promSucc, promPred, y1Node, y2Node : TyNode<TKey>;
begin
  RESULT := nil;

  // BinarySearch YRange just once, At the root
  with root do
  begin
    SortedListOfyNodes.BinarySearch(ky1,posOfFirstInYRange,comparerY);
    SortedListOfyNodes.BinarySearch(ky2,posOfLastInYRange,comparerY);
    if posOfFirstInYRange = posOfLastInYRange then Exit  // no members in YRange
    else posOfLastInYRange := posOfLastInYRange-1;
  end;

  // Find BifurcationNode
  node := root;
  while Assigned(node) do
  begin

    int1 := node.compareX(kx1,node.key);

    if int1 <> 1 then
    begin
      int2 := node.compareX(kx2,node.key);

      if int2 = 1 then
      begin  RESULT := node;  Exit;  end
      else node := node.left;
    end
    else node := node.right;

    if Assigned(node) then
    begin
      if NOT node.updatePosInYRange(ky1,ky2) then Exit;
    end;
  end;
end;

procedure TRangeTree2D<TKey>.CollectSortedKeysOfSubtree(const node : TRangeTree2DNode<TKey>; const ky1, ky2 : TyNode<TKey>);
begin
  if node.isLeaf then
  begin
    if node.IsLeafInYRange then OutputSortedListOfKeys.Add(node.key);
  end
  else
  begin
    if node.left.updatePosInYRange(ky1,ky2) then
      CollectSortedKeysOfSubtree(node.left,ky1,ky2);
    if node.right.updatePosInYRange(ky1,ky2) then
      CollectSortedKeysOfSubtree(node.right,ky1,ky2);
  end;
end;


procedure TRangeTree2D<TKey>.CollectSortedKeysGTk1(const node : TRangeTree2DNode<TKey>; const kx1 : TKey; const ky1, ky2 : TyNode<TKey>);
{assumed that if node = root then root is leaf}
var anInteger : Integer;
begin
  anInteger := node.compareX(kx1,node.key);

  if node.isLeaf then
  begin
    if (anInteger <> 1) AND node.IsLeafInYRange then
      OutputSortedListOfKeys.Add(node.key);
  end
  else
  begin
    if anInteger <> 1 then
    begin
      if node.left.updatePosInYRange(ky1,ky2) then
        CollectSortedKeysGTk1(node.left,kx1,ky1,ky2);
      if node.right.updatePosInYRange(ky1,ky2) then
        CollectSortedKeysOfSubtree(node.right,ky1,ky2);
    end
    else
    begin
      if node.right.updatePosInYRange(ky1,ky2) then
        CollectSortedKeysGTk1(node.right,kx1,ky1,ky2);
    end;
  end;
end;

procedure TRangeTree2D<TKey>.CollectSortedKeysLTk2(const node : TRangeTree2DNode<TKey>; const kx2 : TKey; const ky1, ky2 : TyNode<TKey>);
{assumed that if node = root then root is leaf}
var anInteger : Integer;
begin
  anInteger := node.compareX(kx2,node.key);

  if node.isLeaf then
  begin
    if (anInteger <> -1) AND node.IsLeafInYRange then
      OutputSortedListOfKeys.Add(node.key);
  end
  else
  begin
    if anInteger <> 1 then
    begin
      // node <> root   (otherwise posInYRange Already assigned)
      if node.left.updatePosInYRange(ky1,ky2) then
        CollectSortedKeysLTk2(node.left,kx2,ky1,ky2);
    end
    else
    begin
      if node.left.updatePosInYRange(ky1,ky2) then
        CollectSortedKeysOfSubtree(node.left,ky1,ky2);
      if node.right.updatePosInYRange(ky1,ky2) then
        CollectSortedKeysLTk2(node.right,kx2,ky1,ky2);
    end
  end;
end;

function TRangeTree2D<TKey>.getSortedListOfMembersInRange(const key1, key2 : TKey) : TList<TKey>;
{ outputs the sorted list of keys satisfying k1 < k < k2 : Note input is sorted to satisfy k1<k2 }
var node, BifurcationNode : TRangeTree2DNode<TKey>;
    int1, int2            : Integer;
    kx1, kx2              : TKey;
    ky1, ky2, dummy1, dummy2  : TyNode<TKey>;
begin
  OutputSortedListOfKeys.Clear;
  RESULT := OutputSortedListOfKeys;

  if Assigned(root) then
  begin
    // get X range [kx1,kx2]
    if root.compareX(key1,key2) = 1 then
    begin  kx1 := key2;  kx2 := key1;  end
    else
    begin  kx1 := key1;  kx2 := key2;  end;

    // get Y range [ky1,ky2]
    dummy1 := TyNode<TKey>.create(key1);
    dummy2 := TyNode<TKey>.create(key2);

    if root.compareY(dummy1,dummy2) = 1 then
    begin  ky1 := dummy2;  ky2 := dummy1;  end
    else
    begin  ky1 := dummy1;  ky2 := dummy2;  end;

    // in case of NoPoints in YRange BifNode = nil
    BifurcationNode := getBifurcationNode(kx1,kx2,ky1,ky2);

    if Assigned(BifurcationNode) then
    begin
      if BifurcationNode.isLeaf then
      begin
        CollectSortedKeysGTk1(BifurcationNode,kx1,ky1,ky2);
        CollectSortedKeysLTk2(BifurcationNode,kx2,ky1,ky2);
      end
      else
      begin
        if BifurcationNode.left.updatePosInYRange(ky1,ky2) then
          CollectSortedKeysGTk1(BifurcationNode.left,kx1,ky1,ky2);
        if BifurcationNode.right.updatePosInYRange(ky1,ky2) then
          CollectSortedKeysLTk2(BifurcationNode.right,kx2,ky1,ky2);
      end;
    end;

    // free memory
    ky1.Free;  ky2.Free;
  end;
end;

type TSPt2D = record
  x, y : Single;
  ptNo : Integer;
end;

procedure HowToUseExample;
var compareXYPtNo,
    compareYXPtNo   : TComparison<TSPt2D>;
    RT2D            : TRangeTree2D<TSPt2D>;
    ListOfKeys, L   : TList<TSPt2D>;
    pt, k1, k2      : TSPt2D;
    i               : Integer;
begin
  // generate 100 random points in [0,1]x[0,1]

  ListOfKeys := TList<TSPt2D>.Create;;
  for i := 0 to 100 do
  begin
    pt.x    := random;
    pt.y    := random;
    pt.ptNo := i;
    // Add to list
    ListOfKeys.Add(pt);
  end;

  // RT2D is an object of the class TRangeTree2D<TSPt2D>, that is a TRangeTree2D<TKey>
  // where TKey is TSPt2D, a Range Tree of 2D points. the constructor requires two comparison
  // function <_X and <_Y to be applied on objects of the class Tkey.  As they are
  // constructed below no two keys in ListOfKeys can be equal, since they all have a
  // different pointNo. This permits to have repeated  (x,y) points in the Tree,
  // corresponding to keys that are different wrt the comparison function.

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

  // Fill up the structure with a list of keys such that no equality is possible
  // (i.e No two keys are equal) under both comparison functions previously defined.

  RT2D.BuildTree(ListOfKeys);

  // Create my range defined by [k1,k2], being k1 the BottomLeftMost point and k2 the TopRightMost
  // point of the axis aligned quadrilateral defining the interval [k1.x,k2.x]x[k1.y,k2.y]
  k1.x := 0.2;
  k1.y := 0.4;

  k2.x := 0.8;
  k2.y := 0.5;        // defines 2D interval [0.2,0.8] x [0.4,0.5]

  // use ptNo on the keys to make Closed/Open Intervals
  k1.ptNo := -1;
  k2.ptNo := High(Integer);     // closed interval
  // for open intervals use
  //  k1.ptNo := High(Integer);
  //  k2.ptNo := -1;
  // semi-Open intervals are possible

  // get all members of ListOfKeys in the range [k1,k2], note L is a internal field
  // of the class and should ot be freed
  L := RT2D.getSortedListOfMembersInRange(k1,k2);

  // Free memory
  ListOfKeys.Free;
  RT2D.free;
end;









end.
