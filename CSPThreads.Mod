(**
    CSPThreads.Mod - True concurrency CSP implementation using PThreads
    Provides channels and process scheduling with OS threads.
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
    Author: Artemis Project
*)
MODULE CSPThreads;

IMPORT Collections, Queue, artPThread, SYSTEM;

CONST
    OPEN* = 0;
    CLOSED* = 1;
    READY* = 0;
    RUNNING* = 1;
    BLOCKED* = 2;
    FINISHED* = 3;

TYPE
    Channel* = POINTER TO ChannelDesc;
    ChannelDesc = RECORD
        buffer: Queue.Queue;
        capacity: INTEGER;
        state: INTEGER;
        sendWaiters: Queue.Queue;
        recvWaiters: Queue.Queue;
        mutex: artPThread.Mutex;
        sendCond: artPThread.CondVar;
        recvCond: artPThread.CondVar
    END;
    ProcessProc* = PROCEDURE;
    Process* = POINTER TO ProcessDesc;
    ProcessDesc = RECORD (Collections.Item)
        id: INTEGER;
        state: INTEGER;
        proc: ProcessProc;
        thread: artPThread.Thread
    END;
    Waiter* = POINTER TO WaiterDesc;
    WaiterDesc = RECORD (Collections.Item)
        process: Process;
        message: Collections.ItemPtr;
        ready: BOOLEAN
    END;
    Scheduler* = POINTER TO SchedulerDesc;
    SchedulerDesc = RECORD
        processes: Queue.Queue;
        readyQueue: Queue.Queue;
        currentProcess: Process;
        nextId: INTEGER
    END;

VAR
    defaultScheduler: Scheduler;

PROCEDURE ProcessTrampoline(context: INTEGER): INTEGER;
VAR proc: ProcessProc;
BEGIN
    proc := SYSTEM.VAL(ProcessProc, context);
    IF proc # NIL THEN proc() END;
    RETURN 0
END ProcessTrampoline;

PROCEDURE NewChannel*(capacity: INTEGER): Channel;
VAR ch: Channel;
BEGIN
    NEW(ch);
    ch.buffer := Queue.New();
    ch.capacity := capacity;
    ch.state := OPEN;
    ch.sendWaiters := Queue.New();
    ch.recvWaiters := Queue.New();
    ch.mutex := artPThread.NewMutex();
    ch.sendCond := artPThread.NewCondVar();
    ch.recvCond := artPThread.NewCondVar();
    RETURN ch
END NewChannel;

PROCEDURE FreeChannel*(VAR ch: Channel);
BEGIN
    IF ch # NIL THEN
        ch.state := CLOSED;
        IF ch.buffer # NIL THEN Queue.Clear(ch.buffer) END;
        IF ch.sendWaiters # NIL THEN Queue.Clear(ch.sendWaiters) END;
        IF ch.recvWaiters # NIL THEN Queue.Clear(ch.recvWaiters) END;
        IF ch.mutex # NIL THEN artPThread.FreeMutex(ch.mutex) END;
        IF ch.sendCond # NIL THEN artPThread.FreeCondVar(ch.sendCond) END;
        IF ch.recvCond # NIL THEN artPThread.FreeCondVar(ch.recvCond) END;
        ch := NIL
    END
END FreeChannel;

PROCEDURE CloseChannel*(ch: Channel);
BEGIN
    IF ch # NIL THEN ch.state := CLOSED END
END CloseChannel;

PROCEDURE IsClosed*(ch: Channel): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
    result := FALSE;
    IF ch # NIL THEN result := ch.state = CLOSED END;
    RETURN result
END IsClosed;

