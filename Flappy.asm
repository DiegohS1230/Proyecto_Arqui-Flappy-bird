.model tiny
.code
org 100h
jmp start

; ======================================================
; CONSTANTS
; ======================================================

SCREEN_W       equ 320
SCREEN_H       equ 200

BIRD_X         equ 80
BIRD_W         equ 14
BIRD_H         equ 14

GAP_H_MIN      equ 70
GAP_H_MAX      equ 100
PIPE_W         equ 40
PIPE_SPEED     equ 3
GRAVITY        equ 1
FLAP_VEL       equ -8
MAX_FALL       equ 10

; ======================================================
; VARIABLES
; ======================================================

; Variables de colores para poder cambiarlos en vivo
sky_col        db 3
pipe_col       db 6
bird_col       db 14
text_col       db 15
bark_col       db 4
leaf_col       db 2

pipe_speed     dw PIPE_SPEED
difficulty_mul dw 1
birdY          dw 100
oldBirdY       dw 100
velocity       dw 0
paused         db 0
current_speed  dw PIPE_SPEED
pipeX          dw 320
oldPipeX       dw 320
gapY           dw 70
gapDir         dw 2
gapH           dw 90

score          dw 0
high_score     dw 0
deaths         dw 0
passed         db 0
rand_seed      dw 1234

; ======================================================
; Difficulty
; ======================================================

update_difficulty:
    mov ax, score
    mov bx,  5
    xor dx, dx
    div bx              ; AX=score/5
    inc ax              ; +1 so starts at 1
    cmp ax, 5
    jle no_cap
    mov ax, 5           ; Cap at 5?
no_cap:
    mov difficulty_mul, ax
    
    mov bx, PIPE_SPEED
    mul bx
    mov pipe_speed, ax

    ; shrink gap height
    mov ax, gapH
    sub ax, difficulty_mul
    cmp ax, 60
    jge ok_gap
    mov ax, 60
ok_gap:
    mov gapH, ax
    ret

; ======================================================
; START
; ======================================================
start:
    push cs      
    pop ds       
    call init_gfx
    call show_welcome
    
main_loop:
    call frame_delay

; ==========================
; INPUT (SAFE  pause key)
; ==========================
mov ah, 01h
int 16h
jz noKey                    ;no key,continue

;Pek key withot removig it
mov ah, 01h
int 16h
jz noKey

; AL now contains key but is NOT consumed yet

cmp al, ' '
jne noKey_flap

; SPACE pressed ? now consume it
mov ah, 00h
int 16h
mov velocity, FLAP_VEL
call play_flap_sound
jmp noKey

noKey_flap:
; DO NOT CONSUME the key let pause block read it
noKey:
; =======================
;  CHECK FOR PAUSE KEY
; =======================
mov ah, 01h
int 16h
jz noPauseCheck

mov ah, 00h
int 16h

cmp al, 'p'
jne not_p1
jmp toggle_pause
not_p1:

cmp al, 'P'
jne not_p2
jmp toggle_pause
not_p2:

cmp al, 27         ; ESC
jne noPauseCheck
jmp toggle_pause

noPauseCheck:
    ; PHYSICS
    mov ax, velocity
    add ax, GRAVITY
    cmp ax, MAX_FALL
    jle velOK
    mov ax, MAX_FALL
velOK:
    mov velocity, ax

    mov ax, birdY
    add ax, velocity
    cmp ax, 0
    jge noCeil
    xor ax, ax
    mov velocity, 0
noCeil:
    cmp ax, 175
    jle noFloor
    mov ax, 175
noFloor:
    mov birdY, ax

    ; PIPE MOVEMENT
    mov ax, pipeX
    mov bx, pipe_speed
    sub ax, bx
    mov pipeX, ax
    
    cmp ax, -PIPE_W
    jg noReset

    mov pipeX, SCREEN_W
    mov passed, 0

    ; Random gap Y position (20-110)
    call get_random
    and ax, 127      
    cmp ax, 90
    jle gap_y_ok
    sub ax, 90
gap_y_ok:
    add ax, 20       
    mov gapY, ax

    ; Random gap height (70-100)
    call get_random
    and ax, 31       
    add ax, GAP_H_MIN 
    cmp ax, GAP_H_MAX
    jle gap_h_ok
    mov ax, GAP_H_MAX
gap_h_ok:
    mov gapH, ax

noReset:

    ; SCORING
    mov ax, pipeX
    add ax, PIPE_W
    cmp ax, BIRD_X
