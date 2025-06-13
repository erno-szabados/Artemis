(**
    CSP.Mod - Communicating Sequential Processes implementation
    
    A minimal CSP implementation following Hoare's model with channels and processes.
    Built on Artemis Collections for portability.
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
*)
MODULE CSP;

IMPORT Collections, Queue, artPThread, SYSTEM;

CONST
    (** Channel states *)
    OPEN* = 0;
    CLOSED* = 1;
    
    (** Process states *)
    READY* = 0;
    RUNNING* = 1;
    BLOCKED* = 2;
    FINISHED* = 3;

TYPE
    (** Opaque channel type for message passing *)
    Channel* = POINTER TO ChannelDesc;
    ChannelDesc = RECORD
        buffer: Queue.Queue;
        capacity: INTEGER;
        state: INTEGER;
        sendWaiters: Queue.Queue;
        recvWaiters: Queue.Queue
    END;
    
    (** Process procedure type *)
    ProcessProc* = PROCEDURE;
    
    (** Opaque process type *)
    Process* = POINTER TO ProcessDesc;
    ProcessDesc = RECORD (Collections.Item)
        id: INTEGER;
        state: INTEGER;
        proc: ProcessProc;
        thread: artPThread.Thread
    END;
    
    (** Waiter for blocking operations *)
    Waiter* = POINTER TO WaiterDesc;
    WaiterDesc = RECORD (Collections.Item)
        process: Process;
        message: Collections.ItemPtr;
        ready: BOOLEAN
    END;
    
    (** Simple scheduler *)
    Scheduler* = POINTER TO SchedulerDesc;
    SchedulerDesc = RECORD
        processes: Queue.Queue;
        readyQueue: Queue.Queue;
        currentProcess: Process;
        nextId: INTEGER
    END;

VAR
    defaultScheduler: Scheduler;

(* Trampoline for process threads *)
PROCEDURE ProcessTrampoline(context: INTEGER): INTEGER;
VAR proc: ProcessProc;
BEGIN
    proc := SYSTEM.VAL(ProcessProc, context);
    IF proc # NIL THEN
        proc()
    END;
    RETURN 0
END ProcessTrampoline;

(** Create a new channel with given capacity (0 = synchronous) *)
PROCEDURE NewChannel*(capacity: INTEGER): Channel;
VAR ch: Channel;
BEGIN
    NEW(ch);
    ch.buffer := Queue.New();
    ch.capacity := capacity;
    ch.state := OPEN;
    ch.sendWaiters := Queue.New();
    ch.recvWaiters := Queue.New();
    RETURN ch
END NewChannel;

(** Free a channel and its resources *)
PROCEDURE FreeChannel*(VAR ch: Channel);
BEGIN
    IF ch # NIL THEN
        ch.state := CLOSED;
        IF ch.buffer # NIL THEN
            Queue.Clear(ch.buffer)
        END;
        IF ch.sendWaiters # NIL THEN
            Queue.Clear(ch.sendWaiters)
        END;
        IF ch.recvWaiters # NIL THEN
            Queue.Clear(ch.recvWaiters)
        END;
        ch := NIL
    END
END FreeChannel;

(** Close a channel (no more sends allowed) *)
PROCEDURE CloseChannel*(ch: Channel);
BEGIN
    IF ch # NIL THEN
        ch.state := CLOSED
    END
END CloseChannel;

(** Check if channel is closed *)
PROCEDURE IsClosed*(ch: Channel): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
    result := FALSE;
    IF ch # NIL THEN
        result := ch.state = CLOSED
    END;
    RETURN result
END IsClosed;

(** Non-blocking send - returns TRUE if sent, FALSE if would block *)
PROCEDURE TrySend*(ch: Channel; item: Collections.ItemPtr): BOOLEAN;
VAR 
    result: BOOLEAN;
    waiter: Collections.ItemPtr;
