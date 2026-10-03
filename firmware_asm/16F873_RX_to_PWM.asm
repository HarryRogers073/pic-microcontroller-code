Title	"16F873_RX_to_PWM.asm"
;   *********************************************************************
;   * Program title: 16F873_RX_to_PWM                             	*
;   *									*
;   * SYSTEM OVERVIEW AND STEP-BY-STEP OPERATION			*
;   *									*
;   * 1. Input: Pin RB4 monitors radio signals. State changes trigger	*
;   * an 'Interrupt on Change', pausing the main loop to run the ISR.	*
;   *									*
;   * 2. Measurement: On a rising edge, the ISR resets Timer0. On a	*
;   * falling edge, it reads Timer0 to capture the pulse width.		*
;   *									*
;   * 3. Maths: A 1ms offset is subtracted from the measured width.	*
;   * The result is capped to a maximum limit and multiplied by 4 to	*
;   * create an 8-bit PWM brightness value.				*
;   *									*
;   * 4. Output: The hardware Capture/Compare/PWM (CCP) module		*
;   * generates a continuous signal using Timer2. The calculated value	*
;   * is written to CCPR1L to adjust the LED duty cycle automatically.	*
;   *									*
;   * 5. Watchdog: RC frames arrive every 20ms. Timer1 acts as a	*
;   * 65.5ms timeout. If a pulse fails to arrive, Timer1 overflows	*
;   * (setting PIR1,0), and the main loop forces the PWM safely OFF.	*
;   *									*
;   * CONFIGURATION OPTIONS						*
;   *									*
;   * 1. Fail-Safe State: The default state upon signal loss is		*
;   * OFF (0xFF). To default to ON (0x00), change the MOVLW value	*
;   * in both the SETUP and TIMEOUT_TRIG sections.			*
;   *									*
;   * 2. Timeout Protection: To completely disable the 65.5ms		*
;   * safety timeout, comment out (add a ';' before) the BTFSC and	*
;   * GOTO instructions at the very beginning of MAINLOOP.		*
;   *									*
;   *********************************************************************

	list	p=16f873, f=inhx8m			; Tell the assembler that the chip is a 
							; PIC16F873  f=flash c=eprom
							; f=inhx8m sets up the hex output file to be intel Hex No8

	include <p16f873.inc>				; Standard register definition

	__CONFIG _XT_OSC & _WDT_OFF & _PWRTE_ON & _LVP_OFF & _DEBUG_OFF & _CP_OFF
							; Note the double underscore at the beginning
							; Sets Crystal oscillator ON
							; Sets Watchdog timer OFF
							; Sets Power protection system ON
							; Sets Low Voltage in circuit programming OFF

;
; Variables
;************
;
	CBLOCK	0X20					; Sets up the named variables starting at 0x20 (Decimal: 32)

		W_TEMP					; Holds W register during interrupts
		STATUS_TEMP				; Holds STATUS register during interrupts
		PULSEWID				; The final calculated PWM brightness value
		PREV_PORTB				; Previous state of PORTB to detect pin changes
		CURR_PORTB				; Current state of PORTB
		PWM_TEMP				; Temporary maths variable for calculating width

	ENDC
;
;
; Program initialisation
;*************************
;
	org		0x00			; Sets up start point at the very beginning of memory (Decimal: 0)
	GOTO 		SETUP			; Clear and power-up starts at SETUP
;
	org    		0x04			; Sets up interrupt vector (Decimal: 4)
	GOTO		ISR			; Sets up an interrupt to go to ISR

SETUP		
	BSF		STATUS,RP0		; Go to memory Bank 1
	BCF		STATUS,RP1		; included for larger chips with more than 2 banks

	MOVLW		0xFF			; Set the working register to all 1s (Decimal: 255)
	MOVWF		TRISB			; Move the working register into PORTB control 
						; register setting PORTB to be inputs
	MOVLW		0x00			; Set the working register to all 0s (Decimal: 0)
	MOVWF		TRISC			; Move the working register into PORTC control 
						; register setting PORTC to be all outputs

	MOVLW		0x06			; Configure pins for Digital input/output (Decimal: 6)
	MOVWF		ADCON1

	; Initialise Timer0 (Used for 1ms to 2ms pulse measurement)
	BCF		OPTION_REG,T0CS		; Input for timer0 to be internal
	BCF		OPTION_REG,T0SE		; Increment on Low to High transition
	BCF		OPTION_REG,PSA		; SET the prescaler for use on TMR0
	BSF		OPTION_REG,PS0		; Prescaler bit 0
	BSF		OPTION_REG,PS1		; Prescaler bit 1
	BCF		OPTION_REG,PS2		; Set the prescaler value to be 1:16 (16 microsecond ticks)

	; PWM Period setup (Sets frequency to roughly 984Hz)
	MOVLW		0xE0			; Max period value, lowered to force 100 per cent OFF state (Decimal: 253)
	MOVWF		PR2

	BCF		STATUS,RP0		; Go to memory Bank 0
	BCF		STATUS,RP1		; included for larger chips with more than 2 banks

	MOVLW		0x0C			; Value to enable CCP1 in PWM Mode (Decimal: 12)
	MOVWF		CCP1CON

	; Initialise hardware (Drive pin HIGH to turn LEDs OFF)
	MOVLW		0xFF			; Load the OFF constant (Decimal: 255)
	MOVWF		PORTC			; Start with PORTC pins HIGH 
	MOVWF		CCPR1L			; Start PWM duty cycle at 100 per cent (Pin HIGH)
	MOVWF		PULSEWID		; Set initial working variable to OFF state

	; Initialise Timer1 (Used as a hardware watchdog for the 20ms frame)
	MOVLW		0x01			; Timer1 ON, 1:1 prescaler (Decimal: 1)
	MOVWF		T1CON
	BCF		PIR1,0			; Clear Timer1 interrupt flag (TMR1IF)

	; Initialise Timer2 (Used for PWM base clock)
	MOVLW		0x05			; Value to turn Timer2 ON with 1:4 prescaler (Decimal: 5)
	MOVWF		T2CON
	
	MOVF		PORTB,W			; Read current PORTB state
	MOVWF		PREV_PORTB		; Save it as the previous state to detect pin changes later

	; Initialise Interrupts
	BCF		INTCON,T0IE		; Disable Timer0 overflow interrupt
	BCF		INTCON,PEIE		; Disable Peripheral overflow interrupt
	BSF 		INTCON,INTE		; Enable PORTB,0 change interrupt 
	BSF 		INTCON,RBIE		; Enable PORTB change interrupt
	BSF 		INTCON,GIE		; Enable global interrupt