jg noScore
cmp passed, 0
jne noScore
mov passed, 1
inc score
call play_score_sound

call update_difficulty
noScore:

    ; ERASE OLD POSITIONS
    mov bx, BIRD_X
    mov cx, oldBirdY
    mov si, BIRD_W
    mov di, BIRD_H
    mov al, sky_col
    call rect

    mov bx, oldPipeX
    mov cx, 0
    mov si, PIPE_W
    mov di, SCREEN_H
    mov al, sky_col
    call rect

    ; DRAW NEW POSITIONS
    mov bx, BIRD_X
    mov cx, birdY
    mov si, BIRD_W
    mov di, BIRD_H
    mov al, bird_col
    call rect

    ; ARBOL SUPERIOR
    mov bx, pipeX
    mov cx, 0
    mov si, PIPE_W
    mov di, gapY
    cmp di, 8
    jl skip_top
    mov al, pipe_col
    call rect

    ; Veta del tronco superior
    mov bx, pipeX
    add bx, 10
    mov si, 4
    mov al, bark_col
    call rect

    ; Hojas en la parte inferior
    mov bx, pipeX
    mov cx, gapY
    sub cx, 8
    mov si, PIPE_W
    mov di, 8
    mov al, leaf_col
    call rect
skip_top:

    ; ARBOL INFERIOR
    mov bx, pipeX
    mov cx, gapY
    add cx, gapH
    mov si, PIPE_W
    mov ax, SCREEN_H
    sub ax, cx
    cmp ax, 8
    jl skip_bottom
    mov di, ax
    mov al, pipe_col
    call rect

    ; Veta del tronco inferior
    mov bx, pipeX
    add bx, 10
    mov si, 4
    mov al, bark_col
    call rect

    ; Hojas en la parte superior
    mov bx, pipeX
    mov cx, gapY
    add cx, gapH
    mov si, PIPE_W
    mov di, 8
    mov al, leaf_col
    call rect
skip_bottom:

    ; DRAW SCORE HUD (top left)
    call draw_score_hud

    ; Save positions
    mov ax, birdY
    mov oldBirdY, ax
    mov ax, pipeX
    mov oldPipeX, ax

    ; COLLISION
    mov ax, BIRD_X
    add ax, BIRD_W
    cmp ax, pipeX
    jle safe

    mov ax, pipeX
    add ax, PIPE_W
    cmp ax, BIRD_X
    jle safe

    mov ax, birdY
    add ax, BIRD_H
    cmp ax, gapY
    jl crash

    mov ax, birdY
    mov bx, gapY
    add bx, gapH
    cmp ax, bx
    jg crash

    cmp birdY, 175
    jge crash

safe:
    jmp main_loop

crash:
   inc deaths
   call play_crash_sound

call show_game_over
jmp main_loop
toggle_pause:
    cmp paused, 0
    je do_pause

; =============== RESUME ===============
resume_game:
    mov paused, 0
    call clear_pause_overlay
    jmp main_loop

; =============== PAUSE ===============
do_pause:
    mov paused, 1
    call draw_pause_overlay

pause_wait:
    mov ah, 00h
    int 16h
    cmp al, 'p'
    je resume_game
    cmp al, 'P'
    je resume_game
    cmp al, 27
    je resume_game
    jmp pause_wait

; ======================================================
; PLAY FLAP SOUND (Mario-style plop)
; ======================================================
play_flap_sound:
    push ax
    push bx
    push cx
    push dx

    mov bx, 800       
    mov cx, 5         

flap_step:
    mov al, 0B6h
    out 43h, al
    mov al, bl
    out 42h, al
    mov al, bh
    out 42h, al
    
    in al, 61h
    or al, 3
    out 61h, al

    mov dx, 200       
delay_loop:
    dec dx
    jnz delay_loop

    in al, 61h
    and al, 0FCh
    out 61h, al

    add bx, 60
    loop flap_step

    pop dx
    pop cx
    pop bx
    pop ax
    ret
    
play_score_sound:
    push ax
    push bx
    push cx
    push dx

    mov bx, 1200      
    mov cx, 4         

score_step:
    mov al, 0B6h
    out 43h, al
    mov al, bl
    out 42h, al
    mov al, bh
    out 42h, al

    in al, 61h
    or al, 3
    out 61h, al

    mov dx, 250
score_delay:
    dec dx
    jnz score_delay

    in al, 61h
    and al, 0FCh
    out 61h, al

    sub bx, 40        
    loop score_step

    pop dx
    pop cx
    pop bx
    pop ax
    ret
    