BEGIN
    result := FALSE;
    IF (ch # NIL) & (ch.state = OPEN) THEN
        (* Check if there's a waiting receiver *)
        IF ~Queue.IsEmpty(ch.recvWaiters) THEN
            Queue.Dequeue(ch.recvWaiters, waiter);
            IF waiter # NIL THEN
                waiter(Waiter).message := item;
                waiter(Waiter).ready := TRUE;
                result := TRUE
            END
        ELSIF Queue.Count(ch.buffer) < ch.capacity THEN
            (* Buffer has space *)
            Queue.Enqueue(ch.buffer, item);
            result := TRUE
        END
        (* Else would block, return FALSE *)
    END;
    RETURN result
END TrySend;

(** Non-blocking receive - returns TRUE if received, FALSE if would block *)
PROCEDURE TryReceive*(ch: Channel; VAR item: Collections.ItemPtr): BOOLEAN;
VAR 
    result: BOOLEAN;
    waiter: Collections.ItemPtr;
BEGIN
    result := FALSE;
    item := NIL;
    IF ch # NIL THEN
        (* Check buffer first *)
        IF Queue.Count(ch.buffer) > 0 THEN
            Queue.Dequeue(ch.buffer, item);
            result := TRUE;
            
            (* Wake up a waiting sender if any *)
            IF ~Queue.IsEmpty(ch.sendWaiters) THEN
                Queue.Dequeue(ch.sendWaiters, waiter);
                IF waiter # NIL THEN
                    waiter(Waiter).ready := TRUE
                END
            END
        ELSIF ~Queue.IsEmpty(ch.sendWaiters) THEN
            (* Direct transfer from waiting sender *)
            Queue.Dequeue(ch.sendWaiters, waiter);
            IF waiter # NIL THEN
                item := waiter(Waiter).message;
                waiter(Waiter).ready := TRUE;
                result := TRUE
            END
        ELSIF ch.state = CLOSED THEN
            (* Channel closed, no more messages *)
            result := FALSE
        END
    END;
    RETURN result
END TryReceive;

(** Blocking send (simplified - would need scheduler integration) *)
PROCEDURE Send*(ch: Channel; item: Collections.ItemPtr);
VAR success: BOOLEAN;
BEGIN
    success := TrySend(ch, item);
    (* In full implementation, would block here if not successful *)
END Send;

(** Blocking receive (simplified - would need scheduler integration) *)
PROCEDURE Receive*(ch: Channel; VAR item: Collections.ItemPtr);
VAR success: BOOLEAN;
BEGIN
    success := TryReceive(ch, item);
    (* In full implementation, would block here if not successful *)
END Receive;

(** Create a new process *)
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

(** Create a new scheduler *)
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

(** Add a process to scheduler *)
PROCEDURE AddProcess*(sched: Scheduler; proc: Process);
BEGIN
    IF (sched # NIL) & (proc # NIL) THEN
        Queue.Enqueue(sched.processes, proc);
        IF proc.state = READY THEN
            Queue.Enqueue(sched.readyQueue, proc)
        END
    END
END AddProcess;

(** Simple cooperative yield *)
PROCEDURE Yield*();
BEGIN
    (* In full implementation, would switch to next ready process *)
END Yield;

(** Run the scheduler (simplified) *)
PROCEDURE Run*(sched: Scheduler);
VAR 
    proc: Collections.ItemPtr;
    process: Process;
BEGIN
    IF sched # NIL THEN
        WHILE ~Queue.IsEmpty(sched.readyQueue) DO
            Queue.Dequeue(sched.readyQueue, proc);
            IF proc # NIL THEN
                process := proc(Process);
                sched.currentProcess := process;
                process.state := RUNNING;
                
                (* Execute process procedure *)
                IF process.proc # NIL THEN
                    process.proc()
                END;
                
                process.state := FINISHED;
                sched.currentProcess := NIL
            END
        END
    END
END Run;

(** Initialize default scheduler *)
PROCEDURE Init*();
BEGIN
    IF defaultScheduler = NIL THEN
        defaultScheduler := NewScheduler()
    END
END Init;

(** Get default scheduler *)
PROCEDURE DefaultScheduler*(): Scheduler;
BEGIN
    RETURN defaultScheduler
END DefaultScheduler;

BEGIN
    Init()
END CSP.
