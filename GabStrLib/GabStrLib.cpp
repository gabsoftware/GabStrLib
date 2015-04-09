// GabStrLib.cpp : Defines the exported functions for the DLL application.
//
#include "stdafx.h"
#include "GabStrLib.h"

const size_t MAX_STRING_LENGTH = 16777216;
size_t pos;
size_t respos;
size_t offset;
size_t srclength;
size_t slength;
size_t rlength;
char* res;
const char* tmp;
//char* w_ch_source;
bool loaded=false;
bool unloaded=false;
const char* w_ch_err1 = "Error #1: GabStrLib n'était pas chargé ! Appelez la méthode Load au moins une fois auparavant.";
const char* w_ch_err2 = "Error #2: GabStrLib n'est plus chargé !";

//Allocate some memory (16Mb). This is the source string size limit, but we can increase it if needed.
bool Load()
{
	if(loaded == false)
	{
		res = (char*) malloc(MAX_STRING_LENGTH);
		if( res != NULL )
		{
			loaded = true;
			unloaded = false;
			return true;
		}
		else
		{
			return false;
		}
	}
	else
	{
		return false;
	}
}

//replace all occurence of search by replace in source
/*
parameters
source :
    IN : pointer to the source string
search :
    IN : pointer to the string to search
replace :
    IN : pointer to the replacement string
size :
    OUT : the length of the result string
*/
char* Replace(const char* source, const char* search, const char* replace, size_t* size)
{   
	//little checks
	if(loaded == false)
	{
		*size = A_strlen(w_ch_err1);
		return (char*) w_ch_err1;
	}
	if(unloaded==true)
	{
		*size = A_strlen(w_ch_err2);
		return (char*) w_ch_err2;
	}
	offset = 0;
	respos = 0;

	//get the parameters length
	srclength = A_strlen(source);
	slength = A_strlen(search);
	rlength = A_strlen(replace);

	//result string initialisation
	res[0]='\0';

	//searching address of first occurence of search in source, null if not found
	tmp = fast_strstr(source, search);

	//if found then
	if(tmp != NULL)
	{
		//while found
		while( tmp != NULL )
		{
			//computing current match position
			pos = tmp - source;

			//we add to the result string the source string content preceding the current match
			//strncat(res, source + offset, pos - offset);
			A_memcpy(res + respos, source + offset, pos - offset);
			respos += pos - offset;
			res[respos] = '\0';

			//we add the replacement string to the result string
			//strncat(res, replace, rlength);
			A_strcat(res, replace);
			respos += rlength;

			//computing the offset from where we will search next time
			offset = pos + slength;

			//searching address of first occurence of search in source, null if not found
			tmp = fast_strstr(source + offset, search);		
		}

		//we add to the result string the end of the source string
		//strncat(res, source + offset, pos - offset);
		A_strcat(res, source + offset);

	}
	else
	{
		//we found nothing, we will return the source string
		res = A_strcpy(res, source);
	}

	//computing the size of result string
	*size = A_strlen(res);

	//on renvoie la chaine de résultat
	return res;
}


//Replace all occurence of strings contained in t_search array by all strings contained in t_replace array, a little like php's pregreplace but without regular expressions
/*
Parameters :
source :
    IN : source string
t_search :
    IN : Pointer to an array of string to search
t_replace :
    IN : Pointer to an array of string to replace. Array must contains exactly the same number of entries as t_search.
nbsearch :
	IN : must be the length of t_search, represent the number of elements to replace.
size :
    IN : Pointer to the size of the source string
    OUT : Pointer to the size of the result string
*/
char* TReplace(const char* source, const char** t_search, const char** t_replace, int nbsearch, size_t* size)
{
	//little checks
	if(loaded == false)
	{
		*size = A_strlen(w_ch_err1);
		return (char*) w_ch_err1;
	}
	if(unloaded==true)
	{
		*size = A_strlen(w_ch_err2);
		return (char*) w_ch_err2;
	}

	int i;
	char* w_ch_tmp;
	char* w_ch_tmp2;

	//get the length of the source
	srclength = A_strlen(source);

	//copy source string into w_ch_tmp
	w_ch_tmp = (char*) malloc(srclength + 1);
	A_strcpy(w_ch_tmp, source);

	//for each element in both arrays
	for(i=0; i<nbsearch; i++)
	{
		//replace with current elements, result string in w_ch_tmp2
		w_ch_tmp2 = Replace(w_ch_tmp, t_search[i], t_replace[i], size);

		//free w_ch_tmp memory
		free(w_ch_tmp);

		//copy result string in w_ch_tmp
		w_ch_tmp = (char*) malloc(*size + 1);
		A_strcpy(w_ch_tmp, w_ch_tmp2);
	}
	
	//return the result string
	return w_ch_tmp;
}

