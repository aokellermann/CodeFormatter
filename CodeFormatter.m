(* ::Package:: *)

(* Mathematica Package *)

(* Created by the Wolfram Workbench Mar 9, 2012 *)

BeginPackage["CodeFormatter`"]
(* Exported symbols added here with SymbolName::usage *) 

Begin["`Private`"]
(* Implementation of the package *)


ClearAll[preprocess];
preprocess[boxes_] :=
    boxes //.
      {RowBox[{("\t" | "\n") .., expr___}] :> expr} //.
     {
		s_String /; StringMatchQ[s, Whitespace] :> Sequence[],
        RowBox[{r_RowBox}] :> r
     };


ClearAll[$blocks, blockQ];
$blocks = {
   ModuleBlock, BlockBlock, WithBlock, SetBlock, SetDelayedBlock, 
   CompoundExpressionBlock, GeneralHeadBlock,
   HeadBlock, ElemBlock, GeneralBlock, ParenBlock, ListBlock, 
   PatternBlock, PatternTestBlock, FunctionBlock,
   AlternativesBlock, StatementBlock, NewlineBlock, MultilineBlock, 
   FinalTabBlock, GeneralSplitHeadBlock,
   (*FractionBlock,*) EmptySymbol, SemicolonSeparatedGeneralBlock, 
   SuppressedCompoundExpressionBlock,
   (* StyleBlock,*) GeneralBoxBlock, TagSetDelayedBlock, TagSetBlock, 
   ApplyBlock, ApplyLevel1Block,
   RuleBlock, RuleDelayedBlock, MapBlock, FunApplyBlock, IfBlock, 
   IfBlock, IfCommentBlock(*, TopLevelStatementBlock *)
   };
   
blockQ[block_Symbol] :=
    MemberQ[$blocks, block];


ClearAll[$supportedBoxes, boxQ, boxNArgs]
$supportedBoxes = {StyleBox, TagBox, FractionBox (*,DynamicModuleBox*)};
boxQ[box_Symbol] :=
    MemberQ[$supportedBoxes, box];


boxNArgs[_StyleBox] = 1;
boxNArgs[_FractionBox] = 2;
boxNArgs[_TagBox] = 1;
(*boxNArgs[RowBox[{elems___}]]:=Length[{elems}]; *)

(*boxNArgs[_DynamicModuleBox]=2;*)

boxNArgs[_] :=
    Throw[$Failed, boxNArgs];


ClearAll[strsymQ];
strsymQ[s_String] :=
    StringMatchQ[ s, (LetterCharacter | "$") ~~ ((WordCharacter | "$" | "`") ...)];
 
ClearAll[preformat];
(* SetAttributes[preformat,HoldAll]; *)

preformat[expr : (box_?boxQ[args___])] :=
    With[ {n = boxNArgs[expr]},
        GeneralBoxBlock[box,
         n,
         Sequence @@ Map[preformat, Take[{args}, n]],
         Sequence @@ Drop[{args}, n]
         ]
    ];



preformat[
   RowBox[{head : ("Module" | "Block" | "With"), "[", 
     RowBox[{decl_RowBox, ",", body_RowBox}], 
     "]"}]] :=
    (head /. {"Module" -> ModuleBlock, 
        "Block" -> BlockBlock, "With" -> WithBlock})[preformat@decl, 
     preformat@body];

preformat[
   RowBox[{lhs_, assignment : (":=" | "="), 
     rhs_}]] :=
    (assignment /. {":=" :> SetDelayedBlock, 
        "=" :> SetBlock})[preformat[lhs], preformat[rhs]];
preformat[
   RowBox[{s_String?strsymQ, "/:", lhs_, assignment : (":=" | "="), 
     rhs_}]] :=
    (assignment /. {":=" :> TagSetDelayedBlock, 
        "=" :> TagSetBlock})[s, preformat[lhs], preformat[rhs]];

preformat[RowBox[{fn_, "@@", expr_}]] :=
    ApplyBlock[preformat@fn, preformat@expr];

