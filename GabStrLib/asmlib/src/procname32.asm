;                   procname32.asm                      © Agner Fog 2008-06-03
;
;
; ProcessorName
; =============
; This function produces a zero-terminated ASCII string containing a name
; for the microprocessor in human-readable format.
; 
; © 2003 - 2008 GNU General Public License www.gnu.org/licenses/gpl.html
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.686
.xmm
.model flat

.data

NameBuffer db 50H dup (0)              ; Static buffer to contain name

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
Read_EIP_into_EDI LABEL NEAR
        mov     edi, [esp]
        ret

ENDIF  ; End IF POSITIONINDEPENDENT


; ********** ProcessorName function **********
; C++ prototype:
; extern "C" char * ProcessorName ();

; This function finds the name of the microprocessor. The name is returned
; in the parameter text, which must be a character array of at least 68 bytes.

_ProcessorName PROC NEAR
PUBLIC _ProcessorName

        push    ebx
        push    edi
        
; Make edi point to NameBuffer:
        
IFDEF POSITIONINDEPENDENT

; Position-independent code for ELF and Mach-O shared objects:
MAKEDATAPOINTER EDI, NameBuffer

ELSE

; Normal code requiring base relocation:
        mov     edi, offset NameBuffer
        
ENDIF        
        
; detect if CPUID instruction supported by microprocessor:
        pushfd
        pop     eax
        xor     eax, 1 SHL 21          ; Check if CPUID bit can toggle
        push    eax
        popfd
        pushfd
        pop     ebx
        xor     eax, ebx
        and     eax, 1 SHL 21
        jnz     NOID                   ; CPUID not supported
        xor     eax, eax
        cpuid                          ; Get number of CPUID functions
        test    eax, eax
        jnz     IDENTIFYABLE           ; Function 1 supported
        
NOID:
        ; processor has no CPUID
        mov     DWORD PTR [edi], '8308'   ; Write text '80386 or 80486'
        mov     DWORD PTR [edi+4], 'ro 6'
        mov     DWORD PTR [edi+8], '408 '
        mov     DWORD PTR [edi+12], '68'  ; End with 0
        jmp     PNEND
        
IDENTIFYABLE:
        mov     eax, 80000000H
        cpuid
        cmp     eax, 80000004H         ; Text if extended vendor string available
        jb      no_ext_vendor_string

        ; Has extended vendor string
        mov     eax, 80000002H
        cpuid
        mov     [edi], eax             ; Store 16 bytes of extended vendor string
        mov     [edi+4], ebx
        mov     [edi+8], ecx
        mov     [edi+0CH], edx
        mov     eax, 80000003H
        cpuid
        mov     [edi+10H], eax         ; Next 16 bytes
        mov     [edi+14H], ebx
        mov     [edi+18H], ecx
        mov     [edi+1CH], edx
        mov     eax, 80000004H
        cpuid
        mov     [edi+20H], eax         ; Next 16 bytes
        mov     [edi+24H], ebx
        mov     [edi+28H], ecx
        mov     [edi+2CH], edx
        jmp     get_family_and_model
        
no_ext_vendor_string:
        ; No extended vendor string. Get short vendor string
        xor     eax, eax
        cpuid
        mov     [edi],ebx              ; Store short vendor string
        mov     [edi+4],edx
        mov     [edi+8],ecx
        mov     BYTE PTR [edi+12],0    ; Terminate string
        
get_family_and_model:
        push    edi                    ; Save string address
        xor     eax, eax
        mov     ecx, 30H
        cld
        repne   SCASB                  ; Find end of text
        dec     edi
        mov     DWORD PTR [edi], 'maF '   ; Append text " Family "
        mov     DWORD PTR [edi+4], ' yli'
        add     edi, 8

        mov     eax, 1
        cpuid                          ; Get family and model
        mov     ebx, eax
        mov     ecx, eax
        shr     eax, 8
        and     eax, 0FH               ; Family
        shr     ecx, 20
        and     ecx, 0FFH              ; Extended family
        add     eax, ecx               ; Family + extended family
        call    WriteHex               ; Write as hexadecimal

        mov     DWORD PTR [edi], 'oM H' ; Write text "H Model "
        mov     DWORD PTR [edi+4], ' led'
        add     edi, 8
        
        mov     eax, ebx
        shr     eax, 4
        and     eax, 0FH               ; Model
        mov     ecx, ebx
        shr     ecx, 12
        and     ecx, 0F0H              ; Extended model
        or      eax, ecx               ; Model | extended model
        call    WriteHex               ; Write as hexadecimal

        mov     DWORD PTR [edi], 'H'   ; Write text "H"
        pop     edi                    ; Restore string address
        
PNEND:  ; finished
        mov     eax, edi               ; Pointer to result
        pop     edi
        pop     ebx
        ret
_ProcessorName ENDP

WriteHex LABEL NEAR                    ; Local function: Write 2 hexadecimal digits
        ; Parameters: AL = number to write, EDI = text destination
        mov     ecx, eax
        shr     ecx, 4
        and     ecx, 0FH               ; most significant digit first
        cmp     ecx, 10
        jnb     W1
        ; 0 - 9
        add     ecx, '0'
        jmp     W2
W1:     ; A - F
        add     ecx, 'A' - 10
W2:     mov     [edi], cl              ; write digit
                
        mov     ecx, eax
        and     ecx, 0FH               ; next digit
        cmp     ecx, 10
        jnb     W3
        ; 0 - 9
        add     ecx, '0'
        jmp     W4
W3:     ; A - F
        add     ecx, 'A' - 10
W4:     mov     [edi+1], cl            ; write digit
        add     edi, 2                 ; advance string pointer
        ret
        
END
