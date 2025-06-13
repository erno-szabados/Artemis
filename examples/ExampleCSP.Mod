(**
    ExampleCSP.Mod - Demonstrates using CSP for concurrent programming patterns.

    This example shows basic CSP concepts including channels, processes,
    and common concurrency patterns like producer-consumer.

    Copyright (C) 2025
    Released under The 3-Clause BSD License.
*)
MODULE ExampleCSP;

IMPORT CSP := CSPThreads, Collections, Out, Chars, artPThread;

TYPE
    (* Example message types *)
    StringMessage = RECORD(Collections.Item)
        text: ARRAY 64 OF CHAR;
        id: INTEGER
    END;
    StringMessagePtr = POINTER TO StringMessage;
    
    NumberMessage = RECORD(Collections.Item)
        value: INTEGER;
        sequence: INTEGER
    END;
    NumberMessagePtr = POINTER TO NumberMessage;

VAR
    (* Global channels for examples *)
    numberChannel: CSP.Channel;
    scheduler: CSP.Scheduler;

(** Helper to create a string message *)
PROCEDURE NewStringMessage(text: ARRAY OF CHAR; id: INTEGER): StringMessagePtr;
VAR msg: StringMessagePtr;
BEGIN
    NEW(msg);
    Chars.Copy(text, msg.text);
    msg.id := id;
    RETURN msg
END NewStringMessage;

(** Helper to create a number message *)
PROCEDURE NewNumberMessage(value, sequence: INTEGER): NumberMessagePtr;
VAR msg: NumberMessagePtr;
BEGIN
    NEW(msg);
    msg.value := value;
    msg.sequence := sequence;
    RETURN msg
END NewNumberMessage;

(** Basic channel operations example *)
PROCEDURE DemonstrateBasicChannels();
VAR
    ch: CSP.Channel;
    msg: StringMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