; **************Main Program **********************************
MAINLOOP
	; Step 1: Check if Timer1 has overflowed (approx 65.5ms without a pulse)
	BTFSC		PIR1,0			; Read TMR1IF. It goes high if signal is lost
	GOTO		TIMEOUT_TRIG

	; Step 2: Update the PWM brightness using the last valid pulse calculation
	MOVF		PULSEWID,W		; Get the latest calculated width
	MOVWF		CCPR1L			; Write it to the PWM register
	GOTO		MAINLOOP		; Loop forever (main execution)

TIMEOUT_TRIG
	; Signal lost condition: Force the PWM to the OFF state for safety
	MOVLW		0xFF			; Load OFF constant (Decimal: 255)
	MOVWF		CCPR1L			; Write OFF state to PWM register
	
	; The loop stays here safely.
	; The interrupt routine clears the TMR1IF flag when a valid pulse returns.
	GOTO		MAINLOOP
;*************End of main program*******************************

; ************Interrupt servicing routines ;***************************
ISR		
	BCF		INTCON,GIE		; Disable all interrupts during the interrupt
	MOVWF		W_TEMP			; store away the W register
	MOVF		STATUS,W
	MOVWF		STATUS_TEMP		; store away the STATUS register	
	
	; Edge Detection: Read current state of the pins
	MOVF		PORTB,W
	MOVWF		CURR_PORTB

	; Check if RB4 specifically has changed state
	XORWF		PREV_PORTB,W		; XOR reveals which pins changed
	ANDLW		0x10			; Mask out everything except pin 4 (Decimal: 16)
	BTFSC		STATUS,Z		; If Zero flag is set, RB4 did NOT change
	GOTO		ISR_EXIT		; Exit if it was a different pin

	; RB4 changed: Update previous state history for the next interrupt
	MOVF		CURR_PORTB,W
	MOVWF		PREV_PORTB

	; Branch based on the pin state (Rising or Falling)
	BTFSS		CURR_PORTB,0x04		; Check bit 4 (Decimal: 4). Is the pin high or low?
	GOTO		HITOLO			; Pin is low: Falling edge (End of RC pulse)
	GOTO		LOTOHI			; Pin is high: Rising edge (Start of RC pulse)

LOTOHI
	; Pulse started: Reset the measurement timer to zero
	CLRF		TMR0
	
	; Reset the hardware timeout watchdog
	CLRF		TMR1H			; Clear Timer1 high byte
	CLRF		TMR1L			; Clear Timer1 low byte
	BCF		PIR1,0			; Clear the overflow flag (TMR1IF) to release timeout lock
	
	GOTO		ISR_EXIT

HITOLO
	; Pulse ended: Capture the timer width value
	MOVF		TMR0,W
	MOVWF		PWM_TEMP

	; Subtract 1ms base offset
	MOVLW		0x3E			; Load 1ms offset (Decimal: 62)
	SUBWF		PWM_TEMP,F		; PWM_TEMP = PWM_TEMP minus 62
	BTFSC		STATUS,C		; Carry flag is clear on a negative result (borrow)
	GOTO		CHECK_UPPER
	
	; Pulse was under 1ms: Force output to OFF state
	MOVLW		0xFF			; Load OFF constant (Decimal: 255)
	MOVWF		PULSEWID
	GOTO		ISR_EXIT

CHECK_UPPER
	; Check if the value exceeds the maximum allowed range
	MOVF		PWM_TEMP,W
	SUBLW		0x3F			; Subtract W from the max range (Decimal: 63)
	BTFSC		STATUS,C		; Carry flag is clear if W was greater than 63
	GOTO		SCALE_UP
	
	; Pulse was over 2ms: Limit to the maximum allowed value
	MOVLW		0x3F			; Load max constant (Decimal: 63)
	MOVWF		PWM_TEMP

SCALE_UP
	; Multiply by 4 to map 0x00-0x3F (Decimal: 0-63) to an 8-bit duty cycle 0x00-0xFC (Decimal: 0-252)
	BCF		STATUS,C		; Clear carry before rotating
	RLF		PWM_TEMP,F		; Multiply by 2
	BCF		STATUS,C		; Clear carry again
	RLF		PWM_TEMP,F		; Multiply by 2 again (total times 4)

	; Invert the logic (e.g. 0x00 becomes 0xFF / Decimal: 255)
	COMF		PWM_TEMP,W		; Reverse the bits
	MOVWF		PULSEWID		; Save final calculated width

ISR_EXIT
	BCF		INTCON,RBIF		; Clear PORTB change Interrupt Flag
	MOVF		STATUS_TEMP,W		; Restore the status register
	MOVWF		STATUS
	MOVF		W_TEMP,W		; Restore the W register
	BSF		INTCON,GIE		; Re-enable the interrupts
	RETFIE
	;*************End of Interrupt handling routine**********************
end