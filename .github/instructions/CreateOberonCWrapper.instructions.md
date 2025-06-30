---
applyTo: '*.c;*.h;*.obn'
---

## Creating C wrappers

1. Create a file named M.obn with the the exported declarations.
   Proper Procedures should have empty bodies to satisfy syntax requirements.
   Example: `PROCEDURE MyProc; BEGIN END MyProc;` 
   Function procedures should have a dummy return value to satisfy syntax requirements.
   Example: `PROCEDURE MyFunc() : BOOLEAN; BEGIN RETURN TRUE END MyFunc;` 

2. Create a file named MTest.obn which imports M (and preferably  write
    unit tests for M)
3. Build MTest with the command
        obnc MTest.obn
4. Copy the generated file .obnc/M.c to the current directory. In M.c,
    delete the generator comment on the first line.
5. Copy the generated file .obnc/M.h to the current directory.
6. Implement M.c. Update M.h as needed.

### Notes on C Wrappers

1. The initialization function M__Init is called each time a client
  module imports M. Its statements should therefore be  guarded  with an
  initialization flag to make sure they are executed only once.
2. To use pointers to C structures, declare INTEGERS in oberon, 
   OBNC_INTEGER is 32-bit, Oberon has no way to represent 64-bit integers. 
   Therefore you have to update the generated code: the relevant casts should be revised, 
   and uintptr_t should be used instead of OBNC_INTEGER.
   This works as long as there is no direct access to the structure fields from Oberon code.