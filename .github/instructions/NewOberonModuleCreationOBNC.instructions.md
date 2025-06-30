---
applyTo: '*.Mod'
---
## Creating Oberon Modules with OBNC compiler

Create a minimal stub with the opaque type and empty procedures.
Every procedure should have a body, even if it is empty, to satisfy the syntax requirements of the Oberon-07 language.
Create a minimal test module that imports the new module. 
The makefile discovers the module and you can compile it with 

`make MyModuleTest`

### Minimal Test Example:

```Oberon-07
(** MyModuleTest.Mod - Tests for MyModule.Mod.

Copyright (C) 2025 Artemis Project Contributors

Released under The 3-Clause BSD License.
*)
MODULE MyModuleTest;
IMPORT MyModule, Tests;

VAR
  ts: Tests.TestSet;

PROCEDURE TestExample(): BOOLEAN;
VAR
  pass: BOOLEAN; (* Other variable declarations*)
BEGIN
  pass := TRUE;
  
  (* Perform the test *)
  
  Tests.ExpectedBool(TRUE, MyModule.MyFunc(), "MyModule.MyFunc() pass", pass)
  
  RETURN pass
END TestExample;

(* Other testcases as needed. *)

BEGIN
  Tests.Init(ts, "Example Tests");
  Tests.Add(ts, TestExample);

  ASSERT(Tests.Run(ts));
END MyModuleTest.

```

### Best practices 

- Use modules to encapsulate functionality. Use opaque pointers to expose necessary types. Hide implementation details.
- Export only what is necessary; keep the interface clean.
- Local procedures (procedures defined inside other procedures) can promote cleaner code organization by grouping related code together. 
- Local procedures can make deeply nested code. Use with care.

