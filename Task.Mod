(**
    CSPCoop.Mod - Minimal cooperative CSP scheduler with buffered message passing
    Suitable for MCUs and single-core systems. No threads, no blocking, no preemption.
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
    Author: Artemis Project
*)
MODULE Task;

IMPORT Collections, Queue;

TYPE
    TaskContext* = POINTER TO TaskContextDesc;
    TaskContextDesc* = RECORD
    END;

    TaskProc* = PROCEDURE (ctx : TaskContext);
    Task = POINTER TO TaskDesc;

    TaskDesc = RECORD (Collections.Item)
        proc: TaskProc;
        context: TaskContext
    END;
    Scheduler* = POINTER TO SchedulerDesc;
    SchedulerDesc = RECORD
        tasks: Queue.Queue;
        current: Task
    END;
    Channel* = POINTER TO ChannelDesc;
    ChannelDesc = RECORD
        buffer: Queue.Queue;
        capacity: INTEGER
    END;

(* Create a new scheduler *)
PROCEDURE NewScheduler*(): Scheduler;
VAR sched: Scheduler;
BEGIN
    NEW(sched);
    sched.tasks := Queue.New();
    sched.current := NIL;
    RETURN sched
END NewScheduler;

(* Add a task to the scheduler *)
PROCEDURE AddTask*(sched: Scheduler; proc: TaskProc; ctx : TaskContext);
VAR t: Task;
BEGIN
    IF (sched # NIL) & (proc # NIL) THEN
        NEW(t); t.proc := proc; t.context := ctx;
        Queue.Enqueue(sched.tasks, t)
    END
END AddTask;

(* Yield control to the next task *)
PROCEDURE Yield*();
BEGIN
    (* In a real implementation, this would switch to the next task. Here, it's a no-op placeholder. *)
END Yield;

(* Run the scheduler (simple round-robin) *)
PROCEDURE Run*(sched: Scheduler);
VAR t: Collections.ItemPtr;
BEGIN
    IF sched # NIL THEN
        WHILE ~Queue.IsEmpty(sched.tasks) DO
            Queue.Dequeue(sched.tasks, t);
            IF t # NIL THEN
                sched.current := t(Task);
                IF sched.current.proc # NIL THEN sched.current.proc(t(Task).context) END
            END
        END
    END
END Run;

(* Create a new buffered channel *)
PROCEDURE NewChannel*(capacity: INTEGER): Channel;
VAR ch: Channel;
BEGIN
    NEW(ch);
    ch.buffer := Queue.New();
    ch.capacity := capacity;
    RETURN ch
END NewChannel;

(* Send a message to the channel (FALSE if full) *)
PROCEDURE Send*(ch: Channel; msg: Collections.ItemPtr): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
    result := FALSE;
    IF (ch # NIL) & (Queue.Count(ch.buffer) < ch.capacity) THEN
        Queue.Enqueue(ch.buffer, msg);
        result := TRUE
    END;
    RETURN result
END Send;

(* Receive a message from the channel (FALSE if empty) *)
PROCEDURE Receive*(ch: Channel; VAR msg: Collections.ItemPtr): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
    result := FALSE;
    msg := NIL;
    IF (ch # NIL) & (Queue.Count(ch.buffer) > 0) THEN
        Queue.Dequeue(ch.buffer, msg);
        result := TRUE
    END;
    RETURN result
END Receive;

END Task.
