;                   instrset32.asm                      © Agner Fog 2007-06-14
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
; language", 2008. (www.agner.org/optimize/).
; 
; © 2003, 2008 GNU General Public License www.gnu.org/licenses/gpl.html
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; ********** InstructionSet function **********
; C++ prototype:
; extern "C" int InstructionSet (void);
;
; return value:
;  0 = use 80386 instruction set
;  1 or above = MMX instructions supported
;  2 or above = conditional move and FCOMI supported
;  3 or above = SSE (XMM) supported by processor and operating system
;  4 or above = SSE2 supported by processor and operating system
;  5 or above = SSE3 supported by processor and operating system
;  6 or above = Supplementary SSE3 supported by processor and operating system
;  8 or above = SSE4.1 supported by processor and operating system
; 10 or above = SSE4.2 supported by processor and operating system
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.686
.xmm
.model flat

.data
_IInstrSet dd    -1
public _IInstrSet

.code

IFDEF POSITIONINDEPENDENT
; Make position-independent code for ELF and Mach-O shared objects:

; Define instruction codes for register names
?EAX  equ  000b
?EBX  equ  011b
?ECX  equ  001b
?EDX  equ  010b
?ESI  equ  110b
?EDI  equ  111b
?EBP  equ  101b
?ESP  equ  100b

; Macro for making pointer to a reference point in data segment in 32 bit code.
; Call this macro in the beginning of a function that needs to address data
; in the data segment. 
;
; Parameters:
; REGISTERNAME:   A 32-bit register that you want to use as pointer
; REFERENCEPOINT: A label in the data segment
; 
; The macro will make the register point to the reference point

MAKEDATAPOINTER MACRO REGISTERNAME, REFERENCEPOINT
local p0, p1, p2
   call Read_EIP_into_&REGISTERNAME       ; make register point to p0
p0:                                       ; register REGISTERNAME now points here
   db  81h                                ; beginning of add REGISTERNAME, xxx instruction
p1:   
   call near ptr REFERENCEPOINT + (p2-p0) ; Bogus CALL instruction for making self-relative reference
p2:
; back patch CALL instruction to change it to  ADD REGISTERNAME, (REFERENCEPOINT - p0)
   org p1                    
   db  0C0H + ?&REGISTERNAME              ; second byte of instruction  ADD REGISTERNAME, (REFERENCEPOINT - p0)
   org p2                                 ; now REGISTERNAME points to REFERENCEPOINT
ENDM 

; Local function for reading instruction pointer into edi
Read_EIP_into_EDX LABEL NEAR
        mov     edx, [esp]
        ret

ENDIF  ; End IF POSITIONINDEPENDENT



_InstructionSet PROC NEAR
PUBLIC _InstructionSet                  ; extern "C" name

        
IFDEF POSITIONINDEPENDENT
        ; Position-independent code for ELF and Mach-O shared objects:
        MAKEDATAPOINTER EDX, _IInstrSet
        mov     eax, [edx]
ELSE
        mov     eax, [_IInstrSet]
ENDIF        
        ; Check if this function has been called before
        test    eax, eax
        js      FirstTime              ; Negative means first time
        ret                            ; Early return. Has been called before

FirstTime:                             ; Function has not been called before
        push    ebx

IFNDEF  POSITIONINDEPENDENT
        mov     edx, offset _IInstrSet ; make edx point to _IInstrSet
ENDIF
        push    edx                    ; save address of _IInstrSet
        
        ; detect if CPUID instruction supported by microprocessor:
        pushfd
        pop     eax
        btc     eax, 21                ; check if CPUID bit can toggle
        push    eax
        popfd
        pushfd
        pop     ebx
        xor     ebx, eax
        xor     eax, eax               ; 0
        bt      ebx, 21
        jc      ISEND                  ; CPUID not supported
        cpuid                          ; get number of CPUID functions
        test    eax, eax
        jz      ISEND                  ; function 1 not supported
        mov     eax, 1
        cpuid                          ; get features
        xor     eax, eax               ; 0
        test    edx, 1                 ; floating point support
        jz      ISEND
        bt      edx, 23                ; MMX support        
        jnc     ISEND
        inc     eax                    ; 1
        bt      edx, 15                ; conditional move support
        jnc     ISEND
        inc     eax                    ; 2
        bt      edx, 24                ; FXSAVE support by microprocessor
        jnc     ISEND
        bt      edx, 25                ; SSE support by microprocessor
        jnc     ISEND
        inc     eax                    ; 3
        bt      edx, 26                ; SSE2 support by microprocessor
        jnc     OSXMM
        inc     eax                    ; 4
        test    ecx, 1                 ; SSE3 support by microprocessor
        jz      OSXMM
        inc     eax                    ; 5        
        bt      ecx, 9                 ; Suppl-SSE3 support by microprocessor
        jnc     OSXMM
        inc     eax                    ; 6
        bt      ecx, 19                ; SSE4.1 support by microprocessor
        jnc     OSXMM
        mov     eax, 8                 ; 8
        bt      ecx, 20                ; SSE4.2 support by microprocessor
        jnc     OSXMM
        mov     eax, 10                ; 10
        
OSXMM:  ; test if operating system supports XMM registers:
        mov     ebx, esp               ; save stack pointer
        sub     esp, 200H              ; allocate space for FXSAVE
        and     esp, -10H              ; align by 16
TESTDATA = 0D95A34BEH                  ; random test value
TESTPS   = 10CH                        ; position to write TESTDATA = upper part of XMM6 image
        fxsave  [esp]                  ; save FP/MMX and XMM registers
        mov     ecx,[esp+TESTPS]       ; read part of XMM6 register
        xor     DWORD PTR [esp+TESTPS],TESTDATA  ; change value
        fxrstor [esp]                  ; load changed value into XMM6
        mov     [esp+TESTPS],ecx       ; restore old value in buffer
        fxsave  [esp]                  ; save again
        mov     edx,[esp+TESTPS]       ; read changed XMM6 register
        mov     [esp+TESTPS],ecx       ; restore old value
        fxrstor [esp]                  ; load old value into XMM6
        xor     ecx, edx               ; get difference between old and new value
        mov     esp, ebx               ; restore stack pointer
        cmp     ecx, TESTDATA          ; test if XMM6 was changed correctly
        je      ISEND                  ; test successful
        mov     eax, 2                 ; test failed. XMM not supported by operating system
        
ISEND:  pop     edx                    ; address of _IInstrSet
        mov     [edx], eax             ; save value in public variable _IInstrSet
        pop     ebx
        ret                            ; return value is in eax

_InstructionSet ENDP

END
