(**
    CSPCoopTest.Mod - Tests for CSPCoop (cooperative, portable CSP)
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
*)
MODULE CSPCoopTest;

IMPORT CSPCoop, Collections, Tests;

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
    ch: CSPCoop.Channel;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPCoop.NewChannel(0);
    Tests.ExpectedBool(FALSE, CSPCoop.IsClosed(ch), "New channel should be open", pass);
    ch := CSPCoop.NewChannel(5);
    Tests.ExpectedBool(FALSE, CSPCoop.IsClosed(ch), "New buffered channel should be open", pass);
    CSPCoop.CloseChannel(ch);
    Tests.ExpectedBool(TRUE, CSPCoop.IsClosed(ch), "Closed channel should report closed", pass);
    RETURN pass
END TestChannelCreation;

PROCEDURE TestNonBlockingOperations*(): BOOLEAN;
VAR 
    ch: CSPCoop.Channel;
    msg1, msg2: TestMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPCoop.NewChannel(2);
    msg1 := NewMessage(42);
    msg2 := NewMessage(84);
    success := CSPCoop.TrySend(ch, msg1);
    Tests.ExpectedBool(TRUE, success, "Should send to empty buffer", pass);
    success := CSPCoop.TrySend(ch, msg2);
    Tests.ExpectedBool(TRUE, success, "Should send to buffer with space", pass);
    success := CSPCoop.TrySend(ch, NewMessage(126));
    Tests.ExpectedBool(FALSE, success, "Should not send to full buffer", pass);
    success := CSPCoop.TryReceive(ch, result);
    Tests.ExpectedBool(TRUE, success, "Should receive from buffer", pass);
    Tests.ExpectedInt(42, result(TestMessagePtr).value, "Should receive first message", pass);
    success := CSPCoop.TryReceive(ch, result);
    Tests.ExpectedBool(TRUE, success, "Should receive second message", pass);
    Tests.ExpectedInt(84, result(TestMessagePtr).value, "Should receive second message value", pass);
    success := CSPCoop.TryReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Should not receive from empty buffer", pass);
    RETURN pass
END TestNonBlockingOperations;

PROCEDURE TestSynchronousChannel*(): BOOLEAN;
VAR 
    ch: CSPCoop.Channel;
    msg: TestMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPCoop.NewChannel(0);
    msg := NewMessage(123);
    success := CSPCoop.TrySend(ch, msg);
    Tests.ExpectedBool(FALSE, success, "Should not send to sync channel without receiver", pass);
    success := CSPCoop.TryReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Should not receive from sync channel without sender", pass);
    RETURN pass
END TestSynchronousChannel;

PROCEDURE TestProcessCreation*(): BOOLEAN;
VAR 
    proc: CSPCoop.Process;
    sched: CSPCoop.Scheduler;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    proc := CSPCoop.NewProcess(NIL);
    Tests.ExpectedBool(proc # NIL, TRUE, "Should create process", pass);
    sched := CSPCoop.NewScheduler();
    Tests.ExpectedBool(sched # NIL, TRUE, "Should create scheduler", pass);
    CSPCoop.AddProcess(sched, proc);
    RETURN pass
END TestProcessCreation;

PROCEDURE SimpleProcess();
BEGIN
END SimpleProcess;

PROCEDURE TestProcessExecution*(): BOOLEAN;
VAR 
    proc: CSPCoop.Process;
    sched: CSPCoop.Scheduler;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    sched := CSPCoop.NewScheduler();
    proc := CSPCoop.NewProcess(SimpleProcess);
    CSPCoop.AddProcess(sched, proc);
    CSPCoop.Run(sched);
    Tests.ExpectedBool(TRUE, TRUE, "Process execution completed", pass);
    RETURN pass
END TestProcessExecution;

PROCEDURE TestClosedChannel*(): BOOLEAN;
VAR 
    ch: CSPCoop.Channel;
    msg: TestMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPCoop.NewChannel(1);
    msg := NewMessage(999);
    success := CSPCoop.TrySend(ch, msg);
    Tests.ExpectedBool(TRUE, success, "Should send before closing", pass);
    CSPCoop.CloseChannel(ch);
    success := CSPCoop.TrySend(ch, NewMessage(888));
    Tests.ExpectedBool(FALSE, success, "Should not send to closed channel", pass);
    success := CSPCoop.TryReceive(ch, result);
    Tests.ExpectedBool(TRUE, success, "Should receive buffered message from closed channel", pass);
    Tests.ExpectedInt(999, result(TestMessagePtr).value, "Should receive correct value", pass);
    success := CSPCoop.TryReceive(ch, result);
    Tests.ExpectedBool(FALSE, success, "Should not receive from empty closed channel", pass);
    RETURN pass
END TestClosedChannel;

PROCEDURE TestChannelDestruction*(): BOOLEAN;
VAR ch: CSPCoop.Channel; pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := CSPCoop.NewChannel(2);
    Tests.ExpectedBool(FALSE, ch = NIL, "Channel should be created", pass);
    CSPCoop.FreeChannel(ch);
    Tests.ExpectedBool(TRUE, ch = NIL, "Channel should be NIL after FreeChannel", pass);
    RETURN pass
END TestChannelDestruction;

BEGIN
    Tests.Init(ts, "CSPCoop Tests");
    Tests.Add(ts, TestChannelCreation);
    Tests.Add(ts, TestNonBlockingOperations);
    Tests.Add(ts, TestSynchronousChannel);
    Tests.Add(ts, TestProcessCreation);
    Tests.Add(ts, TestProcessExecution);
    Tests.Add(ts, TestClosedChannel);
    Tests.Add(ts, TestChannelDestruction);
    ASSERT(Tests.Run(ts));
END CSPCoopTest.
