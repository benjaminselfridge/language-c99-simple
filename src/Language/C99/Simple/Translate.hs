module Language.C99.Simple.Translate where

import GHC.Exts             (fromList)
import Control.Monad.State  (State, execState, get, put)

import           Language.C99.Simple.AST
import qualified Language.C99.AST         as C

import Language.C99.Util.Expr
import Language.C99.Util.IsList
import Language.C99.Util.Wrap

import Language.C99.Simple.Util

translate = transtransunit

transtransunit :: TransUnit -> C.TransUnit
transtransunit (TransUnit decln) = undefined -- TODO

transfundef :: FunDef -> C.FunDef
transfundef = undefined -- TODO

transdecln :: Decln -> C.Decln
transdecln (Decln storespec ty name init) = C.Decln dspecs dlist where
  dspecs = getdeclnspecs ty
  dlist  = Just $ C.InitDeclrBase $ C.InitDeclrInitr declr init'
  declr = execState (getdeclr ty) (identdeclr name)
  init' = transinit init


getdeclr :: Type -> State C.Declr ()
getdeclr ty = case ty of
  Type      ty'     -> do
    getdeclr ty'
    declr <- get
    put $ C.Declr Nothing (C.DirectDeclrDeclr declr)

  TypeSpec  ty' -> return ()

  Ptr       ty' -> do
    let (quals, ty'') = gettypequals ty'
    getdeclr ty''
    declr <- get
    put $ insertptr (C.PtrBase quals) declr

  Array ty' len -> do
    let lenexpr = (wrap.transexpr) <$> len
    (C.Declr ptr declr) <- get
    put $ C.Declr ptr (C.DirectDeclrArray1 declr Nothing lenexpr)

  Const    ty' -> getdeclr ty'
  Restrict ty' -> getdeclr ty'
  Volatile ty' -> getdeclr ty'


getdeclnspecs :: Type -> C.DeclnSpecs
getdeclnspecs ty = case ty of
  Type     ty'   -> getdeclnspecs ty'
  TypeSpec ty'   -> foldtypespecs $ spec2spec ty'
  Ptr      ty'   -> getdeclnspecs (snd $ gettypequals ty')
  Array    ty' _ -> getdeclnspecs ty'
  Const    ty'   -> C.DeclnSpecsQual C.QConst    (Just $ getdeclnspecs ty')
  Restrict ty'   -> C.DeclnSpecsQual C.QRestrict (Just $ getdeclnspecs ty')
  Volatile ty'   -> C.DeclnSpecsQual C.QVolatile (Just $ getdeclnspecs ty')


