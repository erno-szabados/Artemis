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
	artPThread__CondVar_ cv;
	pthread_cond_t *pcv;

	/* Allocate memory for the condvar record */
	cv = OBNC_Allocate(sizeof(struct artPThread__CondVarDesc_), OBNC_REGULAR_ALLOC);

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


int artPThread__Wait_(artPThread__CondVar_ cv_, artPThread__Mutex_ mutex_)
{
	pthread_cond_t *pcv;
	pthread_mutex_t *pmutex;

	if (cv_ == NULL || mutex_ == NULL) {
		return 0; /* FALSE - invalid condvar or mutex */
	}

	pcv = (pthread_cond_t *)(uintptr_t)cv_->handle_;
	pmutex = (pthread_mutex_t *)(uintptr_t)mutex_->handle_;

	if (pcv == NULL || pmutex == NULL) {
		return 0; /* FALSE - invalid handle */
	}

	if (pthread_cond_wait(pcv, pmutex) == 0) {
		return 1; /* TRUE - success */
	} else {
		return 0; /* FALSE - wait failed */
	}
}


int artPThread__Signal_(artPThread__CondVar_ cv_)
{
	pthread_cond_t *pcv;

	if (cv_ == NULL) {
		return 0; /* FALSE - invalid condvar */
	}

	pcv = (pthread_cond_t *)(uintptr_t)cv_->handle_;

	if (pcv == NULL) {
		return 0; /* FALSE - invalid handle */
	}

	if (pthread_cond_signal(pcv) == 0) {
		return 1; /* TRUE - success */
	} else {
		return 0; /* FALSE - signal failed */
	}
}


int artPThread__Broadcast_(artPThread__CondVar_ cv_)
{
	pthread_cond_t *pcv;

	if (cv_ == NULL) {
		return 0; /* FALSE - invalid condvar */
	}

	pcv = (pthread_cond_t *)(uintptr_t)cv_->handle_;

	if (pcv == NULL) {
		return 0; /* FALSE - invalid handle */
	}

	if (pthread_cond_broadcast(pcv) == 0) {
		return 1; /* TRUE - success */
	} else {
		return 0; /* FALSE - broadcast failed */
	}
}


struct artPThread__ThreadStartArg {
	artPThread__ThreadProc_ proc_;
};

static void *artPThread__ThreadTrampoline(void *arg)
{
	struct artPThread__ThreadStartArg *startArg = (struct artPThread__ThreadStartArg *)arg;
	if (startArg && startArg->proc_) {
		startArg->proc_(0); // Call with dummy argument
	}
	free(startArg);
	return NULL;
}

artPThread__Thread_ artPThread__NewThread_(artPThread__ThreadProc_ proc_)
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

	if (pthread_create(pth, NULL, artPThread__ThreadTrampoline, startArg) != 0) {
		free(pth);
		free(startArg);
		return NULL;
	}

	thread->handle_ = (OBNC_INTEGER)(uintptr_t)pth;
	return thread;
}

int artPThread__Join_(artPThread__Thread_ thread_)
{
	pthread_t *pth;
	if (thread_ == NULL) {
		return 0;
	}
	pth = (pthread_t *)(uintptr_t)thread_->handle_;
	if (pth == NULL) {
		return 0;
	}
	if (pthread_join(*pth, NULL) == 0) {
		free(pth);
		thread_->handle_ = 0;
		return 1;
	} else {
		return 0;
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