//Do a fast string replacement, we must provide the coordinates of the string to search and replace.
/*
Parameters :

source :
    IN : pointer to the source string
search_start :
	IN : where the replacement begin in source
search_length :
	IN : the lenght of the string to replace
replace :
	IN : pointer to the replacement string
replace_length :
	IN : length of the replacement string
size            :
    IN : pointer to the length of source.
    OUT : pointer to the length of the string after replacement is done.

*/
char* Fast_Replace(const char* source, const int search_start, const int search_length, const char* replace, const int replace_length, size_t* size)
{
	//little checks
	if(loaded == false)
	{
		*size = A_strlen(w_ch_err1);
		return (char*) w_ch_err1;
	}
	if(unloaded==true)
	{
		*size = A_strlen(w_ch_err2);
		return (char*) w_ch_err2;
	}
	
	//result string initialisation
	//res[0]='\0';

	//we add to the result string the source string content preceding the current match
	A_memcpy(res, source + search_start, search_start);
	res[search_start] = '\0';

	//we add the replacement string to the result string
	A_strcat(res, replace);

	//we add the rest of the source string
	A_strcat(res, source + search_start + search_length);

	//computing the size of result string
	*size = *size - search_length + replace_length;

	//on renvoie la chaine de résultat
	return res;
}


//Very fast string replace function, because we provide the replacement coordinates.
/*
Parameters :
source :
    IN : pointer to the source string
t_search :
	IN : array of sReplace structure
nbsearch :
	IN : must be the length of t_search, represent the number of replacements
size :
    IN : the source string length
    OUT : the result string length
*/
char* Fast_TReplace(const char* source, sReplace t_search[], int nbsearch, size_t* size)
{
	//little checks
	if(loaded == false)
	{
		if(!Load())
		{
			*size = A_strlen(w_ch_err1);
			return (char*) w_ch_err1;
		}
	}

	if(unloaded==true)
	{
		*size = A_strlen(w_ch_err2);
		return (char*) w_ch_err2;
	}

	//le programme intelligent évite les efforts inutiles : on ne remplace que si necessaire
	if(nbsearch<1)
	{
		A_memcpy(res, source, *size);
		res[*size] = '\0';
		return res;	
	}
	
	int i;
	size_t pos_res;
	size_t pos_src;
	size_t length;

	//debug
	//char buffer[256];

	pos_res = 0;
	pos_src = 0;

	//main loop
	for(i = 0; i < nbsearch; i++)
	{
		//MessageBox( NULL, TEXT("début"), TEXT("Titre"), MB_OK );
		
		//copy the unreplaced part to the result string
		length = t_search[i].search_start - pos_src;

		//sprintf_s( buffer, "[1] length=%u, res=%p, pos_res=%u, source=%p, pos_src=%u", length, res, pos_res, source, pos_src );
		//MessageBox( NULL, buffer, TEXT("Titre"), MB_OK );

		A_memcpy(res + pos_res, source + pos_src, length);

		pos_src = t_search[i].search_start + t_search[i].search_length;

		//sprintf_s( buffer, "[2] res=%p, pos_src=%u, t_search[%d].search_start=%u, t_search[%d].search_length=%u", res, pos_src, i, t_search[i].search_start, i, t_search[i].search_length );
		//MessageBox( NULL, buffer, TEXT("Titre"), MB_OK );

		pos_res += length;

		//sprintf_s( buffer, "[3] length=%u, pos_res=%u", length, pos_res );
		//MessageBox( NULL, buffer, TEXT("Titre"), MB_OK );

		//sprintf_s( buffer, "[4] res=%p, pos_res=%u, t_search[%d].replace=%p, t_search[%d].replace_length=%u", res, pos_res, i, t_search[i].replace, i, t_search[i].replace_length );
		//MessageBox( NULL, buffer, TEXT("Titre"), MB_OK );

		//copy the replacement string to result string
		A_memcpy(res + pos_res, t_search[i].replace, t_search[i].replace_length);


		pos_res += t_search[i].replace_length;

		//sprintf_s( buffer, "[5] pos_res=%u, t_search[%d].replace_length=%u", pos_res, i, t_search[i].replace_length );
		//MessageBox( NULL, buffer, TEXT("Titre"), MB_OK );

		//MessageBox( NULL, TEXT("fin"), TEXT("Titre"), MB_OK );
	}

	//copy the end of the source string to result string
	length = *size - pos_src;
	A_memcpy(res + pos_res, source + pos_src, length);
	pos_res += length;
	res[pos_res] = '\0';

	//define the size of the result string
	*size = pos_res;

	//MessageBox( NULL, TEXT("Sortie"), TEXT("Titre"), MB_OK );

	//return the result string
	return res;
}



