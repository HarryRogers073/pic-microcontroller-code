;================================================================================
; Program:       PWM_Simple.asm
; Description:   Direct RC pulse width to LED PWM brightness controller
; Author:        Harry Rogers (University of Brighton)
; Date:          2022
; Target Device: Microchip PIC16F873 (4 MHz Crystal)
;================================================================================

        list    p=16f873, f=inhx8m
        include <p16f873.inc>

;*********************************************************
; BASIC RCâPULSE â LED BRIGHTNESS PROGRAM
;*********************************************************
; HOW THIS PROGRAM WORKS:
;
; 1. An RC receiver sends a control pulse on RB4.
;    - 1.0 ms HIGH  = stick minimum
;    - 1.5 ms HIGH  = stick centre
;    - 2.0 ms HIGH  = stick maximum
;
; 2. The PIC uses Timer0 to measure how long RB4 stays HIGH.
;
; 3. The measured pulse width is converted into a value
;    from 0x00 to 0xFF by subtracting the 1 ms baseline.
;
; 4. This value is written directly into CCPR1L, which sets
;    the duty cycle of the CCP1 PWM module on RC2.
;
; 5. The LED connected to RC2 becomes brighter as the duty
;    cycle increases:
;       - 0% duty  â LED OFF
;       - 50% duty â medium brightness
;       - 100% duty â full brightness
;
; This is the simplest possible implementation:
;     RC pulse width â PWM duty â LED brightness
;
;*********************************************************

        __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _LVP_OFF

;*********************************************************
; Variables
;*********************************************************
        CBLOCK  0x20
W_TEMP                  ; Save W during ISR
STATUS_TEMP             ; Save STATUS during ISR
PULSE_WIDTH             ; Brightness value (0x000xFF)
        ENDC

;*********************************************************
; Reset + Interrupt vectors
;*********************************************************
        org     0x00
        GOTO    SETUP          ; GOTO k : jump to SETUP

        org     0x04
        GOTO    ISR            ; Interrupt vector ISR

;*********************************************************
; SETUP
;*********************************************************
SETUP
        ;-------------------------------
        ; Select Bank 1
        ;-------------------------------
        BSF     STATUS, RP0    ; BSF f,b : set bit b in register f
        BCF     STATUS, RP1    ; BCF f,b : clear bit b in register f

        ;-------------------------------
        ; TRIS configuration
        ;-------------------------------
        MOVLW   0xFF           ; MOVLW k : load literal into W
        MOVWF   TRISB          ; MOVWF f : W TRISB (all inputs)

        MOVLW   b'11111011'    ; RC2 = output (CCP1)
        MOVWF   TRISC

        ;-------------------------------
        ; Timer0 setup (pulse measurement)
        ;-------------------------------
        MOVLW   b'11010001'    ; OPTION_REG: prescaler 1:4, internal clock
        MOVWF   OPTION_REG

        ;-------------------------------
        ; Timer2 + CCP1 PWM setup
        ;-------------------------------
        MOVLW   0xFF
        MOVWF   PR2            ; PWM period

        MOVLW   b'00000111'    ; T2CON: TMR2ON=1, prescaler=1:16
        MOVWF   T2CON

        MOVLW   b'00001100'    ; CCP1CON: PWM mode
        MOVWF   CCP1CON

        CLRF    CCPR1L         ; CLRF f : clear file register (duty = 0)

        ;-------------------------------
        ; Back to Bank 0
        ;-------------------------------
        BCF     STATUS, RP0

        ;-------------------------------
        ; Clear ports + variables
        ;-------------------------------
        CLRF    PORTB
        CLRF    PORTC
        CLRF    PULSE_WIDTH

        ;-------------------------------
        ; Enable RB4 interrupt
        ;-------------------------------
        MOVF    PORTB, W       ; MOVF f,W : read PORTB to clear mismatch
        BCF     INTCON, RBIF   ; Clear PORTB change flag
        BSF     INTCON, RBIE   ; Enable PORTB change interrupt
        BSF     INTCON, GIE    ; Enable global interrupts

;*********************************************************
; MAIN LOOP
;*********************************************************
MAIN
        MOVF    PULSE_WIDTH, W ; W = brightness
        MOVWF   CCPR1L         ; CCPR1L = duty high byte

        BCF     CCP1CON, 0 ; Lower 2 duty bits = 0
        BCF     CCP1CON, 1

        GOTO    MAIN           ; Loop forever

;*********************************************************
; INTERRUPT SERVICE ROUTINE
;*********************************************************
ISR
        MOVWF   W_TEMP         ; Save W
        SWAPF   STATUS, W      ; SWAPF f,W : swap nibbles of STATUS into W
        MOVWF   STATUS_TEMP    ; Save STATUS

        ; Check RB change interrupt
        BTFSS   INTCON, RBIF   ; BTFSS f,b : skip if bit set
        GOTO    ISR_EXIT

        MOVF    PORTB, W       ; Read PORTB to clear mismatch

        ; Check RB4 state
        BTFSS   PORTB, 4       ; If RB4 = 0 falling edge
        GOTO    FALLING_EDGE

RISING_EDGE
        MOVLW   0x00           ; Reset Timer0
        MOVWF   TMR0
        GOTO    CLEAR_FLAG

FALLING_EDGE
        MOVF    TMR0, W        ; W = pulse width in ticks

        ; Subtract 1 ms offset (â 0xFA ticks)
        MOVLW   0xFA
        SUBWF   TMR0, W        ; W = TMR0 - 0xFA

        ; If negative, clamp to 0
        BTFSS   STATUS, C
        CLRW

        MOVWF   PULSE_WIDTH    ; Store brightness (0x000xFF)

CLEAR_FLAG
        BCF     INTCON, RBIF   ; Clear RB change flag

ISR_EXIT
        SWAPF   STATUS_TEMP, W ; Restore STATUS
        MOVWF   STATUS
        SWAPF   W_TEMP, F      ; Restore W (first swap)
        SWAPF   W_TEMP, W      ; Then into W
        RETFIE                 ; Return from interrupt

        end
