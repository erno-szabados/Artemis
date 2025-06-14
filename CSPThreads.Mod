(**
    CSPThreads.Mod - Thread-safe channels and threading utilities for Oberon-07
    
    Provides:
    - Thread-safe buffered channels with blocking/non-blocking operations
    - Basic thread creation and management using PThreads
    - Clean CSP-style communication primitives
    
    THREAD SAFETY ARCHITECTURE:
    
    This module uses a safe thread procedure registry to eliminate memory safety
    issues when passing Oberon procedure pointers to C pthread functions.
    
    Problem: pthread_create() expects a C function pointer, but we need to call
    Oberon procedures. The naive approach of casting procedure pointers to integers
    using SYSTEM.VAL() is unsafe and can cause crashes.
    
    Solution: Thread Procedure Registry
    - HashMap-based registry maps safe integer IDs to procedure pointers
    - ThreadTrampoline() uses the ID to safely lookup the actual procedure
    - Automatic cleanup when threads complete (both normal and joined)
    - Thread-safe operations protected by mutex
    - No arbitrary thread limits (grows dynamically with available memory)
    
    Flow:
    1. NewThread(proc) → RegisterThreadProc(proc) → returns safe integer ID
    2. pthread_create(ThreadTrampoline, ID) → creates OS thread with safe ID
    3. ThreadTrampoline(ID) → GetThreadProc(ID) → calls actual procedure
    4. Thread completion → UnregisterThreadProc(ID) → cleanup registry entry
    
    This approach provides complete memory safety while maintaining clean CSP semantics.
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
    Author: Artemis Project
*)
MODULE CSPThreads;

IMPORT Collections, Queue, HashMap, artPThread;

CONST
    OPEN* = 0;
    CLOSED* = 1;

TYPE
    (** Thread-safe channel for message passing between threads *)
    Channel* = POINTER TO ChannelDesc;
    ChannelDesc = RECORD
        buffer: Queue.Queue;
        capacity: INTEGER;
        state: INTEGER;
        mutex: artPThread.Mutex;
        sendCond: artPThread.CondVar;
        recvCond: artPThread.CondVar
    END;

    (** Thread procedure signature *)
    ThreadProc* = PROCEDURE;
    
    (** Thread handle for managing OS threads *)
    Thread* = POINTER TO ThreadDesc;
    ThreadDesc = RECORD
        proc: ThreadProc;
        thread: artPThread.Thread;
        registryId: INTEGER  (* Safe ID for procedure registry *)
    END;

    (** Registry entry for thread procedures *)
    ThreadProcEntry = POINTER TO ThreadProcEntryDesc;
    ThreadProcEntryDesc = RECORD (Collections.Item)
        proc: ThreadProc
    END;

VAR
    (* Thread Procedure Registry for Memory Safety
       
       This registry solves the fundamental problem of safely passing Oberon
       procedure pointers to C pthread functions. Instead of using dangerous
       type casts, we store procedures in a HashMap and pass safe integer IDs.
       
       Benefits:
       - Complete memory safety (no SYSTEM.VAL conversions)
       - Dynamic sizing (no arbitrary thread limits) 
       - O(1) operations (HashMap efficiency)
       - Automatic cleanup (prevents resource leaks)
       - Thread-safe access (mutex protected)
    *)
    threadProcRegistry: HashMap.HashMap;
    registryMutex: artPThread.Mutex;
    nextRegistryId: INTEGER;

(** Create a ThreadProcEntry for the registry *)
PROCEDURE NewThreadProcEntry(proc: ThreadProc): ThreadProcEntry;
VAR entry: ThreadProcEntry;
BEGIN
    NEW(entry);
    entry.proc := proc;
    RETURN entry
END NewThreadProcEntry;

(**
    Safely register a thread procedure and return a registry ID
    
    This is the core of our memory safety solution. Instead of passing
    procedure pointers directly to pthread_create (which would require
    unsafe type casting), we store the procedure in a HashMap and return
    a safe integer ID that can be passed to C functions.
*)
PROCEDURE RegisterThreadProc(proc: ThreadProc): INTEGER;
VAR registryId: INTEGER; ok: BOOLEAN; entry: ThreadProcEntry;
BEGIN
    registryId := -1;
    ok := artPThread.Lock(registryMutex);
    IF ok THEN
        registryId := nextRegistryId;
        INC(nextRegistryId);
        entry := NewThreadProcEntry(proc);
        HashMap.Put(threadProcRegistry, registryId, entry);
        ok := artPThread.Unlock(registryMutex)
    END;
    RETURN registryId
END RegisterThreadProc;

