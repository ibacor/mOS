    org 07c00h

;==================================================================
BaseOfStack     equ 07c00h  ;堆栈基地址(栈底, 从这个位置向低地址生长)

%include    "load.inc"
;==================================================================

    jmp short LABEL_START   ; start to boot
    nop

; 下面是 FAT12 磁盘的头, 之所以包含它是因为下面用到了磁盘的一些信息
%include    "fat12hdr.inc"

LABEL_START:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, BaseOfStack

    ; 清屏
    mov ax, 0600h
    mov bx, 0700h
    mov cx, 0
    mov dx, 0184fh
    int 10h

    mov dh, 0   ;"Booting  "
    call DispStr

    ;软驱复位
    xor ah, ah
    xor dl, dl
    int 13h
    

; 下面在 A 盘的根目录寻找 LOADER.BIN
    mov word [wSectorNo], SectorNoOfRootDirectory
LABEL_SEARCH_IN_ROOT_DIR_BEGIN:
    cmp word [wRootDirSizeForLoop], 0
    jz  LABEL_NO_LOADERBIN
    dec word [wRootDirSizeForLoop]
    
    mov ax, BaseOfLoader
    mov es, ax
    mov bx, OffsetOfLoader
    mov ax, [wSectorNo]
    mov cl, 1
    call ReadSector

    mov si, LoaderFileName
    mov di, OffsetOfLoader
    cld
    mov dx, 10h
LABEL_SEARCH_FOR_LOADERBIN:
    cmp dx, 0
    jz  LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR
    dec dx
    mov cx, 11
LABEL_CMP_FILENAME:
    cmp cx, 0
    jz  LABEL_FILENAME_FOUND
    dec cx
    lodsb
    cmp al, byte [es:di]
    jz  LABEL_GO_ON
    jmp LABEL_DIFFERENT

LABEL_GO_ON:
    inc di
    jmp LABEL_CMP_FILENAME

LABEL_DIFFERENT:
    and di, 0FFE0h
    add di, 20h
    mov si, LoaderFileName
    jmp LABEL_SEARCH_FOR_LOADERBIN

LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
    add word [wSectorNo], 1
    jmp LABEL_SEARCH_IN_ROOT_DIR_BEGIN

LABEL_NO_LOADERBIN:
    mov ah, 2   ;"No LOADER"
    call DispStr

    jmp $   ;没有找到 LOADER.BIN, 死循环在这里

LABEL_FILENAME_FOUND:
    mov ax, RootDirSectors
    and di, 0FFE0h
    add di, 01Ah
    mov cx, word [es:di]
    push cx
    add cx, ax
    add cx, DeltaSectorNo
    mov ax, BaseOfLoader
    mov es, ax
    mov bx, OffsetOfLoader
    mov ax, cx

LABEL_GOON_LOADING_FILE:
    push ax
    push bx
    mov ah, 0Eh
    mov al, '.'
    mov bl, 0Fh
    int 10h
    pop bx
    pop ax

    mov cl, 1
    call ReadSector
    pop ax
    call GetFATEntry
    cmp ax, 0FFFh
    jz  LABEL_FILE_LOADED
    push ax
    mov dx, RootDirSectors
    add ax, dx
    add ax, DeltaSectorNo
    add bx, [BPB_BytsPerSec]
    jmp LABEL_GOON_LOADING_FILE
LABEL_FILE_LOADED:
    mov dh, 1   ;"Ready.  "
    call DispStr
;*******************************
;jump to the begin of LAODER.BIN, Boot Sector end!
    jmp BaseOfLoader:OffsetOfLoader
;********************************

;变量============================================
wRootDirSizeForLoop dw  RootDirSectors

wSectorNo           dw  0
bOdd                db  0

;================================================
; string
LoaderFileName  db  "LOADER  BIN", 0

MessageLength   equ 9
BootMessage:    db  "Booting  "
Message1:       db  "Ready.   "
Message2:       db  "No LOADER"
;================================================ 

;------------------------------------------------
;显示一个字符串, 函数开始时 dh 中应该是字符串序号(0-based)
DispStr:
    mov ax, MessageLength
    mul dh
    add ax, BootMessage
    mov bp, ax
    mov ax, ds
    mov es, ax
    mov cx, MessageLength  ;string length
    mov ax, 01301h
    mov bx, 0007h   ;page 0, black background white word
    mov dl, 0
    int 10h
    ret


;------------------------------------------------
ReadSector:
    ; 怎样由扇区号求扇区在磁盘中的位置 (扇区号 -> 柱面号, 起始扇区, 磁头号)
    ; -----------------------------------------------------------------
    ; 设扇区号为 x
    ;                           ┌ 柱面号 = y >> 1
    ;       x           ┌ 商 y ┤
    ; -------------- => ┤      └ 磁头号 = y & 1
    ;  每磁道扇区数     │
    ;                   └ 余 z => 起始扇区号 = z + 1
    push bp
    mov  bp, sp
    sub  esp, 2

    mov  byte [bp-2], cl
    push bx
    mov  bl, [BPB_SecPerTrk]
    div  bl
    inc  ah
    mov  cl, ah
    mov  dh, al
    shr  al, 1
    mov  ch, al
    and  dh, 1
    pop  bx

    mov  dl, [BS_DrvNum]
.GoOnReading:
    mov ah, 2
    mov al, byte [bp-2]
    int 13h
    jc  .GoOnReading

    add esp, 2
    pop bp

    ret

;--------------------------------------------------
GetFATEntry:
    push es
    push bx
    push ax
    mov ax, BaseOfLoader
    sub ax, 0100h
    mov es, ax
    pop ax
    mov byte [bOdd], 0
    mov bx, 3
    mul bx
    mov bx, 2
    div bx
    cmp dx, 0
    jz  LABEL_EVEN
    mov byte [bOdd], 1
LABEL_EVEN:
    xor dx, dx
    mov bx, [BPB_BytsPerSec]
    div bx

    push dx
    mov bx, 0
    add ax, SectorNoOfFAT1
    mov cl, 2
    call ReadSector

    pop dx
    add bx, dx
    mov ax, [es:bx]
    cmp byte[bOdd], 1
    jnz LABEL_EVEN_2
    shr ax, 4
LABEL_EVEN_2:
    and ax, 0FFFh

LABEL_GET_FAT_ENRY_OK:
    pop bx
    pop es
    ret

times 510-($-$$)    db 0
dw    0xaa55        ; end flag

