/* Template to start coding with the PIC16F873

 * Hardware Description
 * Uses 4 MHz Crystal

 * 
 * 	RA0 -
 * 	RA1 -
 * 	RA2 - 
 * 	RA3 -
 *  RA4 - 

 * 	RB0 - Blue wire of RIGHT Motor 
 * 	RB1 - Pink wire of RIGHT Motor
 * 	RB2 - Yellow wire of RIGHT Motor
 * 	RB3 - Yellow wire of LEFT Motor
 *  RB4 - Blue wire of LEFT Motor
 *  RB5 - Pink wire of LEFT Motor
 *  RB6 - 
 *  RB7 - 
 * 
 *  RC0 - 
 * 	RC1 - Orange wire of LEFT Motor
 * 	RC2 - 
 * 	RC3 - LCD Screen 
 * 	RC4 - LCD Screen 
 * 	RC5 - 
 * 	RC6 - 
 * 	RC7 - 
 */
#include <xc.h>
#pragma config FOSC=XT,WDTE=OFF,PWRTE=ON,CP=OFF,BOREN=OFF,LVP=OFF

#define _XTAL_FREQ            4000000
#define TRUE 1             // Sets True to be 1
#define FALSE 0            // Sets False to be 0
#define I2C_BaudRate          100000

/////////////////////////////////////////////////////////////////////////// --- Defining Pins --- ///////////////////////////////////////////////////////////////////////////////


// Definitions for right motor pins
#define RIGHT_BLUE_MOTOR    PORTBbits.RB0    // Right Motor Blue wire
#define RIGHT_PINK_MOTOR    PORTBbits.RB1    // Right Motor Pink wire
#define RIGHT_YELLOW_MOTOR  PORTBbits.RB2    // Right Motor Yellow wire
#define RIGHT_ORANGE_MOTOR  PORTCbits.RC7    // Right Motor Orange wire

// Definitions for left motor pins
#define LEFT_BLUE_MOTOR     PORTBbits.RB4    // Left Motor Blue wire
#define LEFT_PINK_MOTOR     PORTBbits.RB5    // Left Motor Pink wire
#define LEFT_YELLOW_MOTOR   PORTBbits.RB3    // Left Motor Yellow wire
#define LEFT_ORANGE_MOTOR   PORTCbits.RC1    // Left Motor Orange wire

#define SCL_D               PORTCbits.RC3    // I2C SCL pin
#define SDA_D               PORTCbits.RC4    // I2C SDA pin

/////////////////////////////////////////////////////////////////////////// --- Defining LCD Components --- ///////////////////////////////////////////////////////////////////////////////


#define LCD_BACKLIGHT         0x08
#define LCD_NOBACKLIGHT       0x00
#define LCD_FIRST_ROW         0x80
#define LCD_SECOND_ROW        0xC0
#define LCD_THIRD_ROW         0x94
#define LCD_FOURTH_ROW        0xD4
#define LCD_CLEAR             0x01
#define LCD_RETURN_HOME       0x02
#define LCD_ENTRY_MODE_SET    0x04
#define LCD_CURSOR_OFF        0x0C
#define LCD_UNDERLINE_ON      0x0E
#define LCD_BLINK_CURSOR_ON   0x0F
#define LCD_MOVE_CURSOR_LEFT  0x10
#define LCD_MOVE_CURSOR_RIGHT 0x14
#define LCD_TURN_ON           0x0C
#define LCD_TURN_OFF          0x08
#define LCD_SHIFT_LEFT        0x18
#define LCD_SHIFT_RIGHT       0x1E
#define LCD_TYPE              2 // 0 -> 5x7 | 1 -> 5x10 | 2 -> 2 lines

//---[ I2C Routines ]---

void I2C_Master_Init();
void I2C_Master_Wait();
void I2C_Master_Start();
void I2C_Master_RepeatedStart();
void I2C_Master_Stop();
void I2C_ACK();
void I2C_NACK();
unsigned char I2C_Master_Write(unsigned char data);
unsigned char I2C_Read_Byte(void);


void LCD_Init(unsigned char I2C_Add);
void IO_Expander_Write(unsigned char Data);
void LCD_Write_4Bit(unsigned char Nibble);
void LCD_CMD(unsigned char CMD);
void LCD_Set_Cursor(unsigned char ROW, unsigned char COL);
void LCD_Write_Char(char);
void LCD_Write_String(char*);
void Backlight();
void noBacklight();
void LCD_SR();
void LCD_SL();
void LCD_Clear();

/////////////////////////////////////////////////////////////////////////// --- LCD Functions --- ///////////////////////////////////////////////////////////////////////////////

