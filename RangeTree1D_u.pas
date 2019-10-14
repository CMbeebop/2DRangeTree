unit RangeTree1D_u;

{ Delphi implementation of generic 1D range search -> TRangeTree1D<TKey>

  Based on the ideas in session 2, 3 of the course 6.851 MIT OpenWare
  https://ocw.mit.edu/courses/electrical-engineering-and-computer-science/6-851-advanced-data-structures-spring-2012/lecture-videos/

  HOW TO USE:
  TKey is a userdefined class that allows for the relational operator "<" , defined
  through a comparison function that must be provided by the user in the constructor.

  the DS TRangeTree1D<TKey> can then be arranged statically using build method
  for a given input List of TKey or  it can be arranged dinamically using insert and
  delete methods one by one on the members of the List. At this point the DS will
  contain a set of keys S, and is ready to answer queries on the form find the subset Sm
  with the keys that lie in the interval [k1,k2], where k1, k2 are some bounding keys that
  cdefine a 1D interval.

    queries:                                  expected time scale
    insert,                                        O(log|S|)
    delete,                                        O(log|S|)
    isAnyInRange                                   O(log|S|)
    HowManyInRange,                                O(log|S|)
    getSortedListOfKeysInRange,                  O(Sm + log|S|)
    getDictOfKeysInRange                         O(Sm + log|S|)

  Note: see the procedures BuildRangeTreeDynamicAndQuery and BuildRangeTreeStaticAndQuery, for
  an example on how to use TRangeTree1D<TKey>. There we use  TKey = TEdges2D an edge defined by
  2 EndPoints that we query by their lengths.

  OVERVIEW
  Balanced trees using BB[alpha] tree -> Tree with data at the the leafs.
  after Insert/elete Operations the tree is rebalance automaticaly if there is a neeed.}

interface

uses Math, System.SysUtils,DIalogs, System.Variants, System.Classes, System.Generics.collections,
     Generics.Defaults;

type  TRangeTree1DNode<TKey> = class

    parent, left, right : TRangeTree1DNode<TKey>;
    isLeftChild         : Boolean;
    key                 : TKey;
    compare             : TComparison<TKey>;
    public
    constructor create(const compare_ : TComparison<TKey>);
    procedure initNode(const key_: TKey; const parent_: TRangeTree1DNode<TKey>);
    function find(const key : TKey) : TRangeTree1DNode<TKey>;
    procedure insert(var node : TRangeTree1DNode<TKey>);

    private
    size, size_left, size_right : Integer;
    isLeaf                      : Boolean;
    function isBalanced : Boolean;
    procedure Balance(var pointerToRoot : TRangeTree1DNode<TKey>);
    procedure SplitNode(const idxStart, idxEnd : Integer; const SortedListOfLeafNodes : TList<TRangeTree1DNode<TKey>>; var ListOfNoLeafNodes : TList<TRangeTree1DNode<TKey>>); overload;
    procedure SplitNode(const idxStart, idxEnd : Integer;const SortedList : TList<TKey>); overload;
    procedure UpdateSizesUpToTheRoot(var HighestInbalancedNode : TRangeTree1DNode<TKey>);
    procedure ExtractSubTreeNodes(var ListOfLeafs, ListOfNoLeafs : TList<TRangeTree1DNode<TKey>>);
    function getRightMostNodeOfSubtree : TRangeTree1DNode<TKey>;
end;

type TRangeTree1D<TKey> = Class(TObject)

    compare                : TComparison<TKey>;
    private
    root                   : TRangeTree1DNode<TKey>;
    OutputDictOfKeys       : TDictionary<TKey,Boolean>;
    OutputSortedListOfKeys : TList<TKey>;
    FCount                 : Integer;    // number of objects in the tree
    procedure CollectSortedKeysOfSubtree(const node : TRangeTree1DNode<TKey>);
    procedure CollectSortedKeysGTk1(const node : TRangeTree1DNode<TKey>; const k1 : TKey);
    procedure CollectSortedKeysLTk2(const node : TRangeTree1DNode<TKey>; const k2 : TKey);
    procedure CollectSubTreeLeafsToDictionary(const node : TRangeTree1DNode<TKey>);
    function getBifurcationNode(const k1,k2 : TKey) : TRangeTree1DNode<TKey>;
    function extract(const key : TKey) : TRangeTree1DNode<TKey>;
    function find(const key : TKey): TRangeTree1DNode<TKey>;

    public
    constructor create(const compare_ : TComparison<TKey>);
    procedure Build(var ListOfKeys : TList<TKey>);
    procedure free;
    function insert(const key : TKey) : Boolean;
    function delete(const key : TKey) : Boolean;
    property Count : integer read FCount;
    function isAnyInRange(const key1, key2 : TKey) : Boolean;
    function HowManyInRange(const key1, key2 : TKey) : Integer;
    function getDictOfMembersInRange(const key1, key2 : TKey) : TDictionary<TKey,Boolean>;
    function getSortedListOfMembersInRange(const key1, key2 : TKey) : TList<TKey>;
