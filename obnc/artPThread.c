/*
 * artPThread.c - POSIX threads wrapper for artPThread.obn
 *
 * Copyright (C) 2025
 *
 * Released under The 3-Clause BSD License.
 * See https://opensource.org/licenses/BSD-3-Clause
 */

#include ".obnc/artPThread.h"
#include <obnc/OBNC.h>
#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>

#define OBERON_SOURCE_FILENAME "artPThread.obn"

const int artPThread__MutexDesc_id;
const int *const artPThread__MutexDesc_ids[1] = {&artPThread__MutexDesc_id};
const OBNC_Td artPThread__MutexDesc_td = {artPThread__MutexDesc_ids, 1};

const int artPThread__CondVarDesc_id;
const int *const artPThread__CondVarDesc_ids[1] = {&artPThread__CondVarDesc_id};
const OBNC_Td artPThread__CondVarDesc_td = {artPThread__CondVarDesc_ids, 1};

const int artPThread__ThreadDesc_id;
const int *const artPThread__ThreadDesc_ids[1] = {&artPThread__ThreadDesc_id};
const OBNC_Td artPThread__ThreadDesc_td = {artPThread__ThreadDesc_ids, 1};

/* Thread procedure wrapper */
typedef struct {
    void (*proc)(void);
} ThreadData;

static void* thread_wrapper(void* arg) {
    ThreadData* data = (ThreadData*)arg;
    data->proc();
    free(data);
    return NULL;
}

artPThread__Mutex_ artPThread__NewMutex_(void) {
    artPThread__Mutex_ mutex;
    pthread_mutex_t* pmutex;
    
    OBNC_NEW(mutex, &artPThread__MutexDesc_td, struct artPThread__MutexDesc_Heap, OBNC_ATOMIC_NOINIT_ALLOC);
    
    pmutex = malloc(sizeof(pthread_mutex_t));
    if (pmutex && pthread_mutex_init(pmutex, NULL) == 0) {
        (*OBNC_PT(mutex, 0)).handle_ = (OBNC_INTEGER)(uintptr_t)pmutex;
    } else {
        if (pmutex) free(pmutex);
        (*OBNC_PT(mutex, 0)).handle_ = 0;
    }
    
    return mutex;
}

void artPThread__FreeMutex_(artPThread__Mutex_ *mutex_) {
    if (*mutex_ && (*OBNC_PT((*mutex_), 0)).handle_) {
        pthread_mutex_t* pmutex = (pthread_mutex_t*)(uintptr_t)(*OBNC_PT((*mutex_), 0)).handle_;
        pthread_mutex_destroy(pmutex);
        free(pmutex);
        (*OBNC_PT((*mutex_), 0)).handle_ = 0;
        *mutex_ = 0;
    }
}

int artPThread__Lock_(artPThread__Mutex_ mutex_) {
    if (!mutex_ || !(*OBNC_PT(mutex_, 0)).handle_) return 0;
    
    pthread_mutex_t* pmutex = (pthread_mutex_t*)(uintptr_t)(*OBNC_PT(mutex_, 0)).handle_;
    return pthread_mutex_lock(pmutex) == 0 ? 1 : 0;
}

int artPThread__Unlock_(artPThread__Mutex_ mutex_) {
    if (!mutex_ || !(*OBNC_PT(mutex_, 0)).handle_) return 0;
    
    pthread_mutex_t* pmutex = (pthread_mutex_t*)(uintptr_t)(*OBNC_PT(mutex_, 0)).handle_;
    return pthread_mutex_unlock(pmutex) == 0 ? 1 : 0;
}

int artPThread__TryLock_(artPThread__Mutex_ mutex_) {
    if (!mutex_ || !(*OBNC_PT(mutex_, 0)).handle_) return 0;
    
    pthread_mutex_t* pmutex = (pthread_mutex_t*)(uintptr_t)(*OBNC_PT(mutex_, 0)).handle_;
    return pthread_mutex_trylock(pmutex) == 0 ? 1 : 0;
}

