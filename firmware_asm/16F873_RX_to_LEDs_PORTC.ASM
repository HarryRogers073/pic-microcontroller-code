;===============================================================================
; File:         16F873_RX_to_LEDs_PORTC.ASM
; Written by:   Harry Rogers
; Date:         May 2022
; Description:  Direct Port C diagnostic latching from receiver pulse inputs
;===============================================================================

;************************************************************************************
; Program title:  16F873_RX_to_PWM_2026
;
; 16F873
; 4MHz crystal
; A program to decode standard receiver pulses and convert them to an 8-bit number.
; This number is then used to set the PWM duty cycle on CCP1 (PORTC, 2).
;************************************************************************************	
					
    list	p=16f873, f=inhx8m		; Tell the assembler that you're using a 
					; PIC16F873  f=flash c=eprom
					; f=inhx8m sets up the hex output file to be intel Hex no8

    include <p16f873.inc>		; Standard register definitions

    __CONFIG _HS_OSC & _CP_ALL & _WDT_OFF & _PWRTE_ON & _LVP_OFF & _DEBUG_OFF
					; Sets Crystal oscillator ON
					; Sets Code Protection ON
					; Sets Watchdog timer OFF
					; Sets Power protection system ON
					; Low Voltage in circuit programming is OFF allowing PORT RB3 to be digital I/O
					; Switches off DEBUG

; Setup variables                      
;****************
    CBLOCK	0X20			; Sets up the named variables
    PULSEWID
    STATUS_TEMP
    W_TEMP
    ENDC

; Program initialisation
;*************************
    ORG 0x00				; Reset vector
    GOTO setup				; Jump to setup

    ORG 0x04				; Interrupt vector
    GOTO ISR				; Jump to interrupt service routine

setup
    BSF		STATUS,RP0		; Go to memory Bank 1
    BCF		STATUS,RP1		; included for larger chips with more than 2 banks
    
    MOVLW	0xFF			; Set PORTB to all inputs 
    MOVWF	TRISB			;
    
    MOVLW	0x00			; Set PORTC to all outputs (CCP1 is on RC2)
    MOVWF	TRISC			; 
    
; Setup PWM Period (PR2)
    MOVLW	0xFF			; Set PR2 for maximum 8-bit resolution
    MOVWF	PR2
    
; Initialise Timer0
    BCF		OPTION_REG,T0CS		; Input for  timer0 to be internal
    BCF		OPTION_REG,T0SE		; Increment in Lo to Hi transition
    BCF		OPTION_REG,PSA		; SET the prescaler for use on TMR0
    BSF		OPTION_REG,PS0		;
    BCF		OPTION_REG,PS1		; 
    BCF		OPTION_REG,PS2		; Set the prescaler value to be 1:4
    
    BCF		STATUS, RP0		; Return to bank 0
    
; Initialise CCP1 for PWM
    MOVLW	0x0C			; Set CCP1 to PWM mode (b'00001100')
    MOVWF	CCP1CON

; Initialise Timer2 for PWM
    MOVLW	0x05			; Timer2 ON, Prescaler 1:4 (b'00000101')
    MOVWF	T2CON
    
; Initialise Interrupts   
    BCF		INTCON, T0IE		; Disable Timer0 overflow interrupt
    BCF		INTCON, PEIE		; Disable Peripheral overflow interrupt
    BSF 	INTCON, INTE		; Enable PORTB,0 change interrupt 
    BSF 	INTCON, RBIE		; Enable PORTB change interrupt
    BSF 	INTCON, GIE		; Enable global interrupt

; Reset PORTC
    MOVLW	0xFF			; Clear PORTC to start
    MOVWF	PORTC			; 

; Main loop: continuously monitor for pulses and update PWM
;**********************************************************
main_loop:
    MOVF	PULSEWID, W		; Read the captured receiver pulse width
    MOVWF	CCPR1L			; Load it into the PWM duty cycle register
    GOTO	main_loop		; Loop forever (main execution)
    
; Interrupt Service Routine
;**************************
ISR:
    BCF		INTCON,GIE		; Disable interrupts during the interrupt
    MOVWF	W_TEMP			; store away the W register
    MOVF	STATUS,W
    MOVWF	STATUS_TEMP		; store away the STATUS register
    
    BTFSS	PORTB,4			; We are in the interrupt routine so PORTB,4 has 		
					; changed
    GOTO	HITOLO			; Negative edge
    GOTO	LOTOHI			; Positive edge
LOTOHI
    MOVLW	0x23
    MOVWF	TMR0
    GOTO	INTERRUPTRETURN
HITOLO	
    MOVF	TMR0,W			; Put TMR0 into the working register
    MOVWF	PULSEWID		; Put the working register into PULSEWID
    GOTO	INTERRUPTRETURN
INTERRUPTRETURN			
    BCF		INTCON,RBIF		; Clear PORTB change Interrupt Flag
    MOVF	STATUS_TEMP,W		; Restore the status register
    MOVWF	STATUS
    MOVF	W_TEMP,W		; Restore the W register
    BSF		INTCON,GIE		; Re enable the interrupts			
    RETFIE				; Return from interrupt
    
    END