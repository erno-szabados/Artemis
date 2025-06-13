(**
    ExampleTask.Mod - Demonstrates cooperative multitasking with stackless coroutines
    
    This example shows how to use the Task module for cooperative multitasking:
    - Stackless coroutines using resume points and case statements
    - Non-blocking channel communication between tasks
    - Producer-consumer patterns
    - Proper yielding to prevent stack overflow
    
    Key Concepts Demonstrated:
    1. Task contexts extending TaskContextDesc
    2. Resume points for stackless coroutines
    3. Voluntary yielding with Yield() and YieldAt()
    4. Channel-based message passing
    5. Cooperative scheduling without preemption
    
    Copyright (C) 2025
    Released under The 3-Clause BSD License.
*)
MODULE ExampleTask;

IMPORT Task, Collections, Out;

TYPE
    (** Wrapper for INTEGER as Collections.Item for channel messages *)
    IntegerWrapper = RECORD(Collections.Item)
        value: INTEGER
    END;
    IntegerWrapperPtr = POINTER TO IntegerWrapper;

    (** Context for producer task *)
    ProducerContext = POINTER TO ProducerContextDesc;
    ProducerContextDesc = RECORD (Task.TaskContextDesc)
        ch: Task.Channel;
        produced: INTEGER;
        maxItems: INTEGER
    END;

    (** Context for consumer task *)
    ConsumerContext = POINTER TO ConsumerContextDesc;
    ConsumerContextDesc = RECORD (Task.TaskContextDesc)
        ch: Task.Channel;
        consumed: INTEGER;
        total: INTEGER;
        maxItems: INTEGER
    END;

    (** Context for counting task *)
    CounterContext = POINTER TO CounterContextDesc;
    CounterContextDesc = RECORD (Task.TaskContextDesc)
        counter: INTEGER;
        maxCount: INTEGER;
        name: ARRAY 32 OF CHAR
    END;

(** Helper to create integer wrapper messages *)
PROCEDURE NewIntegerWrapper(value: INTEGER): Collections.ItemPtr;
VAR wrapper: IntegerWrapperPtr; result: Collections.ItemPtr;
BEGIN
    NEW(wrapper);
    wrapper.value := value;
    result := wrapper;
    RETURN result
END NewIntegerWrapper;

(** Producer task - creates and sends messages to a channel *)
PROCEDURE ProducerTask(ctx: Task.TaskContext);
VAR pCtx: ProducerContext; msg: Collections.ItemPtr; ok: BOOLEAN;
BEGIN
    pCtx := ctx(ProducerContext);
    
    CASE pCtx.resumePoint OF
    | 0: (* Initialization *)
        Out.String("[Producer] Starting production of "); Out.Int(pCtx.maxItems, 0); Out.String(" items"); Out.Ln;
        pCtx.produced := 0; 
        Task.Yield(ctx)
        
    | 1: (* Production loop *)
        msg := NewIntegerWrapper(pCtx.produced + 100);
        ok := Task.Send(pCtx.ch, msg);
        IF ok THEN 
            INC(pCtx.produced);
            Out.String("[Producer] Produced item #"); Out.Int(pCtx.produced, 0); 
            Out.String(" (value: "); Out.Int(pCtx.produced + 99, 0); Out.String(")"); Out.Ln
        ELSE
            Out.String("[Producer] Channel full, will retry"); Out.Ln
        END;
        
        IF pCtx.produced < pCtx.maxItems THEN
            Task.YieldAt(ctx, 1)  (* Continue producing *)
        ELSE
            Task.Yield(ctx)       (* Move to completion *)
        END
        
    | 2: (* Completion *)
        Out.String("[Producer] Finished! Produced "); Out.Int(pCtx.produced, 0); Out.String(" items total"); Out.Ln
    END
END ProducerTask;

(** Consumer task - receives and processes messages from a channel *)
PROCEDURE ConsumerTask(ctx: Task.TaskContext);
VAR cCtx: ConsumerContext; msg: Collections.ItemPtr; ok: BOOLEAN;
BEGIN
    cCtx := ctx(ConsumerContext);
    
    CASE cCtx.resumePoint OF
    | 0: (* Initialization *)
        Out.String("[Consumer] Starting consumption of "); Out.Int(cCtx.maxItems, 0); Out.String(" items"); Out.Ln;
        cCtx.consumed := 0; 
        cCtx.total := 0; 
        Task.Yield(ctx)
        
    | 1: (* Consumption loop *)
        ok := Task.Receive(cCtx.ch, msg);
        IF ok THEN 
            INC(cCtx.consumed);
            cCtx.total := cCtx.total + msg(IntegerWrapperPtr).value;
            Out.String("[Consumer] Consumed item #"); Out.Int(cCtx.consumed, 0);
            Out.String(" (value: "); Out.Int(msg(IntegerWrapperPtr).value, 0); 
            Out.String(", running total: "); Out.Int(cCtx.total, 0); Out.String(")"); Out.Ln
        ELSE
            Out.String("[Consumer] Channel empty, will retry"); Out.Ln
        END;
        
        IF cCtx.consumed < cCtx.maxItems THEN
            Task.YieldAt(ctx, 1)  (* Continue consuming *)
        ELSE
            Task.Yield(ctx)       (* Move to completion *)
        END
        
    | 2: (* Completion *)
        Out.String("[Consumer] Finished! Consumed "); Out.Int(cCtx.consumed, 0); 
        Out.String(" items, total value: "); Out.Int(cCtx.total, 0); Out.Ln
    END
END ConsumerTask;

