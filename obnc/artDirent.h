/*GENERATED BY OBNC 0.17.2*/

#ifndef artDirent_h
#define artDirent_h
#include <dirent.h>
#include <obnc/OBNC.h>

typedef struct artDirent__DirScannerDesc_ *artDirent__DirScanner_;

typedef struct artDirent__DirScannerDesc_ {
	DIR* handle_;
	int isOpen_;
	int hasError_;
} artDirent__DirScannerDesc_;

struct artDirent__DirScannerDesc_Heap {
	const OBNC_Td *td;
	struct artDirent__DirScannerDesc_ fields;
};

#define artDirent__DirScannerDesc_id obnc__artDirent__DirScannerDesc_id
extern const int artDirent__DirScannerDesc_id;

#define artDirent__DirScannerDesc_ids obnc__artDirent__DirScannerDesc_ids
extern const int *const artDirent__DirScannerDesc_ids[1];

#define artDirent__DirScannerDesc_td obnc__artDirent__DirScannerDesc_td
extern const OBNC_Td artDirent__DirScannerDesc_td;

#define artDirent__OpenScanner_ obnc__artDirent__OpenScanner_
artDirent__DirScanner_ artDirent__OpenScanner_(const char path_[], OBNC_INTEGER path_len);

#define artDirent__NextEntry_ obnc__artDirent__NextEntry_
int artDirent__NextEntry_(artDirent__DirScanner_ scanner_, char name_[], OBNC_INTEGER name_len, int *isDirectory_);

#define artDirent__CloseScanner_ obnc__artDirent__CloseScanner_
void artDirent__CloseScanner_(artDirent__DirScanner_ *scanner_);

#define artDirent__IsValid_ obnc__artDirent__IsValid_
int artDirent__IsValid_(artDirent__DirScanner_ scanner_);

#define artDirent__Init obnc__artDirent__Init
void artDirent__Init(void);

#endif
