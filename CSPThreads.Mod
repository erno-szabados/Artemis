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
    (** Thread-safe buffered channel for message passing between threads *)
    BufferedChannel* = POINTER TO BufferedChannelDesc;
    BufferedChannelDesc = RECORD
        buffer: Queue.Queue;
        capacity: INTEGER;
        state: INTEGER;
        mutex: artPThread.Mutex;
        sendCond: artPThread.CondVar;
        recvCond: artPThread.CondVar
    END;

    (** Thread-safe synchronous channel for rendezvous communication *)
    SyncChannel* = POINTER TO SyncChannelDesc;
    SyncChannelDesc = RECORD
        state: INTEGER;
        mutex: artPThread.Mutex;
        sendCond: artPThread.CondVar;
        recvCond: artPThread.CondVar;
        (* Rendezvous state *)
        pendingItem: Collections.ItemPtr;  (* Item waiting for handoff *)
        senderWaiting: BOOLEAN;            (* TRUE if sender is blocked *)
        receiverWaiting: BOOLEAN           (* TRUE if receiver is blocked *)
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

    (* Registry entry for thread procedures *)
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

(* Create a ThreadProcEntry for the registry *)
PROCEDURE NewThreadProcEntry(proc: ThreadProc): ThreadProcEntry;
VAR entry: ThreadProcEntry;
BEGIN
    NEW(entry);
    entry.proc := proc;
    RETURN entry
END NewThreadProcEntry;