unsigned char RS, i2c_add, BackLight_State = LCD_BACKLIGHT;


//---------------[ I2C Routines ]-------------------
//--------------------------------------------------

// Initialises the I2C module
void I2C_Master_Init()
{
  SSPCON = 0x28;  // I2C master mode, clock = FOSC/(4*(SSPADD+1))
  SSPCON2 = 0x00; // Clear SSPCON2 register
  SSPSTAT = 0x00; // Clear SSPSTAT register
  SSPADD = ((_XTAL_FREQ/4)/I2C_BaudRate) - 1; // Set baud rate
  SCL_D = 1;      // Set SCL and SDA pins as inputs
  SDA_D = 1;
}

// Waits until I2C module is idle
void I2C_Master_Wait()
{
  while ((SSPSTAT & 0x04) || (SSPCON2 & 0x1F));
}

// Sends start condition
void I2C_Master_Start()
{
  I2C_Master_Wait();
  SEN = 1;
}

// Sends repeated start condition
void I2C_Master_RepeatedStart()
{
  I2C_Master_Wait();
  RSEN = 1;
}

// Sends stop condition
void I2C_Master_Stop()
{
  I2C_Master_Wait();
  PEN = 1;
}

// Sends ACK signal
void I2C_ACK(void)
{
  ACKDT = 0; // 0 -> ACK
  I2C_Master_Wait();
  ACKEN = 1; // Send ACK
}

// Sends NACK signal
void I2C_NACK(void)
{
  ACKDT = 1; // 1 -> NACK
  I2C_Master_Wait();
  ACKEN = 1; // Send NACK
}

// Writes a byte to the I2C bus
unsigned char I2C_Master_Write(unsigned char data)
{
  I2C_Master_Wait();
  SSPBUF = data;
  while(!SSPIF); // Wait Until Completion
  SSPIF = 0;
  return ACKSTAT;
}

// Reads a byte from the I2C bus
unsigned char I2C_Read_Byte(void)
{
  //---[ Receive & Return A Byte ]---
  I2C_Master_Wait();
  RCEN = 1; // Enable & Start Reception
  while(!SSPIF); // Wait Until Completion
  SSPIF = 0; // Clear The Interrupt Flag Bit
  I2C_Master_Wait();
  return SSPBUF; // Return The Received Byte
}

void LCD_Init(unsigned char I2C_Add)
{
  i2c_add = I2C_Add;
  IO_Expander_Write(0x00);
  __delay_ms(30);
  LCD_CMD(0x03);
  __delay_ms(5);
  LCD_CMD(0x03);
  __delay_ms(5);
  LCD_CMD(0x03);
  __delay_ms(5);
  LCD_CMD(LCD_RETURN_HOME);
__delay_ms(5);
  LCD_CMD(0x20 | (LCD_TYPE << 2));
  __delay_ms(50);
  LCD_CMD(LCD_TURN_ON);
  __delay_ms(50);
  LCD_CMD(LCD_CLEAR);
  __delay_ms(50);
  LCD_CMD(LCD_ENTRY_MODE_SET | LCD_RETURN_HOME);
  __delay_ms(50);
}

// Writes a byte to the IO expander (which in turn writes to the LCD module)
void IO_Expander_Write(unsigned char Data)
{
  I2C_Master_Start();
  I2C_Master_Write(i2c_add);
  I2C_Master_Write(Data | BackLight_State);
  I2C_Master_Stop();
}

// Writes a 4-bit nibble to the LCD module
void LCD_Write_4Bit(unsigned char Nibble)
{
  // Get The RS Value To LSB OF Data
  Nibble |= RS;
  IO_Expander_Write(Nibble | 0x04);
  IO_Expander_Write(Nibble & 0xFB);
  __delay_us(50);
}

// Sends a command to the LCD module
void LCD_CMD(unsigned char CMD)
{
  RS = 0; // Command Register Select
  LCD_Write_4Bit(CMD & 0xF0);
  LCD_Write_4Bit((CMD << 4) & 0xF0);
}

// Writes a character to the LCD module
void LCD_Write_Char(char Data)
{
  RS = 1; // Data Register Select
  LCD_Write_4Bit(Data & 0xF0);
  LCD_Write_4Bit((Data << 4) & 0xF0);
}

// Writes a string to the LCD module
void LCD_Write_String(char* Str)
{
  for(int i=0; Str[i]!='\0'; i++)
    LCD_Write_Char(Str[i]);
}

