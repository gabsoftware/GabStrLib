/*                         ASMLIB.H                            Agner Fog 2008

Header file for the asmlib function library.

This library is available in many versions for different platforms.
See asmlib-instructions.pdf for details.

The random number generators are declared in asmlibran.h.

(c) 2003 - 2008. GNU General Public License www.gnu.org/licenses/gpl.html

******************************************************************************/

#ifndef ASMLIB_H
#define ASMLIB_H


/***********************************************************************
Define compiler-specific types and directives
***********************************************************************/

// Define type size_t
#ifndef _SIZE_T_DEFINED
#include "stddef.h"
#endif

// Define 32 bit signed and unsigned integers.
// Change these definitions, if necessary, to match a particular platform
#if defined(_WIN16) || defined(__MSDOS__) || defined(_MSDOS) 
   // 16 bit systems use long int for 32 bit integer
   typedef long int           int32;   // 32 bit signed integer
   typedef unsigned long int  uint32;  // 32 bit unsigned integer
#else
   // Most other systems use int for 32 bit integer
   typedef int                int32;   // 32 bit signed integer
   typedef unsigned int       uint32;  // 32 bit unsigned integer
#endif

// Define 64 bit signed and unsigned integers, if possible
#if (defined(__WINDOWS__) || defined(_WIN32)) && (defined(_MSC_VER) || defined(__INTEL_COMPILER))
   // Microsoft and other compilers under Windows use __int64
   typedef __int64            int64;   // 64 bit signed integer
   typedef unsigned __int64   uint64;  // 64 bit unsigned integer
   #define INT64_DEFINED               // Remember that int64 is defined
#elif defined(__unix__) && (defined(_M_IX86) || defined(_M_X64))
   // Gnu and other compilers under Linux etc. use long long
   typedef long long          int64;   // 64 bit signed integer
   typedef unsigned long long uint64;  // 64 bit unsigned integer
   #define INT64_DEFINED               // Remember that int64 is defined
#else
   // 64 bit integers not defined
   // You may include definitions for other platforms here
#endif

// Define directives for aligning by 16
#if (defined(__WINDOWS__) || defined(_WIN32))
   #if defined(_MSC_VER) || defined(__INTEL_COMPILER)
      // MS and Intel compilers for Windows have alignment directive before class declaration
      #define ALIGN_PRE   __declspec(align(16))
      #define ALIGN_POST 
      #define ALIGN_SUPPORTED
   #else // Other compiler may not support alignment
      #define ALIGN_PRE
      #define ALIGN_POST
   #endif
#elif defined(__unix__) || defined(__linux__) || defined(__GNUC__)
   // Unix compilers have alignment directive after class declaration
   #define ALIGN_PRE
   #define ALIGN_POST  __attribute((aligned(16)))
   #define ALIGN_SUPPORTED
#else
   // Other platforms not supported
   #error  Possibly wrong platform. Must be x86 or x86-64
#endif

// Define macro for extern "C" __stdcall call for dynamic linking:
#if defined(_WIN32) && !defined(_WIN64)
   // __stdcall used only in 32-bit Windows
   #define DLL_STDCALL  __stdcall
#else
   // 64-bit Windows has only one calling convention.
   // 32 and 64 bit Linux does not use __stdcall for dynamic linking
   #define DLL_STDCALL
#endif

// Turn off name mangling
#ifdef __cplusplus
extern "C" {
#endif

/***********************************************************************
Function prototypes for simple functions
***********************************************************************/

void * A_memcpy (void * dest, const void * src, size_t count); // Copy count bytes from src to dest
void * A_memmove(void * dest, const void * src, size_t count); // Same as memcpy, allows overlap between src and dest
void * A_memset (void * dest, int c, size_t count);            // Set count bytes in dest to (char)c
char * A_strcat   (char * dest, const char * src);             // Concatenate strings dest and src. Store result in dest
char * A_strcpy (char * dest, const char * src);               // Copy string src to dest
size_t A_strlen   (const char * str);                          // Get length of zero-terminated string
extern size_t   CacheBypassLimit;                              // The above functions can bypass cache when writing memory bigger than this limit

int    InstructionSet(void);                                   // Tell which instruction set is supported
extern int IInstrSet;                                          // Set by first call to InstructionSet()
char * ProcessorName(void);                                    // ASCIIZ text describing microprocessor
void   Serialize();                                            // Serialize before and after __readpmc()
int    RoundD (double x);                                      // Round to nearest or even
int    RoundF (float  x);                                      // Round to nearest or even
#ifdef INT64_DEFINED
   uint64 ReadTSC(void);                                       // Read microprocessor internal clock (64 bits)
#else
   uint32 ReadTSC(void);                                       // Read microprocessor internal clock (only 32 bits supported by compiler)
#endif

#ifdef __cplusplus
}  // end of extern "C"

static inline int Round (double x) {   // Overload name Round
   return RoundD(x);}
static inline int Round (float  x) {   // Overload name Round
   return RoundF(x);}

#endif // __cplusplus

#endif // ASMLIB_H
