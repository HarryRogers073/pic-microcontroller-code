list    p = 16f873 ,  f = inhx8m
    include  < p16f873.inc >
    __CONFIG _XT_OSC  &  _WDT_OFF  &  _PWRTE_ON  &  _LVP_OFF  &  _DEBUG_OFF  &  _CP_OFF

    CBLOCK  0X20                    
        W_TEMP                  
        STATUS_TEMP             
        PULSEWID                
        PREV_PORTB              
        CURR_PORTB              
        PWM_TEMP                
    ENDC

    org     0x00            
    GOTO    SETUP           

    org     0x04            
    GOTO    ISR         

SETUP       
    BSF     STATUS , RP0      
    BCF     STATUS , RP1      
    MOVLW   0xFF            
    MOVWF   TRISB           
    MOVLW   0x00            
    MOVWF   TRISC           
    MOVLW   0x06            
    MOVWF   ADCON1
    
    ; Initialise Timer0 
    BCF     OPTION_REG , T0CS     
    BCF     OPTION_REG , T0SE     
    BCF     OPTION_REG , PSA      
    BSF     OPTION_REG , PS0      
    BSF     OPTION_REG , PS1      
    BCF     OPTION_REG , PS2      
    
    ; PWM Period setup 
    MOVLW   0xFD            
    MOVWF   PR2
    BCF     STATUS , RP0      
    BCF     STATUS , RP1      
    MOVLW   0x0C            
    MOVWF   CCP1CON
    
    ; Initialise hardware 
    MOVLW   0xFF            
    MOVWF   PORTC           
    MOVWF   CCPR1L          
    MOVWF   PULSEWID        
    
    ; Initialise Timer2 
    MOVLW   0x05            
    MOVWF   T2CON
    
    MOVF    PORTB , W         
    MOVWF   PREV_PORTB      
    
    ; Initialise Interrupts
    BCF     INTCON , T0IE     
    BCF     INTCON , PEIE     
    BSF     INTCON , INTE     
    BSF     INTCON , RBIE     
    BSF     INTCON , GIE      

MAINLOOP
    MOVF    PULSEWID , W      
    MOVWF   CCPR1L          
    GOTO    MAINLOOP        

ISR     
    BCF     INTCON , GIE      
    MOVWF   W_TEMP          
    MOVF    STATUS , W
    MOVWF   STATUS_TEMP     
    
    ; Edge Detection
    MOVF    PORTB , W
    MOVWF   CURR_PORTB
    
    XORWF   PREV_PORTB , W        
    ANDLW   0x10            
    BTFSC   STATUS , Z        
    GOTO    ISR_EXIT        
    
    MOVF    CURR_PORTB , W
    MOVWF   PREV_PORTB
    
    BTFSS   CURR_PORTB , 0x04     
    GOTO    HITOLO          
    GOTO    LOTOHI          

LOTOHI
    ; Pulse started
    CLRF    TMR0
    GOTO    ISR_EXIT

HITOLO
    ; Pulse ended
    MOVF    TMR0 , W
    MOVWF   PWM_TEMP
    
    ; Subtract 1ms base offset
    MOVLW   0x3E            
    SUBWF   PWM_TEMP , F      

SCALE_UP
    ; Multiply by 4 
    BCF     STATUS ,C         
    RLF     PWM_TEMP , F      
    BCF     STATUS ,C         
    RLF     PWM_TEMP , F      
    
    ; Invert the logic
    COMF    PWM_TEMP , W      
    MOVWF   PULSEWID        

ISR_EXIT
    BCF     INTCON , RBIF     
    MOVF    STATUS_TEMP , W       
    MOVWF   STATUS
    MOVF    W_TEMP , W        
    BSF     INTCON , GIE      
    RETFIE

end