play_crash_sound:
    push ax
    push bx
    push cx
    push dx

    mov bx, 300       
    mov cx, 6         

crash_step:
    mov al, 0B6h
    out 43h, al
    mov al, bl
    out 42h, al
    mov al, bh
    out 42h, al

    in al, 61h
    or al, 3
    out 61h, al

    mov dx, 200
crash_delay:
    dec dx
    jnz crash_delay

    in al, 61h
    and al, 0FCh
    out 61h, al

    add bx, 50        
    loop crash_step

    pop dx
    pop cx
    pop bx
    pop ax
    ret
    
; ======================================================
; PANTALLA DE BIENVENIDA
; ======================================================
show_welcome:
    push ax
    push bx
    push cx
    push si
    push di

draw_welcome_screen:
    call draw_sky_once
    call draw_pipes_welcome
    call draw_bird_welcome
    
    mov bx, 88
    mov cx, 50
    call draw_text_flappy
    
    ; Mensaje "PRESS S"
    mov bx, 125
    mov cx, 130
    call draw_text_start

welcome_wait:
    mov ah, 00h
    int 16h

    cmp al, ' '      ; ESPACIO = Colores Alternativos
    je set_alt_colors

    cmp al, 0Dh      ; ENTER = Colores Originales
    je set_orig_colors

    cmp al, 's'      ; 'S' minúscula para iniciar
    je welcome_done
    cmp al, 'S'      ; 'S' mayúscula para iniciar
    je welcome_done

cmp al, 27       ; ESC = Salir
    jne welcome_wait 
    jmp exit_game    

set_alt_colors:
    mov sky_col, 1   ; Azul oscuro
    mov pipe_col, 8  ; Gris
    mov bark_col, 8  ; Gris
    mov leaf_col, 10 ; Verde neón
    mov bird_col, 12 ; Rojo
    mov text_col, 11 ; Cian claro (Texto Neón)
    jmp draw_welcome_screen
    
set_orig_colors:
    mov sky_col, 3   ; Cian original
    mov pipe_col, 6  ; Café original
    mov bark_col, 4  ; Rojo oscuro original
    mov leaf_col, 2  ; Verde original
    mov bird_col, 14 ; Amarillo original
    mov text_col, 15 ; Blanco original
    jmp draw_welcome_screen

welcome_done:
    call draw_sky_once
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret
   
; ======================================================
; TUBERIAS PARA LA PANTALLA DE BIENVENIDA
; ======================================================
draw_pipes_welcome:
    push ax
    push bx
    push cx
    push si
    push di

    ; Tuberia izquierda superior
    mov bx, 12
    mov cx, 35
    mov si, 22
    mov di, 43
    mov al, pipe_col
    call rect

    ; Tapa inferior de la tuberia superior
    mov bx, 8
    mov cx, 76
    mov si, 30
    mov di, 8
    mov al, leaf_col
    call rect

    ; Tuberia izquierda inferior
    mov bx, 12
    mov cx, 145
    mov si, 22
    mov di, 35
    mov al, pipe_col
    call rect

    ; Tapa superior de la tuberia inferior
    mov bx, 8
    mov cx, 141
    mov si, 30
    mov di, 8
    mov al, leaf_col
    call rect

    ; Tuberia derecha superior
    mov bx, 286
    mov cx, 25
    mov si, 22
    mov di, 35
    mov al, pipe_col
    call rect

    ; Tapa inferior derecha
    mov bx, 282
    mov cx, 56
    mov si, 30
    mov di, 8
    mov al, leaf_col
    call rect

    ; Tuberia derecha inferior
    mov bx, 286
    mov cx, 112
    mov si, 22
    mov di, 68
    mov al, pipe_col
    call rect

    ; Tapa superior derecha
    mov bx, 282
    mov cx, 108
    mov si, 30
    mov di, 8
    mov al, leaf_col
    call rect

    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret
    
; ======================================================
; PAJARO DECORATIVO
; ======================================================
draw_bird_welcome:
    push ax
    push bx
    push cx
    push si
    push di

    ; Cuerpo 
    mov bx, 153
    mov cx, 95
    mov si, BIRD_W
    mov di, BIRD_H
    mov al, bird_col
    call rect

    ; Ala naranja
    mov bx, 157
    mov cx, 103
    mov si, 9
    mov di, 4
    mov al, 6
    call rect

    ; Ojo blanco
    mov bx, 166
    mov cx, 98
    mov si, 5
    mov di, 5
    mov al, 15
    call rect

    ; Pupila negra
    mov bx, 169
    mov cx, 100
    mov si, 2
    mov di, 2
    mov al, 0
    call rect

    ; Pico naranja
    mov bx, 167
    mov cx, 104
    mov si, 3
    mov di, 2
    mov al, 0Ch
    call rect

    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------
