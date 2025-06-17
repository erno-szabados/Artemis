#include ".obnc/artPThread.h"
#include <obnc/OBNC.h>
#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <stdint.h>

#define OBERON_SOURCE_FILENAME "artPThread.obn"

const OBNC_INTEGER artPThread__MutexDesc_id;
const OBNC_INTEGER *const artPThread__MutexDesc_ids[1] = {&artPThread__MutexDesc_id};
const OBNC_Td artPThread__MutexDesc_td = {artPThread__MutexDesc_ids, 1};

const OBNC_INTEGER artPThread__CondVarDesc_id;
const OBNC_INTEGER *const artPThread__CondVarDesc_ids[1] = {&artPThread__CondVarDesc_id};
const OBNC_Td artPThread__CondVarDesc_td = {artPThread__CondVarDesc_ids, 1};

const OBNC_INTEGER artPThread__ThreadDesc_id;
const OBNC_INTEGER *const artPThread__ThreadDesc_ids[1] = {&artPThread__ThreadDesc_id};
const OBNC_Td artPThread__ThreadDesc_td = {artPThread__ThreadDesc_ids, 1};

artPThread__Mutex_ artPThread__NewMutex_(void)
{
	artPThread__Mutex_ mutex;
	pthread_mutex_t *pmutex;
	
	/* Allocate memory for the mutex record (by GC) */
	mutex = OBNC_Allocate(sizeof(struct artPThread__MutexDesc_), OBNC_REGULAR_ALLOC);
	if (mutex == NULL) {
		return NULL; /* Memory allocation failed */
	}
	
	/* Allocate memory for pthread_mutex_t */
	pmutex = malloc(sizeof(pthread_mutex_t));
	if (pmutex == NULL) {
		return NULL; /* Memory allocation failed */
	}
	
	/* Initialize the mutex */
	if (pthread_mutex_init(pmutex, NULL) != 0) {
		free(pmutex);
		return NULL; /* Mutex initialization failed */
	}
	
	/* Store the pthread_mutex_t pointer as handle */
	mutex->handle_ = (OBNC_INTEGER)(uintptr_t)pmutex;
	
	return mutex;
}


void artPThread__FreeMutex_(artPThread__Mutex_ *mutex_)
{
	pthread_mutex_t *pmutex;
	
	if (mutex_ != NULL && *mutex_ != NULL) {
		/* Get the pthread_mutex_t pointer from handle */
		pmutex = (pthread_mutex_t *)(uintptr_t)(*mutex_)->handle_;
		
		if (pmutex != NULL) {
			/* Destroy the mutex */
			pthread_mutex_destroy(pmutex);
			
			/* Free the allocated memory */
			free(pmutex);
		}
		
		/* Set the pointer to NULL */
		*mutex_ = NULL;
	}
}


OBNC_INTEGER artPThread__Lock_(artPThread__Mutex_ mutex_)
{
	pthread_mutex_t *pmutex;
	if (mutex_ == NULL) {
		return artPThread__InvalidMutex_; /* invalid mutex */
	}
	pmutex = (pthread_mutex_t *)(uintptr_t)mutex_->handle_;
	if (pmutex == NULL) {
		return artPThread__InvalidHandle_; /* invalid handle */
	}
	OBNC_INTEGER r = pthread_mutex_lock(pmutex);
	if (r == 0) return artPThread__Ok_;
	if (r == EDEADLK) return artPThread__Deadlock_;
	if (r == EINVAL) return artPThread__InvalidHandle_;
	if (r == EAGAIN) return artPThread__MaxRecursion_;
	if (r == ENOTRECOVERABLE) return artPThread__NotRecoverable_;
	if (r == EOWNERDEAD) return artPThread__OwnerDead_;
	if (r == ENOMEM) return artPThread__ResourceExhausted_;
	return artPThread__UnknownError_;
}


OBNC_INTEGER artPThread__Unlock_(artPThread__Mutex_ mutex_)
{
	pthread_mutex_t *pmutex;
	
	if (mutex_ == NULL) {
		return artPThread__InvalidMutex_; /* invalid mutex */
	}
	
	/* Get the pthread_mutex_t pointer from handle */
	pmutex = (pthread_mutex_t *)(uintptr_t)mutex_->handle_;
	
	if (pmutex == NULL) {
		return artPThread__InvalidHandle_; /* invalid handle */
	}
	
	/* Unlock the mutex */
	OBNC_INTEGER r = pthread_mutex_unlock(pmutex);
	if (r == 0) return artPThread__Ok_;
	if (r == EPERM) return artPThread__NotOwner_;
	if (r == EINVAL) return artPThread__InvalidHandle_;
	return artPThread__UnknownError_;
}


