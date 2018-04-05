{-# LANGUAGE MultiWayIf          #-}
{-# LANGUAGE ScopedTypeVariables #-}
-- | common things that are necessary to implement strategies.
module Strategy.Util
  ( module Strategy.Util
  , Ident
  , Type
  ) where

import           Control.Lens
import           Language.C
import           Language.C.Analysis.SemRep    hiding (Stmt)
import           Language.C.Analysis.TypeUtils
import           RIO                           hiding (view)
import           System.IO                     (hPutStr)
import           System.Random
import           Text.PrettyPrint.HughesPJ     (render)



import           Data
import           Instrumentation
import           Persistence
import           Types

class (HasTranslationUnit env, HasLogFunc env, HasDiffParameters env) => StrategyEnv env


-- | runs the given translation unit against the configured verifiers.
verify :: (IsStrategyEnv env) => CTranslationUnit SemPhase -> RIO env [VerifierRun]
verify tu = do
  vs <- view (diffParameters . verifiers)
  withSystemTempFile "input.c" $ \fp h -> do
        -- write file
        originalFileName <- view (diffParameters . program)
        let content = render . pretty $ tu
            hsh = hash content
        persist' $ CProgram content originalFileName
        liftIO $ hPutStr h content >> hFlush h
        -- run each verifier
        forM vs $ \v -> do
            env <- mkVerifierEnv (15 * 1000 * 1000) -- 15 seconds
            r <- runRIO env $ execute v fp
            let run = VerifierRun (verifierName v) r hsh
            persist' run
            return run


conclude :: [VerifierRun] -> Conclusion
conclude  rs = if
  | all (\r -> verdict (verifierResult r) == Sat) rs                  -> StrongAgreement Sat
  | all (\r -> verdict (verifierResult r) == Unsat) rs                -> StrongAgreement Unsat
  | all (\r -> verdict (verifierResult r) `elem` [Sat, Unknown]) rs   -> WeakAgreement Sat
  | all (\r -> verdict (verifierResult r) `elem` [Unsat, Unknown]) rs -> WeakAgreement Unsat
  | length sats > length unsats && not (null unsats)                  -> Unsoundness unsats
  | length unsats > length sats && not (null sats)                    -> Incompleteness sats
  | otherwise -> Disagreement
  where
    unsats = [ runVerifierName r | r <- rs, verdict (verifierResult r) == Unsat ]
    sats =   [ runVerifierName r | r <- rs, verdict (verifierResult r) == Sat ]

mkAssertion :: (MonadIO m ) => Ident -> Type -> m Stmt
mkAssertion varName ty = do
      constv <- if | ty `sameType` integral TyChar -> do
                      (c :: Char) <- liftIO randomIO
                      return $ CCharConst (CChar c False) (undefNode, ty)
                   | ty `sameType` integral TyBool -> do
                      (b :: Bool) <- liftIO randomIO
                      let v = if b then 1 else 0
                      return $ CIntConst (cInteger v) (undefNode, ty)
                   | ty `sameType` integral TyUInt -> do
                       (v :: Int32) <- liftIO randomIO
                       return $ CIntConst (cInteger $ fromIntegral (abs v))  (undefNode, ty)
                   | otherwise -> do
                       (v :: Int32) <- liftIO randomIO
                       return $ CIntConst (cInteger $ fromIntegral v) (undefNode, ty)
      let  constant'   = CConst constv
           var        = CVar varName (undefNode, ty)
           identifier = CVar (builtinIdent "__VERIFIER_assert") (undefNode,voidType)
           expression = CBinary CNeqOp var constant' (undefNode, boolType)
           stmt       = CExpr (Just $ CCall identifier [expression] (undefNode, voidType)) (undefNode, voidType)
      return stmt