// Sets the cursor position on the LCD module
void LCD_Set_Cursor(unsigned char ROW, unsigned char COL)
{
  switch(ROW)
  {
    case 2:
      LCD_CMD(0xC0 + COL-1);
      break;
    case 3:
      LCD_CMD(0x94 + COL-1);
      break;
    case 4:
      LCD_CMD(0xD4 + COL-1);
      break;
    // Case 1
    default:
      LCD_CMD(0x80 + COL-1);
  }
}

// Turns on the LCD backlight
void Backlight()
{
  BackLight_State = LCD_BACKLIGHT;
  IO_Expander_Write(0);
}

// Turns off the LCD backlight
void noBacklight()
{
  BackLight_State = LCD_NOBACKLIGHT;
  IO_Expander_Write(0);
}

// Scrolls the text on the LCD module to the left
void LCD_SL()
{
  LCD_CMD(0x18);
  __delay_us(40);
}

// Scrolls the text on the LCD module to the right
void LCD_SR()
{
  LCD_CMD(0x1C);
  __delay_us(40);
}

// Clears the LCD module
void LCD_Clear()
{
  LCD_CMD(0x01);
  __delay_us(40);
}

// Converts an unsigned integer to a string
char * utoa(char * buf, unsigned int val, int base) {
    unsigned int v;
    char c;

    v = val;
    do {
        v /= base; // Divide the value by the base
        buf++; // Increment the buffer pointer
    } while (v != 0);
    *buf-- = 0; // Null-terminate the string and decrement the buffer pointer
    do {
        c = val % base; // Get the remainder of the value divided by the base
        val /= base; // Divide the value by the base
        if (c >= 10)
            c += 'A' - '0' - 10; // Convert to a hexadecimal character if necessary
        c += '0'; // Convert to a decimal character
        *buf-- = c; // Store the character in the buffer and decrement the buffer pointer
    } while (val != 0);
    return ++buf; // Return the buffer pointer
}

// Converts an integer to a string
char * itoa(char * buf, int val, int base) {
    char * cp = buf; // Store the initial buffer pointer

    if (val < 0) {
        *buf++ = '-'; // Add a minus sign if the value is negative
        val = -val; // Make the value positive
    }
    utoa(buf, (unsigned int) val, base); // Convert the value to a string
    return cp; // Return the initial buffer pointer
}

///////////////////////////////////////////////////////////////////////////--- Motor Sequences ---//////////////////////////////////////////////////////////////////////

/*
Define 2D arrays representing motor step sequences

Each row represents a different motor step, and each integer represents the state of one of the motor segments (e.g. LEFT_ORANGE_MOTOR is either 1(HIGH) or 0(OFF) depending on the step).

There are three arrays: CW (clockwise movement sequence), CCW (counterclockwise movement sequence), and Static (static sequence, no movement).
*/

int CW[4][4] = { //Clockwise movement sequence
    {1, 1, 0, 0}, //step 1
    {0, 1, 1, 0}, //step 2
    {0, 0, 1, 1}, //step 3
    {1, 0, 0, 1} //step 4
};

int CCW[4][4] = { //Counterclockwise movement sequence, Reverse of the array above so that the motor rotates the opposite way
    {1, 0, 0, 1}, //step 4
    {0, 0, 1, 1}, //step 3
    {0, 1, 1, 0}, //step 2
    {1, 1, 0, 0} //step 1
};

int Static[4][4] = { //Static sequence (no movement), all of the array is 0 so no movement will occur
    {0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}
};

///////////////////////////////////////////////////////////////////////////--- Motor Control ---/////////////////////////////////////////////////////////////////////

void motorControl(int loops, int m2_seq[4][4], int m1_seq[4][4]) {
    /* 
    Function to control motors with specified sequences

    Parameters:
       loops: Number of times to iterate through the motor sequences
       m1_seq: 2D array representing the motor sequence for the left motor
       m2_seq: 2D array representing the motor sequence for the right motor

    */

    // Iterate through the specified number of loops
    for (int i = 0; i < loops; i++) {
        // Iterate through each row of the motor sequence arrays
        for (int j = 0; j < 4; j++) {
            // Setting Left Motor Pins based on m1_seq array
            LEFT_BLUE_MOTOR = m1_seq[j][0]; // Set the state of LEFT_BLUE_MOTOR based on the value in the j-th row, first column of m1_seq
            LEFT_PINK_MOTOR = m1_seq[j][1]; // Set the state of LEFT_PINK_MOTOR based on the value in the j-th row, second column of m1_seq
            LEFT_YELLOW_MOTOR = m1_seq[j][2]; // Set the state of LEFT_YELLOW_MOTOR based on the value in the j-th row, third column of m1_seq
            LEFT_ORANGE_MOTOR = m1_seq[j][3]; // Set the state of LEFT_ORANGE_MOTOR based on the value in the j-th row, fourth column of m1_seq

            // Setting Right Motor Pins based on m2_seq array, similar to the left motor
            RIGHT_BLUE_MOTOR = m2_seq[j][0];
            RIGHT_PINK_MOTOR = m2_seq[j][1];
            RIGHT_YELLOW_MOTOR = m2_seq[j][2];
            RIGHT_ORANGE_MOTOR = m2_seq[j][3];
            __delay_ms(100); // Delay for motor control
        }
    }
}

