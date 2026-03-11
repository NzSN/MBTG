{-# LANGUAGE OverloadedStrings #-}

-- | ITF JSON parser.
module MBTG.Parser.ITF
  ( parseITF
  , parseITFFile
  ) where

import Control.Exception (throwIO)
import Data.Aeson (eitherDecode')
import Data.ByteString.Lazy (ByteString, readFile)
import MBTG.Types (Trace)
import Prelude hiding (readFile)

-- | Parse ITF JSON from ByteString.
parseITF :: ByteString -> Either String Trace
parseITF = eitherDecode'

-- | Parse ITF JSON file.
parseITFFile :: FilePath -> IO Trace
parseITFFile path = do
  content <- readFile path
  case parseITF content of
    Left err -> throwIO $ userError $ "Failed to parse ITF: " ++ err
    Right trace -> pure trace