; Texto "FLAPPY BIRD"   BX=x, CX=y
; ------------------------------------------------------
draw_text_flappy:
    push bx
    push cx
    call draw_letter_f
    add bx, 14
    call draw_letter_l
    add bx, 14
    call draw_letter_a
    add bx, 14
    call draw_letter_p
    add bx, 14
    call draw_letter_p
    add bx, 14
    call draw_letter_y
    add bx, 22                  
    call draw_letter_b
    add bx, 14
    call draw_letter_i
    add bx, 14
    call draw_letter_r
    add bx, 14
    call draw_letter_d
    pop cx
    pop bx
    ret

; ======================================================
; DRAW SCORE HUD (FIXED)
; ======================================================
draw_score_hud:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Erase old score area 
    mov bx, 5
    mov cx, 5
    mov si, 70
    mov di, 12
    mov al, sky_col
    call rect
    
    ; Erase old deaths area 
    mov bx, 280
    mov cx, 5
    mov si, 35
    mov di, 12
    mov al, sky_col
    call rect
    
    ; Draw score digits
    mov bx, 8
    mov cx, 6
    mov ax, score
    call draw_number_simple
    
    ; Draw deaths
    mov bx, 290
    mov cx, 6
    mov ax, deaths
    call draw_number_simple
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

draw_pause_overlay:
    ; Dark transparent rectangle
    mov bx, 60
    mov cx, 70
    mov si, 200
    mov di, 60
    mov al, 0
    call rect

    ; Border
    mov bx, 60
    mov cx, 70
    mov si, 200
    mov di, 2
    mov al, text_col
    call rect

    mov bx, 60
    mov cx, 130
    mov si, 200
    mov di, 2
    mov al, text_col
    call rect

    mov bx, 60
    mov cx, 70
    mov si, 2
    mov di, 60
    mov al, text_col
    call rect

    mov bx, 258
    mov cx, 70
    mov si, 2
    mov di, 60
    mov al, text_col
    call rect

    ; Draw text "PAUSED"
    mov bx, 110
    mov cx, 95
    call draw_text_paused
    ret

; ======================================================
; SHOW GAME OVER SCREEN
; ======================================================
show_game_over:
    ; Update high score
    mov ax, score
    cmp ax, high_score
    jle skip_hs
    mov high_score, ax
skip_hs:

    ; Draw black rectangle
    mov bx, 40
    mov cx, 60
    mov si, 240
    mov di, 100
    mov al, 0
    call rect

    ; Border
    mov bx, 42
    mov cx, 62
    mov si, 236
    mov di, 2
    mov al, text_col
    call rect
    
    mov bx, 42
    mov cx, 156
    mov si, 236
    mov di, 2
    mov al, text_col
    call rect
    
    mov bx, 42
    mov cx, 62
    mov si, 2
    mov di, 96
    mov al, text_col
    call rect
    
    mov bx, 276
    mov cx, 62
    mov si, 2
    mov di, 96
    mov al, text_col
    call rect

    ; Draw "GAME OVER"
    mov bx, 90
    mov cx, 75
    call draw_text_gameover

    ; Draw "SCORE: XX"
    mov bx, 100
    mov cx, 95
    call draw_text_score
    
    mov bx, 180
    mov cx, 95
    mov ax, score
    call draw_number_simple

    ; Draw "BEST: XX"
    mov bx, 105
    mov cx, 110
    call draw_text_best
    
    mov bx, 180
    mov cx, 110
    mov ax, high_score
    call draw_number_simple
    
    ; Draw "DEATHS: XX"
    mov bx, 95
    mov cx, 125
    call draw_text_deaths
    mov bx, 180
    mov cx, 125
    mov ax, deaths
    call draw_number_simple

    ; Draw "PRESS ENTER "
    mov bx, 80
    mov cx, 140
    call draw_text_enter