(** Simple counting task to demonstrate basic yielding *)
PROCEDURE CounterTask(ctx: Task.TaskContext);
VAR cCtx: CounterContext;
BEGIN
    cCtx := ctx(CounterContext);
    
    CASE cCtx.resumePoint OF
    | 0: (* Initialization *)
        Out.String("["); Out.String(cCtx.name); Out.String("] Starting count to "); Out.Int(cCtx.maxCount, 0); Out.Ln;
        cCtx.counter := 0; 
        Task.Yield(ctx)
        
    | 1: (* Counting loop *)
        INC(cCtx.counter);
        Out.String("["); Out.String(cCtx.name); Out.String("] Count: "); Out.Int(cCtx.counter, 0); Out.Ln;
        
        IF cCtx.counter < cCtx.maxCount THEN
            Task.YieldAt(ctx, 1)  (* Continue counting *)
        ELSE
            Task.Yield(ctx)       (* Move to completion *)
        END
        
    | 2: (* Completion *)
        Out.String("["); Out.String(cCtx.name); Out.String("] Finished counting!"); Out.Ln
    END
END CounterTask;

(** Demonstrate basic cooperative multitasking with multiple counter tasks *)
PROCEDURE DemonstrateBasicMultitasking();
VAR 
    sched: Task.Scheduler;
    ctx1, ctx2: CounterContext;
BEGIN
    Out.String("=== Basic Cooperative Multitasking Demo ==="); Out.Ln;
    Out.String("Two counter tasks will interleave execution through voluntary yielding."); Out.Ln;
    Out.Ln;
    
    sched := Task.NewScheduler();
    
    (* Create two counter tasks *)
    NEW(ctx1); 
    ctx1.maxCount := 3;
    ctx1.name := "TaskA";
    
    NEW(ctx2); 
    ctx2.maxCount := 4;
    ctx2.name := "TaskB";
    
    Task.AddTask(sched, CounterTask, ctx1);
    Task.AddTask(sched, CounterTask, ctx2);
    
    Out.String("Running tasks... (notice interleaved execution)"); Out.Ln;
    Task.Run(sched);
    
    Out.Ln
END DemonstrateBasicMultitasking;

(** Demonstrate producer-consumer pattern with channel communication *)
PROCEDURE DemonstrateProducerConsumer();
VAR 
    sched: Task.Scheduler;
    pCtx: ProducerContext;
    cCtx: ConsumerContext;
    ch: Task.Channel;
BEGIN
    Out.String("=== Producer-Consumer Demo ==="); Out.Ln;
    Out.String("Producer and consumer tasks communicate via a buffered channel."); Out.Ln;
    Out.String("Notice how they cooperate through voluntary yielding and message passing."); Out.Ln;
    Out.Ln;
    
    sched := Task.NewScheduler();
    ch := Task.NewChannel(2);  (* Buffered channel with capacity 2 *)
    
    (* Create producer context *)
    NEW(pCtx); 
    pCtx.ch := ch;
    pCtx.maxItems := 5;
    
    (* Create consumer context *)
    NEW(cCtx); 
    cCtx.ch := ch;
    cCtx.maxItems := 5;
    
    Task.AddTask(sched, ProducerTask, pCtx);
    Task.AddTask(sched, ConsumerTask, cCtx);
    
    Out.String("Running producer and consumer... (notice cooperative message passing)"); Out.Ln;
    Task.Run(sched);
    
    Out.String("Expected total: 100+101+102+103+104 = 510"); Out.Ln;
    Out.Ln
END DemonstrateProducerConsumer;

(** Demonstrate mixed workload: counters + producer-consumer *)
PROCEDURE DemonstrateMixedWorkload();
VAR 
    sched: Task.Scheduler;
    pCtx: ProducerContext;
    cCtx: ConsumerContext;
    counterCtx: CounterContext;
    ch: Task.Channel;
BEGIN
    Out.String("=== Mixed Workload Demo ==="); Out.Ln;
    Out.String("Multiple task types running cooperatively: counter + producer + consumer."); Out.Ln;
    Out.Ln;
    
    sched := Task.NewScheduler();
    ch := Task.NewChannel(1);  (* Smaller buffer to show more interaction *)
    
    (* Create counter task *)
    NEW(counterCtx); 
    counterCtx.maxCount := 3;
    counterCtx.name := "Counter";
    
    (* Create producer *)
    NEW(pCtx); 
    pCtx.ch := ch;
    pCtx.maxItems := 3;
    
    (* Create consumer *)
    NEW(cCtx); 
    cCtx.ch := ch;
    cCtx.maxItems := 3;
    
    Task.AddTask(sched, CounterTask, counterCtx);
    Task.AddTask(sched, ProducerTask, pCtx);
    Task.AddTask(sched, ConsumerTask, cCtx);
    
    Out.String("Running mixed workload... (notice all tasks interleaving)"); Out.Ln;
    Task.Run(sched);
    
    Out.Ln
END DemonstrateMixedWorkload;

(** Main demonstration runner *)
PROCEDURE Run();
BEGIN
    Out.String("Task Module - Cooperative Multitasking Examples"); Out.Ln;
    Out.String("================================================"); Out.Ln;
    Out.Ln;
    
    DemonstrateBasicMultitasking();
    DemonstrateProducerConsumer();
    DemonstrateMixedWorkload();
    
    Out.String("All demonstrations completed!"); Out.Ln;
    Out.String("Key takeaways:"); Out.Ln;
    Out.String("- Tasks yield voluntarily using Yield() and YieldAt()"); Out.Ln;
    Out.String("- Resume points allow stackless coroutine execution"); Out.Ln;
    Out.String("- Channels enable non-blocking message passing"); Out.Ln;
    Out.String("- Cooperative scheduling ensures predictable behavior"); Out.Ln
END Run;

BEGIN
    Run()
END ExampleTask.
