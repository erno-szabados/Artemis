(**
    CSPTest.Mod - Tests for CSP module
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
*)
MODULE CSPTest;

IMPORT CSP, Collections, Tests, artPThread;

TYPE
    TestMessage = RECORD (Collections.Item)
        value: INTEGER
    END;
    TestMessagePtr = POINTER TO TestMessage;

VAR
    ts: Tests.TestSet;

PROCEDURE NewMessage(val: INTEGER): TestMessagePtr;
VAR msg: TestMessagePtr;
BEGIN
    NEW(msg);
    msg.value := val;
    RETURN msg
END NewMessage;

PROCEDURE TestChannelCreation*(): BOOLEAN;
VAR 
    ch: CSP.Channel;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    
    (* Test synchronous channel *)
    ch := CSP.NewChannel(0);
    Tests.ExpectedBool(FALSE, CSP.IsClosed(ch), "New channel should be open", pass);
    
    (* Test buffered channel *)
    ch := CSP.NewChannel(5);
    Tests.ExpectedBool(FALSE, CSP.IsClosed(ch), "New buffered channel should be open", pass);
    
    (* Test closing *)
    CSP.CloseChannel(ch);
    Tests.ExpectedBool(TRUE, CSP.IsClosed(ch), "Closed channel should report closed", pass);
    
    RETURN pass
END TestChannelCreation;

PROCEDURE TestNonBlockingOperations*(): BOOLEAN;
VAR 
    ch: CSP.Channel;
    msg1, msg2: TestMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    
    (* Test buffered channel *)
    ch := CSP.NewChannel(2);
    msg1 := NewMessage(42);
    msg2 := NewMessage(84);
    
    (* Should be able to send to buffer *)
    success := CSP.TrySend(ch, msg1);
    Tests.ExpectedBool(TRUE, success, "Should send to empty buffer", pass);
    
    success := CSP.TrySend(ch, msg2);
    Tests.ExpectedBool(TRUE, success, "Should send to buffer with space", pass);
    
    (* Buffer should now be full *)
    success := CSP.TrySend(ch, NewMessage(126));
    Tests.ExpectedBool(FALSE, success, "Should not send to full buffer", pass);
    
    (* Should be able to receive *)
    success := CSP.TryReceive(ch, result);
    Tests.ExpectedBool(TRUE, success, "Should receive from buffer", pass);
    Tests.ExpectedInt(42, result(TestMessagePtr).value, "Should receive first message", pass);
    
    success := CSP.TryReceive(ch, result);
    Tests.ExpectedBool(TRUE, success, "Should receive second message", pass);
    Tests.ExpectedInt(84, result(TestMessagePtr).value, "Should receive second message value", pass);
    
    (* Buffer should now be empty *)
    success := CSP.TryReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Should not receive from empty buffer", pass);
    
    RETURN pass
END TestNonBlockingOperations;

PROCEDURE TestSynchronousChannel*(): BOOLEAN;
VAR 
    ch: CSP.Channel;
    msg: TestMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    
    (* Test synchronous channel (capacity = 0) *)
    ch := CSP.NewChannel(0);
    msg := NewMessage(123);
    
    (* Should not be able to send without receiver *)
    success := CSP.TrySend(ch, msg);
    Tests.ExpectedBool(FALSE, success, "Should not send to sync channel without receiver", pass);
    
    (* Should not be able to receive without sender *)
    success := CSP.TryReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Should not receive from sync channel without sender", pass);
    
    RETURN pass
END TestSynchronousChannel;

PROCEDURE TestProcessCreation*(): BOOLEAN;
VAR 
    proc: CSP.Process;
    sched: CSP.Scheduler;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    
    (* Test process creation *)
    proc := CSP.NewProcess(NIL);
    Tests.ExpectedBool(proc # NIL, TRUE, "Should create process", pass);
    
    (* Test scheduler creation *)
    sched := CSP.NewScheduler();
    Tests.ExpectedBool(sched # NIL, TRUE, "Should create scheduler", pass);
    
    (* Test adding process to scheduler *)
    CSP.AddProcess(sched, proc);
    (* No direct way to test this without exposing internals *)
    
    RETURN pass
END TestProcessCreation;

PROCEDURE SimpleProcess();
BEGIN
    (* Simple process that does nothing *)
END SimpleProcess;

PROCEDURE TestProcessExecution*(): BOOLEAN;
VAR 
    proc: CSP.Process;
    sched: CSP.Scheduler;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    
    sched := CSP.NewScheduler();
    proc := CSP.NewProcess(SimpleProcess);
    
    CSP.AddProcess(sched, proc);
    CSP.Run(sched);
    
    (* If we get here, basic execution worked *)
    Tests.ExpectedBool(TRUE, TRUE, "Process execution completed", pass);
    
    RETURN pass
END TestProcessExecution;

PROCEDURE TestClosedChannel*(): BOOLEAN;
VAR 
    ch: CSP.Channel;
    msg: TestMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    
    ch := CSP.NewChannel(1);
    msg := NewMessage(999);
    
    (* Send a message then close *)
    success := CSP.TrySend(ch, msg);
    Tests.ExpectedBool(TRUE, success, "Should send before closing", pass);
    
    CSP.CloseChannel(ch);
    
    (* Should not be able to send to closed channel *)
    success := CSP.TrySend(ch, NewMessage(888));
    Tests.ExpectedBool(FALSE, success, "Should not send to closed channel", pass);
    
    (* Should still be able to receive buffered message *)
    success := CSP.TryReceive(ch, result);
    Tests.ExpectedBool(TRUE, success, "Should receive buffered message from closed channel", pass);
    Tests.ExpectedInt(999, result(TestMessagePtr).value, "Should receive correct value", pass);
    
    (* No more messages available *)
    success := CSP.TryReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Should not receive from empty closed channel", pass);
    
    RETURN pass
END TestClosedChannel;

PROCEDURE TestChannelDestruction*(): BOOLEAN;
VAR ch: CSP.Channel; pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSP.NewChannel(2);
    Tests.ExpectedBool(FALSE, ch = NIL, "Channel should be created", pass);
    CSP.FreeChannel(ch);
    Tests.ExpectedBool(TRUE, ch = NIL, "Channel should be NIL after FreeChannel", pass);
    RETURN pass
END TestChannelDestruction;

PROCEDURE JoinableProcess();
BEGIN
    (* Simulate work *)
    artPThread.Sleep(100)
END JoinableProcess;

PROCEDURE TestProcessJoin*(): BOOLEAN;
VAR
    proc: CSP.Process;
    ok, pass: BOOLEAN;
BEGIN
    pass := TRUE;
    proc := CSP.NewProcess(JoinableProcess);
    ok := CSP.JoinProcess(proc);
    Tests.ExpectedBool(TRUE, ok, "JoinProcess should succeed", pass);
    (* Second join should fail (already joined) *)
    ok := CSP.JoinProcess(proc);
    Tests.ExpectedBool(FALSE, ok, "JoinProcess should fail on already joined process", pass);
    RETURN pass
END TestProcessJoin;

BEGIN
    Tests.Init(ts, "CSP");
    Tests.Add(ts, TestChannelCreation);
    Tests.Add(ts, TestNonBlockingOperations);
    Tests.Add(ts, TestSynchronousChannel);
    Tests.Add(ts, TestProcessCreation);
    Tests.Add(ts, TestProcessExecution);
    Tests.Add(ts, TestClosedChannel);
    Tests.Add(ts, TestChannelDestruction);
    Tests.Add(ts, TestProcessJoin);
    ASSERT(Tests.Run(ts));
END CSPTest.
