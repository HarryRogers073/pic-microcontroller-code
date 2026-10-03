list    p=16f873, f=inhx8m        ; Set chip type and hex output format
    include <p16f873.inc>             ; Load standard names (like PORTB)
    
    __CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _LVP_OFF & _DEBUG_OFF & _CP_OFF

    CBLOCK  0x20                      ; Start custom memory slots at 0x20
        W_TEMP                        ; Safely hold W register during interrupt
        STATUS_TEMP                   ; Safely hold STATUS during interrupt
        PWM_TEMP                      ; Store stopwatch time for calculations
    ENDC

    org     0x00                      ; Start address when powered on
    GOTO    SETUP                     ; Jump past interrupts to setup

    org     0x04                      ; Interrupt address
    GOTO    ISR                       ; Jump to Interrupt Service Routine (ISR)

SETUP
    BSF     STATUS, RP0               ; Set RP0 bit to select Bank 1
    BCF     STATUS, RP1               ; Ensure RP1 bit is 0
    
    MOVLW   0xFF                      ; Load W register with 255
    MOVWF   TRISB                     ; Copy W to TRISB (Port B as inputs)
    
    MOVLW   0x00                      ; Load W register with 0
    MOVWF   TRISC                     ; Copy W to TRISC (Port C as outputs)
    
    MOVLW   0x06                      ; Load W with 6
    MOVWF   ADCON1                    ; Set pins to digital (disable analogue)

    ; Initialise Timer0 (Stopwatch)
    BCF     OPTION_REG, T0CS          ; Use internal clock
    BCF     OPTION_REG, T0SE          ; Count on rising edge
    BCF     OPTION_REG, PSA           ; Connect clock divider to Timer0
    BCF     OPTION_REG, PS2           ; Set divider so 1ms equals 125 ticks
    BSF     OPTION_REG, PS1           
    BCF     OPTION_REG, PS0           

    MOVLW   0x7D                      ; Load W with 125 hex
    MOVWF   PR2                       ; Set PWM hardware limit to 125
    
    BCF     STATUS, RP0               ; Clear RP0 bit to select Bank 0
    
    MOVLW   0x0C                      ; Load W with 12
    MOVWF   CCP1CON                   ; Turn on LED dimming hardware

    MOVLW   0x04                      ; Load W with 4
    MOVWF   T2CON                     ; Turn on Timer2 (controls output speed)

    ; Configure interrupts
    BCF     INTCON, T0IE              ; Disable timer interrupt
    BCF     INTCON, PEIE              ; Disable hardware interrupts
    BCF     INTCON, INTE              ; Disable pin 0 interrupt
    BSF     INTCON, RBIE              ; Enable Port B change interrupt
    
    MOVF    PORTB, W                  ; Read Port B to clear old pin states
    BCF     INTCON, RBIF              ; Clear Port B alert flag
    BSF     INTCON, GIE               ; Turn on master interrupt switch

MAINLOOP
    SLEEP                             ; Stop processing to save power
    GOTO    MAINLOOP                  ; Loop back and sleep forever

ISR
    ; Save programme state safely
    MOVWF   W_TEMP                    ; Save W register to memory
    SWAPF   STATUS, W                 ; Swap STATUS into W safely
    MOVWF   STATUS_TEMP               ; Save STATUS to memory

    ; Check pin state
    BTFSS   PORTB, 4                  ; Is pin 4 high? Skip next line if yes
    GOTO    HITOLO                    ; Pin is low, jump to pulse end

LOTOHI
    ; Pulse started
    CLRF    TMR0                      ; Overwrite Timer0 with 0 to restart
    GOTO    ISR_EXIT                  ; Jump to exit

HITOLO
    ; Pulse ended
    MOVF    TMR0, W                   ; Copy stopwatch time to W
    MOVWF   PWM_TEMP                  ; Save time to our memory slot
    
    MOVLW   0x7D                      ; Load W with 125 (1ms offset)
    SUBWF   PWM_TEMP, F               ; Subtract 125 from saved time
    
    BTFSS   STATUS, C                 ; Did it drop below zero? Skip if no
    CLRF    PWM_TEMP                  ; Force memory to 0 if underflow

    MOVF    PWM_TEMP, W               ; Load current value back to W
    SUBLW   0x7D                      ; Subtract W from 125 to flip direction
    
    BTFSS   STATUS, C                 ; Did it go too high? Skip if no
    CLRF    W                         ; Force W to 0 if overflow
    
    MOVWF   CCPR1L                    ; Send final brightness to LED hardware

ISR_EXIT
    MOVF    PORTB, W                  ; Read port to acknowledge pin change
    BCF     INTCON, RBIF              ; Clear the interrupt alert flag
    
    SWAPF   STATUS_TEMP, W            ; Swap saved STATUS back to W
    MOVWF   STATUS                    ; Restore STATUS register
    SWAPF   W_TEMP, F                 ; Prepare saved W register
    SWAPF   W_TEMP, W                 ; Restore W register safely
    
    RETFIE                            ; Return to main programme

    end