preformat[RowBox[{fn_, "@@@", expr_}]] :=
    ApplyLevel1Block[preformat@fn, preformat@expr];

preformat[RowBox[{fn_, "/@", expr_}]] :=
    MapBlock[preformat@fn, preformat@expr];

preformat[RowBox[{fn_, "@", expr_}]] :=
    FunApplyBlock[preformat@fn, preformat@expr];

preformat[RowBox[{lhs_, "\[Rule]", rhs_}]] :=
    RuleBlock[preformat@lhs, preformat@rhs];

preformat[RowBox[{lhs_, "\[RuleDelayed]", rhs_}]] :=
    RuleDelayedBlock[preformat@lhs, preformat@rhs];



preformat[RowBox[{p_, "?", test_}]] :=
    PatternTestBlock[preformat[p], preformat[test]];
preformat[RowBox[{body_, "&"}]] :=
    FunctionBlock[preformat[body]];
preformat[RowBox[alts : {PatternSequence[_, "|"] .., _}]] :=
    AlternativesBlock @@ Map[preformat, alts[[1 ;; -1 ;; 2]]];
preformat[
   RowBox[{"If", "[", RowBox[{cond_, ",", iftrue_, ",", iffalse_}], 
     "]"}]] :=
    IfBlock[preformat@cond, preformat@iftrue, preformat@iffalse];



