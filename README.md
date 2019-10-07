# 2DRangeTree

Delphi implementation of generic 2D range search tree -> (see TRangeTree2D<TKey> in RangeTree2D_u.pas). Based on the ideas of session 3 of the course 6.851 MIT OpenWare

https://ocw.mit.edu/courses/electrical-engineering-and-computer-science/6-851-advanced-data-structures-spring-2012/

OVERVIEW: The Data structure (DS) is designed for solving the problem of given a set S of 2D points find the subset Sm that lies inside an axis aligned box [a1,a2]x[b1,b2]. Fast report queries O(|Sm| + log |S|) are expected. The DS is validated in RangeTree3DForm_u.pas, and an executable of the project is available under the name
                  
                                                  RangeTree2DForm_prjct
                                            
Further descriptions can be found in the corresponding units.

CONTENTS: RangeTree2DForm_u.pas, RangeTree2DForm_u.dfm, RangeTree2D_u.pas, QuarterRangeSearch_u.pas