end;

//// Forward declaration
//procedure BuildRangeTreeDynamicAndQuery;
//procedure BuildRangeTreeStaticAndQuery;

implementation

const alpha = 0.2;

// Begin define methods of TRangeTree1DNode
constructor TRangeTree1DNode<TKey>.create(const compare_ : TComparison<TKey>);
begin
  inherited create;
  compare := compare_;
end;

procedure TRangeTree1DNode<TKey>.initNode(const key_: TKey; const parent_: TRangeTree1DNode<TKey>);
begin
  key        := key_;
  right      := nil;
  left       := nil;
  parent     := parent_;
  isLeaf     := TRUE;
  size       := 1;
  size_left  := 0;
  size_right := 0;
end;

function TRangeTree1DNode<TKey>.isBalanced : Boolean;
{self assumed not a leaf}
var alphaSize : Single;
begin
  alphaSize := alpha*size;
  if (size_left < alphaSize) OR (size_right < alphaSize) then RESULT := FALSE
  else                                                        RESULT := TRUE;
end;

procedure TRangeTree1DNode<TKey>.Balance(var pointerToRoot : TRangeTree1DNode<TKey>);
{reuses old nodes}
var ListOfLeafNodes,
    ListOfNoLeafNodes : TList<TRangeTree1DNode<TKey>>;
    newNode           : TRangeTree1DNode<TKey>;
begin
  ListOfLeafNodes   := TList<TRangeTree1DNode<TKey>>.Create;
  ListOfNoLeafNodes := TList<TRangeTree1DNode<TKey>>.Create;

  newNode := self;

  if Assigned(newNode.parent) then
  begin
    if newNode.isLeftChild then
      newNode.parent.left  := newNode
    else // then newNode is a rightChild
      newNode.parent.right := newNode;
  end
  else pointerToRoot := NewNode;

  self.ExtractSubTreeNodes(ListOfLeafNodes,ListOfNoLeafNodes);
  // last member of ListOfNoLeafNodes is self so we exclude it from reusable nodes
  ListOfNoLeafNodes.delete(ListOfNoLeafNodes.Count-1);

  newNode.splitNode(0,ListOfLeafNodes.Count-1,ListOfLeafNodes,ListOfNoLeafNodes);
  ListOfLeafNodes.Free;
  ListOfNoLeafNodes.Free;
end;

procedure TRangeTree1DNode<TKey>.ExtractSubTreeNodes(var ListOfLeafs, ListOfNoLeafs : TList<TRangeTree1DNode<TKey>>);
begin
  if isLeaf then
    ListOfLeafs.Add(Self)
  else
  begin
    Self.left.ExtractSubTreeNodes(ListOfLeafs, ListOfNoLeafs);
    Self.right.ExtractSubTreeNodes(ListOfLeafs, ListOfNoLeafs);
    ListOfNoLeafs.Add(Self);
  end;
end;

