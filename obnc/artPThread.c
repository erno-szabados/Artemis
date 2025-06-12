#include ".obnc/artPThread.h"
#include <obnc/OBNC.h>
#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <stdint.h>


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

artPThread__Mutex_ artPThread__NewMutex_(void)
{
	artPThread__Mutex_ mutex;
	pthread_mutex_t *pmutex;
	
	/* Allocate memory for the mutex record */
	mutex = OBNC_Allocate(sizeof(struct artPThread__MutexDesc_), OBNC_REGULAR_ALLOC);
	
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


int artPThread__Lock_(artPThread__Mutex_ mutex_)
{
	pthread_mutex_t *pmutex;
	
	if (mutex_ == NULL) {
		return 0; /* FALSE - invalid mutex */
	}
	
	/* Get the pthread_mutex_t pointer from handle */
	pmutex = (pthread_mutex_t *)(uintptr_t)mutex_->handle_;
	
	if (pmutex == NULL) {
		return 0; /* FALSE - invalid handle */
	}
	
	/* Lock the mutex */
	if (pthread_mutex_lock(pmutex) == 0) {
		return 1; /* TRUE - success */
	} else {
		return 0; /* FALSE - lock failed */
	}
}


int artPThread__Unlock_(artPThread__Mutex_ mutex_)
{
	pthread_mutex_t *pmutex;
	
	if (mutex_ == NULL) {
		return 0; /* FALSE - invalid mutex */
	}
	
	/* Get the pthread_mutex_t pointer from handle */
	pmutex = (pthread_mutex_t *)(uintptr_t)mutex_->handle_;
	
	if (pmutex == NULL) {
		return 0; /* FALSE - invalid handle */
	}
	
	/* Unlock the mutex */
	if (pthread_mutex_unlock(pmutex) == 0) {
		return 1; /* TRUE - success */
	} else {
		return 0; /* FALSE - unlock failed */
	}
}


int artPThread__TryLock_(artPThread__Mutex_ mutex_)
{
	pthread_mutex_t *pmutex;

	if (mutex_ == NULL) {
		return 0; /* FALSE - invalid mutex */
	}

	/* Get the pthread_mutex_t pointer from handle */
	pmutex = (pthread_mutex_t *)(uintptr_t)mutex_->handle_;

	if (pmutex == NULL) {
		return 0; /* FALSE - invalid handle */
	}

	/* Try to lock the mutex (non-blocking) */
	if (pthread_mutex_trylock(pmutex) == 0) {
		return 1; /* TRUE - success */
	} else {
		return 0; /* FALSE - already locked or error */
	}
}


artPThread__CondVar_ artPThread__NewCondVar_(void)
{
	return 0;
}


void artPThread__FreeCondVar_(artPThread__CondVar_ *cv_)
{
}


int artPThread__Wait_(artPThread__CondVar_ cv_, artPThread__Mutex_ mutex_)
{
	return 0;
}


int artPThread__Signal_(artPThread__CondVar_ cv_)
{
	return 1;
}


int artPThread__Broadcast_(artPThread__CondVar_ cv_)
{
	return 0;
}


artPThread__Thread_ artPThread__NewThread_(artPThread__ThreadProc_ proc_)
{
	return 0;
}


int artPThread__Join_(artPThread__Thread_ thread_)
{
	return 0;
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