; Wait for Enter
wait_enter:
    mov ah, 00h
    int 16h        ; get key
    cmp al, 27     ; ESC = exit
    je exit_game
    cmp al, 0Dh    ; Enter = retry
    jne wait_enter ; loop until Enter
    
    ; Reset
    mov birdY, 100
    mov oldBirdY, 100
    mov velocity, 0
    mov pipeX, 320
    mov oldPipeX, 320
    mov gapY, 70
    mov gapDir, 2
    mov gapH, 90
    mov score, 0
    mov passed, 0
    mov difficulty_mul, 1   
    mov pipe_speed, 3 
    call draw_sky_once
    ret

exit_game:
    mov ax, 3
    int 10h
    mov ah, 4Ch
    int 21h

; ======================================================
; DRAW NUMBER (FIXED)
; BX=x, CX=y, AX=number (0-999)
; ======================================================
draw_number_simple:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    mov si, bx  ; SI = X position
    mov di, cx  ; DI = Y position
    
    ; Convert to digits
    xor dx, dx
    mov bx, 100
    div bx
    mov bx, dx  ; BX = remainder (tens + ones)
    
    ; Draw hundreds (skip if 0)
    push ax
    push bx
    cmp al, 0
    je skip_hundreds
    add al, '0'  
    mov bx, si
    mov cx, di
    call draw_digit_3x5
skip_hundreds:
    pop bx
    pop ax
    add si, 4
    
    ; Draw tens
    mov ax, bx
    xor dx, dx
    mov bx, 10
    div bx
    push dx     ; Save ones
    add al, '0'
    mov bx, si
    mov cx, di
    call draw_digit_3x5
    add si, 4
    
    ; Draw ones
    pop ax
    add al, '0'
    mov bx, si
    mov cx, di
    call draw_digit_3x5
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ======================================================
; DRAW SINGLE DIGIT (FIXED)
; ======================================================
draw_digit_3x5:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es
    
    ; Set up video segment
    push ax
    mov ax, 0A000h
    mov es, ax
    pop ax
    
    mov bp, bx  ; BP = X position
    push cx     ; Save Y position on stack
    
    sub al, '0'
    cmp al, 9
    ja skip_digit
    
    ; Calculate font offset
    mov ah, 0
    mov si, 15
    mul si
    mov si, ax
    add si, offset digit_font  ;stride
    
    ; Draw 5 rows
    pop dx      ; DX = Y position
    push dx
    mov bx, 5   ; BX = row counter
    
draw_d_row:
    push bp     ; Save X position
    push bx     ; Save row counter
    mov cx, 3   ; CX = column counter
    
draw_d_col:
    push cx
    mov al, byte ptr cs:[si]  
    inc si
    cmp al, 1
    jne skip_pix
    
    ; Calculate and draw pixel
    push si
    mov ax, dx
    push dx
    mov si, 320
    mul si   
    pop dx
    add ax, bp 
    mov di, ax                                         
    mov al, text_col
    stosb
    pop si
    
skip_pix:
    inc bp         
    pop cx
    loop draw_d_col
    
    pop bx      
    pop bp      
    inc dx      
    dec bx
    jnz draw_d_row
    
    pop dx      
    
skip_digit:
    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret


draw_text_paused:
    push bx
    push cx

    call draw_letter_p
    add bx, 14
    call draw_letter_a
    add bx, 14
    call draw_letter_u
    add bx, 14
    call draw_letter_s
    add bx, 14
    call draw_letter_e
    add bx, 14
    call draw_letter_d

    pop cx
    pop bx
    ret

draw_letter_u:
    push bx    ;X
    push cx    ;Y
    push si    ;WID
    push di    ;HIE

    mov si, 2
    mov di, 10
    mov al, text_col
    call rect          ; Left vertical

    add bx, 10
    call rect          ; Right vertical

    sub bx, 10
    add cx, 10
    mov si, 12
    mov di, 2
    call rect          ; Bottom bar

    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_d:
    push bx
    push cx
    push si
    push di

    mov si, 2
    mov di, 12
    mov al, text_col
    call rect          ; Left vertical

    mov si, 8
    mov di, 2
    call rect          ; Top bar

    add cx, 10
    mov si, 8
    mov di, 2
    call rect          ; Bottom bar

    add bx, 8
    sub cx, 8
    mov si, 2
    mov di, 8
    call rect          ; Right vertical curve

    pop di
    pop si
    pop cx
    pop bx
    ret

