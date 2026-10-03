#include <xc.h>  // This defines all the C commands we are going to use
#pragma config FOSC = XT, WDTE = OFF, PWRTE = ON, CP = OFF
#define _XTAL_FREQ 4000000 //4 MHz crystal for use with delay macros
#define TRUE 1             // Sets True to be 1
#define FALSE 0            // Sets False to be 0
#define Pink1 PORTBbits.RB0
#define Blue1 PORTBbits.RB1
#define Yellow1 PORTBbits.RB2
#define Orange1 PORTBbits.RB3

void main(void) {
    TRISA = 0b00000000;
    TRISB = 0b00000000;
    
    while(TRUE)
    {
        Blue1 = 1;
        Pink1 = 0;
        Yellow1 = 0;
        Orange1 = 1;
        __delay_ms(4);
       
        Blue1 = 1;
        Pink1 = 1;
        Yellow1 = 0;
        Orange1 = 0;
        __delay_ms(4);
        
        Blue1 = 0;
        Pink1 = 1;
        Yellow1 = 1;
        Orange1 = 0;
        __delay_ms(4);
        
        Blue1 = 0;
        Pink1 = 0;
        Yellow1 = 1;
        Orange1 = 1;
        __delay_ms(4);
     
    }
}
