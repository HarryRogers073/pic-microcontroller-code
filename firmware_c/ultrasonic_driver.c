#include <xc.h>
#pragma config FOSC=XT,WDTE=OFF,PWRTE=ON,CP=OFF
#define _XTAL_FREQ 4000000
#define TRUE 1
#define FALSE 0
#define LED PORTBbits.RB0
#define Triggerpin PORTBbits.RB2
#define Echopin PORTCbits.RC0
unsigned long echo_timer;
void main()
{//1
TRISA = 0b11111111;
TRISB = 0b00000000;
TRISC = 0b00000000;
OPTION_REG = 0b00000100;

 

while (TRUE)
{//2
   
    Triggerpin = 1;
    __delay_us(9);
    Triggerpin = 0;
   
    while (Echopin == 0);
        TMR0 = 0;
       
        while (Echopin == 1)
        {
            if (TMR0 > 50)
            {
               
                TMR0 = 60;
            }
        }

        echo_timer = TMR0;

        if (echo_timer < 49)
            {
            LED = 1;
            } else
            {
            LED = 0;
            }
           __delay_ms(100);
}
}