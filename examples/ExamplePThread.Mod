(**
    ExamplePThread.Mod - Simple pthreads demo: multiple threads increment a shared counter
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
    Demonstrates thread creation, mutex usage, and joining in Oberon-07.
    Author: Artemis Project
*)
MODULE ExamplePThread;

IMPORT Out, artPThread, SYSTEM;

CONST
    NumThreads = 4;
    IncrementsPerThread = 10000;
    ThreadSleepMs = 1;

TYPE
    CounterContext = POINTER TO CounterContextDesc;
    CounterContextDesc = RECORD
        counter: INTEGER;
        mutex: artPThread.Mutex
    END;

    ThreadArg = POINTER TO ThreadArgDesc;
    ThreadArgDesc = RECORD
        ctx: CounterContext;
        increments: INTEGER
    END;

VAR
    threads: ARRAY NumThreads OF artPThread.Thread;
    args: ARRAY NumThreads OF ThreadArg;
    ctx: CounterContext;
    i: INTEGER;

(* Thread procedure: increments the shared counter *)
PROCEDURE ThreadProc(context: INTEGER): INTEGER;
VAR arg: ThreadArg;
    j: INTEGER;
    ok : BOOLEAN;
BEGIN
    arg := SYSTEM.VAL(ThreadArg, context);
    IF arg # NIL THEN
        FOR j := 0 TO arg.increments - 1 DO
            IF artPThread.Lock(arg.ctx.mutex) THEN
                arg.ctx.counter := arg.ctx.counter + 1;
                ok := artPThread.Unlock(arg.ctx.mutex)
            END;
            artPThread.Sleep(ThreadSleepMs)
        END
    END;
    RETURN 0
END ThreadProc;

BEGIN
    Out.String("ExamplePThread: Threaded Counter Demo"); Out.Ln;
    NEW(ctx); ctx.counter := 0;
    ctx.mutex := artPThread.NewMutex();
    IF ctx.mutex = NIL THEN
        Out.String("Failed to create mutex."); Out.Ln;
    ELSE
        FOR i := 0 TO NumThreads - 1 DO
            NEW(args[i]);
            args[i].ctx := ctx;
            args[i].increments := IncrementsPerThread;
            threads[i] := artPThread.NewThread(ThreadProc, SYSTEM.VAL(INTEGER, args[i]));
            IF threads[i] = NIL THEN
                Out.String("Failed to create thread "); Out.Int(i, 0); Out.Ln
            END
        END;
        FOR i := 0 TO NumThreads - 1 DO
            IF threads[i] # NIL THEN
                IF ~artPThread.Join(threads[i]) THEN
                    Out.String("Failed to join thread "); Out.Int(i, 0); Out.Ln
                END
            END
        END;
        Out.String("Final counter value: "); Out.Int(ctx.counter, 0); Out.Ln;
        Out.String("Expected value: "); Out.Int(NumThreads * IncrementsPerThread, 0); Out.Ln;
        artPThread.FreeMutex(ctx.mutex)
    END;
    Out.String("ExamplePThread completed."); Out.Ln
END ExamplePThread.
