{-# LANGUAGE OverloadedStrings #-}

-- | MBTG - Model-Based Testing Generator
module MBTG
  ( module MBTG.Types
  , module MBTG.Parser.ITF
  , module MBTG.Generator.TypeScript
  , generateTests
  ) where

import MBTG.Generator.TypeScript
import MBTG.Parser.ITF
import MBTG.Types

import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeBaseName, (</>))

-- | Generate test file from an ITF trace file.
generateTests :: FilePath -> FilePath -> IO ()
generateTests traceFile outputDir = do
  trace <- parseITFFile traceFile
  let baseName = takeBaseName traceFile
      testName = baseName ++ ".test.ts"
      outputPath = outputDir </> testName
  createDirectoryIfMissing True outputDir
  generateTypeScriptFile traceFile outputPath trace
  putStrLn $ "Generated: " ++ outputPath