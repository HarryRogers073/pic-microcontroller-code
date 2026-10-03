/* Kay Hendriksen 09.05.22
 * code mostly taken from "Interfacing I2C LCD 16×2 Tutorial With PIC Microcontrollers | MPLAB XC8"
 * by Khaled Magdy : https://urldefense.com/v3/__https://deepbluembedded.com/interfacing-i2c-lcd-16x2-tutorial-with-pic-microcontrollers-mplab-xc8/Modified__;!!IWcW7C1FDU-5!ddfFNB9HfNrWPvzCzclcvrw9_RHD2L_NvDo9oEPf_lTEIRiPSPGGbqBGSKO5kuiMvr00teQAmOtwkI_82gY86AO1SnQBQxDqXFZIBjw$  to make it work with 16MHz clock 
 * 
 * Modified to make it work with 16MHz, 4.7k resistors pull up resistor have been added on SCL & SDA (note from Chris G - not needed since the chip daughter module already has them fitted)
*/
#include <xc.h>
#pragma config FOSC=XT,WDTE=OFF,PWRTE=ON,CP=OFF,BOREN=OFF,LVP=OFF

#define _XTAL_FREQ            4000000

#define I2C_BaudRate          100000
#define SCL_D           PORTCbits.RC3      //Set these to the pins you are using
#define SDA_D           PORTCbits.RC4      //Set these to the pins you are using
#define Button           PORTAbits.RA2
#define LED PORTCbits.RC2

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

//-----------[ Functions' Prototypes ]--------------
int incrementCounter(int button);
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

//---[ LCD Routines ]---

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



// Global variables
unsigned char RS, i2c_add, BackLight_State = LCD_BACKLIGHT;

//---------------[ I2C Routines ]-------------------
//--------------------------------------------------

// Initializes the I2C module
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
//======================================================

//---------------[ LCD Routines ]----------------
//-----------------------------------------------

// Initializes the LCD module
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

// Global counter variable
int counter = 0;

// Function to increment counter when button is pressed
int incrementCounter(int button) {
    if (button == 1) { // Assuming Button value of 1 indicates it's pressed
        LED=1;
        counter++;
        
    }
    return counter;
}

// Main function
void main(void) {
    TRISA = 0b11111111;
    TRISB = 0b00000000;
    TRISC = 0b00011000;
  OPTION_REG = 0b00000010;
  // Initialize I2C and LCD module
  I2C_Master_Init();
  LCD_Init(0x4E); // Initialize LCD module with I2C address = 0x4E

  // Write text to LCD module
  while(1){
  
    LCD_Clear();
    LCD_Set_Cursor(1, 1);
    LCD_Write_String(incrementCounter(Button));
    __delay_ms(1000);
    LED = 0;
    
  
  }
}


