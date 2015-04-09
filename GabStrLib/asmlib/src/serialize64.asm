;                   serialize64.asm                      © Agner Fog 2007-06-15
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

.code

; ********** Serialize function **********
; C++ prototype:
; extern "C" void Serialize();


Serialize PROC
        push    rbx                    ; ebx is modified by cpuid
        sub     eax, eax
        cpuid                          ; cpuid function 0
        pop     rbx
        ret
Serialize ENDP
        
END