OBNC_INTEGER artPThread__TryLock_(artPThread__Mutex_ mutex_)
{
	pthread_mutex_t *pmutex;
	if (mutex_ == NULL) {
		return artPThread__InvalidMutex_; /* invalid mutex */
	}
	pmutex = (pthread_mutex_t *)(uintptr_t)mutex_->handle_;
	if (pmutex == NULL) {
		return artPThread__InvalidHandle_; /* invalid handle */
	}
	OBNC_INTEGER r = pthread_mutex_trylock(pmutex);
	if (r == 0) return artPThread__Ok_;
	if (r == EBUSY) return artPThread__Busy_;
	if (r == EINVAL) return artPThread__InvalidHandle_;
	if (r == EAGAIN) return artPThread__MaxRecursion_;
	if (r == ENOTRECOVERABLE) return artPThread__NotRecoverable_;
	if (r == EOWNERDEAD) return artPThread__OwnerDead_;
	return artPThread__UnknownError_;
}


artPThread__CondVar_ artPThread__NewCondVar_(void)
{
	artPThread__CondVar_ cv;
	pthread_cond_t *pcv;

	/* Allocate memory for the condvar record */
	cv = OBNC_Allocate(sizeof(struct artPThread__CondVarDesc_), OBNC_REGULAR_ALLOC);
	if (cv == NULL) {
		return NULL; /* Memory allocation failed */
	}

	/* Allocate memory for pthread_cond_t */
	pcv = malloc(sizeof(pthread_cond_t));
	if (pcv == NULL) {
		return NULL; /* Memory allocation failed */
	}

	/* Initialize the condvar */
	if (pthread_cond_init(pcv, NULL) != 0) {
		free(pcv);
		return NULL; /* Initialization failed */
	}

	/* Store the pthread_cond_t pointer as handle */
	cv->handle_ = (OBNC_INTEGER)(uintptr_t)pcv;

	return cv;
}


void artPThread__FreeCondVar_(artPThread__CondVar_ *cv_)
{
	pthread_cond_t *pcv;

	if (cv_ != NULL && *cv_ != NULL) {
		/* Get the pthread_cond_t pointer from handle */
		pcv = (pthread_cond_t *)(uintptr_t)(*cv_)->handle_;

		if (pcv != NULL) {
			/* Destroy the condvar */
			pthread_cond_destroy(pcv);
			/* Free the allocated memory */
			free(pcv);
		}

		/* Set the pointer to NULL */
		*cv_ = NULL;
	}
}


OBNC_INTEGER artPThread__Wait_(artPThread__CondVar_ cv_, artPThread__Mutex_ mutex_)
{
	pthread_cond_t *pcv;
	pthread_mutex_t *pmutex;

	if (cv_ == NULL) {
		return artPThread__InvalidCondvar_; /* invalid condvar  */
	}

	if (mutex_ == NULL) {
		return artPThread__InvalidMutex_; /* invalid mutex */
	}
	pcv = (pthread_cond_t *)(uintptr_t)cv_->handle_;
	pmutex = (pthread_mutex_t *)(uintptr_t)mutex_->handle_;
	if (pcv == NULL || pmutex == NULL) {
		return artPThread__InvalidHandle_; /* invalid handle */
	}
	OBNC_INTEGER r = pthread_cond_wait(pcv, pmutex);
	if (r == 0) return artPThread__Ok_;
	if (r == EINVAL) return artPThread__InvalidHandle_;
	if (r == ENOTRECOVERABLE) return artPThread__NotRecoverable_;
	if (r == EOWNERDEAD) return artPThread__OwnerDead_;
	if (r == EPERM) return artPThread__NotOwner_;
	return artPThread__UnknownError_;
}


