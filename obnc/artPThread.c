#include ".obnc/artPThread.h"
#include <obnc/OBNC.h>

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
	return 0;
}


void artPThread__FreeMutex_(artPThread__Mutex_ *mutex_)
{
}


int artPThread__Lock_(artPThread__Mutex_ mutex_)
{
	return 0;
}


int artPThread__Unlock_(artPThread__Mutex_ mutex_)
{
	return 0;
}


int artPThread__TryLock_(artPThread__Mutex_ mutex_)
{
	return 0;
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
}


void artPThread__Init(void)
{
}