(*
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

(* Safely retrieve a thread procedure by registry ID *)
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

(* Unregister a thread procedure when thread completes *)
PROCEDURE UnregisterThreadProc(registryId: INTEGER);
VAR ok, removed: BOOLEAN;
BEGIN
    ok := artPThread.Lock(registryMutex);
    IF ok THEN
        removed := HashMap.Remove(threadProcRegistry, registryId);
        ok := artPThread.Unlock(registryMutex)
    END
END UnregisterThreadProc;

(*
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

(** Free buffered channel resources - call when done with channel *)
PROCEDURE FreeBufferedChannel*(VAR ch: BufferedChannel);
BEGIN
    IF ch # NIL THEN
        ch.state := CLOSED;
        IF ch.buffer # NIL THEN 
            Queue.Free(ch.buffer)  (* Free the queue completely *)
        END;
        IF ch.mutex # NIL THEN artPThread.FreeMutex(ch.mutex) END;
        IF ch.sendCond # NIL THEN artPThread.FreeCondVar(ch.sendCond) END;
        IF ch.recvCond # NIL THEN artPThread.FreeCondVar(ch.recvCond) END;
        ch := NIL
    END
END FreeBufferedChannel;

(** Create a new thread-safe buffered channel with specified buffer capacity *)
PROCEDURE NewBufferedChannel*(capacity: INTEGER): BufferedChannel;
VAR ch: BufferedChannel;
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
            FreeBufferedChannel(ch)
        END
    END;
    RETURN ch
END NewBufferedChannel;

(** Close a buffered channel - no more sends allowed, receives drain remaining messages *)
PROCEDURE CloseBufferedChannel*(ch: BufferedChannel);
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
END CloseBufferedChannel;

(** Check if buffered channel is closed *)
PROCEDURE IsBufferedClosed*(ch: BufferedChannel): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
    result := FALSE;
    IF ch # NIL THEN result := ch.state = CLOSED END;
    RETURN result
END IsBufferedClosed;

(** Non-blocking send - returns TRUE if message was sent, FALSE if buffer full or error *)
PROCEDURE TrySend*(ch: BufferedChannel; item: Collections.ItemPtr): BOOLEAN;
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
PROCEDURE TryReceive*(ch: BufferedChannel; VAR item: Collections.ItemPtr): BOOLEAN;
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

(** Blocking send - waits until message can be sent or buffered channel is closed *)
PROCEDURE Send*(ch: BufferedChannel; item: Collections.ItemPtr);
VAR done, ok, canProceed: BOOLEAN;
BEGIN
    done := FALSE;
    canProceed := (ch # NIL) & (ch.state = OPEN);
    
    IF canProceed THEN
        ok := artPThread.Lock(ch.mutex);
        canProceed := ok
    END;
    
    WHILE canProceed & ~done DO
        IF ch.state # OPEN THEN
            done := TRUE
        ELSIF Queue.Count(ch.buffer) < ch.capacity THEN
            Queue.Enqueue(ch.buffer, item);
            ok := artPThread.Signal(ch.recvCond);
            done := TRUE
        ELSE
            (* Wait automatically unlocks mutex, waits, then re-locks on wake *)
            ok := artPThread.Wait(ch.sendCond, ch.mutex);
            IF ~ok THEN 
                done := TRUE;
                canProceed := FALSE
            END
        END
    END;
    
    IF canProceed THEN
        ok := artPThread.Unlock(ch.mutex)
    END
END Send;

(** Blocking receive - waits until message available or buffered channel closed and empty *)
PROCEDURE Receive*(ch: BufferedChannel; VAR item: Collections.ItemPtr);
VAR done, ok, canProceed: BOOLEAN;
BEGIN
    done := FALSE;
    item := NIL;
    canProceed := ch # NIL;
    
    IF canProceed THEN
        ok := artPThread.Lock(ch.mutex);
        canProceed := ok
    END;
    
    WHILE canProceed & ~done DO
        IF Queue.Count(ch.buffer) > 0 THEN
            Queue.Dequeue(ch.buffer, item);
            ok := artPThread.Signal(ch.sendCond);
            done := TRUE
        ELSIF ch.state = CLOSED THEN
            done := TRUE
        ELSE
            (* Wait automatically unlocks mutex, waits, then re-locks on wake *)
            ok := artPThread.Wait(ch.recvCond, ch.mutex);
            IF ~ok THEN 
                done := TRUE;
                canProceed := FALSE
            END
        END
    END;
    
    IF canProceed THEN
        ok := artPThread.Unlock(ch.mutex)
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

(** 
   Synchronous Channel Operations
   
   True CSP-style synchronous communication with rendezvous semantics.
   Sender and receiver block until both are ready, then handoff occurs directly.
 *)

(** Free synchronous channel resources *)
PROCEDURE FreeSyncChannel*(VAR ch: SyncChannel);
BEGIN
    IF ch # NIL THEN
        ch.state := CLOSED;
        ch.pendingItem := NIL;
        ch.senderWaiting := FALSE;
        ch.receiverWaiting := FALSE;
        IF ch.mutex # NIL THEN artPThread.FreeMutex(ch.mutex) END;
        IF ch.sendCond # NIL THEN artPThread.FreeCondVar(ch.sendCond) END;
        IF ch.recvCond # NIL THEN artPThread.FreeCondVar(ch.recvCond) END;
        ch := NIL
    END
END FreeSyncChannel;

(** Close a synchronous channel - no more operations allowed *)
PROCEDURE CloseSyncChannel*(ch: SyncChannel);
VAR ok: BOOLEAN;
BEGIN
    IF ch # NIL THEN
        ok := artPThread.Lock(ch.mutex);
        IF ok THEN
            ch.state := CLOSED;
            (* Wake up any waiting threads *)
            ok := artPThread.Broadcast(ch.sendCond);
            ok := artPThread.Broadcast(ch.recvCond);
            ok := artPThread.Unlock(ch.mutex)
        END
    END
END CloseSyncChannel;

(** Create a new synchronous channel for rendezvous communication *)
PROCEDURE NewSyncChannel*(): SyncChannel;
VAR ch: SyncChannel;
BEGIN
    ch := NIL;
    NEW(ch);
    ch.state := OPEN;
    ch.mutex := artPThread.NewMutex();
    ch.sendCond := artPThread.NewCondVar();
    ch.recvCond := artPThread.NewCondVar();
    ch.pendingItem := NIL;
    ch.senderWaiting := FALSE;
    ch.receiverWaiting := FALSE;
    
    (* Check if all resources were allocated successfully *)
    IF (ch.mutex = NIL) OR (ch.sendCond = NIL) OR (ch.recvCond = NIL) THEN
        FreeSyncChannel(ch)
    END;
    RETURN ch
END NewSyncChannel;

(** Check if synchronous channel is closed *)
PROCEDURE IsSyncClosed*(ch: SyncChannel): BOOLEAN;
VAR result: BOOLEAN;
BEGIN
    result := FALSE;
    IF ch # NIL THEN result := ch.state = CLOSED END;
    RETURN result
END IsSyncClosed;

(** Non-blocking synchronous send - returns TRUE only if receiver ready *)
PROCEDURE TrySyncSend*(ch: SyncChannel; item: Collections.ItemPtr): BOOLEAN;
VAR result, ok: BOOLEAN;
BEGIN
    result := FALSE;
    IF ch # NIL THEN
        ok := artPThread.TryLock(ch.mutex);
        IF ok THEN
            IF (ch.state = OPEN) & ch.receiverWaiting & ~ch.senderWaiting THEN
                (* Direct handoff to waiting receiver *)
                ch.pendingItem := item;
                ch.senderWaiting := FALSE;
                ch.receiverWaiting := FALSE;
                ok := artPThread.Signal(ch.recvCond);
                result := TRUE
            END;
            ok := artPThread.Unlock(ch.mutex)
        END
    END;
    RETURN result
END TrySyncSend;

(** Non-blocking synchronous receive - returns TRUE only if sender ready *)
PROCEDURE TrySyncReceive*(ch: SyncChannel; VAR item: Collections.ItemPtr): BOOLEAN;
VAR result, ok: BOOLEAN;
BEGIN
    result := FALSE;
    item := NIL;
    IF ch # NIL THEN
        ok := artPThread.TryLock(ch.mutex);
        IF ok THEN
            IF (ch.state = OPEN) & ch.senderWaiting & ~ch.receiverWaiting THEN
                (* Direct handoff from waiting sender *)
                item := ch.pendingItem;
                ch.pendingItem := NIL;
                ch.senderWaiting := FALSE;
                ch.receiverWaiting := FALSE;
                ok := artPThread.Signal(ch.sendCond);
                result := TRUE
            END;
            ok := artPThread.Unlock(ch.mutex)
        END
    END;
    RETURN result
END TrySyncReceive;

(** Blocking synchronous send - waits for receiver rendezvous *)
PROCEDURE SyncSend*(ch: SyncChannel; item: Collections.ItemPtr);
VAR done, ok, canProceed: BOOLEAN;
BEGIN
    done := FALSE;
    canProceed := (ch # NIL) & (ch.state = OPEN);
    
    IF canProceed THEN
        ok := artPThread.Lock(ch.mutex);
        canProceed := ok
    END;
    
    WHILE canProceed & ~done DO
        IF ch.state # OPEN THEN
            done := TRUE
        ELSIF ch.receiverWaiting & ~ch.senderWaiting THEN
            (* Receiver is waiting - direct handoff *)
            ch.pendingItem := item;
            ch.senderWaiting := FALSE;
            ch.receiverWaiting := FALSE;
            ok := artPThread.Signal(ch.recvCond);
            done := TRUE
        ELSE
            (* No receiver ready - wait for one *)
            ch.senderWaiting := TRUE;
            ch.pendingItem := item;
            ok := artPThread.Wait(ch.sendCond, ch.mutex);
            IF ~ok THEN 
                ch.senderWaiting := FALSE;
                ch.pendingItem := NIL;
                done := TRUE;
                canProceed := FALSE
            ELSIF ~ch.receiverWaiting THEN
                (* Woke up but no receiver - someone else got it *)
                ch.senderWaiting := FALSE;
                ch.pendingItem := NIL;
                done := TRUE
            END
        END
    END;
    
    IF canProceed THEN
        ok := artPThread.Unlock(ch.mutex)
    END
END SyncSend;

(** Blocking synchronous receive - waits for sender rendezvous *)
PROCEDURE SyncReceive*(ch: SyncChannel; VAR item: Collections.ItemPtr);
VAR done, ok, canProceed: BOOLEAN;
BEGIN
    done := FALSE;
    item := NIL;
    canProceed := ch # NIL;
    
    IF canProceed THEN
        ok := artPThread.Lock(ch.mutex);
        canProceed := ok
    END;
    
    WHILE canProceed & ~done DO
        IF ch.state = CLOSED THEN
            done := TRUE
        ELSIF ch.senderWaiting & ~ch.receiverWaiting THEN
            (* Sender is waiting - direct handoff *)
            item := ch.pendingItem;
            ch.pendingItem := NIL;
            ch.senderWaiting := FALSE;
            ch.receiverWaiting := FALSE;
            ok := artPThread.Signal(ch.sendCond);
            done := TRUE
        ELSE
            (* No sender ready - wait for one *)
            ch.receiverWaiting := TRUE;
            ok := artPThread.Wait(ch.recvCond, ch.mutex);
            IF ~ok THEN 
                ch.receiverWaiting := FALSE;
                done := TRUE;
                canProceed := FALSE
            ELSIF ~ch.senderWaiting THEN
                (* Woke up but no sender - someone else got it *)
                ch.receiverWaiting := FALSE;
                done := TRUE
            END
        END
    END;
    
    IF canProceed THEN
        ok := artPThread.Unlock(ch.mutex)
    END
END SyncReceive;

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
