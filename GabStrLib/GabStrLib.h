#include "asmlib\asmlib.h"
#include <string>
using namespace std;

#ifndef _DLL_H_
#define _DLL_H_

#if BUILDING_DLL
# define DLLIMPORT __declspec (dllexport)
#else /* Not BUILDING_DLL */
# define DLLIMPORT __declspec (dllimport)
#endif /* Not BUILDING_DLL */


struct sReplace
{
	char* search;
	size_t search_start;
	size_t search_length;
	char* replace;
	size_t replace_length;
};


char* stristr(register const char* Source, register const char* What);
char* fast_strstr(const char* phaystack, const char* pneedle);

extern "C" {
	DLLIMPORT bool Load();
	DLLIMPORT int Unload();
	DLLIMPORT char* Replace(const char* source, const char* search, const char* replace, size_t* size);
	DLLIMPORT char* TReplace(const char* source, const char** t_search, const char** t_replace, int nbsearch, size_t* size);
	DLLIMPORT char* Fast_Replace(const char* source, const int search_start, const int search_length, const char* replace, const int replace_length, size_t* size);
	DLLIMPORT char* Fast_TReplace(const char* source, sReplace t_search[], int nbsearch, size_t* size);
}

#endif /* _DLL_H_ */