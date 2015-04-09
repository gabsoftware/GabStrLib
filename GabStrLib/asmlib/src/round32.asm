;          ROUND32.ASM                                          Agner Fog 2007

; © 2003-2007 GNU General Public License www.gnu.org/licenses/gpl.html

.686
.model flat

.code

; ********** round function **********
; C++ prototype:
; extern "C" int RoundD (double x);
; extern "C" int RoundF (float  x);

; This function converts a single or double precision floating point number 
; to an integer, rounding to nearest or even. Does not check for overflow.
; This function is much faster than the default conversion method in C++
; which uses truncation.

_RoundD PROC NEAR
PUBLIC _RoundD
        fld     qword ptr [esp+4]      ; Load x
        push    eax                    ; Make temporary space on stack
        fistp   dword ptr [esp]        ; Round. Store in temporary stack space
        pop     eax                    ; Read from temporary stack space
        ret
_RoundD  ENDP

_RoundF PROC NEAR
PUBLIC _RoundF
        fld     dword ptr [esp+4]
        push    eax
        fistp   dword ptr [esp]
        pop     eax
        ret
_RoundF ENDP

END
