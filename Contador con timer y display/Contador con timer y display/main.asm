;
; Contador con timer y display.asm
;
; Created: 2/11/2025 2:19:09 PM
; Author : super
;


.include "M328PDEF.inc"     
.cseg
.org	0x0000

DISPLAY: .DB 0x3F,0x06,0x5B,0x4F,0x66,0x6D,0x7D,0x07,0x7F,0x6F,0x77,0x7C,0x39,0x5E,0x79,0x71



// Configuración de la pila
	LDI     R16, LOW(RAMEND)
	OUT     SPL, R16
	LDI     R16, HIGH(RAMEND)
	OUT     SPH, R16

// Configuracion MCU

SETUP:
	// Configurar Prescaler "Principal"
    LDI R16, (1 << CLKPCE)
    STS CLKPR, R16      ; Habilitar cambio de PRESCALER
    LDI R16, 0b00000100
    STS CLKPR, R16      ; Configurar Prescaler a 16 (F_cpu = 1MHz)

    // Inicializar timer0
     CALL    TMR0

    // Configurar Puerto B como salida y todo apagado
    LDI		R16, 0xFF
	OUT		DDRB, R16
	LDI		R16, 0x00
	OUT		PORTB, R16

	// Configurar Puerto D como salida y todo apagado
    LDI		R16, 0xFF
	OUT		DDRD, R16
	LDI		R16, 0x00
	OUT		PORTD, R16

	// Configurar Puerto C como ENTRADA y con pull-up
    LDI		R16, 0x00
	OUT		DDRC, R16
	LDI		R16, 0xFF
	OUT		PORTC, R16

	// El contador empieza en 0
	LDI		R19, 0x00
	LDI		R21, 0x01
	LDI		R24, 0X01

	// Cargar el contenido de DISPLAY en X
	LDI		XL, LOW(DISPLAY*2)
	LDI		XH, HIGH(DISPLAY*2)

	// Cargar el primer valor del DISPLAY en el display
    LDI     XL, LOW(DISPLAY*2)
    LDI     XH, HIGH(DISPLAY*2)
    MOVW    Z, X
    LPM     R16, Z
    OUT     PORTD, R16
  

MAIN_LOOP:
    CALL    INDICADOR        ; Comparar valores y actualizar LED
	CALL    CONTADOR         ; Actualizar contador sin interrupciones
    CALL    LEER_BOTON1      ; Leer botones después
    CALL    LEER_BOTON2
    RJMP    MAIN_LOOP
	
// Subrutinas

CONTADOR:
    IN      R16, TIFR0          // Leer registro de interrupción de TIMER 0
    SBRS    R16, TOV0           // Salta si el bit 0 está "set" (TOV0 bit)
    RJMP    CONTADOR            // Reiniciar loop
    SBI     TIFR0, TOV0         // Limpiar bandera de "overflow"
    LDI     R16, 10            
    OUT     TCNT0, R16          // Volver a cargar valor inicial en TCNT0

    CPI     R21, 1              // Comparar si R21 == 0
    BREQ    NO_INCREMENT        // Si R21 es 0, no incrementar el contador

    INC     R18
    CPI     R18, 100            // TCNT0 seteado a 100ms
    BRNE    CONTADOR
    CLR     R18
    INC     R19

    // Contador para LED (cada 10 desbordamientos = 1s)
    INC     R20                 // Incrementar el contador de tiempo LED
    CPI     R20, 10             // ¿Han pasado 10 desbordamientos de 100ms?
    BRNE    NO_LED_TOGGLE       // Si no, saltar
    LDI     R20, 0              // Reiniciar el contador de 1s
    IN      R16, PORTB          // Leer estado actual de PORTB
    EOR		R16, R24			// Alternar bit del LED (PB0)
    OUT     PORTB, R16          // Escribir de nuevo a PORTB

NO_LED_TOGGLE:
    CPI     R19, 0x10           // Compara si R19 llega a 16
    BRNE    NO_RESET
    LDI     R19, 0x00           // Reinicia a 0 cuando llegue a 16
    RET

NO_INCREMENT:
    RET