OBNC_INTEGER artPThread__Signal_(artPThread__CondVar_ cv_)
{
	pthread_cond_t *pcv;

	if (cv_ == NULL) {
		return artPThread__InvalidCondvar_; /* invalid condvar */
	}

	pcv = (pthread_cond_t *)(uintptr_t)cv_->handle_;

	if (pcv == NULL) {
		return artPThread__InvalidHandle_; /* invalid handle */
	}

	OBNC_INTEGER r = pthread_cond_signal(pcv);
	if (r == 0) return artPThread__Ok_;
	if (r == EINVAL) return artPThread__InvalidHandle_
;
	return artPThread__UnknownError_;
}


OBNC_INTEGER artPThread__Broadcast_(artPThread__CondVar_ cv_)
{
	pthread_cond_t *pcv;

	if (cv_ == NULL) {
		return artPThread__InvalidCondvar_; /* invalid condvar */
	}

	pcv = (pthread_cond_t *)(uintptr_t)cv_->handle_;

	if (pcv == NULL) {
		return artPThread__InvalidHandle_; /* invalid handle */
	}

	OBNC_INTEGER r = pthread_cond_broadcast(pcv);
	if (r == 0) return artPThread__Ok_;
	if (r == EINVAL) return artPThread__InvalidHandle_;
	return artPThread__UnknownError_;
}


struct artPThread__ThreadStartArg {
	artPThread__ThreadProc_ proc_;
	OBNC_INTEGER context_;
};

/**
 * POSIX threads require a function with the signature (void *(*)(void *)) as the entry point.
 * Oberon-07 thread procedures have the signature artPThread__ThreadProc_.
 */
/**
 * Thread trampoline function that calls the user-defined procedure.
 * This function receives the pointer to the start argument structure,
 * extracts the procedure pointer, and calls it with a dummy argument.
 * After the procedure call, it frees the start argument structure.
 */
static void *artPThread__ThreadTrampoline(void *arg)
{
	struct artPThread__ThreadStartArg *startArg = (struct artPThread__ThreadStartArg *)arg;
	if (startArg && startArg->proc_) {
		startArg->proc_(startArg->context_);
	}
	free(startArg);
	return NULL;
}

/**
 * Creates a new thread and starts it with the given procedure.
 * The procedure should match the artPThread__ThreadProc_ signature.
 * Returns a pointer to the thread descriptor or NULL on failure.
 */
artPThread__Thread_ artPThread__NewThread_(artPThread__ThreadProc_ proc_, OBNC_INTEGER context_)
{
	artPThread__Thread_ thread;
	pthread_t *pth;
	struct artPThread__ThreadStartArg *startArg;

	if (proc_ == NULL) {
		return NULL;
	}

	thread = OBNC_Allocate(sizeof(struct artPThread__ThreadDesc_), OBNC_REGULAR_ALLOC);
	pth = malloc(sizeof(pthread_t));
	if (thread == NULL || pth == NULL) {
		if (pth) free(pth);
		return NULL;
	}

	startArg = malloc(sizeof(struct artPThread__ThreadStartArg));
	if (startArg == NULL) {
		free(pth);
		return NULL;
	}
	startArg->proc_ = proc_;
	startArg->context_ = context_;

	if (pthread_create(pth, NULL, artPThread__ThreadTrampoline, startArg) != 0) {
		free(pth);
		free(startArg);
		return NULL;
	}

	thread->handle_ = (OBNC_INTEGER)(uintptr_t)pth;
	return thread;
}

OBNC_INTEGER artPThread__Join_(artPThread__Thread_ thread_)
{
	pthread_t *pth;
	if (thread_ == NULL) {
		return artPThread__InvalidHandle_;
	}
	pth = (pthread_t *)(uintptr_t)thread_->handle_;
	if (pth == NULL) {
		return artPThread__InvalidHandle_;
	}
	OBNC_INTEGER r = pthread_join(*pth, NULL);
	if (r == 0) {
		free(pth);
		thread_->handle_ = 0;
		return artPThread__Ok_;
	} else if (r == EINVAL) {
		return artPThread__InvalidHandle_;
	} else {
		return artPThread__UnknownError_;
	}
}


void artPThread__Sleep_(OBNC_INTEGER ms_)
{
	if (ms_ > 0) {
		usleep(ms_ * 1000);  /* Convert milliseconds to microseconds */
	}
}


void artPThread__Init(void)
{
}