; ======================================================
; 3x5 DIGIT FONT DATA
; ======================================================
digit_font:
db 1,1,1, 1,0,1, 1,0,1, 1,0,1, 1,1,1  ; 0
db 0,1,0, 1,1,0, 0,1,0, 0,1,0, 1,1,1  ; 1
db 1,1,1, 0,0,1, 1,1,1, 1,0,0, 1,1,1  ; 2
db 1,1,1, 0,0,1, 1,1,1, 0,0,1, 1,1,1  ; 3
db 1,0,1, 1,0,1, 1,1,1, 0,0,1, 0,0,1  ; 4
db 1,1,1, 1,0,0, 1,1,1, 0,0,1, 1,1,1  ; 5
db 1,1,1, 1,0,0, 1,1,1, 1,0,1, 1,1,1  ; 6
db 1,1,1, 0,0,1, 0,0,1, 0,1,0, 0,1,0  ; 7
db 1,1,1, 1,0,1, 1,1,1, 1,0,1, 1,1,1  ; 8
db 1,1,1, 1,0,1, 1,1,1, 0,0,1, 1,1,1  ; 9

; ======================================================
; TEXT DRAWING - IMPROVED LETTER SHAPES
; ======================================================
draw_text_gameover:
    push bx
    push cx
    call draw_letter_g
    add bx, 16
    call draw_letter_a
    add bx, 16
    call draw_letter_m
    add bx, 16
    call draw_letter_e
    add bx, 20
    call draw_letter_o
    add bx, 16
    call draw_letter_v
    add bx, 16
    call draw_letter_e
    add bx, 16
    call draw_letter_r
    pop cx
    pop bx
    ret

clear_pause_overlay:
    mov bx, 60
    mov cx, 70
    mov si, 200
    mov di, 60
    mov al, sky_col     
    call rect
    ret

draw_text_score:
    push bx
    call draw_letter_s
    add bx, 13
    call draw_letter_c
    add bx, 13
    call draw_letter_o
    add bx, 13
    call draw_letter_r
    add bx, 13
    call draw_letter_e
    pop bx
    ret

draw_text_best:
    push bx
    call draw_letter_b
    add bx, 13
    call draw_letter_e
    add bx, 13
    call draw_letter_s
    add bx, 13
    call draw_letter_t
    pop bx
    ret

draw_text_deaths:
    push bx
    call draw_letter_d
    add bx, 13
    call draw_letter_e
    add bx, 13
    call draw_letter_a
    add bx, 13
    call draw_letter_t
    add bx, 13
    call draw_letter_h
    add bx, 13
    call draw_letter_s
    pop bx
    ret

; Rutina modificada para pintar "PRESS S" al inicio
draw_text_start:
    push bx
    call draw_letter_p
    add bx, 11
    call draw_letter_r
    add bx, 11
    call draw_letter_e
    add bx, 11
    call draw_letter_s
    add bx, 11
    call draw_letter_s
    add bx, 16
    call draw_letter_s
    pop bx
    ret
    
draw_text_enter:
    push bx
    call draw_letter_p
    add bx, 11
    call draw_letter_r
    add bx, 11
    call draw_letter_e
    add bx, 11
    call draw_letter_s
    add bx, 11
    call draw_letter_s
    add bx, 16
    call draw_letter_e
    add bx, 11
    call draw_letter_n
    add bx, 11
    call draw_letter_t
    pop bx
    ret

; Letter drawing with better shapes (12x12 pixels)
draw_letter_a:
    push bx
    push cx
    push si
    push di
    ; Top horizontal
    mov si, 10
    mov di, 2
    mov al, text_col
    call rect
    add cx, 2
    ; Left vertical
    mov si, 2
    mov di, 8
    call rect
    ; Right vertical
    add bx, 8
    call rect
    sub bx, 8
    ; Middle horizontal
    add cx, 3
    mov si, 10
    mov di, 2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_b:
    push bx
    push cx
    push si
    push di
    ; Left vertical
    mov si, 2
    mov di, 12
    mov al, text_col
    call rect
    ; Top horizontal
    mov si, 8
    mov di, 2
    call rect
    ; Middle horizontal
    add cx, 5
    call rect
    ; Bottom horizontal
    add cx, 5
    call rect
    sub cx, 10
    ; Right curves
    add bx, 8
    mov si, 2
    mov di, 2
    call rect
    add cx, 3
    call rect
    add cx, 3
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_c:
    push bx
    push cx
    push si
    push di
    ; Top horizontal
    mov si, 10
    mov di, 2
    mov al, text_col
    call rect
    ; Left vertical
    add cx, 2
    mov si, 2
    mov di, 8
    call rect
    ; Bottom horizontal
    add cx, 8
    mov si, 10
    mov di, 2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_e:
    push bx
    push cx
    push si
    push di
    ; Left vertical
    mov si, 2
    mov di, 12
    mov al, text_col
    call rect
    ; Top horizontal
    mov si, 10
    mov di, 2
    call rect
    ; Middle horizontal
    add cx, 5
    mov si, 8
    call rect
    ; Bottom horizontal
    add cx, 5
    mov si, 10
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_g:
    push bx
    push cx
    push si
    push di
    ; Top horizontal
    mov si, 12
    mov di, 2
    mov al, text_col
    call rect
    ; Left vertical
    add cx, 2
    mov si, 2
    mov di, 8
    call rect
    ; Bottom horizontal
    add cx, 8
    mov si, 12
    mov di, 2
    call rect
    sub cx, 8
    ; Right vertical (short)
    add bx, 10
    mov si, 2
    mov di, 5
    call rect
    ; Middle bar
    add cx, 3
    sub bx, 4
    mov si, 6
    mov di, 2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret
    