procedure TRangeTree1DNode<TKey>.SplitNode(const idxStart, idxEnd : Integer; const SortedListOfLeafNodes : TList<TRangeTree1DNode<TKey>>; var ListOfNoLeafNodes : TList<TRangeTree1DNode<TKey>>);
var idxEndLeft, n, no2 : Integer;
begin
  n := idxEnd-idxStart;
  if n = 0 then
  begin  // key has been assigned already
    size       := 1;
    size_left  := 0;
    size_right := 0;
    isLeaf     := TRUE;
  end
  else
  begin
    no2 := Trunc(0.5*n);
    idxEndLeft := idxStart + no2;
    // revise CurrentNode
    key        := SortedListOfLeafNodes[idxEndLeft].key;
    size       := n+1;
    size_left  := idxEndLeft-idxStart+1;
    size_right := size-size_left;
    isLeaf     := FALSE;
    // we reuse SortedList[idxStart] in left is a leaf
    if size_left = 1 then
      left := SortedListOfLeafNodes[idxStart]
    else   // reuse last entry of ListOfNoLeafNodes
    begin
      left := ListOfNoLeafNodes[ListOfNoLeafNodes.Count-1];
      ListOfNoLeafNodes.delete(ListOfNoLeafNodes.Count-1);
    end;
    left.parent      := self;
    left.isLeftChild := TRUE;
    left.SplitNode(idxStart,idxEndLeft,SortedListOfLeafNodes,ListOfNoLeafNodes);

    // we reuse SortedList[idxEndLeft+1] in right is a leaf
    if size_right = 1 then
      right := SortedListOfLeafNodes[idxEndLeft+1]
    else
    begin
      right := ListOfNoLeafNodes[ListOfNoLeafNodes.Count-1];
      ListOfNoLeafNodes.delete(ListOfNoLeafNodes.Count-1);
    end;
    right.parent      := self;
    right.isLeftChild := FALSE;
    right.SplitNode(idxEndLeft+1,idxEnd,SortedListOfLeafNodes,ListOfNoLeafNodes);
  end;
end;

procedure TRangeTree1DNode<TKey>.SplitNode(const idxStart, idxEnd : Integer; const SortedList : TList<TKey>);
var idxEndLeft, n, no2 : Integer;
    leafKey            : TKey;
begin
  n := idxEnd-idxStart;
  if n = 0 then
  begin
    leafkey    := SortedList[idxStart];
    key        := leafkey;
    size       := 1;
    size_left  := 0;
    size_right := 0;
    isLeaf     := TRUE;
  end
  else
  begin
    no2 := Trunc(0.5*n);
    idxEndLeft := idxStart + no2;
    // revise CurrentNode
    key        := SortedList[idxEndLeft];
    size       := n+1;
    size_left  := idxEndLeft-idxStart+1;
    size_right := size-size_left;
    isLeaf     := FALSE;
    // Create New Left Node
    left             := TRangeTree1DNode<TKey>.create(compare);
    left.parent      := self;
    left.isLeftChild := TRUE;
    left.SplitNode(idxStart,idxEndLeft,SortedList);
    // Create New Left Node
    right := TRangeTree1DNode<TKey>.create(compare);
    right.parent := self;
    right.isLeftChild := FALSE;
    right.SplitNode(idxEndLeft+1,idxEnd,SortedList);
  end;
end;

procedure TRangeTree1DNode<TKey>.UpdateSizesUpToTheRoot(var HighestInbalancedNode : TRangeTree1DNode<TKey>);
{self assumed balanced (because it is a leaf), balance of the sequence of parents up to the root
 is revised and Highest Inbalanced parent is output}
var node : TRangeTree1DNode<TKey>;
begin
  HighestInbalancedNode := nil;
  node := self;
  while Assigned(node) do
  begin
    if Assigned(node.parent) then
    begin
      Dec(node.parent.size);
      if node.isLeftChild then Dec(node.parent.size_left)
      else                     Dec(node.parent.size_right);
      // check balance
      if NOT node.parent.isBalanced then
        HighestInbalancedNode := node.parent;
    end;
    // update
    node := node.parent;
  end;
end;

