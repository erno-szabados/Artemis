(**
    TaskTest.Mod - Minimal tests for Task cooperative scheduler and channels
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
*)
MODULE TaskTest;

IMPORT Task, Tests, Out, Collections;

TYPE
    (** Wrapper for INTEGER - a Collections.Item *)
    IntegerWrapper* = RECORD(Collections.Item)
        value*: INTEGER
    END;
    IntegerWrapperPtr* = POINTER TO IntegerWrapper;

    (* Context descriptor - pass data to tasks. *)
    MyContext = POINTER TO MyContextDesc;
    MyContextDesc = RECORD (Task.TaskContextDesc)
        value: INTEGER;
        counter: INTEGER;
        phase: INTEGER
    END;

    ProducerContext = POINTER TO ProducerContextDesc;
    ProducerContextDesc = RECORD (Task.TaskContextDesc)
        ch: Task.Channel;
        produced: INTEGER
    END;

    ConsumerContext = POINTER TO ConsumerContextDesc;
    ConsumerContextDesc = RECORD (Task.TaskContextDesc)
        ch: Task.Channel;
        consumed: INTEGER;
        total: INTEGER
    END;

VAR ts: Tests.TestSet;

(** Create a new INTEGER wrapper *)
PROCEDURE NewIntegerWrapper(i: INTEGER): Collections.ItemPtr;
VAR wrapper: IntegerWrapperPtr; result: Collections.ItemPtr;
BEGIN
    NEW(wrapper);
    wrapper.value := i;
    result := wrapper;
    RETURN result
END NewIntegerWrapper;

PROCEDURE MyTask(ctx: Task.TaskContext);
VAR myCtx: MyContext;
BEGIN
  myCtx := ctx(MyContext);
  
  CASE myCtx.resumePoint OF
  | 0: (* Initialization *)
    Out.String("Task starting, value="); Out.Int(myCtx.value, 0); Out.Ln;
    myCtx.counter := 0; Task.Yield(ctx)
  | 1: (* Work phase *)
    INC(myCtx.counter); Out.String("Working, counter="); Out.Int(myCtx.counter, 0); Out.Ln;
    IF myCtx.counter < 3 THEN Task.YieldAt(ctx, 1) ELSE Task.Yield(ctx) END
  | 2: (* Completion *)
    myCtx.value := 255; Out.String("Task completed, value="); Out.Int(myCtx.value, 0); Out.Ln
  END
END MyTask;

PROCEDURE ProducerTask(ctx: Task.TaskContext);
VAR pCtx: ProducerContext; msg: Collections.ItemPtr; ok: BOOLEAN;
BEGIN
  pCtx := ctx(ProducerContext);
  
  CASE pCtx.resumePoint OF
  | 0: (* Start producing *)
    pCtx.produced := 0; Task.Yield(ctx)
  | 1: (* Produce items *)
    msg := NewIntegerWrapper(pCtx.produced + 100);
    ok := Task.Send(pCtx.ch, msg);
    IF ok THEN 
      INC(pCtx.produced); Out.String("Produced: "); Out.Int(pCtx.produced + 99, 0); Out.Ln 
    END;
    IF pCtx.produced < 3 THEN Task.YieldAt(ctx, 1) ELSE Task.Yield(ctx) END
  | 2: (* Finished *)
    Out.String("Producer finished"); Out.Ln
  END
END ProducerTask;

PROCEDURE ConsumerTask(ctx: Task.TaskContext);
VAR cCtx: ConsumerContext; msg: Collections.ItemPtr; ok: BOOLEAN;
BEGIN
  cCtx := ctx(ConsumerContext);
  
  CASE cCtx.resumePoint OF
  | 0: (* Start consuming *)
    cCtx.consumed := 0; cCtx.total := 0; Task.Yield(ctx)
  | 1: (* Consume items *)
    ok := Task.Receive(cCtx.ch, msg);
    IF ok THEN 
      INC(cCtx.consumed); 
      cCtx.total := cCtx.total + msg(IntegerWrapperPtr).value;
      Out.String("Consumed: "); Out.Int(msg(IntegerWrapperPtr).value, 0); Out.Ln 
    END;
    IF cCtx.consumed < 3 THEN Task.YieldAt(ctx, 1) ELSE Task.Yield(ctx) END
  | 2: (* Finished *)
    Out.String("Consumer finished, total="); Out.Int(cCtx.total, 0); Out.Ln
  END
END ConsumerTask;

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

PROCEDURE TestYielding(): BOOLEAN;
VAR sched: Task.Scheduler; ctx1, ctx2: MyContext; pass: BOOLEAN;
BEGIN
    pass := TRUE;
    Out.String("=== Testing Yielding ==="); Out.Ln;
    sched := Task.NewScheduler();
    
    (* Add two tasks that will interleave *)
    NEW(ctx1); ctx1.value := 10;
    NEW(ctx2); ctx2.value := 20;
    
    Task.AddTask(sched, MyTask, ctx1);
    Task.AddTask(sched, MyTask, ctx2);
    Task.Run(sched);
    
    Tests.ExpectedBool(TRUE, ctx1.value = 255, "First task should complete", pass);
    Tests.ExpectedBool(TRUE, ctx2.value = 255, "Second task should complete", pass);
    Out.Ln;
    RETURN pass
END TestYielding;

PROCEDURE TestProducerConsumer(): BOOLEAN;
VAR sched: Task.Scheduler; pCtx: ProducerContext; cCtx: ConsumerContext; ch: Task.Channel; pass: BOOLEAN;
BEGIN
    pass := TRUE;
    Out.String("=== Testing Producer-Consumer ==="); Out.Ln;
    sched := Task.NewScheduler();
    ch := Task.NewChannel(2);
    
    NEW(pCtx); pCtx.ch := ch;
    NEW(cCtx); cCtx.ch := ch;
    
    Task.AddTask(sched, ProducerTask, pCtx);
    Task.AddTask(sched, ConsumerTask, cCtx);
    Task.Run(sched);
    
    Tests.ExpectedInt(3, cCtx.consumed, "Consumer should receive 3 items", pass);
    Tests.ExpectedInt(303, cCtx.total, "Consumer total should be 100+101+102=303", pass);
    Out.Ln;
    RETURN pass
END TestProducerConsumer; 

BEGIN
    Tests.Init(ts, "Task Tests");
    Tests.Add(ts, TestChannelSendReceive);
    Tests.Add(ts, TestChannelBufferLimits);
    Tests.Add(ts, TestChannelEmptyReceive);
    Tests.Add(ts, TestScheduler);
    Tests.Add(ts, TestYielding);
    Tests.Add(ts, TestProducerConsumer);
    IF ~Tests.Run(ts) THEN
        Out.String("Some Task tests failed."); Out.Ln
    END
END TaskTest.