draw_letter_f:
    push bx
    push cx
    push si
    push di
    ; Vertical izquierda
    mov si, 2
    mov di, 12
    mov al, text_col
    call rect
    ; Horizontal superior
    mov si, 10
    mov di, 2
    call rect
    ; Horizontal media
    add cx, 5
    mov si, 8
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret
    
draw_letter_h:
    push bx
    push cx
    push si
    push di
    ; Left vertical
    mov si, 2
    mov di, 12
    mov al, text_col
    call rect
    ; Right vertical
    add bx, 8
    call rect
    sub bx, 8
    ; Middle horizontal
    add cx, 5
    mov si, 10
    mov di, 2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret
    
draw_letter_i:
    push bx
    push cx
    push si
    push di
    ; Barra superior
    mov si, 8
    mov di, 2
    mov al, text_col
    call rect
    ; Vertical central
    add bx, 3
    mov si, 2
    mov di, 12
    call rect
    sub bx, 3
    ; Barra inferior
    add cx, 10
    mov si, 8
    mov di, 2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret
    
draw_letter_l:
    push bx
    push cx
    push si
    push di
    ; Vertical izquierda
    mov si, 2
    mov di, 12
    mov al, text_col
    call rect
    ; Horizontal inferior
    add cx, 10
    mov si, 10
    mov di, 2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_m:
    push bx
    push cx
    push si
    push di
    ; Left vertical
    mov si, 2
    mov di, 12
    mov al, text_col
    call rect
    ; Right vertical
    add bx, 10
    call rect
    sub bx, 10
    ; Left diagonal peak
    add bx, 2
    MOV CX,CX
    mov si, 2
    mov di, 4
    call rect
    
    ADD BX,2
    ADD CX,4
    MOV DI,4
    CALL rect
    ; Right diagonal peak
    SUB bx, 2
    SUB CX,4
    ADD BX,4
    MOV DI,4
    call rect
    ADD BX,2
    ADD CX,4
    MOV DI,4
    CALL rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_o:
    push bx
    push cx
    push si
    push di
    ; Top horizontal
    mov si, 12
    mov di, 2
    mov al, text_col
    call rect
    ; Left vertical
    add cx, 2
    mov si, 2
    mov di, 8
    call rect
    ; Right vertical
    add bx, 10
    call rect
    sub bx, 10
    ; Bottom horizontal
    add cx, 8
    mov si, 12
    mov di, 2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_p:
    push bx
    push cx
    push si
    push di
    ; Left vertical
    mov si, 2
    mov di, 12
    mov al, text_col
    call rect
    ; Top horizontal
    mov si, 8
    mov di, 2
    call rect
    ; Right vertical (top half)
    add bx, 8
    add cx, 2
    mov si, 2
    mov di, 3
    call rect
    sub bx, 8
    ; Middle horizontal
    add cx, 3
    mov si, 8
    mov di, 2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_r:
    push bx
    push cx
    push si
    push di
    ; Left vertical
    mov si, 2
    mov di, 12
    mov al, text_col
    call rect
    ; Top horizontal
    mov si, 8
    mov di, 2
    call rect
    ; Right vertical (top)
    add bx, 8
    add cx, 2
    mov si, 2
    mov di, 3
    call rect
    sub bx, 8
    ; Middle horizontal
    add cx, 3
    mov si, 8
    mov di, 2
    call rect
    ; Diagonal leg
    add bx, 5
    add cx, 2
    mov si, 2
    mov di, 5
    call rect
    add bx, 2
    add cx, 2
    mov di, 3
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret
    
