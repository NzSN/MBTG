# MBTG (Model-Based Testing Generator)

MBTG is a unittests generator that generate via transform [ITF JSON](https://apalache-mc.org/docs/adr/015adr-trace.html) (Informal Trace Format JSON) into unittests in programming languages (Typescript, C/C++, Python, etc) that used to verify that whether the code being tested is satisfied constraints of the model descript by correspond TLA+ description.

There is a papaer that roughly explain the process to do that, [Model-based testing with TLA+
and Apalache ∗](https://conf.tlapl.us/2020/09-Kuprianov_and_Konnov-Model-based_testing_with_TLA_+_and_Apalache.pdf).

# Architecture of MBTG

```
┌─────────────────────────────────────────────────────────────────┐
│                           CLI Layer                             │
│  app/Main.hs                                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  mbtg generate --trace <input.itf.json> --output <dir/> │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Library Layer                            │
│  src/MBTG.hs                                                    │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  generateTests :: FilePath -> FilePath -> IO ()          │   │
│  │  1. Parse ITF JSON                                       │   │
│  │  2. Generate test code                                   │   │
│  │  3. Write output file                                    │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
┌──────────────────┐ ┌────────────────┐ ┌────────────────────┐
│   Parser Layer   │ │  Types Layer   │ │  Generator Layer   │
│  Parser/ITF.hs   │ │   Types.hs     │ │  Generator/TS.hs   │
├──────────────────┤ ├────────────────┤ ├────────────────────┤
│ parseITF         │ │ Trace          │ │ generateTypeScript │
│ parseITFFile     │ │ State          │ │ generateStateTest  │
│                  │ │ Expr (10 ctor) │ │ exprToTS           │
└──────────────────┘ └────────────────┘ └────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Data Flow                                │
│                                                                 │
│  ITF JSON --> Trace --> [State] --> TypeScript Test Code        │
│                                                                 │
│  Input:                    Internal:          Output:           │
│  {                         Trace {            describe('...') { │
│    "vars": [...],            vars: [...],       it('state 0') { │
│    "states": [...]           states: [...]        expect(...)   │
│  }                         }                   }                │
│                                                }                │
└─────────────────────────────────────────────────────────────────┘
```

## Components

| Component   | File                              | Responsibility                             |
|-------------|-----------------------------------|--------------------------------------------|
| **CLI**     | `app/Main.hs`                     | Command-line interface, option parsing     |
| **API**     | `src/MBTG.hs`                     | High-level entry point, orchestrates pipeline |
| **Types**   | `src/MBTG/Types.hs`               | ITF data types (Trace, State, Expr)        |
| **Parser**  | `src/MBTG/Parser/ITF.hs`          | ITF JSON → Haskell types                   |
| **Generator** | `src/MBTG/Generator/TypeScript.hs` | Haskell types → TypeScript test code     |

## Extensibility

To add a new target language (e.g., Python):

1. Create `src/MBTG/Generator/Python.hs`
2. Implement `generatePython :: Trace -> Text`
3. Add CLI subcommand in `app/Main.hs`
4. Expose from `src/MBTG.hs` 