NO_RESET:
    OUT     PORTB, R19          // Mostrar el valor de R19 en PORTB
    RET
	

TMR0:
    LDI     R16, (1<<CS01) | (1<<CS00)
    OUT     TCCR0B, R16         // Setear prescaler del TIMER 0 a 64
    LDI     R16, 0            
    OUT     TCNT0, R16          // Cargar valor inicial en TCNT0
    RET

LEER_BOTON1:
    SBIS    PINC, 0  
    CALL    SUMAR_D1  
    RET
	
LEER_BOTON2:
    SBIS    PINC, 1  
    CALL    RESTAR_D1  
    RET    

SUMAR_D1:
    CALL    ANTIRREBOTE
    SBIC    PINC, 0
    RET

    LDI     ZL, LOW(DISPLAY*2 + 15)  ; Última dirección de la tabla
    LDI     ZH, HIGH(DISPLAY*2 + 15)

    CP      XL, ZL                   ; Comparar si estamos en el último valor
    CPC     XH, ZH
    BRNE    CONTINUAR_SUMAR

    LDI     XL, LOW(DISPLAY*2)       ; Si es el último, reiniciar al primer valor
    LDI     XH, HIGH(DISPLAY*2)
    LDI     R21, 1                   ; ***Corregido: Reiniciar R21 también***
    RJMP    CARGAR_VALOR

CONTINUAR_SUMAR:
    ADIW    XL, 1                    
    INC     R21                      ; ***Mover aquí el incremento de R21***

CARGAR_VALOR:
    MOVW    Z, X
    LPM     R16, Z
    CALL    ACTUALIZAR_DISPLAY2
    RET   

REINICIAR: 
	LDI		R21, 1
	RET

REINICIAR2: 
	LDI		R21, 0x0F
	RET

RESTAR_D1:
    CALL    ANTIRREBOTE
    SBIC    PINC, 1
    RET
	
    LDI     ZL, LOW(DISPLAY*2)         ; Primera dirección de la tabla
    LDI     ZH, HIGH(DISPLAY*2)

    CP      XL, ZL                     ; Comparar si estamos en la primera posición
    CPC     XH, ZH
    BRNE    CONTINUAR_RESTAR

    LDI     XL, LOW(DISPLAY*2 + 15)     ; Si es la primera, ir al último
    LDI     XH, HIGH(DISPLAY*2 + 15)
    LDI     R21, 16                     ; ***Corregido: Reiniciar R21 también***
    RJMP    CARGAR_VALOR2

CONTINUAR_RESTAR:
    SBIW    XL, 1                      
    DEC     R21                         ; ***Mover aquí el decremento de R21***

CARGAR_VALOR2:
    MOVW    Z, X
    LPM     R16, Z
    CALL    ACTUALIZAR_DISPLAY1
    RET


ACTUALIZAR_DISPLAY1:
    OUT     PORTD, R16       ; Enviar valor al display
    RET

ESPERAR1:
	SBIS	PINC, 1
	RJMP	ESPERAR1
	RET

ACTUALIZAR_DISPLAY2:
    OUT     PORTD, R16       ; Enviar valor al display
    RET
    
ESPERAR2:
	SBIS	PINC, 0
	RJMP	ESPERAR2
	RET

INDICADOR:
    CPI     R21, 0
    BRNE    CHECK_MATCH
    SBI     PORTB, 4
    RET

CHECK_MATCH:
	DEC		R21
    CP      R21, R19       ; Comparar directamente
    BRNE    NO_MATCH

    SBI     PORTB, 4
	INC		R21
    CLR     R19
    CLR     R18
    RET

NO_MATCH:
	INC		R21
    RET
	
RESULT:
	SBI		PORTB, 4
	CLR     R19
	RET	
	

ANTIRREBOTE:
    LDI     R16, 5             ; Esperar 5 ciclos de comprobación (ajustable)

ANTIRREBOTE_LOOP:
    SBIC    PINC, 0            ; Si el botón ya no está presionado, salir
    RET
    DEC     R16
    BRNE    ANTIRREBOTE_LOOP
    RET
	