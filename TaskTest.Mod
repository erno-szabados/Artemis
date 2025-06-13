(**
    TaskTest.Mod - Minimal tests for Task cooperative scheduler and channels
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
*)
MODULE TaskTest;

IMPORT Task, Tests, Out, Collections;

TYPE
    (** Wrapper for INTEGER a Collections.Item *)
    IntegerWrapper* = RECORD(Collections.Item)
        value*: INTEGER
    END;
    IntegerWrapperPtr* = POINTER TO IntegerWrapper;

    MyContext = POINTER TO MyContextDesc;
    MyContextDesc = RECORD (Task.TaskContextDesc)
        value: INTEGER
    END;

VAR ts: Tests.TestSet;

PROCEDURE MyTask(ctx: Task.TaskContext);
BEGIN
  IF ctx IS MyContext THEN
    Out.String("Task ran with value: "); Out.Int(ctx(MyContext).value, 0); Out.Ln;
    ctx(MyContext).value := 255
  END
END MyTask;

(** Create a new dictionary wrapper *)
PROCEDURE NewIntegerWrapper(i: INTEGER): Collections.ItemPtr;
VAR wrapper: IntegerWrapperPtr; result: Collections.ItemPtr;
BEGIN
    NEW(wrapper);
    wrapper.value := i;
    result := wrapper;
    RETURN result
END NewIntegerWrapper;

PROCEDURE TestChannelSendReceive(): BOOLEAN;
VAR ch: Task.Channel; ok: BOOLEAN; pass: BOOLEAN; msg, out : Collections.ItemPtr;
BEGIN
    msg := NewIntegerWrapper(42);
    pass := TRUE;
    ch := Task.NewChannel(2);
    ok := Task.Send(ch, msg);
    Tests.ExpectedBool(TRUE, ok, "Send should succeed", pass);
    ok := Task.Receive(ch, out);
    Tests.ExpectedBool(TRUE, ok, "Receive should succeed", pass);
    Tests.ExpectedInt(42, out(IntegerWrapperPtr).value, "Received value should match sent value", pass);
    RETURN pass
END TestChannelSendReceive;

PROCEDURE TestChannelBufferLimits(): BOOLEAN;
VAR ch: Task.Channel; ok: BOOLEAN; pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := Task.NewChannel(1);
    ok := Task.Send(ch, NewIntegerWrapper(1));
    Tests.ExpectedBool(TRUE, ok, "Send to empty buffer should succeed", pass);
    ok := Task.Send(ch, NewIntegerWrapper(2));
    Tests.ExpectedBool(FALSE, ok, "Send to full buffer should fail", pass);
    RETURN pass
END TestChannelBufferLimits;

PROCEDURE TestChannelEmptyReceive(): BOOLEAN;
VAR ch: Task.Channel; out: Collections.ItemPtr; ok: BOOLEAN; pass: BOOLEAN;
BEGIN
    pass := TRUE;
    ch := Task.NewChannel(1);
    ok := Task.Receive(ch, out);
    Tests.ExpectedBool(FALSE, ok, "Receive from empty buffer should fail", pass);
    RETURN pass
END TestChannelEmptyReceive;



PROCEDURE TestScheduler(): BOOLEAN;
VAR sched: Task.Scheduler; ctx : MyContext; pass: BOOLEAN;
BEGIN
    pass := TRUE;
    sched := Task.NewScheduler();
    NEW(ctx); ctx.value := 42;
    Task.AddTask(sched, MyTask, ctx);
    Task.Run(sched);
    Tests.ExpectedBool(TRUE, ctx.value = 255, "Task should update the context value.", pass);
    RETURN pass
END TestScheduler; 

BEGIN
    Tests.Init(ts, "Task Tests");
    Tests.Add(ts, TestChannelSendReceive);
    Tests.Add(ts, TestChannelBufferLimits);
    Tests.Add(ts, TestChannelEmptyReceive);
    Tests.Add(ts, TestScheduler);
    IF ~Tests.Run(ts) THEN
        Out.String("Some Task tests failed."); Out.Ln
    END
END TaskTest.