spec2spec :: TypeSpec -> [C.TypeSpec]
spec2spec ts = case ts of
  Void                -> [C.TVoid]
  Char                -> [C.TChar]
  Signed_Char         -> [C.TSigned, C.TChar]
  Unsigned_Char       -> [C.TUnsigned, C.TChar]

  Short               -> [C.TShort]
  Signed_Short        -> [C.TSigned, C.TShort]
  Short_Int           -> [C.TShort, C.TInt]
  Signed_Short_Int    -> [C.TSigned, C.TShort, C.TInt]

  Unsigned_Short      -> [C.TUnsigned, C.TShort]
  Unsigned_Short_Int  -> [C.TUnsigned, C.TShort, C.TInt]

  Int                 -> [C.TInt]
  Signed              -> [C.TSigned]
  Signed_Int          -> [C.TSigned, C.TInt]

  Unsigned            -> [C.TUnsigned]
  Unsigned_Int        -> [C.TUnsigned, C.TInt]

  Long                -> [C.TLong]
  Signed_Long         -> [C.TSigned, C.TLong]
  Long_Int            -> [C.TLong, C.TInt]
  Signed_Long_Int     -> [C.TSigned, C.TLong, C.TInt]

  Unsigned_Long       -> [C.TUnsigned, C.TLong]
  Unsgined_Long_Int   -> [C.TUnsigned, C.TLong, C.TInt]

  Long_Long           -> [C.TLong, C.TLong]
  Signed_Long_Long    -> [C.TSigned, C.TLong, C.TLong]
  Long_Long_Int       -> [C.TLong, C.TLong, C.TInt]
  Signed_Long_Long_Int-> [C.TSigned, C.TLong, C.TLong, C.TInt]

  Unsigned_Long_Long      -> [C.TUnsigned, C.TLong, C.TLong]
  Unsigned_Long_Long_Int  -> [C.TUnsigned, C.TLong, C.TLong, C.TInt]

  Float               -> [C.TFloat]
  Double              -> [C.TDouble]
  Long_Double         -> [C.TLong, C.TDouble]
  Bool                -> [C.TBool]
  Float_Complex       -> [C.TComplex, C.TFloat]
  Double_Complex      -> [C.TComplex, C.TDouble]
  Long_Double_Complex -> [C.TLong, C.TDouble, C.TComplex]
  TypedefName name -> [C.TTypedef $ C.TypedefName $ ident name]
  Struct      name -> [C.TStructOrUnion $ C.StructOrUnionForwDecln C.Struct (ident name)]
  StructDecln name declns -> [C.TStructOrUnion $ C.StructOrUnionDecln C.Struct (ident <$> name) declns'] where
    declns' = fromList $ map transstructdecln declns


transstructdecln = undefined -- TODO



transexpr :: Expr -> C.Expr
transexpr e = case e of
  Ident     i         -> wrap $ C.PrimIdent $ ident i
  LitInt    i         -> wrap $ litint    i
  LitDouble d         -> wrap $ litdouble d
  LitString s         -> wrap $ litstring s
  Index     arr idx   -> wrap $ indexexpr arr idx
  Funcall   fun args  -> wrap $ funcall   fun args
  Dot       e   field -> wrap $ dotexpr   e field
  Arrow     e   field -> wrap $ arrowexpr e field
  InitVal   ty  init  -> wrap $ initexpr  ty init
  UnaryOp   op e      -> wrap $ unaryop op e
  Cast      ty e      -> wrap $ castexpr ty e
  BinaryOp  op e1 e2  -> binaryop op e1 e2
  AssignOp  op e1 e2  -> wrap $ assignop op e1 e2


unaryop :: UnaryOp -> Expr -> C.UnaryExpr
unaryop op e = case op of
    Inc     -> C.UnaryInc          (wrap e')
    Dec     -> C.UnaryDec          (wrap e')
    Ref     -> C.UnaryOp C.UORef   (wrap e')
    DeRef   -> C.UnaryOp C.UODeref (wrap e')
    Plus    -> C.UnaryOp C.UOPlus  (wrap e')
    Min     -> C.UnaryOp C.UOMin   (wrap e')
    BoolNot -> C.UnaryOp C.UOBNot  (wrap e')
    Not     -> C.UnaryOp C.UONot   (wrap e')
  where
    e' = transexpr e

binaryop :: BinaryOp -> Expr -> Expr -> C.Expr
binaryop op e1 e2 = case op of
    Mult          -> wrap $ C.MultMult   (wrap e1') (wrap e2')
    Div           -> wrap $ C.MultDiv    (wrap e1') (wrap e2')
    Mod           -> wrap $ C.MultMod    (wrap e1') (wrap e2')
    Add           -> wrap $ C.AddPlus    (wrap e1') (wrap e2')
    Sub           -> wrap $ C.AddMin     (wrap e1') (wrap e2')
    ShiftL        -> wrap $ C.ShiftLeft  (wrap e1') (wrap e2')
    ShiftR        -> wrap $ C.ShiftRight (wrap e1') (wrap e2')
    Lessthan      -> wrap $ C.RelLT      (wrap e1') (wrap e2')
    GreaterThan   -> wrap $ C.RelGT      (wrap e1') (wrap e2')
    LessThanEq    -> wrap $ C.RelLE      (wrap e1') (wrap e2')
    GreaterThanEq -> wrap $ C.RelGE      (wrap e1') (wrap e2')
    Equal         -> wrap $ C.EqEq       (wrap e1') (wrap e2')
    NotEqual      -> wrap $ C.EqNEq      (wrap e1') (wrap e2')
    And           -> wrap $ C.And        (wrap e1') (wrap e2')
    XOr           -> wrap $ C.XOr        (wrap e1') (wrap e2')
    Or            -> wrap $ C.Or         (wrap e1') (wrap e2')
    LAnd          -> wrap $ C.LAnd       (wrap e1') (wrap e2')
    LOr           -> wrap $ C.LOr        (wrap e1') (wrap e2')
  where
    e1' = transexpr e1
    e2' = transexpr e2

assignop :: AssignOp -> Expr -> Expr -> C.AssignExpr
assignop op e1 e2 = C.Assign e1' op' e2' where
  e1' = wrap $ transexpr e1
  e2' = wrap $ transexpr e2
  op' = case op of
    Assign       -> C.AEq
    AssignMult   -> C.ATimes
    AssignDiv    -> C.ADiv
    AssignMod    -> C.AMod
    AssignAdd    -> C.AAdd
    AssignSub    -> C.ASub
    AssignShiftL -> C.AShiftL
    AssignShiftR -> C.AShiftR
    AssignAnd    -> C.AAnd
    AssignXOr    -> C.AXOr
    AssignOr     -> C.AOr

transinit :: Init -> C.Init
transinit (InitExpr e)   = C.InitExpr (wrap $ transexpr e)
transinit (InitArray es) = C.InitArray (fromList $ map transinit es)

initexpr ty init = C.PostfixInits ty' init' where
  ty'   = transtypename ty
  init' = fromList $ map transinit init

indexexpr arr idx = C.PostfixIndex arr' idx' where
  arr' = wrap $ transexpr arr
  idx' = wrap $ transexpr idx

dotexpr e field = C.PostfixDot e' field' where
  e'     = wrap $ transexpr e
  field' = ident field

arrowexpr e field = C.PostfixArrow e' field' where
  e'     = wrap $ transexpr e
  field' = ident field

castexpr ty e = C.Cast ty' e' where
  ty' = transtypename ty
  e'  = wrap $ transexpr e

funcall fun args = C.PostfixFunction fun' args' where
  fun'  = wrap $ transexpr fun
  args' = Just $ fromList argses

  argses :: [C.AssignExpr]
  argses = map wrap exprs

  exprs :: [C.Expr]
  exprs = map transexpr args


transtypename = undefined -- TODO


getabstractdeclr :: Type -> State C.AbstractDeclr ()
getabstractdeclr ty = case ty of
  Type ty'    -> do
    getabstractdeclr ty'
    adeclr <- get
    put $ C.AbstractDeclrDirect Nothing (C.DirectAbstractDeclr adeclr)

  TypeSpec ts -> return ()

  Ptr ty' -> do
    let (quals, ty'') = gettypequals ty'
    getabstractdeclr ty''
    adeclr <- get
    let ptr = C.PtrBase quals
    put $ C.AbstractDeclrDirect (Just ptr) (C.DirectAbstractDeclr adeclr)

  Array ty' len -> do
    getabstractdeclr ty'
    (C.AbstractDeclrDirect ptr adeclr) <- get
    let len'     = (wrap.transexpr) <$> len
        arrdeclr = C.DirectAbstractDeclrArray1 (Just adeclr) Nothing len'
    put $ C.AbstractDeclrDirect ptr arrdeclr

  Const    ty' -> getabstractdeclr ty'
  Restrict ty' -> getabstractdeclr ty'
  Volatile ty' -> getabstractdeclr ty'