///////////////////////////////////////////////////////////////////////////--- Motor Commands ---/////////////////////////////////////////////////////////////////////


void forward(int steps){ //initialises with the integer steps
    
    /* Move forward, set number of steps then as the motors are facing opposite directions,
    if they both turned clockwise they would move in opposite directions,
    so one must go clockwise and the other counterclockwise */
    
    LCD_Clear(); //clears LCD screen
    LCD_Set_Cursor(1, 1); //sets cursor to first row and first column of the LCD
    LCD_Write_String("forward"); //prints "forward" at cursor on LCD
    
    
    motorControl(steps, CW, CCW); 
    // Calls a function with the parameters:
    // steps: An integer representing the number of times to iterate through the motor sequences.
    // CW: A 2D array representing the clockwise movement sequence for the motors, with each element indicating the state of a motor segment.
    // CCW: A 2D array representing the counterclockwise movement sequence for the motors, with each element indicating the state of a motor segment.
}

void backward(int steps){ // Move backward by specified steps.
    LCD_Clear(); 
    LCD_Set_Cursor(1, 1);
    LCD_Write_String("backward");
    motorControl(steps, CCW, CW); // Motors turn in opposite directions to forward, one counterclockwise, the other clockwise.
}

void pivotLeft(int steps){ // Pivot left by specified steps.
    LCD_Clear();
    LCD_Set_Cursor(1, 1);
    LCD_Write_String("pivotLeft");
    motorControl(steps, Static, CW); // The right motor remains static, left motor moves backward.
}

void pivotRight(int steps){  // Pivot right by specified steps
    LCD_Clear();
    LCD_Set_Cursor(1, 1);
    LCD_Write_String("pivotRight");
    motorControl(steps, CCW, Static); // The left motor remains static, right motor moves backward.
}

void turnLeft(int steps){ // Turn left by specified steps.
    LCD_Clear();
    LCD_Set_Cursor(1, 1);
    LCD_Write_String("turnLeft");
    motorControl(steps, CW, CW); // Right motor moves forward, left motor moves backward.
}

void turnRight(int steps){// Turn right by specified steps.
    LCD_Clear();
    LCD_Set_Cursor(1, 1);
    LCD_Write_String("turnRight");
    motorControl(steps, CCW, CCW); // Left motor moves forward, right motor moves backward.
}

/////////////////////////////////////////////////////////////////////////// --- Main Loop --- ///////////////////////////////////////////////////////////////////////////////

void demo() {
    __delay_ms(100);
    
    forward(300);       // Move forward for 300 milliseconds
    __delay_ms(40);     // Delay for 40 milliseconds
    
    turnLeft(300);      // Turn left for 300 milliseconds
    __delay_ms(40);     // Delay for 40 milliseconds
    
    turnRight(300);     // Turn right for 300 milliseconds
    __delay_ms(40);     // Delay for 40 milliseconds
    
    pivotLeft(300);     // Pivot left for 300 milliseconds
    __delay_ms(40);     // Delay for 40 milliseconds
    
    pivotRight(300);    // Pivot right for 300 milliseconds
    __delay_ms(40);     // Delay for 40 milliseconds
    
    backward(300);      // Move backward for 300 milliseconds
    __delay_ms(40);     // Delay for 40 milliseconds
}


void main(void) {  // Main code
    TRISA = 0b11111111;     // Set PORTA as input
    TRISB = 0b00000000;     // Set PORTB as output
    TRISC = 0b00011001;     // Set PORTC as input/output as required
    OPTION_REG = 0b00000100;   // Set OPTION_REG configuration
    ADCON0 = 0b10000001;    // Set ADCON0 configuration
    ADCON1 = 0b00001110;    // Set ADCON1 configuration for left justified 8 bit result in ADRESH, all pins digital except RA0

    I2C_Master_Init();     // Initialise I2C Master
    LCD_Init(0x4E);        // Initialise LCD
    
    while(1) {
        
        demo();             // Run the demo function indefinitely
        
       
    }
}