function TRangeTree1DNode<TKey>.find(const key : TKey) : TRangeTree1DNode<TKey>;
(* returns the node containing the key in calling Node's subtree or nil if not found *)
var anInteger : Integer;
begin
  anInteger := compare(Self.key,key);
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

procedure TRangeTree1DNode<TKey>.insert(var node : TRangeTree1DNode<TKey>);
(* inserts input node into the subtree rooted as calling node,
   after this insert the tree needs a balance check from nodes up to root *)
var aInteger : Integer;
    tmpKey   : TKey;
    newNode  : TRangeTree1DNode<TKey>;
begin
  if NOT Assigned(node) then Exit;

  aInteger := Self.compare(Self.key,node.key);

  if isLeaf then
  begin
    Inc(size);  Inc(size_left);  Inc(size_right);
    isLeaf := FALSE;
    if aInteger = 1 then
    begin
      node.isLeftChild := TRUE;
      tmpKey           := Self.key;
      Self.key         := node.key; // max of leftSubtree
      Self.left        := node;
      // create a new node to put at the right
      newNode          := TRangeTree1DNode<TKey>.create(compare);
      newNode.initNode(tmpKey,Self);
      newNode.isLeftChild := FALSE;

      Self.right := newNode;
      node.parent := self;
    end
    else if aInteger = -1 then
    begin
      node.isLeftChild := FALSE;
      Self.right       := node;
      // create a new node to put at the left
      newNode          := TRangeTree1DNode<TKey>.create(compare);
      newNode.initNode(key,Self);
      newNode.isLeftChild := TRUE;

      Self.left := newNode;
      node.parent := self;
    end
    else // then node.key = key
      Raise Exception.Create('TRangeTree1DNode.Insert Error : attempt to insert a Key already existing');
  end
  else // naviagate to a leaf
  begin
    Inc(size);
    if aInteger = 1 then
    begin
      self.left.insert(node);
      Inc(size_left);
    end
    else if aInteger = -1 then
    begin
      Inc(size_right);
      self.right.insert(node);
    end
    else // then key1 = key2
      Raise Exception.Create('TRangeTree1DNode.Insert Error : attempt to insert a Key already existing');
  end;
end;

function TRangeTree1DNode<TKey>.getRightMostNodeOfSubtree : TRangeTree1DNode<TKey>;
begin
  if isLeaf then RESULT := self
  else           RESULT := self.right.getRightMostNodeOfSubtree;
end;
// End define methods of TRangeTree1DNode<TKey>

// Begin define methods of TRangeTree1D
constructor TRangeTree1D<TKey>.create(const compare_ : TComparison<TKey>);
begin
  inherited create;
  root                              := nil;
  compare                           := compare_;
  OutputDictOfKeys                  := TDictionary<TKey,Boolean>.create;
  OutputSortedListOfKeys            := TList<TKey>.create;
end;

procedure TRangeTree1D<TKey>.free;
var ListOfLeafNodes,
    ListOfNoLeafNodes : TList<TRangeTree1DNode<TKey>>;
    i                 : Integer;
begin
  OutputSortedListOfKeys.Free;
  OutputDictOfKeys.Free;
  if Assigned(root) then
  begin
    ListOfLeafNodes   := TList<TRangeTree1DNode<TKey>>.create;
    ListOfNoLeafNodes := TList<TRangeTree1DNode<TKey>>.create;
    root.ExtractSubTreeNodes(ListOfLeafNodes,ListOfNoLeafNodes);
    // free all Nodes
    for i := 0 to ListOfLeafNodes.Count-1 do
      ListOfLeafNodes[i].free;
    ListOfLeafNodes.Free;
    for i := 0 to ListOfNoLeafNodes.Count-1 do
      ListOfNoLeafNodes[i].free;
    ListOfNoLeafNodes.Free;
  end;
  inherited free;
end;

procedure TRangeTree1D<TKey>.Build(var ListOfKeys : TList<TKey>);
var compareFun : IComparer<TKey>;
begin
  compareFun := TComparer<TKey>.Construct(compare);
  ListOfKeys.Sort(compareFun);

  root := TRangeTree1DNode<TKey>.Create(compare);
  root.splitNode(0,ListOfKeys.Count-1,ListOfKeys);
  FCount := ListOfKeys.Count;
end;

function TRangeTree1D<TKey>.insert(const key : TKey) : Boolean;
var HighestInbalancedNode, node : TRangeTree1DNode<TKey>;
(* after this operation the Tree should be balanced *)
begin
  node := TRangeTree1DNode<TKey>.create(compare);
  node.initNode(key,nil);
  if NOT Assigned(self.root) then // First Node in the tree
    self.root := node
  else
  begin
    self.root.insert(node);
    // node must be a leaf of the tree and any of the subtrees containing node might be inbalance.
    // It will be enough just to balance one subtree, the one closest to the root
    // in case the leaf is the root FCount must be one and no imbalance is possible
    HighestInbalancedNode := nil;
    while Assigned(node.Parent) do
    begin // move up and check balance (avoid checking balance of a leaf)
      node := node.parent;
      if NOT node.isBalanced then HighestInbalancedNode := node;
    end;
    if Assigned(HighestInbalancedNode) then
      HighestInbalancedNode.Balance(self.root);
  end;
  Inc(FCount);
end;

function TRangeTree1D<TKey>.find(const key : TKey) : TRangeTree1DNode<TKey>;
 (* returns node containing key or nil if it is not there *)
begin
  RESULT := Self.root.find(key);
end;

function TRangeTree1D<TKey>.delete(const key : TKey) : Boolean;
var node : TRangeTree1DNode<TKey>;
begin
  node := extract(key);
  if Assigned(node) then
  begin
    RESULT := TRUE;
    node.Free;
  end
  else {key was not in the DS}
    RESULT := FALSE
end;

function TRangeTree1D<TKey>.extract(const key : TKey) : TRangeTree1DNode<TKey>;
var ParentNode, promotedNode,
    HighestInbalancedNode,
    AffectedNode                      : TRangeTree1DNode<TKey>;
begin
  RESULT := self.root.find(key);
  if Assigned(RESULT) then  {key is in the DS}
  begin
    // There will be two or one nodes with this key (one if we stract max of the tree)
    // One is the leaf (that we want to extract) and the other a no-leaf node (i.e. AffectedNode)
    // whose key will need revision
    AffectedNode := nil;
    while NOT RESULT.isLeaf do
    begin
      AffectedNode := RESULT;
      RESULT       := RESULT.left.find(key);
    end;
    // At this Point RESULT contains the leaf
    if Assigned(RESULT.parent) then
    begin
      // promotedNode will replace ParentNode
      ParentNode := RESULT.parent;
      if RESULT.isLeftChild then promotedNode := ParentNode.right
      else                       promotedNode := ParentNode.left;
      // revise NewParentNode Conections
      if Assigned(ParentNode.Parent) then
      begin
        promotedNode.parent := ParentNode.Parent;
        if ParentNode.isLeftChild then
        begin
          promotedNode.parent.left  := promotedNode;
          promotedNode.isLeftChild  := TRUE;
        end
        else // then ParentNode is a rightChild
        begin
          promotedNode.parent.right := promotedNode;
          promotedNode.isLeftChild  := FALSE;
        end;
      end
      else
      begin
        promotedNode.parent := nil;
        if ParentNode.isLeftChild then promotedNode.isLeftChild  := TRUE
        else                           promotedNode.isLeftChild  := FALSE;

        root := promotedNode;
      end;

      // revise Keys of AffectedNode To newKey -> might happen that AffectedNode = parentNode
      if Assigned(AffectedNode) then
        AffectedNode.key := promotedNode.getRightMostNodeOfSubtree.key;

      ParentNode.Free;

      promotedNode.UpdateSizesUpToTheRoot(HighestInbalancedNode);

      if Assigned(HighestInbalancedNode) then
        HighestInbalancedNode.Balance(root);
    end
    else // then the root is the leaf to extract
      root := nil;

    Dec(FCount);
  end;
end;

function TRangeTree1D<TKey>.getBifurcationNode(const k1,k2 : TKey) : TRangeTree1DNode<TKey>;
{assumed k1<k2}
var node       : TRangeTree1DNode<TKey>;
    int1, int2 : Integer;
begin
  // Find BifurcationNode
  node   := root;
  RESULT := nil;
  while Assigned(node) do
  begin
    int1 := node.compare(k1,node.key);
    if int1 <> 1 then
    begin
      int2 := node.compare(k2,node.key);

      if int2 = 1 then
      begin  RESULT := node;  Exit;  end
      else
        node := node.left;
    end
    else node := node.right;
  end;
end;

function TRangeTree1D<TKey>.isAnyInRange(const key1, key2 : TKey) : Boolean;
var BifurcationNode : TRangeTree1DNode<TKey>;
    k1, k2          : TKey;
begin
  // Saveguard k1 >= k2
  if root.compare(key1,key2) > 0 then
  begin  k1 := key2;  k2 := key1;  end
  else
  begin  k1 := key1;  k2 := key2;  end;

  BifurcationNode := getBifurcationNode(k1,k2);
  RESULT          := Assigned(BifurcationNode);
end;


function TRangeTree1D<TKey>.HowManyInRange(const key1, key2 : TKey) : Integer;
{ Finds |K| with K=(k_i) i=1,..,|K|. Number of keys of the tree satisfying
   k1 < k < k2 : Note input is sorted to satisfy k1<k2 }
var node, BifurcationNode : TRangeTree1DNode<TKey>;
    int1, int2            : Integer;
    k1, k2                : TKey;
begin
  // Saveguard k1 >= k2
  if root.compare(key1,key2) > 0 then
  begin  k1 := key2;  k2 := key1;  end
  else
  begin  k1 := key1;  k2 := key2;  end;

  BifurcationNode := getBifurcationNode(k1,k2);

  if Assigned(BifurcationNode) then
  begin
    if BifurcationNode.isleaf then RESULT := 1
    else
    begin
      RESULT := 0;
      // Track k1 to a leaf count nodes at right subtree when move left
      node := bifurcationNode.left;
      while NOT node.isLeaf do
      begin
        int1 := node.compare(k1,node.key);

        if int1 = 1 then
          node := node.right
        else
        begin
          RESULT  := RESULT + node.size_right;
          node    := node.left;
        end
      end;
      // node at the leaf
      int1 := node.compare(k1,node.key);
      if int1 <> 1 then  RESULT := RESULT + node.size;

      // Track k2 to a leaf count nodes at left subtree when move left
      node := bifurcationNode.right;
      while NOT node.isLeaf do
      begin
        int2 := node.compare(k2,node.key);

        if int2 = 1 then
        begin
          RESULT := RESULT + node.size_left;
          node   := node.right;
        end
        else
          node   := node.left
      end;
      // node at the leaf
      int2 := node.compare(k2,node.key);
      if int2 <> -1 then  RESULT := RESULT + node.size;
    end;
  end
  else RESULT := 0;
end;

procedure TRangeTree1D<TKey>.CollectSubTreeLeafsToDictionary(const node : TRangeTree1DNode<TKey>);
{assumed node is assigned because it is the child of a non-leaf}
begin
  if node.isLeaf then OutputDictOfKeys.Add(node.key,TRUE)
  else
  begin
    CollectSubTreeLeafsToDictionary(node.left);
    CollectSubTreeLeafsToDictionary(node.right);
  end;
end;

procedure TRangeTree1D<TKey>.CollectSortedKeysOfSubtree(const node : TRangeTree1DNode<TKey>);
begin
  if node.isLeaf then OutputSortedListOfKeys.Add(node.key)
  else
  begin
    CollectSortedKeysOfSubtree(node.left);
    CollectSortedKeysOfSubtree(node.right);
  end;
end;

procedure TRangeTree1D<TKey>.CollectSortedKeysGTk1(const node : TRangeTree1DNode<TKey>; const k1 : TKey);
var anInteger : Integer;
begin
  anInteger := node.compare(k1,node.key);

  if node.isLeaf then
  begin
    if anInteger<> 1 then OutputSortedListOfKeys.Add(node.key);
  end
  else
  begin
    if anInteger <> 1 then
    begin
      CollectSortedKeysGTk1(node.left,k1);
      CollectSortedKeysOfSubtree(node.right);
    end
    else CollectSortedKeysGTk1(node.right,k1);
  end;
end;

procedure TRangeTree1D<TKey>.CollectSortedKeysLTk2(const node : TRangeTree1DNode<TKey>; const k2 : TKey);
var anInteger : Integer;
begin
  anInteger := node.compare(k2,node.key);

  if node.isLeaf then
  begin
    if anInteger <> -1 then OutputSortedListOfKeys.Add(node.key);
  end
  else
  begin
    if anInteger <> 1 then
      CollectSortedKeysLTk2(node.left,k2)
    else
    begin
      CollectSortedKeysOfSubtree(node.left);
      CollectSortedKeysLTk2(node.right,k2);
    end
  end;
end;

function TRangeTree1D<TKey>.getDictOfMembersInRange(const key1, key2 : TKey) : TDictionary<TKey,Boolean>;
{ outputs a dictionary with the set K=(k_i) i=1,..,|K|. keys of the tree satisfying
   k1 < k < k2 : Note input is sorted to satisfy k1<k2 }
var node, BifurcationNode : TRangeTree1DNode<TKey>;
    int1, int2            : Integer;
    k1, k2                : TKey;
begin
  // Saveguard k1 >= k2
  if root.compare(key1,key2) > 0 then
  begin  k1 := key2;  k2 := key1;  end
  else
  begin  k1 := key1;  k2 := key2;  end;

  OutputDictOfKeys.Clear;
  RESULT := OutputDictOfKeys;

  BifurcationNode := getBifurcationNode(k1,k2);

  if Assigned(BifurcationNode) then
  begin
    if BifurcationNode.isleaf then RESULT.Add(BifurcationNode.key,TRUE)
    else
    begin
      // Track k1 to a leaf count nodes at right subtree when move left
      node := bifurcationNode.left;
      while NOT node.isLeaf do
      begin
        int1 := node.compare(k1,node.key);

        if int1 = 1 then
          node := node.right
        else
        begin
          CollectSubTreeLeafsToDictionary(node.right);
          node := node.left;
        end
      end;
      // node at the leaf
      int1 := node.compare(k1,node.key);
      if int1 <> 1 then RESULT.Add(node.key,TRUE);

      // Track k2 to a leaf count nodes at left subtree when move left
      node := bifurcationNode.right;
      while NOT node.isLeaf do
      begin
        int2 := node.compare(k2,node.key);

        if int2 = 1 then
        begin
          CollectSubTreeLeafsToDictionary(node.left);
          node   := node.right;
        end
        else
          node   := node.left
      end;
      // node at the leaf
      int2 := node.compare(k2,node.key);
      if int2 <> -1 then RESULT.Add(node.key,TRUE);
    end;
  end
end;

function TRangeTree1D<TKey>.getSortedListOfMembersInRange(const key1, key2 : TKey) : TList<TKey>;
{ outputs the sorted list of keys satisfying k1 < k < k2 : Note input is sorted to satisfy k1<k2 }
var node, BifurcationNode : TRangeTree1DNode<TKey>;
    int1, int2            : Integer;
    k1, k2                : TKey;
begin
  OutputSortedListOfKeys.Clear;
  RESULT := OutputSortedListOfKeys;

  if Assigned(root) then
  begin
    // Saveguard k1 >= k2
    if root.compare(key1,key2) > 0 then
    begin  k1 := key2;  k2 := key1;  end
    else
    begin  k1 := key1;  k2 := key2;  end;

    BifurcationNode := getBifurcationNode(k1,k2);
    if Assigned(BifurcationNode) then
    begin
      if BifurcationNode.isLeaf then
      begin
        CollectSortedKeysGTk1(BifurcationNode,k1);
        CollectSortedKeysLTk2(BifurcationNode,k2);
      end
      else
      begin
        CollectSortedKeysGTk1(BifurcationNode.left,k1);
        CollectSortedKeysLTk2(BifurcationNode.right,k2);
      end;
    end;
  end;
end;
//End define netods of TRangeTree1D


// HOW TO USE EXAMPLES  -> using TKey = TEdge2D a record representing an edge in 2D.
// the queries will regard edges with length in a given 1D interval

 type TSPt2D = record
   x, y : Single;
 end;

type TEdge2D = record
  FirstPoint   : TSPt2D;
  SecondPoint  : TSPt2D;
  Length       : Single;
  EdgeNo       : Integer;
end;


function getRandomListOfEdges(const NEdges : Integer) : TList<TEdge2D>;
{ generate edges with EndPoints randomly distributed in [0,1]x[0,1] }
var edge : TEdge2D;
    i    : Integer;
begin
  RESULT := TList<TEdge2D>.create;
  with edge do
  begin
    for i := 0 to NEdges-1 do
    begin
      FirstPoint.x  := random;
      FirstPoint.y  := random;
      SecondPoint.x := random;
      SecondPoint.y := random;
      Length        := sqrt( sqr(SecondPoint.x - FirstPoint.x) +
                             sqr(SecondPoint.y - FirstPoint.y) );
      EdgeNo        := i;

      RESULT.Add(edge);
    end;
  end;
end;


procedure BuildRangeTreeDynamicAndQuery;
var ListOfEdges2D, L : TList<TEdge2D>;
    RT1D             : TRangeTree1D<TEdge2D>;
    i                : Integer;
    edge, k1, k2     : TEdge2D;
    compareByLength  : TComparison<TEdge2D>;
begin
  // get random List with with 1000 edges, with ends in [0,1]x[0,1]
  ListOfEdges2D := getRandomListOfEdges(1000);
  // Define Comparison function on edges length s.t. no equality is possible between members on ÁListOfEdges2D
  compareByLength := function(const left, right: TEdge2D) : Integer
                     begin
                       RESULT := TComparer<Single>.Default.Compare(left.length,right.length);
                       if RESULT = 0 then
                         RESULT := TComparer<Integer>.Default.Compare(left.EdgeNo,right.EdgeNo);
                     end;

  // create 1DRangeTree DS and build it with the ListOfEdges dynamically
  RT1D := TRangeTree1D<TEdge2D>.create(compareByLength);
  for i := 0 to ListOfEdges2D.Count-1 do
  begin
    edge := ListOfEdges2D[i];
    RT1D.insert(edge);
  end;

  // look for edges with length in the range [0.5, sqrt(2)]
  k1.Length := 0.5;           k1.EdgeNo := -1;
  k2.Length := sqrt(2);       k2.EdgeNo := High(Integer); // for closed range

  L := RT1D.getSortedListOfMembersInRange(k1,k2);

  // Eliminate Those edges from RT1D
  for i := 0 to L.Count-1 do
  begin
    edge := L[i];
    RT1D.delete(edge);
  end;

  // do a new query for edges with length in the interval (0.0, 0.5)  // that should be all remaining
  k1.Length := 0.0;            k1.EdgeNo := High(Integer);
  k2.Length := sqrt(2);        k2.EdgeNo := -1;           // for open range

  L := RT1D.getSortedListOfMembersInRange(k1,k2);  // note L is just a pointer to a private field of RT1D
                                                   // dont do L.Free as it will be done in RT1D.free;
  // inspect extracted edges
  for i := 0 to L.Count-1 do
  begin
    edge := L[i];
    RT1D.delete(edge);
  end;

  // Free Memory
  RT1D.Free;
  ListOfEdges2D.Free;   // in case Tkey is a class that requires freeing )(ot a record as now),
                        // then the members of the List must be freed before freeing the container
end;

procedure BuildRangeTreeStaticAndQuery;
var RT1D            : TRangeTree1D<TEdge2D>;
    ListOfEdges2D   : TLIst<TEdge2D>;
    compareByLength : TComparison<TEdge2D>;
    k1, k2, edge    : TEdge2D;
    D               : TDictionary<TEdge2D,Boolean>;
    B               : Boolean;
    n1, i           : Integer;
    ListOfIsActive  : TList<Boolean>;
begin
  // generate List of 1000 Random Edges in [0,1]x[0,1]   -> Container for  TKeys = TEdge2D
  ListOfEdges2D := getRandomListOfEdges(1000);

  // Define Comparison function on edges length s.t. no equality is possible between members on ÁListOfEdges2D
  compareByLength := function(const left, right: TEdge2D) : Integer
                     begin
                       RESULT := TComparer<Single>.Default.Compare(left.length,right.length);
                       if RESULT = 0 then
                         RESULT := TComparer<Integer>.Default.Compare(left.EdgeNo,right.EdgeNo);
                     end;

  // create 1DRangeTree DS and build it with the ListOfEdges statically
  RT1D := TRangeTree1D<TEdge2D>.create(compareByLength);
  RT1D.Build(ListOfEdges2D);

  // is Any Member in the range of Lengths [1,sqrt(2)]
  k1.Length := 1;           k1.EdgeNo := -1;
  k2.Length := sqrt(2);     k2.EdgeNo := High(Integer); // for closed range

  B  := RT1D.isAnyInRange(k1,k2);
  // How many do we have in [k1,k2]
  n1 := RT1D.HowManyInRange(k1,k2);

  // get Dictionary with edges with length between 0.45 and 0.55
  k1.Length := 0.45;           k1.EdgeNo := -1;
  k2.Length := 0.55;           k2.EdgeNo := High(Integer); // for closed range

  D  := RT1D.getDictOfMembersInRange(k1,k2);  // note D is just a pointer to a private field of RT1D
                                              // dont do D.Free as it will be done in RT1D.free;

  // make a lIstofIsActive Associated to ListOfEdges2D
  ListOfIsActive := TList<Boolean>.create;
  for i := 0 to ListOfEdges2D.Count-1 do
  begin
    edge := ListOfEdges2D[i];

    if D.ContainsKey(edge) then  ListOfIsActive.Add(TRUE)
    else                         ListOfIsActive.Add(FALSE);
  end;
  // Free Memory
  RT1D.Free;
  ListOfIsActive.Free;
  ListOfEdges2D.free     // records dont have to be freed, when using as TKey a class you
                         // should free the key  before freeing the container
end;




end.


