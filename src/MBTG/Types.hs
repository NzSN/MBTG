{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Types for ITF (Informal Trace Format).
module MBTG.Types
  ( Trace(..)
  , State(..)
  , Expr(..)
  ) where

import Control.Applicative ((<|>))
import Data.Aeson
import Data.Aeson.Key (fromText, toText)
import Data.Aeson.KeyMap (KeyMap)
import qualified Data.Aeson.KeyMap as KM
import Data.Aeson.Types (Parser)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Scientific (floatingOrInteger)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Vector as V
import GHC.Generics (Generic)

-- | ITF trace containing states from TLA+ model execution.
data Trace = Trace
  { traceMeta   :: Maybe Value
  , traceParams :: Maybe [Text]
  , traceVars   :: [Text]
  , traceStates :: [State]
  , traceLoop   :: Maybe Int
  } deriving (Show, Eq, Generic)

-- | State is a mapping from variable names to values.
newtype State = State { unState :: Map Text Expr }
  deriving (Show, Eq)

-- | ITF expression types (10 constructors).
data Expr
  = ExprBool Bool
  | ExprString Text
  | ExprBigInt Integer
  | ExprList [Expr]
  | ExprTuple [Expr]
  | ExprSet [Expr]
  | ExprMap [(Expr, Expr)]
  | ExprRecord (Map Text Expr)
  | ExprVariant Text Expr
  | ExprUnserializable Text
  deriving (Show, Eq, Generic)

instance FromJSON Trace where
  parseJSON = withObject "Trace" $ \v -> Trace
    <$> v .:? "#meta"
    <*> v .:? "params"
    <*> v .: "vars"
    <*> v .: "states"
    <*> v .:? "loop"

instance FromJSON State where
  parseJSON = withObject "State" $ \obj -> do
    let keys = filter (\k -> toText k /= "#meta") (KM.keys obj)
        parseKey k = case KM.lookup k obj of
          Just v -> (toText k,) <$> parseJSON v
          Nothing -> fail $ "Key not found: " ++ T.unpack (toText k)
    pairs <- mapM parseKey keys
    return $ State $ Map.fromList pairs

instance FromJSON Expr where
  parseJSON value = case value of
    Bool b -> pure $ ExprBool b
    String s -> pure $ ExprString s
    Number n -> case floatingOrInteger n of
      Left (_ :: Double) -> fail "Floating point not supported"
      Right i -> pure $ ExprBigInt i
    Array arr -> pure $ ExprList $ V.toList $ fmap parseExprValue arr
    Object obj -> parseExprObject obj
    Null -> pure $ ExprUnserializable "null"

parseExprObject :: KeyMap Value -> Parser Expr
parseExprObject obj =
      parseBigInt
  <|> parseTuple
  <|> parseSet
  <|> parseMap
  <|> parseUnserializable
  <|> parseVariant
  <|> parseRecord
  where
    parseBigInt = do
      n <- obj .: "#bigint"
      pure $ ExprBigInt (read $ T.unpack n)
    
    parseTuple = do
      elems <- obj .: "#tup"
      pure $ ExprTuple $ V.toList $ fmap parseExprValue elems
    
    parseSet = do
      elems <- obj .: "#set"
      pure $ ExprSet $ V.toList $ fmap parseExprValue elems
    
    parseMap = do
      pairs <- obj .: "#map"
      let parsePair arr = case V.toList arr of
            [k, v] -> pure (parseExprValue k, parseExprValue v)
            _ -> fail "Map pair must have 2 elements"
      pairs' <- mapM parsePair pairs
      pure $ ExprMap $ V.toList pairs'
    
    parseUnserializable = do
      s <- obj .: "#unserializable"
      pure $ ExprUnserializable s
    
    parseVariant = do
      tag <- obj .: "tag"
      val <- obj .: "value"
      pure $ ExprVariant tag (parseExprValue val)
    
    parseRecord = do
      let keys = filter (\k -> toText k /= "#meta") (KM.keys obj)
          parseKey k = case KM.lookup k obj of
            Just v -> (toText k,) <$> parseJSON v
            Nothing -> fail $ "Key not found: " ++ T.unpack (toText k)
      pairs <- mapM parseKey keys
      pure $ ExprRecord $ Map.fromList pairs

parseExprValue :: Value -> Expr
parseExprValue = \case
  Bool b -> ExprBool b
  String s -> ExprString s
  Number n -> case floatingOrInteger n of
    Left (_ :: Double) -> ExprUnserializable "float"
    Right i -> ExprBigInt i
  Array arr -> ExprList $ V.toList $ fmap parseExprValue arr
  Object obj -> parseExprValueFromObject obj
  Null -> ExprUnserializable "null"

parseExprValueFromObject :: KeyMap Value -> Expr
parseExprValueFromObject obj
  | Just (String n) <- KM.lookup "#bigint" obj = ExprBigInt (read $ T.unpack n)
  | Just (Array elems) <- KM.lookup "#tup" obj = ExprTuple $ V.toList $ fmap parseExprValue elems
  | Just (Array elems) <- KM.lookup "#set" obj = ExprSet $ V.toList $ fmap parseExprValue elems
  | Just (Array pairs) <- KM.lookup "#map" obj =
      let parsePair v = case v of
            Array arr -> case V.toList arr of
              [k, v'] -> (parseExprValue k, parseExprValue v')
              _ -> (ExprUnserializable "error", ExprUnserializable "error")
            _ -> (ExprUnserializable "error", ExprUnserializable "error")
      in ExprMap $ map parsePair $ V.toList pairs
  | Just (String s) <- KM.lookup "#unserializable" obj = ExprUnserializable s
  | Just tagVal <- KM.lookup "tag" obj, Just valVal <- KM.lookup "value" obj =
      let tag = case tagVal of
            String t -> t
            _ -> "error"
      in ExprVariant tag (parseExprValue valVal)
  | otherwise =
      let keys = filter (\k -> toText k /= "#meta") (KM.keys obj)
          parseKey k = case KM.lookup k obj of
            Just v -> (toText k, parseExprValue v)
            Nothing -> (toText k, ExprUnserializable "error")
      in ExprRecord $ Map.fromList $ map parseKey keys

instance ToJSON Trace where
  toJSON t = object
    [ "#meta" .= traceMeta t
    , "params" .= traceParams t
    , "vars" .= traceVars t
    , "states" .= traceStates t
    , "loop" .= traceLoop t
    ]

instance ToJSON State where
  toJSON (State s) = object $ map (\(k, v) -> fromText k .= v) $ Map.toList s

instance ToJSON Expr where
  toJSON = \case
    ExprBool b -> Bool b
    ExprString s -> String s
    ExprBigInt n -> object [ "#bigint" .= show n ]
    ExprList es -> toJSON es
    ExprTuple es -> object [ "#tup" .= es ]
    ExprSet es -> object [ "#set" .= es ]
    ExprMap pairs -> object [ "#map" .= map (\(k, v) -> [toJSON k, toJSON v]) pairs ]
    ExprRecord m -> object $ map (\(k, v) -> fromText k .= v) $ Map.toList m
    ExprVariant tag val -> object [ "tag" .= tag, "value" .= val ]
    ExprUnserializable s -> object [ "#unserializable" .= s ]