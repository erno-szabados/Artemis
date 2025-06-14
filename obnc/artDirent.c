#include ".obnc/artDirent.h"
#include <obnc/OBNC.h>

#define OBERON_SOURCE_FILENAME "artDirent.obn"

const int artDirent__DirScannerDesc_id;
const int *const artDirent__DirScannerDesc_ids[1] = {&artDirent__DirScannerDesc_id};
const OBNC_Td artDirent__DirScannerDesc_td = {artDirent__DirScannerDesc_ids, 1};

artDirent__DirScanner_ artDirent__OpenScanner_(const char path_[], OBNC_INTEGER path_len)
{
	artDirent__DirScanner_ scanner_ = 0;

	OBNC_NEW(scanner_, &artDirent__DirScannerDesc_td, struct artDirent__DirScannerDesc_Heap, OBNC_ATOMIC_NOINIT_ALLOC);
	(*OBNC_PT(scanner_, 27)).handle_ = 0;
	(*OBNC_PT(scanner_, 28)).isOpen_ = 0;
	(*OBNC_PT(scanner_, 29)).hasError_ = 0;
	return scanner_;
}


int artDirent__NextEntry_(artDirent__DirScanner_ scanner_, char name_[], OBNC_INTEGER name_len, int *isDirectory_)
{
	int result_;

	result_ = 0;
	name_[OBNC_IT(0, name_len, 38)] = '\x00';
	(*isDirectory_) = 0;
	if (scanner_ != 0) {
	}
	return result_;
}


void artDirent__CloseScanner_(artDirent__DirScanner_ *scanner_)
{

	if ((*scanner_) != 0) {
		if ((*OBNC_PT((*scanner_), 50)).isOpen_) {
			(*OBNC_PT((*scanner_), 52)).isOpen_ = 0;
		}
		(*scanner_) = 0;
	}
}


int artDirent__IsValid_(artDirent__DirScanner_ scanner_)
{
	int result_;

	result_ = 0;
	if (scanner_ != 0) {
		result_ = (*OBNC_PT(scanner_, 64)).isOpen_ && (! (*OBNC_PT(scanner_, 65)).hasError_);
	}
	return result_;
}


void artDirent__Init(void)
{
}
