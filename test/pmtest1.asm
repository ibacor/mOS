%include    "pm.inc"

org   07c00h
      jmp   LABEL_BEGIN

[SECTION .gdt]
;GDT
;
LABEL_GDT:          Descriptor  0,             0,  0   ;empty
LABEL_DESC_CODE32:  Descriptor  0,SegCode32Len-1,  DA_C+DA_32  ;
LABEL_DESC_VIDEO:   Descriptor 0B800h,    0ffffh,  DA_DRW
;GDT end

GdtLen      equ     $ - LABEL_GDT
GdtPtr      dw      GdtLen - 1
            dd      0

;GDT selector
SelectorCode32      equ     LABEL_DESC_CODE32 - LABEL_GDT
SelectorVideo       equ     LABEL_DESC_VIDEO  - LABEL_GDT
;end of [SECTION .gdt]

[SECTION .s16]
[BITS   16]
LABEL_BEGIN:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0100h

    ;initial 32bit code segment descriptor
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE32
    mov word [LABEL_DESC_CODE32 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE32 + 4], al
    mov byte [LABEL_DESC_CODE32 + 7], ah

    ;ready to load GDTR
    xor eax,eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_GDT
    mov dword [GdtPtr + 2], eax

    ;load GDTR
    lgdt [GdtPtr]

    ;close interupt
    cli

    ;open A20
    in al, 92h
    or al, 00000010b
    out 92h,al

    ;ready to switch to protect mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ;jump to protect mode
    jmp dword SelectorCode32:0
;END OF [SECTION .s16]

[SECTION .s32]  ;from real mode
[BITS   32]

LABEL_SEG_CODE32:
    mov ax, SelectorVideo
    mov gs, ax

    mov edi,(80 * 11 + 79) * 2  ;row 11, coloum 79
    mov ah, 0Ch     ;balck background,red word
    mov al, 'p'
    mov [gs:edi], ax

    ;end
    jmp $

SegCode32Len    equ $ - LABEL_SEG_CODE32
;END OF [SECTION .s32]
