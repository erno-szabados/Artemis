# Concurrency in Artemis

This guide covers the basic concurrency modules in the Artemis project: `Threads` and `BufferedChannels`. These provide simple, practical tools for concurrent programming in Oberon-07.

## Overview

The concurrency system is based on two main concepts:
- **Threads**: Independent execution units
- **BufferedChannels**: Thread-safe communication between threads

This is a barebones implementation focused on practical use cases rather than theoretical completeness.

## Basic Threading with `Threads`

### Creating and Starting Threads

```oberon
IMPORT Threads;

VAR worker: Threads.Thread;

PROCEDURE WorkerProc();
BEGIN
    (* Your worker logic here *)
END WorkerProc;

worker := Threads.NewThread(WorkerProc);  (* Creates and starts immediately *)
```

**Important Notes:**
- Threads start immediately when created with `NewThread`
- Worker procedures must have no parameters (`PROCEDURE` not `PROCEDURE(params)`)
- Use global variables or channels to pass data to workers

### Waiting for Threads

```oberon
VAR ok: BOOLEAN;
ok := Threads.JoinThread(worker);  (* Wait for worker to complete *)
```

Always join threads before your main program exits, or workers will be killed prematurely.

## Communication with `BufferedChannels`

### Creating Channels

```oberon
IMPORT BufferedChannels, Collections;

VAR 
    jobChan: BufferedChannels.BufferedChannel;
    
jobChan := BufferedChannels.NewChannel(16);  (* Buffer size of 16 *)
```

### Sending Data

```oberon
TYPE
    Job = POINTER TO JobDesc;
    JobDesc = RECORD (Collections.Item)
        filename: ARRAY 256 OF CHAR
    END;

VAR job: Job;
NEW(job);
job.filename := "example.txt";
BufferedChannels.Send(jobChan, job);  (* Blocking send *)
```

**Requirements:**
- All data sent through channels must extend `Collections.Item`
- Use pointer types (`POINTER TO RECORD`)

### Receiving Data

```oberon
VAR 
    item: Collections.ItemPtr;
    job: Job;
    hasData: BOOLEAN;

hasData := BufferedChannels.TryReceive(jobChan, item);  (* Non-blocking *)
IF hasData & (item # NIL) THEN
    job := item(Job);  (* Type guard to cast back *)
    (* Process the job *)
END
```

### Closing Channels

```oberon
BufferedChannels.Close(jobChan);  (* Signal no more data *)
```

Workers can check if a channel is closed:
```oberon
IF ~hasData & BufferedChannels.IsClosed(jobChan) THEN
    (* No more work, exit worker loop *)
END
```

## Real Example: Directory Checksumming

Here's a complete example that demonstrates the typical pattern:

```oberon
MODULE ExampleDirChecksum;

IMPORT Threads, BufferedChannels, Collections, Files, CRC32;

TYPE
    FileJob = POINTER TO FileJobDesc;
    FileJobDesc = RECORD (Collections.Item)
        name: ARRAY 256 OF CHAR
    END;

VAR
    jobChan, resultChan: BufferedChannels.BufferedChannel;
    worker1, worker2: Threads.Thread;

PROCEDURE WorkerThread();
VAR
    item: Collections.ItemPtr;
    job: FileJob;
    hasJob: BOOLEAN;
    (* ... other variables ... *)
BEGIN
    REPEAT
        hasJob := BufferedChannels.TryReceive(jobChan, item);
        IF hasJob & (item # NIL) THEN
            job := item(FileJob);
            (* Calculate checksum for job.name *)
            (* Send result to resultChan *)
        END
    UNTIL ~hasJob & BufferedChannels.IsClosed(jobChan)
END WorkerThread;

BEGIN
    (* Setup channels *)
    jobChan := BufferedChannels.NewChannel(16);
    resultChan := BufferedChannels.NewChannel(16);
    
    (* Start workers *)
    worker1 := Threads.NewThread(WorkerThread);
    worker2 := Threads.NewThread(WorkerThread);
    
    (* Queue work ... *)
    
    (* Signal completion *)
    BufferedChannels.Close(jobChan);
    
    (* Wait for workers *)
    Threads.JoinThread(worker1);
    Threads.JoinThread(worker2);
    
    (* Collect results ... *)
END ExampleDirChecksum.
```

## Typical Patterns

### Producer-Consumer
1. Create buffered channel
2. Start consumer threads
3. Producer queues work items
4. Close channel when done
5. Join threads before exit

### Worker Pool
1. Create job and result channels
2. Start fixed number of workers
3. Workers loop on `TryReceive` until channel closed
4. Join all workers before collecting results

## Limitations

This is a basic implementation with some constraints:

- **No parameterized thread procedures** - use global variables or channels for data
- **Manual thread management** - no built-in worker pool abstraction  
- **Collections.Item requirement** - all channel data must extend this type
- **Global state dependency** - workers typically access module-level channels
- **Basic error handling** - limited support for error propagation

## When to Use

This concurrency system works well for:
- File processing tasks
- Parallel computation
- Producer-consumer patterns
- Simple worker pools

It's probably not suitable for:
- Complex coordination requirements
- Fine-grained parallelism
- Real-time systems
- Applications requiring guaranteed latency

## Performance Notes

- `TryReceive` is non-blocking but may use CPU in tight loops
- Consider adding small delays in worker loops if appropriate
- Buffer sizes affect memory usage vs. contention trade-offs
- Thread creation has overhead - reuse workers when possible

This gives you basic but functional concurrent programming capabilities in Oberon-07.