preformat[RowBox[elems : {PatternSequence[_, ";"] ..}]] :=
    SuppressedCompoundExpressionBlock @@ Map[
      Map[preformat, StatementBlock @@ DeleteCases[#, ";"]] &,
      Split[elems, # =!= ";" &]];

preformat[RowBox[elems : {PatternSequence[_, ";"] .., _}]] :=
    CompoundExpressionBlock @@ Map[
      Map[preformat, StatementBlock @@ DeleteCases[#, ";"]] &,
      Split[elems, # =!= ";" &]];

preformat[RowBox[elems_List]] /; ! FreeQ[elems, "\n" | "\t", 1] :=
    preformat[RowBox[DeleteCases[elems, "\n" | "\t"]]];
preformat[RowBox[{"{", elems___, "}"}]] :=
    ListBlock @@ Map[preformat, {elems}];
preformat[RowBox[{"(", elems__, ")"}]] :=
    ParenBlock @@ Map[preformat, {elems}];
preformat[RowBox[{p_String?strsymQ, ":", elem_}]] :=
    PatternBlock[p, preformat@elem];
preformat[RowBox[{p_String?strsymQ, ":", elem_, ":", def_}]] :=
    PatternBlock[p, preformat@elem, preformat@def];

preformat[RowBox[{head_, "[", elems___, "]"}]] :=
    GeneralHeadBlock[preformat@head, 
     Sequence @@ Map[preformat, {elems}]];
preformat[RowBox[elems : {PatternSequence[_, ","] .., _}]] :=
    SemicolonSeparatedGeneralBlock @@ 
     Map[preformat, DeleteCases[elems, ","]];
preformat[RowBox[elems_List]] :=
    GeneralBlock @@ Map[preformat, elems];
preformat[block_?blockQ[args_]] :=
    block @@ Map[preformat, {args}];

(*
preformat[FractionBox[n_,d_]]:=
FractionBlock[preformat@n,preformat@d];
*)

preformat[a_?AtomQ] :=
    a;

preformat[expr_] :=
    Throw[{$Failed, expr}, preformat];





ClearAll[$combineTopLevelStatements];
$combineTopLevelStatements = True;


ClearAll[processPreformatted];
processPreformatted[GeneralBlock[blocks__]] :=
    GeneralBlock[Sequence @@ Map[processPreformatted, {blocks}]];
processPreformatted[
   preformatted : SemicolonSeparatedGeneralBlock[elems___]] :=
    GeneralBoxBlock[RowBox[{##}] &, Length[{elems}], elems];
processPreformatted[arg_] :=
    arg;




ClearAll[tabify];
tabify[expr_] /; ! FreeQ[expr, TabBlock[_]] :=
    tabify[expr //. TabBlock[sub_] :> TabBlock[sub, True]];

tabify[(block_?blockQ /; ! MemberQ[{TabBlock, FinalTabBlock}, block])[
    elems___]] :=
    block @@ Map[tabify, {elems}];

tabify[TabBlock[FinalTabBlock[el_, flag_], tflag_]] :=
    FinalTabBlock[tabify[TabBlock[el, tflag]], flag];

(*
tabify[TabBlock[(head:ModuleBlock|BlockBlock|WithBlock)[vars_,body_\
],_]]:=
FinalTabBlock[head[vars,tabify@TabBlock[body,True]],False];
*)

tabify[TabBlock[NewlineBlock[el_, flag_], _]] :=
    tabify[NewlineBlock[TabBlock[el, True], flag]];

tabify[TabBlock[t_TabBlock, flag_]] :=
    tabify[TabBlock[tabify[t], flag]];

tabify[TabBlock[GeneralBoxBlock[box_, n_, args___], flag_]] :=
    GeneralBoxBlock[box, n,
     Sequence @@ Map[tabify[TabBlock[#, flag]] &, Take[{args}, n]],
     Sequence @@ Drop[{args}, n]
     ];

tabify[TabBlock[(block_?blockQ /; ! MemberQ[{TabBlock}, block])[
     elems___], flag_]] :=
    FinalTabBlock[
     block @@ Map[tabify@TabBlock[#, False] &, {elems}],
     flag];

tabify[TabBlock[a_?AtomQ, flag_]] :=
    FinalTabBlock[a, flag];

tabify[expr_] :=
    expr;



ClearAll[isNextNewline];
isNextNewline[_NewlineBlock] :=
    True;
isNextNewline[block : (_?blockQ | TabBlock)[fst_, ___]] :=
    isNextNewline[fst];
isNextNewline[_] :=
    False;





ClearAll[postformat];
postformat[GeneralBlock[elems__]] :=
    RowBox[postformat /@ {elems}];
(* Note: BlankSequence in body intentional, to allow for closing \
element *)
postformat[(head : ModuleBlock | BlockBlock | WithBlock)[
    vars_, body__]] :=
    RowBox[{
      head /. {ModuleBlock -> "Module", BlockBlock -> "Block", 
        WithBlock -> "With"},
      "[",
      RowBox[{
        postformat[vars], ",", 
        Sequence @@ (Map[postformat, {body}] //. 
           EmptySymbol[] :> Sequence[])
        }],
      "]"}
     ];
postformat[(head : 
      SetBlock | SetDelayedBlock | RuleBlock | RuleDelayedBlock)[lhs_,
     rhs_]] :=
    RowBox[{
      postformat@lhs, head /. {
        SetBlock -> "=", SetDelayedBlock -> ":=", 
        RuleBlock -> "\[Rule]", RuleDelayedBlock -> "\[RuleDelayed]"
        },
      postformat@rhs
      }];
postformat[(head : TagSetBlock | TagSetDelayedBlock)[s_, lhs_, 
    rhs_]] :=
    RowBox[{postformat@s, "/:", postformat@lhs, 
      head /. {TagSetBlock -> "=", TagSetDelayedBlock -> ":="}, 
      postformat@rhs}];
postformat[(head : 
      MapBlock | ApplyLevel1Block | ApplyBlock | FunApplyBlock)[f_, 
    expr_]] :=
    RowBox[{
      postformat@f, head /. {
        ApplyBlock -> "@@", ApplyLevel1Block -> "@@@", MapBlock -> "/@",
         FunApplyBlock -> "@"
        },
      postformat@expr
      }];
postformat[AlternativesBlock[elems__]] :=
    RowBox[Riffle[postformat /@ {elems}, "|"]];
postformat[FunctionBlock[body_]] :=
    RowBox[{postformat@body, "&"}];
postformat[PatternTestBlock[p_, body_]] :=
    RowBox[{postformat@p, "?", postformat@body}];
postformat[CompoundExpressionBlock[elems__]] :=
    RowBox[Riffle[postformat /@ {elems}, ";"]];

(* Note: fragile! *)

postformat[
    IfBlock[if_, cond_, iftrue_, ifcomment_, iffalse_, 
     closingElement_]] /; ! FreeQ[ifcomment, IfCommentBlock] :=
    RowBox[{postformat@if, "[",
      RowBox[{postformat@cond, ",", postformat@iftrue, ",", 
        postformat@ifcomment, postformat@iffalse, 
        postformat@closingElement //. EmptySymbol[] :> Sequence[]}],
      "]"}];

postformat[IfBlock[cond_, iftrue_, iffalse_]] :=
    RowBox[{"If", "[",
      RowBox[{postformat@cond, ",", postformat@iftrue, ",", 
        postformat@iffalse}],
      "]"}];

postformat[IfCommentBlock[]] :=
    RowBox[{"(*", " ", "else", " ", "*)"}];

postformat[SuppressedCompoundExpressionBlock[elems__]] :=
    RowBox[Append[Riffle[postformat /@ {elems}, ";"], ";"]];

postformat[ListBlock[elems___]] :=
    RowBox[{"{", 
      Sequence @@ (Map[postformat, {elems}] //. 
         EmptySymbol[] :> Sequence[]), "}"}];
postformat[ParenBlock[elems__]] :=
    RowBox[{"(", 
      Sequence @@ (Map[postformat, {elems}] //. 
         EmptySymbol[] :> Sequence[]), ")"}];
postformat[PatternBlock[name_, pt_]] :=
    RowBox[{postformat@name, ":", postformat@pt}];
postformat[PatternBlock[name_, pt_, def_]] :=
    RowBox[{postformat@name, ":", postformat@pt, ":", postformat@def}];
postformat[GeneralHeadBlock[head_, elems___]] :=
    RowBox[{postformat@head, "[", 
      Sequence @@ Riffle[postformat /@ {elems}, ","], "]"}];

postformat[GeneralSplitHeadBlock[head_, elems___, Tabbed[]]] :=
    RowBox[{postformat@head, "[", 
      Sequence @@ Riffle[postformat /@ {elems}, ","],(*"\n","\t", *)
      "]"}];

postformat[GeneralSplitHeadBlock[head_, elems___]] :=
    With[ {formattedElems = postformat /@ {elems}},
        RowBox[{postformat@head, "[",
          Sequence @@ Riffle[Most[formattedElems], ","],
          Last[formattedElems] //. EmptySymbol[] :> Sequence[], "]"}]
    ];
(*
postformat[FractionBlock[n_,d_]]:=
FractionBox[postformat@n,postformat@d];
*)
postformat[GeneralBlock[elems___]] :=
    RowBox[Riffle[postformat /@ {elems}, ","]];
postformat[StatementBlock[elem_]] :=
    postformat[elem];
postformat[MultilineBlock[elems__]] :=
    RowBox[Riffle[postformat /@ {elems}, "\n"]];

(*
postformat[NewlineBlock[elem_,_]]:=
RowBox[{"\n",postformat@elem}];
*)


postformat[NewlineBlock[elem_?isNextNewline, False]] :=
    postformat@elem;


postformat[SemicolonSeparatedGeneralBlock[elems__]] :=
    RowBox[Riffle[postformat /@ {elems}, ","]];

postformat[NewlineBlock[elem_, _]] :=
    RowBox[{"\n", postformat@elem}];

(*
postformat[block_?blockQ[elems__NewlineBlock,last_]]:=
postformat[block[MultilineBlock[Sequence@@({elems}[[All,1]]),last]]];
*)

postformat[GeneralBoxBlock[box_, n_, args___]] :=
    box[
     Sequence @@ Map[postformat, Take[{args}, n]],
     Sequence @@ Drop[{args}, n]
     ];



(*
postformat[FinalTabBlock[GeneralSplitHeadBlock[elems___],True]]/;!\
MatchQ[{elems},{___,Tabbed[]}]:=
postformat[FinalTabBlock[GeneralSplitHeadBlock[elems,Tabbed[]],True]];\

*)

postformat[FinalTabBlock[expr_, True]] :=
    RowBox[{"\t", postformat@expr}];
postformat[FinalTabBlock[expr_, False]] :=
    postformat@expr;

postformat[EmptySymbol[]] :=
    EmptySymbol[];

postformat[a_?AtomQ] :=
    a;


postformat[arg_] :=
    Throw[{$Failed, arg}, postformat];






Clear[maxLen];
maxLen[boxes : (_RowBox | _?boxQ[___])] :=
    Max@Replace[
      Split[
       Append[Cases[boxes, s_String, Infinity], "\n"], # =!= "\n" &],
      {s___, ("\t" | " ") ..., "\n"} :> 
       Total[{s} /. {"\t" -> 4, ss_ :> StringLength[ss]}],
      {1}];


maxLen[expr_] :=
    With[ {boxes = postformat@expr},
        maxLen[boxes] /; MatchQ[boxes, (_RowBox | _?boxQ[___])]
    ];

maxLen[expr_] :=
    Throw[{$Failed, expr}, maxLen];
  
  
  
  
  
ClearAll[$closingElementRules];
$closingElementRules = {
   "Bracket" :> $alignClosingBracket ,
   "List" :> $alignClosingList,
   "Parenthesis" :> $alignClosingParen, 
   "ScopingBracket" :> $alignClosingScopingBracket,
   "IfBracket" :> $alignClosingIfBracket
   };  



ClearAll[closingElement];
closingElement[type_String] :=
    Unevaluated[If[ TrueQ@type,
                    NewlineBlock[EmptySymbol[], True],
                    (* else *)
                    EmptySymbol[]
                ]] /. $closingElementRules;
     
     
     

$maxLineLength = 70;
$alignClosingBracket = True;
$alignClosingList = True;
$alignClosingParen = True;
$alwaysBreakCompoundExpressions = False;
$alignClosingScopingBracket = True;
$alignClosingIfBracket = True;  



ClearAll[needSplitQ];
needSplitQ[expr_, currentTab_] :=
    maxLen[expr] > $maxLineLength - currentTab;
 
 
 
 
 
 ClearAll[format];
(*SetAttributes[format,HoldFirst]; *)
format[expr_] :=
    format[expr, 0];

format[expr : GeneralBoxBlock[box_, n_, args___], currentTab_] :=
    With[ {splitQ = needSplitQ[expr, currentTab]},
        GeneralBoxBlock[box, n,
         If[ n > 0,
             format[First@{args}, currentTab],
             Sequence @@ {}
         ],
         Sequence @@ 
          Map[format[If[ splitQ,
                         NewlineBlock[#, False],
                         #
                     ], currentTab] &, 
           Take[{args}, {2, n}]],
         Sequence @@ Drop[{args}, n]
         ]
    ];

format[TabBlock[expr_], currentTab_] :=
    TabBlock[format[expr, currentTab + 4]];

format[NewlineBlock[expr_, flag_], currentTab_] :=
    NewlineBlock[format[expr, currentTab], flag];

format[block_?blockQ[left___, 
    sc : (_ModuleBlock | _BlockBlock | _WithBlock), right___], 
   currentTab_] :=
    format[block[left, NewlineBlock[sc, True], right], currentTab];

format[(head : ModuleBlock | BlockBlock | WithBlock)[vars_, body_], 
   currentTab_] :=
    head[
     format[vars, currentTab],
     format[NewlineBlock[TabBlock[body], False], currentTab],
     closingElement["ScopingBracket"]
     ];

format[(head : SetDelayedBlock)[lhs_, rhs_], currentTab_] :=
    head[
     format[lhs, currentTab],
     format[NewlineBlock[TabBlock[rhs], False], currentTab]
     ];

format[TagSetDelayedBlock[s_, lhs_, rhs_], currentTab_] :=
    TagSetDelayedBlock[
     format[s, currentTab],
     format[lhs, currentTab],
     format[NewlineBlock[TabBlock[rhs], False], currentTab]
     ];

format[expr : (head : (SetBlock | RuleBlock | RuleDelayedBlock))[lhs_,
       rhs_], currentTab_] /; needSplitQ[expr, currentTab] :=
    head[
     format[lhs, currentTab],
     format[NewlineBlock[TabBlock[rhs], False], currentTab]
     ];


format[(ce : (CompoundExpressionBlock | 
        SuppressedCompoundExpressionBlock))[elems__], currentTab_] :=
    With[ {formatted = Map[format[#, currentTab] &, {elems}]},
        (ce @@ 
           Map[NewlineBlock[#, False] &, 
            formatted]) /;
         $alwaysBreakCompoundExpressions || !FreeQ[formatted, NewlineBlock]
    ];


format[StatementBlock[el_], currentTab_] :=
    StatementBlock[format[el, currentTab]];

format[expr : IfBlock[cond_, iftrue_, iffalse_], currentTab_] /; 
   needSplitQ[expr, currentTab] :=
    With[ {formatF = 
       format[TabBlock@NewlineBlock[#, False], currentTab] &},
        IfBlock[
         format["If", currentTab],
         formatF@cond,
         formatF@iftrue,
         formatF@IfCommentBlock[],
         formatF@iffalse,
         closingElement["IfBracket"]
         ]
    ];

format[expr : GeneralHeadBlock[head_, elems___], currentTab_] :=
    With[ {splitQ = needSplitQ[expr, currentTab]},
        GeneralSplitHeadBlock(* GeneralHeadBlock *)[
          format[head, currentTab],
          Sequence @@ Map[
            format[If[ splitQ,
                       TabBlock@NewlineBlock[#, False],
                       #
                   ], 
              currentTab] &,
            {elems}],
          closingElement["Bracket"]
          ] /; splitQ
    ];

format[expr : (ListBlock[elems___]), currentTab_] /; 
   needSplitQ[expr, currentTab] :=
    NewlineBlock[
     ListBlock[
      Sequence @@ 
       Map[format[TabBlock@NewlineBlock[#, False], 
          currentTab] &, {elems}],
      closingElement["List"]
      ],
     True];

format[expr : (ParenBlock[elems___]), currentTab_] /; 
   needSplitQ[expr, currentTab] :=
    NewlineBlock[
     ParenBlock[
      Sequence @@ 
       Map[format[TabBlock@NewlineBlock[#, False], 
          currentTab] &, {elems}],
      closingElement["Parenthesis"]
      ],
     True];

format[expr : ((head : (ApplyBlock | ApplyLevel1Block | MapBlock | 
           FunApplyBlock))[f_, e_]), currentTab_] /; 
   needSplitQ[expr, currentTab] :=
    head[
     format[f, currentTab],
     format[TabBlock@NewlineBlock[e, False], currentTab]
     ];

(* For a generic block, it is not obvious that we have to tab, so we \
don't*)
format[expr : (block_?blockQ[elems___]), currentTab_] :=
    With[ {splitQ = needSplitQ[expr, currentTab]},
        block @@ Map[
          format[If[ splitQ,
                     NewlineBlock[#, False],
                     #
                 ], currentTab] &,
          {elems}]
    ];

format[a_?AtomQ, _] := a;
 
    
    
    
ClearAll[fullFormat, fullFormatCompact];
fullFormat[boxes_] :=
    postformat@
     tabify@format@processPreformatted@preformat@preprocess@boxes;

fullFormatCompact[boxes_] :=
    Block[ {$alignClosingBracket = False,
      $alignClosingList = False,
      $alignClosingParen = False,
      $alignClosingScopingBracket = False,
      $alignClosingIfBracket = False},
        fullFormat[boxes]
    ];    
     


End[]

EndPackage[]