artPThread__CondVar_ artPThread__NewCondVar_(void) {
    artPThread__CondVar_ cv;
    pthread_cond_t* pcond;
    
    OBNC_NEW(cv, &artPThread__CondVarDesc_td, struct artPThread__CondVarDesc_Heap, OBNC_ATOMIC_NOINIT_ALLOC);
    
    pcond = malloc(sizeof(pthread_cond_t));
    if (pcond && pthread_cond_init(pcond, NULL) == 0) {
        (*OBNC_PT(cv, 0)).handle_ = (OBNC_INTEGER)(uintptr_t)pcond;
    } else {
        if (pcond) free(pcond);
        (*OBNC_PT(cv, 0)).handle_ = 0;
    }
    
    return cv;
}

void artPThread__FreeCondVar_(artPThread__CondVar_ *cv_) {
    if (*cv_ && (*OBNC_PT((*cv_), 0)).handle_) {
        pthread_cond_t* pcond = (pthread_cond_t*)(uintptr_t)(*OBNC_PT((*cv_), 0)).handle_;
        pthread_cond_destroy(pcond);
        free(pcond);
        (*OBNC_PT((*cv_), 0)).handle_ = 0;
        *cv_ = 0;
    }
}

int artPThread__Wait_(artPThread__CondVar_ cv_, artPThread__Mutex_ mutex_) {
    if (!cv_ || !mutex_ || !(*OBNC_PT(cv_, 0)).handle_ || !(*OBNC_PT(mutex_, 0)).handle_) return 0;
    
    pthread_cond_t* pcond = (pthread_cond_t*)(uintptr_t)(*OBNC_PT(cv_, 0)).handle_;
    pthread_mutex_t* pmutex = (pthread_mutex_t*)(uintptr_t)(*OBNC_PT(mutex_, 0)).handle_;
    
    return pthread_cond_wait(pcond, pmutex) == 0 ? 1 : 0;
}

int artPThread__Signal_(artPThread__CondVar_ cv_) {
    if (!cv_ || !(*OBNC_PT(cv_, 0)).handle_) return 0;
    
    pthread_cond_t* pcond = (pthread_cond_t*)(uintptr_t)(*OBNC_PT(cv_, 0)).handle_;
    return pthread_cond_signal(pcond) == 0 ? 1 : 0;
}

int artPThread__Broadcast_(artPThread__CondVar_ cv_) {
    if (!cv_ || !(*OBNC_PT(cv_, 0)).handle_) return 0;
    
    pthread_cond_t* pcond = (pthread_cond_t*)(uintptr_t)(*OBNC_PT(cv_, 0)).handle_;
    return pthread_cond_broadcast(pcond) == 0 ? 1 : 0;
}

artPThread__Thread_ artPThread__NewThread_(void (*proc_)(void)) {
    artPThread__Thread_ thread;
    pthread_t* pthread;
    ThreadData* data;
    
    OBNC_NEW(thread, &artPThread__ThreadDesc_td, struct artPThread__ThreadDesc_Heap, OBNC_ATOMIC_NOINIT_ALLOC);
    
    pthread = malloc(sizeof(pthread_t));
    data = malloc(sizeof(ThreadData));
    
    if (pthread && data) {
        data->proc = proc_;
        if (pthread_create(pthread, NULL, thread_wrapper, data) == 0) {
            (*OBNC_PT(thread, 0)).handle_ = (OBNC_INTEGER)(uintptr_t)pthread;
        } else {
            free(pthread);
            free(data);
            (*OBNC_PT(thread, 0)).handle_ = 0;
        }
    } else {
        if (pthread) free(pthread);
        if (data) free(data);
        (*OBNC_PT(thread, 0)).handle_ = 0;
    }
    
    return thread;
}

int artPThread__Join_(artPThread__Thread_ thread_) {
    if (!thread_ || !(*OBNC_PT(thread_, 0)).handle_) return 0;
    
    pthread_t* pthread = (pthread_t*)(uintptr_t)(*OBNC_PT(thread_, 0)).handle_;
    int result = pthread_join(*pthread, NULL) == 0 ? 1 : 0;
    
    free(pthread);
    (*OBNC_PT(thread_, 0)).handle_ = 0;
    
    return result;
}

void artPThread__Sleep_(OBNC_INTEGER ms_) {
    if (ms_ > 0) {
        usleep(ms_ * 1000);  /* usleep takes microseconds */
    }
}

void artPThread__Init(void) {
    /* Module initialization if needed */
}