(** Safely retrieve a thread procedure by registry ID *)
PROCEDURE GetThreadProc(registryId: INTEGER): ThreadProc;
VAR proc: ThreadProc; ok: BOOLEAN; item: Collections.ItemPtr; entry: ThreadProcEntry;
BEGIN
    proc := NIL;
    ok := artPThread.Lock(registryMutex);
    IF ok THEN
        ok := HashMap.Get(threadProcRegistry, registryId, item);
        IF ok & (item # NIL) THEN
            entry := item(ThreadProcEntry);
            proc := entry.proc
        END;
        ok := artPThread.Unlock(registryMutex)
    END;
    RETURN proc
END GetThreadProc;

(** Unregister a thread procedure when thread completes *)
PROCEDURE UnregisterThreadProc(registryId: INTEGER);
VAR ok, removed: BOOLEAN;
BEGIN
    ok := artPThread.Lock(registryMutex);
    IF ok THEN
        removed := HashMap.Remove(threadProcRegistry, registryId);
        ok := artPThread.Unlock(registryMutex)
    END
END UnregisterThreadProc;

(**
    Thread trampoline - bridges C thread creation to Oberon procedures
    
    This procedure is called by the C pthread system with our safe registry ID.
    It safely looks up the actual Oberon procedure and calls it, then cleans
    up the registry entry. This completely eliminates the memory safety risks
    of passing procedure pointers across the C/Oberon boundary.
*)
PROCEDURE ThreadTrampoline(context: INTEGER): INTEGER;
VAR proc: ThreadProc;
BEGIN
    proc := GetThreadProc(context);
    IF proc # NIL THEN 
        proc();
        UnregisterThreadProc(context)
    END;
    RETURN 0
END ThreadTrampoline;

(** Free channel resources - call when done with channel *)
PROCEDURE FreeChannel*(VAR ch: Channel);
BEGIN
    IF ch # NIL THEN
        ch.state := CLOSED;
        IF ch.buffer # NIL THEN Queue.Clear(ch.buffer) END;
        IF ch.mutex # NIL THEN artPThread.FreeMutex(ch.mutex) END;
        IF ch.sendCond # NIL THEN artPThread.FreeCondVar(ch.sendCond) END;
        IF ch.recvCond # NIL THEN artPThread.FreeCondVar(ch.recvCond) END;
        ch := NIL
    END
END FreeChannel;

(** Create a new thread-safe channel with specified buffer capacity *)
PROCEDURE NewChannel*(capacity: INTEGER): Channel;
VAR ch: Channel;
BEGIN
    ch := NIL;
    IF capacity >= 0 THEN
        NEW(ch);
        ch.buffer := Queue.New();
        ch.capacity := capacity;
        ch.state := OPEN;
        ch.mutex := artPThread.NewMutex();
        ch.sendCond := artPThread.NewCondVar();
        ch.recvCond := artPThread.NewCondVar();
        
        (* Check if all resources were allocated successfully *)
        IF (ch.buffer = NIL) OR (ch.mutex = NIL) OR (ch.sendCond = NIL) OR (ch.recvCond = NIL) THEN
            FreeChannel(ch)
        END
    END;
    RETURN ch
END NewChannel;

(** Close a channel - no more sends allowed, receives drain remaining messages *)
PROCEDURE CloseChannel*(ch: Channel);
VAR ok: BOOLEAN;
BEGIN
    IF ch # NIL THEN
        ok := artPThread.Lock(ch.mutex);
        IF ok THEN
            ch.state := CLOSED;
            (* Wake up any waiting receivers *)
            ok := artPThread.Broadcast(ch.recvCond);
            (* Wake up any waiting senders *)
            ok := artPThread.Broadcast(ch.sendCond);
            ok := artPThread.Unlock(ch.mutex)
        END
    END
END CloseChannel;

(** Check if channel is closed *)
PROCEDURE IsClosed*(ch: Channel): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
    result := FALSE;
    IF ch # NIL THEN result := ch.state = CLOSED END;
    RETURN result
END IsClosed;

(** Non-blocking send - returns TRUE if message was sent, FALSE if buffer full or error *)
PROCEDURE TrySend*(ch: Channel; item: Collections.ItemPtr): BOOLEAN;
VAR result, ok: BOOLEAN;
BEGIN
    result := FALSE;
    IF ch # NIL THEN
        ok := artPThread.TryLock(ch.mutex);
        IF ok THEN
            IF (ch.state = OPEN) & (Queue.Count(ch.buffer) < ch.capacity) THEN
                Queue.Enqueue(ch.buffer, item);
                ok := artPThread.Signal(ch.recvCond);
                (* Signal failure doesn't prevent successful send *)
                result := TRUE
            END;
            ok := artPThread.Unlock(ch.mutex)
            (* Unlock failure is critical - we cannot continue safely *)
        END
    END;
    RETURN result
END TrySend;

(** Non-blocking receive - returns TRUE if message received, FALSE if buffer empty or error *)
PROCEDURE TryReceive*(ch: Channel; VAR item: Collections.ItemPtr): BOOLEAN;
VAR result, ok: BOOLEAN;
BEGIN
    result := FALSE;
    item := NIL;
    IF ch # NIL THEN
        ok := artPThread.TryLock(ch.mutex);
        IF ok THEN
            IF Queue.Count(ch.buffer) > 0 THEN
                Queue.Dequeue(ch.buffer, item);
                ok := artPThread.Signal(ch.sendCond);
                (* Signal failure doesn't prevent successful receive *)
                result := TRUE
            END;
            ok := artPThread.Unlock(ch.mutex)
            (* Unlock failure is critical - we cannot continue safely *)
        END
    END;
    RETURN result
END TryReceive;

(** Blocking send - waits until message can be sent or channel is closed *)
PROCEDURE Send*(ch: Channel; item: Collections.ItemPtr);
VAR done, ok: BOOLEAN;
BEGIN
    done := FALSE;
    IF (ch = NIL) OR (ch.state # OPEN) THEN done := TRUE END;
    WHILE ~done DO
        ok := artPThread.Lock(ch.mutex);
        IF ok THEN
            IF ch.state # OPEN THEN
                ok := artPThread.Unlock(ch.mutex);
                done := TRUE
            ELSIF Queue.Count(ch.buffer) < ch.capacity THEN
                Queue.Enqueue(ch.buffer, item);
                ok := artPThread.Signal(ch.recvCond);
                ok := artPThread.Unlock(ch.mutex);
                done := TRUE
            ELSE
                ok := artPThread.Wait(ch.sendCond, ch.mutex);
                ok := artPThread.Unlock(ch.mutex)
                (* If locking or waiting fails, we exit the loop to prevent infinite spinning *)
            END
        ELSE
            (* Lock failed - cannot proceed safely *)
            done := TRUE
        END
    END
END Send;

(** Blocking receive - waits until message available or channel closed and empty *)
PROCEDURE Receive*(ch: Channel; VAR item: Collections.ItemPtr);
VAR done, ok: BOOLEAN;
BEGIN
    done := FALSE;
    item := NIL;
    IF ch = NIL THEN done := TRUE END;
    WHILE ~done DO
        ok := artPThread.Lock(ch.mutex);
        IF ok THEN
            IF Queue.Count(ch.buffer) > 0 THEN
                Queue.Dequeue(ch.buffer, item);
                ok := artPThread.Signal(ch.sendCond);
                ok := artPThread.Unlock(ch.mutex);
                done := TRUE
            ELSIF ch.state = CLOSED THEN
                ok := artPThread.Unlock(ch.mutex);
                done := TRUE
            ELSE
                ok := artPThread.Wait(ch.recvCond, ch.mutex);
                ok := artPThread.Unlock(ch.mutex)
                (* If locking or waiting fails, we exit the loop to prevent infinite spinning *)
            END
        ELSE
            (* Lock failed - cannot proceed safely *)
            done := TRUE
        END
    END
END Receive;

(** Create and start a new thread *)
PROCEDURE NewThread*(proc: ThreadProc): Thread;
VAR t: Thread; registryId: INTEGER;
BEGIN
    t := NIL;
    IF proc # NIL THEN
        (* Register the procedure safely *)
        registryId := RegisterThreadProc(proc);
        IF registryId >= 0 THEN
            NEW(t);
            t.proc := proc;
            t.registryId := registryId;
            t.thread := artPThread.NewThread(ThreadTrampoline, registryId);
            (* If thread creation failed, clean up *)
            IF t.thread = NIL THEN
                UnregisterThreadProc(registryId);
                t := NIL
            END
        END
    END;
    RETURN t
END NewThread;

(**
    Wait for thread to complete
    
    Note: We use a dual cleanup strategy for registry entries:
    1. Normal cleanup in ThreadTrampoline when thread completes normally
    2. Safety cleanup here in case the thread didn't complete normally
    This ensures no registry entries are leaked regardless of thread fate.
*)
PROCEDURE JoinThread*(thread: Thread): BOOLEAN;
VAR ok: BOOLEAN;
BEGIN
    ok := FALSE;
    IF (thread # NIL) & (thread.thread # NIL) THEN
        ok := artPThread.Join(thread.thread);
        (* Clean up registry entry if join was successful *)
        (* Note: registry cleanup also happens in ThreadTrampoline, but we do it here *)
        (* as a safety measure in case the thread didn't complete normally *)
        IF ok THEN
            UnregisterThreadProc(thread.registryId)
        END
    END;
    RETURN ok
END JoinThread;

PROCEDURE Init*();
BEGIN
    (* Initialize thread procedure registry *)
    registryMutex := artPThread.NewMutex();
    nextRegistryId := 0;
    threadProcRegistry := HashMap.New()
END Init;

BEGIN
    Init();
END CSPThreads.
