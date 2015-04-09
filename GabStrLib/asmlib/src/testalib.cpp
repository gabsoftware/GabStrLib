//          TESTALIB.CPP                                   Agner Fog 2007-06-14

// Test file for asmlib
// Instructions: Compile on any platform and link with the appropriate
// version of the asmlib library.

#include <stdio.h>
#include "asmlibran.h"

int main () {

   // test InstructionSet()
   printf("InstructionSet  = %i\n",   InstructionSet());

   // test ProcessorName()
   printf("ProcessorName   = %s\n",   ProcessorName());
   
   // test ReadTSC()
   ReadTSC();
   int tsc = ReadTSC();
   tsc = ReadTSC() - tsc;
   printf("ReadTSC takes %i clocks\n", tsc);  
   
   // test Round();
   double d;
   for (d = -2; d < 2; d += 0.5) {
      printf("Round %f = %i = %i\n", d, Round(d), Round(float(d)));
   }

   // test Mersenne Twister, single and multi-thread versions
   int i;                                        // loop counter
   int seed = 98765432;                          // use any seed

   MersenneRandomInit(seed);                     // initialize single-thread version
   CRandomMersenneA ranmers(seed);               // initialize thread-safe version

   // Make random bits
   printf("\nMersenne Twister, single and multi-thread versions:\n");
   for (i=0; i<7; i++) printf("%08X  ", MersenneBRandom());
   printf("\n");
   for (i=0; i<7; i++) printf("%08X  ", ranmers.BRandom());

   // Make random integers
   printf("\n");
   for (i=0; i<9; i++) printf("%8i", MersenneIRandom(1,1000));
   printf("\n");
   for (i=0; i<9; i++) printf("%8i", ranmers.IRandom(1,1000));

   // Make random floating point numbers
   printf("\n");
   for (i=0; i<6; i++) printf("%10.8f  ", MersenneRandom());
   printf("\n");
   for (i=0; i<6; i++) printf("%10.8f  ", ranmers.Random());
   
   return 0;
}
