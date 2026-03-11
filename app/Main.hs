{-# LANGUAGE OverloadedStrings #-}

module Main where

import Options.Applicative
import Data.Version (showVersion)
import Paths_MBTG (version)

import MBTG (generateTests)

data Options = Options
  { optCommand :: Maybe Command
  }

data Command = Generate GenerateOpts

data GenerateOpts = GenerateOpts
  { genTraceFile :: FilePath
  , genOutput    :: FilePath
  }

main :: IO ()
main = do
  opts <- execParser optsParser
  case optCommand opts of
    Nothing -> putStrLn $ "MBTG version " ++ showVersion version
    Just (Generate genOpts) -> do
      let traceFile = genTraceFile genOpts
          outputDir = genOutput genOpts
      putStrLn $ "Generating tests from: " ++ traceFile
      generateTests traceFile outputDir
      putStrLn "Done!"

optsParser :: ParserInfo Options
optsParser = info (parseOptions <**> helper <**> simpleVersioner (showVersion version)) $
  fullDesc
  <> progDesc "Model-Based Testing Generator - generates tests from Apalache ITF traces"
  <> header "mbtg - generate unit tests from TLA+ specifications"

parseOptions :: Parser Options
parseOptions = Options <$> optional parseCommand

parseCommand :: Parser Command
parseCommand = subparser $
  command "generate" (info parseGenerate (progDesc "Generate test file from ITF trace"))

parseGenerate :: Parser Command
parseGenerate = Generate <$> parseGenerateOpts

parseGenerateOpts :: Parser GenerateOpts
parseGenerateOpts = GenerateOpts
  <$> strOption
      ( long "trace"
     <> short 't'
     <> metavar "FILE"
     <> help "Path to ITF JSON trace file"
      )
  <*> strOption
      ( long "output"
     <> short 'o'
     <> metavar "DIR"
     <> value "."
     <> help "Output directory for generated tests (default: current directory)"
      )