BEGIN
    Out.String("=== Basic Channel Operations ==="); Out.Ln;
    
    (* Create a buffered channel with capacity 3 *)
    ch := CSP.NewChannel(3);
    Out.String("Created buffered channel (capacity: 3)"); Out.Ln;
    
    (* Send some messages *)
    msg := NewStringMessage("Hello", 1);
    success := CSP.TrySend(ch, msg);
    Out.String("Send 'Hello': ");
    IF success THEN Out.String("SUCCESS") ELSE Out.String("FAILED") END;
    Out.Ln;
    
    msg := NewStringMessage("World", 2);
    success := CSP.TrySend(ch, msg);
    Out.String("Send 'World': ");
    IF success THEN Out.String("SUCCESS") ELSE Out.String("FAILED") END;
    Out.Ln;
    
    msg := NewStringMessage("CSP", 3);
    success := CSP.TrySend(ch, msg);
    Out.String("Send 'CSP': ");
    IF success THEN Out.String("SUCCESS") ELSE Out.String("FAILED") END;
    Out.Ln;
    
    (* Try to send when buffer is full *)
    msg := NewStringMessage("Overflow", 4);
    success := CSP.TrySend(ch, msg);
    Out.String("Send 'Overflow' (should fail): ");
    IF success THEN Out.String("SUCCESS") ELSE Out.String("FAILED") END;
    Out.Ln;
    
    (* Receive messages *)
    Out.String("Receiving messages:"); Out.Ln;
    success := CSP.TryReceive(ch, result);
    IF success & (result # NIL) THEN
        Out.String("  Received: "); Out.String(result(StringMessagePtr).text);
        Out.String(" (id: "); Out.Int(result(StringMessagePtr).id, 0); Out.String(")");
    END;
    Out.Ln;
    
    success := CSP.TryReceive(ch, result);
    IF success & (result # NIL) THEN
        Out.String("  Received: "); Out.String(result(StringMessagePtr).text);
        Out.String(" (id: "); Out.Int(result(StringMessagePtr).id, 0); Out.String(")");
    END;
    Out.Ln;
    
    success := CSP.TryReceive(ch, result);
    IF success & (result # NIL) THEN
        Out.String("  Received: "); Out.String(result(StringMessagePtr).text);
        Out.String(" (id: "); Out.Int(result(StringMessagePtr).id, 0); Out.String(")");
    END;
    Out.Ln;
    
    (* Try to receive from empty channel *)
    success := CSP.TryReceive(ch, result);
    Out.String("Receive from empty channel: ");
    IF success THEN Out.String("SUCCESS") ELSE Out.String("FAILED (expected)") END;
    Out.Ln;
    
    Out.Ln
END DemonstrateBasicChannels;

(** Synchronous channel example *)
PROCEDURE DemonstrateSynchronousChannels();
VAR
    syncCh: CSP.Channel;
    msg: NumberMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
BEGIN
    Out.String("=== Synchronous Channel Operations ==="); Out.Ln;
    
    (* Create a synchronous channel (capacity 0) *)
    syncCh := CSP.NewChannel(0);
    Out.String("Created synchronous channel (capacity: 0)"); Out.Ln;
    
    (* Try to send without receiver - should fail *)
    msg := NewNumberMessage(42, 1);
    success := CSP.TrySend(syncCh, msg);
    Out.String("Send without receiver: ");
    IF success THEN Out.String("SUCCESS") ELSE Out.String("FAILED (expected)") END;
    Out.Ln;
    
    (* Try to receive without sender - should fail *)
    success := CSP.TryReceive(syncCh, result);
    Out.String("Receive without sender: ");
    IF success THEN Out.String("SUCCESS") ELSE Out.String("FAILED (expected)") END;
    Out.Ln;
    
    Out.String("Note: Synchronous channels require coordination between sender and receiver"); Out.Ln;
    Out.Ln
END DemonstrateSynchronousChannels;

(** Channel closing example *)
PROCEDURE DemonstrateChannelClosing();
VAR
    ch: CSP.Channel;
    msg: StringMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
BEGIN
    Out.String("=== Channel Closing ==="); Out.Ln;
    
    ch := CSP.NewChannel(2);
    
    (* Send a message then close *)
    msg := NewStringMessage("Final", 99);
    success := CSP.TrySend(ch, msg);
    Out.String("Send before closing: ");
    IF success THEN Out.String("SUCCESS") ELSE Out.String("FAILED") END;
    Out.Ln;
    
    CSP.CloseChannel(ch);
    Out.String("Channel closed"); Out.Ln;
    
    (* Try to send to closed channel *)
    msg := NewStringMessage("After", 100);
    success := CSP.TrySend(ch, msg);
    Out.String("Send to closed channel: ");
    IF success THEN Out.String("SUCCESS") ELSE Out.String("FAILED (expected)") END;
    Out.Ln;
    
    (* Can still receive buffered messages *)
    success := CSP.TryReceive(ch, result);
    Out.String("Receive buffered message: ");
    IF success THEN 
        Out.String("SUCCESS - "); Out.String(result(StringMessagePtr).text)
    ELSE 
        Out.String("FAILED") 
    END;
    Out.Ln;
    
    (* No more messages available *)
    success := CSP.TryReceive(ch, result);
    Out.String("Receive from empty closed channel: ");
    IF success THEN Out.String("SUCCESS") ELSE Out.String("FAILED (expected)") END;
    Out.Ln;
    
    Out.Ln
END DemonstrateChannelClosing;

(** Simple process procedures for demonstration *)
PROCEDURE ProducerProcess();
VAR 
    msg: NumberMessagePtr;
    success: BOOLEAN;
    i: INTEGER;
BEGIN
    Out.String("Producer: Starting..."); Out.Ln;
    FOR i := 1 TO 5 DO
        msg := NewNumberMessage(i * 10, i);
        success := CSP.TrySend(numberChannel, msg);
        Out.String("Producer: Sent value "); Out.Int(i * 10, 0);
        IF success THEN Out.String(" - SUCCESS") ELSE Out.String(" - FAILED") END;
        Out.Ln
    END;
    Out.String("Producer: Finished"); Out.Ln
END ProducerProcess;

PROCEDURE ConsumerProcess();
VAR 
    result: Collections.ItemPtr;
    success: BOOLEAN;
    count, attempts: INTEGER;
BEGIN
    Out.String("Consumer: Starting..."); Out.Ln;
    count := 0;
    attempts := 0;
    WHILE (count < 5) & (attempts < 100) DO  (* Add attempt limit to prevent infinite loop *)
        success := CSP.TryReceive(numberChannel, result);
        IF success & (result # NIL) THEN
            Out.String("Consumer: Received value "); 
            Out.Int(result(NumberMessagePtr).value, 0);
            Out.String(" (sequence: "); Out.Int(result(NumberMessagePtr).sequence, 0); Out.String(")");
            Out.Ln;
            INC(count)
        END;
        INC(attempts)
        (* Note: In a real implementation, would yield or sleep here *)
    END;
    Out.String("Consumer: Finished (received "); Out.Int(count, 0); Out.String(" messages)"); Out.Ln
END ConsumerProcess;

(** Process and scheduler example *)
PROCEDURE DemonstrateProcesses();
VAR
    producer, consumer: CSP.Process;
    msg: NumberMessagePtr;
    result: Collections.ItemPtr;
    success: BOOLEAN;
    i: INTEGER;
BEGIN
    Out.String("=== Process and Scheduler Demo ==="); Out.Ln;
    
    (* Create a buffered channel for producer-consumer *)
    numberChannel := CSP.NewChannel(3);
    Out.String("Created shared channel for producer-consumer"); Out.Ln;
    
    (* First, demonstrate manual producer-consumer with channel *)
    Out.String("Manual producer-consumer demonstration:"); Out.Ln;
    
    (* Produce some messages *)
    Out.String("Producing messages..."); Out.Ln;
    FOR i := 1 TO 3 DO
        msg := NewNumberMessage(i * 100, i);
        success := CSP.TrySend(numberChannel, msg);
        Out.String("  Sent value "); Out.Int(i * 100, 0);
        IF success THEN Out.String(" - SUCCESS") ELSE Out.String(" - FAILED") END;
        Out.Ln
    END;
    
    (* Consume the messages *)
    Out.String("Consuming messages..."); Out.Ln;
    FOR i := 1 TO 3 DO
        success := CSP.TryReceive(numberChannel, result);
        IF success & (result # NIL) THEN
            Out.String("  Received value "); 
            Out.Int(result(NumberMessagePtr).value, 0);
            Out.String(" (sequence: "); Out.Int(result(NumberMessagePtr).sequence, 0); Out.String(")");
            Out.Ln
        ELSE
            Out.String("  Failed to receive message"); Out.Ln
        END
    END;
    
    (* Now demonstrate process creation and scheduling *)
    Out.String("Process scheduling demonstration:"); Out.Ln;
    producer := CSP.NewProcess(ProducerProcess);
    consumer := CSP.NewProcess(ConsumerProcess);
    Out.String("Created producer and consumer processes"); Out.Ln;
    
    (* Create scheduler and add processes *)
    scheduler := CSP.NewScheduler();
    CSP.AddProcess(scheduler, producer);
    CSP.AddProcess(scheduler, consumer);
    Out.String("Added processes to scheduler"); Out.Ln;
    
    (* Run the scheduler *)
    Out.String("Running scheduler..."); Out.Ln;
    CSP.Run(scheduler);
    Out.String("Scheduler finished"); Out.Ln;
    
    Out.Ln
END DemonstrateProcesses;

(** Status reporting process *)
PROCEDURE StatusProcess();
VAR i: INTEGER;
BEGIN
    Out.String("Status: Process running..."); Out.Ln;
    FOR i := 1 TO 3 DO
        Out.String("Status: Heartbeat "); Out.Int(i, 0); Out.Ln
    END;
    Out.String("Status: Process complete"); Out.Ln
END StatusProcess;

(** Demonstrate multiple concurrent processes *)
PROCEDURE DemonstrateMultipleProcesses();
VAR
    status1, status2, status3: CSP.Process;
    multiScheduler: CSP.Scheduler;
BEGIN
    Out.String("=== Multiple Processes Demo ==="); Out.Ln;
    
    (* Create multiple status processes *)
    status1 := CSP.NewProcess(StatusProcess);
    status2 := CSP.NewProcess(StatusProcess);
    status3 := CSP.NewProcess(StatusProcess);
    
    (* Create scheduler and add all processes *)
    multiScheduler := CSP.NewScheduler();
    CSP.AddProcess(multiScheduler, status1);
    CSP.AddProcess(multiScheduler, status2);
    CSP.AddProcess(multiScheduler, status3);
    
    Out.String("Created 3 status processes"); Out.Ln;
    Out.String("Running all processes..."); Out.Ln;
    CSP.Run(multiScheduler);
    Out.String("All processes finished"); Out.Ln;
    
    Out.Ln
END DemonstrateMultipleProcesses;

(* --- True concurrent producer-consumer demo --- *)
PROCEDURE BlockingProducerProcess();
VAR 
    msg: NumberMessagePtr;
    i: INTEGER;
BEGIN
    Out.String("[BlockingProducer] Starting..."); Out.Ln;
    FOR i := 1 TO 5 DO
        msg := NewNumberMessage(i * 10, i);
        CSP.Send(numberChannel, msg);
        Out.String("[BlockingProducer] Sent value "); Out.Int(i * 10, 0); Out.Ln
    END;
    Out.String("[BlockingProducer] Finished"); Out.Ln
END BlockingProducerProcess;

PROCEDURE BlockingConsumerProcess();
VAR 
    result: Collections.ItemPtr;
    count: INTEGER;
BEGIN
    Out.String("[BlockingConsumer] Starting..."); Out.Ln;
    count := 0;
    WHILE count < 5 DO
        CSP.Receive(numberChannel, result);
        IF result # NIL THEN
            Out.String("[BlockingConsumer] Received value "); 
            Out.Int(result(NumberMessagePtr).value, 0);
            Out.String(" (sequence: "); Out.Int(result(NumberMessagePtr).sequence, 0); Out.String(")");
            Out.Ln;
            INC(count)
        END
    END;
    Out.String("[BlockingConsumer] Finished (received "); Out.Int(count, 0); Out.String(" messages)"); Out.Ln
END BlockingConsumerProcess;

PROCEDURE DemonstrateTrueConcurrency();
VAR
    prod, cons: CSP.Process;
    i: INTEGER;
BEGIN
    Out.String("=== True Concurrency Demo ==="); Out.Ln;
    numberChannel := CSP.NewChannel(2);
    Out.String("Created shared channel for blocking producer-consumer"); Out.Ln;
    prod := CSP.NewProcess(BlockingProducerProcess);
    cons := CSP.NewProcess(BlockingConsumerProcess);
    Out.String("Created producer and consumer processes (threads)"); Out.Ln;
    (* Let threads run concurrently; join by sleeping main thread *)
    FOR i := 1 TO 10 DO
        artPThread.Sleep(100);
    END;
    Out.String("Main thread done waiting. (Check output above for interleaving)"); Out.Ln;
    Out.Ln
END DemonstrateTrueConcurrency;

(* Demonstrate joining a CSP process (waiting for completion) *)
PROCEDURE JoinableExampleProcess();
VAR i: INTEGER;
BEGIN
    Out.String("[JoinableProcess] Working..."); Out.Ln;
    FOR i := 1 TO 3 DO
        Out.String("[JoinableProcess] Step "); Out.Int(i, 0); Out.Ln;
        artPThread.Sleep(100)
    END;
    Out.String("[JoinableProcess] Done!"); Out.Ln
END JoinableExampleProcess;

PROCEDURE DemonstrateProcessJoin();
VAR proc: CSP.Process; ok: BOOLEAN;
BEGIN
    Out.String("=== Process Join Demo ==="); Out.Ln;
    proc := CSP.NewProcess(JoinableExampleProcess);
    Out.String("Started joinable process (thread)"); Out.Ln;
    ok := CSP.JoinProcess(proc);
    IF ok THEN
        Out.String("Main: Successfully joined process.")
    ELSE
        Out.String("Main: Failed to join process!")
    END;
    Out.Ln; Out.Ln
END DemonstrateProcessJoin;

(** Main demonstration *)
PROCEDURE Run*();
BEGIN
    Out.String("CSP (Communicating Sequential Processes) Examples"); Out.Ln;
    Out.String("=================================================="); Out.Ln;
    Out.Ln;
    
    DemonstrateBasicChannels();
    DemonstrateSynchronousChannels();
    DemonstrateChannelClosing();
    DemonstrateProcesses();
    DemonstrateMultipleProcesses();
    DemonstrateTrueConcurrency();
    DemonstrateProcessJoin();
    
    Out.String("CSP Examples Complete!"); Out.Ln
END Run;

BEGIN
    Run()
END ExampleCSP.
