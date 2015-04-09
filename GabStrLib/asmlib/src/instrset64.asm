;                   instrset64.asm                      © Agner Fog 2007-06-14
;
; InstructionSet
; ==============
; This function returns an integer indicating which instruction set is
; supported by the microprocessor and operating system. A program can
; call this function to determine if a particular set of instructions can
; be used.
;
; The method used here for detecting whether XMM instructions are enabled by
; the operating system is different from the method recommended by Intel.
; The method used here has the advantage that it is independent of the 
; ability of the operating system to catch invalid opcode exceptions. The
; method used here has been thoroughly tested on many different versions of
; Intel and AMD microprocessors, and is believed to work reliably. For further
; discussion of this method, see my manual "Optimizing subroutines in assembly
; language", 2007. (www.agner.org/optimize/).
; 
; © 2003 - 2008 GNU General Public License www.gnu.org/licenses/gpl.html
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.data
IInstrSet  dd      -1           ; this public variable is valid after first call
public IInstrSet


.code

; ********** InstructionSet function **********
; C++ prototype:
; extern "C" int InstructionSet (void);

; return value:
;  4 or above = SSE2 supported
;  5 or above = SSE3 supported
;  6 or above = Supplementary SSE3 supported
;  8 or above = SSE4.1 supported
; 10 or above = SSE4.2 supported


InstructionSet PROC
PUBLIC InstructionSet                  ; extern "C" name

        ; Check if this function has been called before
        mov     eax, [IInstrSet]
        test    eax, eax
        js      FirstTime              ; Negative means first time
        ; Early return. Has been called before
        ret                            ; Return value is in eax

FirstTime:
        push    rbx

        mov     eax, 1
        cpuid                          ; get features into edx and ecx
        
        mov     eax, 4                 ; at least SSE2 supported in 64 bit mode
        test    ecx, 1                 ; SSE3 support by microprocessor
        jz      ISEND
        inc     eax                    ; 5
        bt      ecx, 9                 ; Suppl-SSE3 support by microprocessor
        jnc     ISEND
        inc     eax                    ; 6
        bt      ecx, 19                ; SSE4.1 support by microprocessor
        jnc     ISEND
        mov     eax, 8                 ; 8
        bt      ecx, 20                ; SSE4.2 support by microprocessor
        jnc     ISEND
        mov     eax, 10                ; 10
       
ISEND:  mov     [IInstrSet], eax        ; save value in public variable

        pop     rbx
        ret                            ; return value is in eax

InstructionSet ENDP

END
