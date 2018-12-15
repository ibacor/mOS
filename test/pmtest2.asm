%include    "pm.inc"

org   07c00h
      jmp   LABEL_BEGIN

[SECTION .gdt]
;GDT
;                               Base       Limit    Attr
LABEL_GDT:          Descriptor  0,             0,  0   ;empty
LABEL_DESC_NORMAL   Descriptor  0,        0ffffh,  DA_DRW   ;NORMAL DESCRIPTOR
LABEL_DESC_CODE32:  Descriptor  0,SegCode32Len-1,  DA_C+DA_32  ;
LABEL_DESC_CODE16:  Descriptor  0,        0ffffh,  DA_C
LABEL_DESC_DATA:    Descriptor  0,     DataLen-1,  DA_DRW
LABEL_DESC_STACK:   Descriptor  0,    TopOfStack, DA_DRWA+DA_32
LABEL_DESC_TEST:    Descriptor 0500000h,  0ffffh,  DA_DRW
LABEL_DESC_VIDEO:   Descriptor 0B800h,    0ffffh,  DA_DRW
;GDT end

GdtLen      equ     $ - LABEL_GDT
GdtPtr      dw      GdtLen - 1
            dd      0

;GDT selector
SelectorNormal      equ     LABEL_DESC_NORMAL - LABEL_GDT
SelectorCode32      equ     LABEL_DESC_CODE32 - LABEL_GDT
SelectorCode16      equ     LABEL_DESC_CODE16 - LABEL_GDT
SelectorData        equ     LABEL_DESC_DATA   - LABEL_GDT
SelectorStack       equ     LABEL_DESC_STACK  - LABEL_GDT
SelectorTest        equ     LABEL_DESC_TEST   - LABEL_GDT
SelectorVideo       equ     LABEL_DESC_VIDEO  - LABEL_GDT
;end of [SECTION .gdt]

[SECTION .data1]    ;data segment
ALIGN   32
[BITS   32]
LABEL_DATA:
SPValueInRealMode   dw  0
; STRING
PMMessage:          db  "In Protect Mode now. ^-^", 0
OffsetPMMessage     equ PMMessage - $$
StrTest:            db  "ABCDEFGH", 0
OffsetStrTest       equ StrTest - $$
DataLen             equ $ - LABEL_DATA
; END OF [SECTION .data1]

; global stack segment
[SECTION .gs]
ALIGN   32
[BITS   32]
LABEL_STACK:
    times   512 db 0

TopOfStack  equ $ - LABEL_STACK - 1
; END OF [SECTION .gs]

[SECTION .s16]
[BITS   16]
LABEL_BEGIN:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0100h

    mov [LABEL_GO_BACK_TO_REAL+3], ax
    mov [SPValueInRealMode], sp

    ; initial 16bit code segment descriptor
    mov ax, cs
    movzx eax, ax
    shl eax, 4
    add eax, LABEL_DESC_CODE16
    mov word [LABEL_DESC_CODE16 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE16 + 4], al
    mov byte [LABEL_DESC_CODE16 + 7], ah

    ; initial 32bit code segment descriptor
    xor eax, eax
    mov ax, cs
    shl eax, 4
    add eax, LABEL_SEG_CODE32
    mov word [LABEL_DESC_CODE32 + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_CODE32 + 4], al
    mov byte [LABEL_DESC_CODE32 + 7], ah

    ; initial data segment descriptor
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_DATA
    mov word [LABEL_DESC_DATA + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_DATA + 4], al
    mov byte [LABEL_DESC_DATA + 7], ah

    ; initial stack segment descriptor
    xor eax, eax
    mov ax, ds
    shl eax, 4
    add eax, LABEL_STACK
    mov word [LABEL_DESC_STACK + 2], ax
    shr eax, 16
    mov byte [LABEL_DESC_STACK + 4], al
    mov byte [LABEL_DESC_STACK + 7], ah

    ; ready to load GDTR
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

    ; from protect mode to real mode jump here
 LABEL_REAL_ENTRY:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax

    mov sp, [SPValueInRealMode]

    ; close A20
    in  al, 92h
    and al, 11111101b
    out 92h, al

    ; close interupt
    sti

    ; return to DOS
    mov ax, 4c00h
    int 21h
;END OF [SECTION .s16]

[SECTION .s32]  ;from real mode
[BITS   32]

LABEL_SEG_CODE32:
    mov ax, SelectorData
    mov ds, ax      ;dataSegment selector
    mov ax, SelectorTest
    mov es, ax
    mov ax, SelectorVideo
    mov gs, ax
    mov ax, SelectorStack
    mov ss, ax

    mov esp,TopOfStack

    ; show a string
    mov ah, 0Ch
    xor esi, esi
    xor edi, edi
    mov esi, OffsetPMMessage
    mov edi, (80 * 10 + 0) * 2
    cld
.1:
    lodsb
    test al, al
    jz  .2
    mov [gs:edi], ax
    add edi, 2
    jmp .1
.2:
    call DispReturn
    call TestRead
    call TestWrite
    call TestRead
    ;program end

; TestRead-----------------------------------
TestRead:
    xor esi, esi
    mov ecx, 8
.loop:
    mov al, [es:esi]
    call DispAL
    inc esi
    loop .loop

    call DispReturn
    ret
; TestRead-----------------------------------

; TestWrite----------------------------------
TestWrite:
    push esi
    push edi
    xor esi, esi
    xor edi, edi
    mov esi, OffsetStrTest
    cld
.1:
    lodsb
    test al, al
    jz   .2
    mov [es:edi], al
    inc edi
    jmp .1
.2:
    pop edi
    pop esi

    ret
; TestWrite----------------------------------


; DispAL-------------------------------------
; 显示 AL 中的数字
; 默认地:
;   数字已经存在 AL 中
;   edi 始终指向要显示的下一个字符的位置
; 被改变的寄存器:
;   ax, edi

DispAL:
    push ecx
    push edx

    mov ah, 0Ch
    mov dl, al
    shr al, 4
    mov ecx, 2
.begin:
    and al, 01111b
    cmp al, 9
    ja  .1
    add al, '0'
    jmp .2
.1:
    sub al, 0Ah
    add al, 'A'
.2:
    mov [gs:edi],ax
    add edi,2

    mov al, dl
    loop .begin
    add edi,2

    pop edx
    pop ecx

    ret
; DispAL----------------------------------

; DispReturn------------------------------
DispReturn:
    push eax
    push ebx
    mov eax, edi
    mov bl, 160
    div bl
    and eax, 0FFh
    inc eax
    mov bl, 160
    mul bl
    mov edi, eax
    pop ebx
    pop eax

    ret
; DispReturn------------------------------

;----------------------------------------------------
;    jmp SelectorCode16:0
;    
;    mov edi,(80 * 11 + 79) * 2  ;row 11, coloum 79
;    mov ah, 0Ch     ;balck background,red word
;    mov al, 'p'
;    mov [gs:edi], ax

    ;end
;    jmp $
;----------------------------------------------------
SegCode32Len    equ $ - LABEL_SEG_CODE32
;END OF [SECTION .s32]

; 16 位代码段. 由 32 位代码段跳入, 跳出后到实模式
[SECTION .s16code]
ALIGN   32
[BITS   16]
LABEL_SEG_CODE16:
    ;jump to real mode
    mov ax, SelectorNormal
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    mov eax, cr0
    and al, 11111110b
    mov cr0, eax

LABEL_GO_BACK_TO_REAL:
    jmp 0:LABEL_REAL_ENTRY

Code16Len   equ $ - LABEL_SEG_CODE16
; END OF [SECTION .s16code]
