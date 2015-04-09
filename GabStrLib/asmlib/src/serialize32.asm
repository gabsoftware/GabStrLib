;                   serialize32.asm                      © Agner Fog 2007-06-15
;
;
; Serialize
; =============
; This function serializes execution.
; Use this before and after calls to __readpmc() to prevent out-of-order execution.
; 
; © 2007 GNU General Public License www.gnu.org/licenses/gpl.html
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.686
.model flat

.code

; ********** Serialize function **********
; C++ prototype:
; extern "C" void Serialize();


_Serialize PROC NEAR
PUBLIC _Serialize

        push    ebx                    ; ebx is modified by cpuid
        sub     eax, eax
        cpuid                          ; cpuid function 0
        pop     ebx
        ret
_Serialize ENDP
        
END