draw_letter_n:
    push bx
    push cx
    push si
    push di
    ; Left vertical
    mov si, 2
    mov di, 12
    mov al, text_col
    call rect
    ; Right vertical
    add bx, 10
    call rect
    sub bx, 10
    ; Diagonal
    add bx, 2
    mov si, 2
    mov di, 10
    call rect
    add bx, 2
    mov di, 8
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret
    
draw_letter_s:
    push bx
    push cx
    push si
    push di
    ; Top horizontal
    mov si, 10
    mov di, 2
    mov al, text_col
    call rect
    ; Left vertical (top)
    add cx, 2
    mov si, 2
    mov di, 3
    call rect
    ; Middle horizontal
    add cx, 3
    mov si, 10
    mov di, 2
    call rect
    ; Right vertical (bottom)
    add bx, 8
    add cx, 2
    mov si, 2
    mov di, 3
    call rect
    sub bx, 8
    ; Bottom horizontal
    add cx, 3
    mov si, 10
    mov di, 2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_t:
    push bx
    push cx
    push si
    push di
    ; Top horizontal
    mov si, 10
    mov di, 2
    mov al, text_col
    call rect
    ; Middle vertical
    add bx, 4
    add cx, 2
    mov si, 2
    mov di, 10
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret

draw_letter_v:
    push bx
    push cx
    push si ;widht
    push di ;hiehgt
    ; Left diagonal
    mov si, 2
    mov di, 6
    mov al, text_col
    call rect
    add bx, 1
    add cx, 6
    mov di, 4
    call rect
    sub bx, 1
    sub cx, 6
    ; Right diagonal
    add bx, 10
    mov si,2
    mov di,6
    call rect
    sub bx, 1
    add cx, 6
    mov di, 4
    call rect
    sub bx,6
    add cx,1
    mov si,2
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret
    
draw_letter_y:
    push bx
    push cx
    push si
    push di
    ; Brazo izquierdo
    mov si, 2
    mov di, 6
    mov al, text_col
    call rect
    ; Brazo derecho
    add bx, 8
    call rect
    sub bx, 8
    ; Union horizontal
    add cx, 5
    mov si, 10
    mov di, 2
    call rect
    ; Tallo
    add bx, 4
    add cx, 2
    mov si, 2
    mov di, 5
    call rect
    pop di
    pop si
    pop cx
    pop bx
    ret


; ======================================================
; CORE ROUTINES
; ======================================================
draw_sky_once:
    push ax
    push cx
    push di
    push es
    
    mov ax, 0A000h
    mov es, ax
    xor di, di
    mov al, sky_col
    mov ah, al
    mov cx, 32000
    rep stosw   ;two pixel at a time by al and ah
    
    pop es
    pop di
    pop cx
    pop ax
    ret

frame_delay:
    mov dx, 3DAh
fd1: 
    in al, dx
    test al,8
    jnz fd1
fd2: 
    in al, dx
    test al,8
    jz fd2
    mov cx, 1500
fd3:
    loop fd3
    ret

rect:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    push bp
    
    cmp bx, SCREEN_W
    jge rect_exit
    cmp cx, SCREEN_H
    jge rect_exit
    cmp di, 0
    jle rect_exit
    
    ; Save color
    push ax     
    
    mov ax, 0A000h
    mov es, ax
    
    ; Calculate starting position
    mov ax, cx 
    mov dx, 320
    mul dx    
    add ax, bx  
    mov bp, ax  
    
    pop ax      
    push ax     
    
    mov dx, di  
    
rect_row_loop:
    push dx
    mov di, bp
    mov cx, si  
    rep stosb
    add bp, 320  
    pop dx
    dec dx
    jnz rect_row_loop
    
    pop ax      
    
rect_exit:
    pop bp
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

init_gfx:
    mov ax, 13h
    int 10h
    mov ax, 0A000h
    mov es, ax
    ret

; ======================================================
; RANDOM NUMBER GENERATOR 
; Returns random number in AX
; ======================================================
get_random:
    push bx
    push cx
    push dx
    
    ; Update seed using timer
    mov ah, 00h
    int 1Ah        
    xor rand_seed, dx
    
    mov ax, rand_seed
    mov bx, 25173
    mul bx
    add ax, 13849
    mov rand_seed, ax
    
    pop dx
    pop cx
    pop bx
    ret

end start