//Free some memory
int Unload()
{
	free(res);
	if(errno < 1)
	{
		unloaded=true;
	}
	return errno;
}




//custom
char* stristr(register const char* Source, register const char* What)
{
	register char WhatChar;
	register char SourceChar;
	register size_t Length;
    if ((WhatChar = *What++) != 0) {
        Length = strlen(What);
        do {
            do {
                if ((SourceChar = *Source++) == 0) {
                    return (0);
                }
            } while (tolower(SourceChar) != tolower(WhatChar));
			/*} while (SourceChar != WhatChar);*/
        } while (_strnicmp(Source, What, Length) != 0);
        Source--;
    }
    return ((char *)Source);
}/*stristr*/


//int fast_strlen(const char *s)
//{
//    int len = 0;
//    for(;;) {
//        unsigned x = *(unsigned*)s;
//        if((x & 0xFF) == 0) return len;
//        if((x & 0xFF00) == 0) return len + 1;
//        if((x & 0xFF0000) == 0) return len + 2;
//        if((x & 0xFF000000) == 0) return len + 3;
//        s += 4, len += 4;
//    }
//}











#if HAVE_CONFIG_H
# include <config.h>
#endif

#if defined _LIBC || defined HAVE_STRING_H
# include <string.h>
#endif

typedef unsigned chartype;

#undef strstr

char* fast_strstr(const char* phaystack, const char* pneedle)
{
	register const unsigned char *haystack, *needle;
	register chartype b, c;

	haystack = (const unsigned char *) phaystack;
	needle = (const unsigned char *) pneedle;

	b = *needle;
	if (b != '\0')
	{
		haystack--;				/* possible ANSI violation */
		do
		{
			c = *++haystack;
			if (c == '\0')
			{
				goto ret0;
			}
		}
		while (c != b);

		c = *++needle;
		if (c == '\0')
		{
			goto foundneedle;
		}
		++needle;
		goto jin;

		for (;;)
		{
			register chartype a;
			register const unsigned char *rhaystack, *rneedle;

			do
			{
				a = *++haystack;
				if (a == '\0')
				{
					goto ret0;
				}
				if (a == b)
				{
					break;
				}
				a = *++haystack;
				if (a == '\0')
				{
					goto ret0;
				}
shloop:		;
			}
			while (a != b);

jin:		a = *++haystack;
			if (a == '\0')
			{
				goto ret0;
			}

			if (a != c)
			{
				goto shloop;
			}

			rhaystack = haystack-- + 1;
			rneedle = needle;
			a = *rneedle;

			if (*rhaystack == a)
			{
				do
				{
					if (a == '\0')
					{
						goto foundneedle;
					}
					++rhaystack;
					a = *++needle;
					if (*rhaystack != a)
					{
						break;
					}
					if (a == '\0')
					{
						goto foundneedle;
					}
					++rhaystack;
					a = *++needle;
				}
				while (*rhaystack == a);
			}

			needle = rneedle;		/* took the register-poor approach */

			if (a == '\0')
			{
				break;
			}
		}
	}
foundneedle:
	return (char*) haystack;
ret0:
	return 0;
}