PROCEDURE TrySend*(ch: Channel; item: Collections.ItemPtr): BOOLEAN;
VAR result: BOOLEAN; waiter: Collections.ItemPtr;
BEGIN
    result := FALSE;
    IF (ch # NIL) & (ch.state = OPEN) THEN
        IF ~Queue.IsEmpty(ch.recvWaiters) THEN
            Queue.Dequeue(ch.recvWaiters, waiter);
            IF waiter # NIL THEN
                waiter(Waiter).message := item;
                waiter(Waiter).ready := TRUE;
                result := TRUE
            END
        ELSIF Queue.Count(ch.buffer) < ch.capacity THEN
            Queue.Enqueue(ch.buffer, item);
            result := TRUE
        END
    END;
    RETURN result
END TrySend;

PROCEDURE TryReceive*(ch: Channel; VAR item: Collections.ItemPtr): BOOLEAN;
VAR result: BOOLEAN; waiter: Collections.ItemPtr;
BEGIN
    result := FALSE;
    item := NIL;
    IF ch # NIL THEN
        IF Queue.Count(ch.buffer) > 0 THEN
            Queue.Dequeue(ch.buffer, item);
            result := TRUE;
            IF ~Queue.IsEmpty(ch.sendWaiters) THEN
                Queue.Dequeue(ch.sendWaiters, waiter);
                IF waiter # NIL THEN waiter(Waiter).ready := TRUE END
            END
        ELSIF ~Queue.IsEmpty(ch.sendWaiters) THEN
            Queue.Dequeue(ch.sendWaiters, waiter);
            IF waiter # NIL THEN
                item := waiter(Waiter).message;
                waiter(Waiter).ready := TRUE;
                result := TRUE
            END
        ELSIF ch.state = CLOSED THEN
            result := FALSE
        END
    END;
    RETURN result
END TryReceive;

PROCEDURE Send*(ch: Channel; item: Collections.ItemPtr);
VAR success, done, ok: BOOLEAN;
BEGIN
    done := FALSE;
    IF (ch = NIL) OR (ch.state # OPEN) THEN done := TRUE END;
    WHILE ~done DO
        IF artPThread.Lock(ch.mutex) THEN
            success := TrySend(ch, item);
            IF success THEN
                ok := artPThread.Signal(ch.recvCond);
                ok := artPThread.Unlock(ch.mutex);
                done := TRUE
            ELSE
                ok := artPThread.Wait(ch.sendCond, ch.mutex);
                ok := artPThread.Unlock(ch.mutex)
            END
        END
    END
END Send;

PROCEDURE Receive*(ch: Channel; VAR item: Collections.ItemPtr);
VAR success, done, ok: BOOLEAN;
BEGIN
    done := FALSE;
    IF ch = NIL THEN item := NIL; done := TRUE END;
    WHILE ~done DO
        IF artPThread.Lock(ch.mutex) THEN
            success := TryReceive(ch, item);
            IF success THEN
                ok := artPThread.Signal(ch.sendCond);
                ok := artPThread.Unlock(ch.mutex);
                done := TRUE
            ELSIF ch.state = CLOSED THEN
                ok := artPThread.Unlock(ch.mutex);
                item := NIL;
                done := TRUE
            ELSE
                ok := artPThread.Wait(ch.recvCond, ch.mutex);
                ok := artPThread.Unlock(ch.mutex)
            END
        END
    END
END Receive;

PROCEDURE NewProcess*(proc: ProcessProc): Process;
VAR p: Process;
BEGIN
    NEW(p);
    p.proc := proc;
    p.state := READY;
    p.thread := NIL;
    IF defaultScheduler # NIL THEN
        p.id := defaultScheduler.nextId;
        INC(defaultScheduler.nextId)
    ELSE
        p.id := 0
    END;
    IF proc # NIL THEN
        p.thread := artPThread.NewThread(ProcessTrampoline, SYSTEM.VAL(INTEGER, proc))
    END;
    RETURN p
END NewProcess;

PROCEDURE NewScheduler*(): Scheduler;
VAR sched: Scheduler;
BEGIN
    NEW(sched);
    sched.processes := Queue.New();
    sched.readyQueue := Queue.New();
    sched.currentProcess := NIL;
    sched.nextId := 1;
    RETURN sched
END NewScheduler;

PROCEDURE AddProcess*(sched: Scheduler; proc: Process);
BEGIN
    IF (sched # NIL) & (proc # NIL) THEN
        Queue.Enqueue(sched.processes, proc);
        IF proc.state = READY THEN
            Queue.Enqueue(sched.readyQueue, proc)
        END
    END
END AddProcess;

PROCEDURE JoinProcess*(proc: Process): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
    ok := FALSE;
    IF (proc # NIL) & (proc.thread # NIL) THEN
        ok := artPThread.Join(proc.thread);
        IF ok THEN proc.thread := NIL END
    END;
    RETURN ok
END JoinProcess;

PROCEDURE Yield*();
BEGIN
    (* In full implementation, would switch to next ready process *)
END Yield;

PROCEDURE Run*(sched: Scheduler);
VAR proc: Collections.ItemPtr; process: Process;
BEGIN
    IF sched # NIL THEN
        WHILE ~Queue.IsEmpty(sched.readyQueue) DO
            Queue.Dequeue(sched.readyQueue, proc);
            IF proc # NIL THEN
                process := proc(Process);
                sched.currentProcess := process;
                process.state := RUNNING;
                IF process.proc # NIL THEN process.proc() END;
                process.state := FINISHED;
                sched.currentProcess := NIL
            END
        END
    END
END Run;

PROCEDURE Init*();
BEGIN
    IF defaultScheduler = NIL THEN defaultScheduler := NewScheduler() END
END Init;

PROCEDURE DefaultScheduler*(): Scheduler;
BEGIN
    RETURN defaultScheduler
END DefaultScheduler;

BEGIN
    Init()
END CSPThreads.
