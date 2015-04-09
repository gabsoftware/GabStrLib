;          ROUND64.ASM                                          Agner Fog 2007

; © 2007 GNU General Public License www.gnu.org/licenses/gpl.html


.code

; ********** round function **********
; C++ prototype:
; extern "C" int RoundD (double x);
; extern "C" int RoundF (float  x);

; This function converts a single or double precision floating point number 
; to an integer, rounding to nearest or even. Does not check for overflow.
; This function is much faster than the default conversion method in C++
; which uses truncation.

RoundD PROC
        cvtsd2si eax, xmm0             ; Round xmm0 to eax
        ret
RoundD  ENDP

RoundF PROC
        cvtss2si eax, xmm0             ; Round xmm0 to eax
        ret
RoundF ENDP

END
