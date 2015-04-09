;                   procname64.asm                      © Agner Fog 2008-06-03
;
;
; ProcessorName
; =============
; This function produces a zero-terminated ASCII string containing a name
; for the microprocessor in human-readable format.
; 
; © 2007 - 2008 GNU General Public License www.gnu.org/licenses/gpl.html
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.data

NameBuffer db 50H dup (0)              ; Static buffer to contain name


.code


; ********** ProcessorName function **********
; C++ prototype:
; void ProcessorName (char * text);

; This function finds the name of the microprocessor. The name is returned
; in the parameter text, which must be a character array of at least 68 bytes.

ProcessorName PROC

        push    rbx
        push    rdi
        lea     rdi, NameBuffer        ; text pointer
        
        mov     eax, 80000000H
        cpuid
        cmp     eax, 80000004H         ; text if extended vendor string available
        jb      no_ext_vendor_string

        ; Has extended vendor string
        mov     eax, 80000002H
        cpuid
        mov     [rdi], eax             ; store 16 bytes of extended vendor string
        mov     [rdi+4], ebx
        mov     [rdi+8], ecx
        mov     [rdi+0CH], edx
        mov     eax, 80000003H
        cpuid
        mov     [rdi+10H], eax         ; next 16 bytes
        mov     [rdi+14H], ebx
        mov     [rdi+18H], ecx
        mov     [rdi+1CH], edx
        mov     eax, 80000004H
        cpuid
        mov     [rdi+20H], eax         ; next 16 bytes
        mov     [rdi+24H], ebx
        mov     [rdi+28H], ecx
        mov     [rdi+2CH], edx
        jmp     get_family_and_model
        
no_ext_vendor_string:
        ; No extended vendor string. Get short vendor string
        xor     eax, eax
        cpuid
        mov     [rdi],ebx              ; store short vendor string
        mov     [rdi+4],edx
        mov     [rdi+8],ecx
        mov     BYTE PTR [rdi+12],0    ; terminate string
        
get_family_and_model:
        xor     eax, eax
        mov     ecx, 30H
        cld
        repne   SCASB                  ; find end of text
        dec     rdi
        
        mov     DWORD PTR [rdi], 'maF '   ; Append text " Family "
        mov     DWORD PTR [rdi+4], ' yli'
        add     rdi, 8

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

        mov     DWORD PTR [rdi], 'oM H' ; Write text "H Model "
        mov     DWORD PTR [rdi+4], ' led'
        add     rdi, 8
        
        mov     eax, ebx
        shr     eax, 4
        and     eax, 0FH               ; Model
        mov     ecx, ebx
        shr     ecx, 12
        and     ecx, 0F0H              ; Extended model
        or      eax, ecx               ; Model | extended model
        call    WriteHex               ; Write as hexadecimal

        mov     DWORD PTR [rdi], 'H'   ; Write text "H"
        
PNEND:  ; finished
        lea     rax, NameBuffer        ; Pointer to result
        pop     rdi
        pop     rbx
        ret
ProcessorName ENDP

WriteHex LABEL NEAR                    ; Local function: Write 2 hexadecimal digits
        ; Parameters: AL = number to write, RDI = text destination
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
W2:     mov     [rdi], cl              ; write digit
                
        mov     ecx, eax
        and     ecx, 0FH               ; next digit
        cmp     ecx, 10
        jnb     W3
        ; 0 - 9
        add     ecx, '0'
        jmp     W4
W3:     ; A - F
        add     ecx, 'A' - 10
W4:     mov     [rdi+1], cl            ; write digit
        add     rdi, 2                 ; advance string pointer
        ret
        
END
