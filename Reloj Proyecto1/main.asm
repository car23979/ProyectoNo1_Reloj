/*
 Proyecto1.asm

 Created: 05/03/2025 01:37:21 p. m.
 Author : David Carranza

 Descripción: 
 */
//Encabezado
.equ	VALOR_T1 = 0x0000
//.equ	VALOR_T1 = 0xFF50
.equ	VALOR_T0 = 0x00
//.equ	VALOR_T1 = 0x1B1E
//.equ	VALOR_T0 = 0xB2
.def	ACCION = R21
.cseg									// Codigo en la flash

.org	0x0000							// Donde inicia el programa
	JMP	START							// Tiene que saltar para no ejecutar otros

.org	PCI0addr						// Dirección donde esta el vector interrupción PORTB
	JMP	ISR_PCINT0

.org	OVF1addr						// Dirección del vector para timer1
	JMP	TIMER1_OVERFLOW

.org	OVF0addr						// Dirección del vector para timer0
	JMP	TIMER0_OVF


//.def CONTADOR = R19  // Variable para el contador

// Inicio del programa
TABLITA: .DB 0xC0, 0xF9, 0xA4, 0xB0, 0x99, 0x92, 0x82, 0xF8, 0x80, 0x90
DIAS_POR_MES: .DB 32, 29, 32, 31, 32, 31, 32, 32, 31, 32, 31, 32
MESES:		.DB	0x31, 0x28, 0x31, 0x30, 0x31, 0x30, 0x31, 0x31, 0x30, 0x31, 0x30, 0x31

START: 
	// Configurar el SP en 0x03FF (al final de la SRAM) 
	LDI		R16, LOW(RAMEND)			// Carga los bits bajos (0x0FF)
	OUT		SPL, R16					// Configura spl = 0xFF -> r16
	LDI		R16, HIGH(RAMEND)			// Carga los bits altos (0x03)
	OUT		SPH, R16					// Configura sph = 0x03) -> r16

SETUP:

	// Deshabilitar interrupciones globales
	CLI	
// ------------------------------------Configuración del TIMER0----------------------------------
	// Utilizando oscilador a 1MHz - Permitir? parpadeo cada 500 ms
	// Se configura prescaler principal
	LDI		R16, (1 << CLKPCE)			// Se selecciona el bit del CLK (bit 7) 
	STS		CLKPR, R16					// Se habilitar cambio para el prescaler
	LDI		R16, 0b00000100				// En la tabla se ubica qu? bits deben encender
	STS		CLKPR, R16					// Se configura prescaler a 16 para 1MHz
	
	CALL	INIT_TMR0

	LDI		R16, (1 << TOIE0)			// Habilita interrupci?n por desborde del TIMER0
	STS		TIMSK0, R16										
	
// ------------------------------------Configuración del TIMER1----------------------------------

	CALL	INIT_TMR1

// Habilitar interrupci?n por desborde del TIMER1
	LDI		R16, (1 << TOIE1)			// Habilita interrupci?n por desborde del TIMER1
	STS		TIMSK1, R16					

// ------------------------------------Configuraci?n de los puertos----------------------------------
	//	PORTD, PORTC y PB5 como salida 
	LDI		R16, 0xFF
	OUT		DDRD, R16					// Setear puerto D como salida (1 -> no recibe)
	OUT		DDRC, R16					// Setear puerto C como salida 
	LDI		R16, 0x00					// Se apagan las salidas
	OUT		PORTD, R16
	OUT		PORTC, R16
	
	// Configurar PB como entradas con pull ups habilitados
	LDI		R16, (0 << PB1) | (0 << PB2) | (0 << PB4)	// Se configura PB1, PB2 y PB4 como entradas y PB5/PB3/PB1 como salida (0010 1010)
	OUT		DDRB, R16
	LDI		R16, (1 << PB0) | (1 << PB3) | (1 << PB5)	// Se configura PB1, PB2 y PB4 como entradas y PB5/PB3/PB1 como salida (0010 1010)
	OUT		DDRB, R16
	LDI		R16, (1 << PB1) | (1 << PB2) | (1 << PB4)
	OUT		PORTB, R16					// Habilitar pull-ups 
	CBI		PORTB, PB0					// Se le carga valor de 0 a PB0 (Salida apagada) 
	CBI		PORTB, PB3					// Se le carga valor de 0 a PB3 (Salida apagada)
	CBI		PORTB, PB5					// Se le carga valor de 0 a PB5 (Salida apagada)

// ------------------------------------Configuraci?n de interrupci?n para botones----------------------------------
	LDI		R16, (1 << PCINT1) | (1 << PCINT2) | (1 << PCINT4)	// Se seleccionan los bits de la m?scara (5)
	STS		PCMSK0, R16								// Bits habilitados (PB0, PB1, PB2, PB3 y PB4) por m?scara		

	LDI		R16, (1 << PCIE0)						// Habilita las interrupciones Pin-Change en PORTB
	STS		PCICR, R16								// "Avisa" al registros PCICR que se habilitan en PORTB
													// Da "permiso" "habilita"

//---------------------------------------------INICIALIZAR DISPLAY-------------------------------------------------
	CALL	INIT_DIS7
	
//---------------------------------------------------REGISTROS-----------------------------------------------------
	CLR		R4										// Registro para valores de Z
	CLR		R5										// Registro para unidades minutos alarma /
	CLR		R3										// Registro para decenas minutos alarma /
	CLR		R12										// Registro para unidades horas alarma /
	CLR		R13										// Registro para decenas horas alarma /
		  //R16 - MULTIUSOS GENERAL 
	LDI		R17, 0x00								// Registro para contador de MODOS /
	LDI		R18, 0xFF								// Registro para guardar estado de botones
	LDI		R19, 0x00								// Registro para contador de unidades /(minutos) display
	LDI		R20, 0x00								// Accion para timer /
	LDI		R21, 0x00								// Registro para boton de accion /
	LDI		R22, 0x00								// Registro para contador de decenas /(minutos)
	LDI		R23, 0x00								// Registro para contador de unidades /(horas)
	LDI		R24, 0x00								// Registro para contador de desbordamientos
	LDI		R25, 0x00								// Registro para contador de decenas / (horas)
	LDI		R26, 0x01								// Registro para contador de unidades /(d?as)
	LDI		R27, 0x00								// Registro para contador de decenas /(d?as)
	LDI		R28, 0x01								// Registro para contador de unidades /(meses)
	LDI		R29, 0x00								// Registro para contador de decenas /(meses)
	SEI												// Se habilitan interrupciones globales


// Loop principal
MAIN:  
	CALL	MULTIPLEX
	// Revisa en qu? modo est? 
	CPI		R17, 0 
	BREQ	CALL_RELOJ_NORMAL
	CPI		R17, 1
	BREQ	CALL_FECHA_NORMAL
	CPI		R17, 2
	BREQ	CALL_CONFIG_MIN_RELOJ
	CPI		R17, 3
	BREQ	CALL_CONFIG_HOR_RELOJ
	CPI		R17, 4
	BREQ	CALL_CONFIG_MES_FECHA
	CPI		R17, 5
	BREQ	CALL_CONFIG_DIA_FECHA
	CPI		R17, 6
	BREQ	CALL_CONFIG_MIN_ALARMA
	CPI		R17, 7
	BREQ	CALL_CONFIG_HOR_ALARMA
	CPI		R17, 8 
	BREQ	CALL_APAGAR_ALARMA
	RJMP	MAIN

// Llama el modo para realizar acci?n
CALL_RELOJ_NORMAL:
	CALL	RELOJ_NORMAL
	RJMP	MAIN	
CALL_FECHA_NORMAL:
	CALL	FECHA_NORMAL
	RJMP	MAIN
CALL_CONFIG_MIN_RELOJ:
	CALL	CONFIG_MIN
	RJMP	MAIN
CALL_CONFIG_HOR_RELOJ:
	CALL	CONFIG_HOR
	RJMP	MAIN
CALL_CONFIG_MES_FECHA:
	CALL	CONFIG_MES
	RJMP	MAIN
CALL_CONFIG_DIA_FECHA:
	CALL	CONFIG_DIA
	RJMP	MAIN
CALL_CONFIG_MIN_ALARMA:
	CALL	CONFIG_MIN_ALARM
	RJMP	MAIN
CALL_CONFIG_HOR_ALARMA:
	CALL	CONFIG_HOR_ALARM
	RJMP	MAIN
CALL_APAGAR_ALARMA:
	CALL	ALARM_OFF
	RJMP	MAIN

// ---------------------------------------------- Subrutina de multiplexaci?n -----------------------------------
MULTIPLEX:
	CPI		R17, 0				// Modo reloj normal
	BREQ	MULTIPLEX_HORA		
	CPI		R17, 1				// Modo fecha normal
	BREQ	MULTIPLEX_FECHA
	CPI		R17, 2				// Modo config minutos
	BREQ	MULTIPLEX_HORA
	CPI		R17, 3				// Modo config horas
	BREQ	MULTIPLEX_HORA
	CPI		R17, 4				// Modo config mes
	BREQ	MULTIPLEX_FECHA
	CPI		R17, 5				// Modo config dias
	BREQ	MULTIPLEX_FECHA
	CPI		R17, 6				// Modo config min alarma
	BREQ	MULTIPLEX_ALARMA
	CPI		R17, 7				// Modo config horas alarma
	BREQ	MULTIPLEX_ALARMA
	CPI		R17, 8				// Modo apagar alarma
	BREQ	MULTIPLEX_ALARMA_OFF
	RET
MULTIPLEX_HORA: 
	// Se multiplexan displays
	MOV		R16, R24				// Se copia el valor de R24 (del timer0) 
	ANDI	R16, 0b00000011			// Se realiza un ANDI, con el prop?sito de multiplexar displays
	CPI		R16, 0 
	BREQ	MOSTRAR_UNI_MIN
	CPI		R16, 1
	BREQ	MOSTRAR_DEC_MIN
	CPI		R16, 2
	BREQ	MOSTRAR_UNI_HOR
	CPI		R16, 3
	BREQ	MOSTRAR_DEC_HOR
	RET
MULTIPLEX_FECHA:
	MOV		R16, R24				// Se copia el valor de R24 (del timer0)
	ANDI	R16, 0b00000011			// Se realiza un ANDI, con el prop?sito de multiplexar displays
	CPI		R16, 0 
	BREQ	MOSTRAR_UNIDAD_MES
	CPI		R16, 1
	BREQ	MOSTRAR_DECENA_MES
	CPI		R16, 2
	BREQ	MOSTRAR_UNIDAD_DIA
	CPI		R16, 3
	BREQ	MOSTRAR_DECENA_DIA
	RET
MULTIPLEX_ALARMA:
	MOV		R16, R24				// Se copia el valor de R24 (del timer0)
	ANDI	R16, 0b00000011			// Se realiza un ANDI, con el prop?sito de multiplexar displays
	CPI		R16, 0 
	BREQ	MOSTRAR_UNIDAD_MIN_AL
	CPI		R16, 1
	BREQ	MOSTRAR_DECENA_MIN_AL
	CPI		R16, 2
	BREQ	MOSTRAR_UNIDAD_HOR_AL
	CPI		R16, 3
	BREQ	MOSTRAR_DECENA_HOR_AL
	RET
MULTIPLEX_ALARMA_OFF:
	RJMP	MULTI_AL_OFF

// ---------------------------------------- Sub-rutinas para multiplexaci?n de displays -----------------------------------
MOSTRAR_UNI_MIN:
	CBI		PORTC, PC1				// Se deshabilita transistor para PC1
	CBI		PORTC, PC2				// Se deshabilita transistor para PC2
	CBI		PORTC, PC3				// Se deshabilita transistor para PC3
	CBI		PORTC, PC0				// Habilitar transistor 1 - Unidades minutos
	// Mostrar unidades de minutos
	LDI		ZL, LOW(TABLITA<<1)
	LDI		ZH, HIGH(TABLITA<<1)
	ADD		ZL, R19					// Cargar el valor del contador de unidades a z
	LPM		R4, Z					// Guardar el valor de Z
	CBI		PORTC, PC1				// Se deshabilita transistor para PC1
	CBI		PORTC, PC2				// Se deshabilita transistor para PC2
	CBI		PORTC, PC3				// Se deshabilita transistor para PC3
	SBI		PORTC, PC0				// Habilitar transistor 1 - Unidades minutos
	OUT		PORTD, R4
	RET
MOSTRAR_DEC_MIN: 
	// Mostrar decenas de minutos
	LDI		ZL, LOW(TABLITA<<1)
	LDI		ZH, HIGH(TABLITA<<1)
	ADD		ZL, R22					// Cargar el valor del contador de unidades a z
	LPM		R4, Z					// Guardar el valor de Z
	CBI		PORTC, PC0				// Se deshabilita transistor para PC0
	CBI		PORTC, PC2				// Se deshabilita transistor para PC2
	CBI		PORTC, PC3				// Se deshabilita transistor para PC3
	SBI		PORTC, PC1				// Habilitar transistor 2 - Decenas minutos
	OUT		PORTD, R4
	RET

MOSTRAR_UNIDAD_MES:
	RJMP	MOSTRAR_UNI_MES
MOSTRAR_DECENA_MES:
	RJMP	MOSTRAR_DEC_MES
MOSTRAR_UNIDAD_DIA:
	RJMP	MOSTRAR_UNI_DIA
MOSTRAR_DECENA_DIA:
	RJMP	MOSTRAR_DEC_DIA

MOSTRAR_UNI_HOR: 
	// Mostrar decenas de horas
	LDI		ZL, LOW(TABLITA<<1)
	LDI		ZH, HIGH(TABLITA<<1)
	ADD		ZL, R23					// Cargar el valor del contador de unidades a z
	LPM		R4, Z					// Guardar el valor de Z
	CBI		PORTC, PC0				// Se deshabilita transistor para PC0
	CBI		PORTC, PC1				// Se deshabilita transistor para PC1
	CBI		PORTC, PC3				// Se deshabilita transistor para PC3
	SBI		PORTC, PC2				// Habilitar transistor 3 - Unidades horas
	OUT		PORTD, R4
	RET
MOSTRAR_DEC_HOR:  
	// Mostrar decenas de horas
	LDI		ZL, LOW(TABLITA<<1)
	LDI		ZH, HIGH(TABLITA<<1)
	ADD		ZL, R25					// Cargar el valor del contador de unidades a z
	LPM		R4, Z					// Guardar el valor de Z
	CBI		PORTC, PC0				// Se deshabilita transistor para PC0
	CBI		PORTC, PC1				// Se deshabilita transistor para PC1
	CBI		PORTC, PC2				// Se deshabilita transistor para PC2
	SBI		PORTC, PC3				// Habilitar transistor 4 - Decenas horas
	OUT		PORTD, R4
	RET

MOSTRAR_UNIDAD_MIN_AL:
	RJMP	MOSTRAR_UNI_MIN_AL
MOSTRAR_DECENA_MIN_AL:
	RJMP	MOSTRAR_DEC_MIN_AL
MOSTRAR_UNIDAD_HOR_AL:
	RJMP	MOSTRAR_UNI_HOR_AL
MOSTRAR_DECENA_HOR_AL:
	RJMP	MOSTRAR_DEC_HOR_AL	

// Multiplexaci?n de fecha
MOSTRAR_UNI_MES:
	// Mostrar unidades de minutos
	LDI		ZL, LOW(TABLITA<<1)
	LDI		ZH, HIGH(TABLITA<<1)
	ADD		ZL, R28					// Cargar el valor del contador de unidades a z
	LPM		R4, Z					// Guardar el valor de Z
	CBI		PORTC, PC1				// Se deshabilita transistor para PC1
	CBI		PORTC, PC2				// Se deshabilita transistor para PC2
	CBI		PORTC, PC3				// Se deshabilita transistor para PC3
	SBI		PORTC, PC0				// Habilitar transistor 1 - Unidades minutos
	OUT		PORTD, R4
	RET
MOSTRAR_DEC_MES: 
	// Mostrar decenas de minutos
	LDI		ZL, LOW(TABLITA<<1)
	LDI		ZH, HIGH(TABLITA<<1)
	ADD		ZL, R29					// Cargar el valor del contador de unidades a z
	LPM		R4, Z					// Guardar el valor de Z
	CBI		PORTC, PC0				// Se deshabilita transistor para PC0
	CBI		PORTC, PC2				// Se deshabilita transistor para PC2
	CBI		PORTC, PC3				// Se deshabilita transistor para PC3
	SBI		PORTC, PC1				// Habilitar transistor 2 - Decenas minutos
	OUT		PORTD, R4
	RET
MOSTRAR_UNI_DIA: 
	// Mostrar decenas de horas
	LDI		ZL, LOW(TABLITA<<1)
	LDI		ZH, HIGH(TABLITA<<1)
	ADD		ZL, R26					// Cargar el valor del contador de unidades a z
	LPM		R4, Z					// Guardar el valor de Z
	CBI		PORTC, PC0				// Se deshabilita transistor para PC0
	CBI		PORTC, PC1				// Se deshabilita transistor para PC1
	CBI		PORTC, PC3				// Se deshabilita transistor para PC3
	SBI		PORTC, PC2				// Habilitar transistor 3 - Unidades horas
	OUT		PORTD, R4
	RET
MOSTRAR_DEC_DIA:  
	// Mostrar decenas de horas
	LDI		ZL, LOW(TABLITA<<1)
	LDI		ZH, HIGH(TABLITA<<1)
	ADD		ZL, R27					// Cargar el valor del contador de unidades a z
	LPM		R4, Z					// Guardar el valor de Z
	CBI		PORTC, PC0				// Se deshabilita transistor para PC0
	CBI		PORTC, PC1				// Se deshabilita transistor para PC1
	CBI		PORTC, PC2				// Se deshabilita transistor para PC2
	SBI		PORTC, PC3				// Habilitar transistor 4 - Decenas horas
	OUT		PORTD, R4
	RET

// Multiplexaci?n para alarma
MOSTRAR_UNI_MIN_AL:
	// Mostrar unidades de minutos
	LDI		ZL, LOW(TABLITA<<1)
	LDI		ZH, HIGH(TABLITA<<1)
	ADD		ZL, R5					// Cargar el valor del contador de unidades a z
	LPM		R4, Z					// Guardar el valor de Z
	CBI		PORTC, PC1				// Se deshabilita transistor para PC1
	CBI		PORTC, PC2				// Se deshabilita transistor para PC2
	CBI		PORTC, PC3				// Se deshabilita transistor para PC3
	SBI		PORTC, PC0				// Habilitar transistor 1 - Unidades minutos
	OUT		PORTD, R4
	RET
MOSTRAR_DEC_MIN_AL: 
	// Mostrar decenas de minutos
	LDI		ZL, LOW(TABLITA<<1)
	LDI		ZH, HIGH(TABLITA<<1)
	ADD		ZL, R3					// Cargar el valor del contador de unidades a z
	LPM		R4, Z					// Guardar el valor de Z
	CBI		PORTC, PC0				// Se deshabilita transistor para PC0
	CBI		PORTC, PC2				// Se deshabilita transistor para PC2
	CBI		PORTC, PC3				// Se deshabilita transistor para PC3
	SBI		PORTC, PC1				// Habilitar transistor 2 - Decenas minutos
	OUT		PORTD, R4
	RET
MOSTRAR_UNI_HOR_AL: 
	// Mostrar decenas de horas
	LDI		ZL, LOW(TABLITA<<1)
	LDI		ZH, HIGH(TABLITA<<1)
	ADD		ZL, R12					// Cargar el valor del contador de unidades a z
	LPM		R4, Z					// Guardar el valor de Z
	CBI		PORTC, PC0				// Se deshabilita transistor para PC0
	CBI		PORTC, PC1				// Se deshabilita transistor para PC1
	CBI		PORTC, PC3				// Se deshabilita transistor para PC3
	SBI		PORTC, PC2				// Habilitar transistor 3 - Unidades horas
	OUT		PORTD, R4
	RET
MOSTRAR_DEC_HOR_AL:  
	// Mostrar decenas de horas
	LDI		ZL, LOW(TABLITA<<1)
	LDI		ZH, HIGH(TABLITA<<1)
	ADD		ZL, R13					// Cargar el valor del contador de unidades a z
	LPM		R4, Z					// Guardar el valor de Z
	CBI		PORTC, PC0				// Se deshabilita transistor para PC0
	CBI		PORTC, PC1				// Se deshabilita transistor para PC1
	CBI		PORTC, PC2				// Se deshabilita transistor para PC2
	SBI		PORTC, PC3				// Habilitar transistor 4 - Decenas horas
	OUT		PORTD, R4
	RET

// Multiplexaci?n para modo de apagar alarma
MULTI_AL_OFF:
	MOV		R16, R24				// Se copia el valor de R24 (del timer0)
	ANDI	R16, 0b00000011			// Se realiza un ANDI, con el prop?sito de multiplexar displays
	CPI		R16, 0 
	BREQ	MOSTRAR_UNI_MIN_AL_OFF
	CPI		R16, 1
	BREQ	MOSTRAR_DEC_MIN_AL_OFF
	CPI		R16, 2
	BREQ	MOSTRAR_UNI_HOR_AL_OFF
	CPI		R16, 3
	BREQ	MOSTRAR_DEC_HOR_AL_OFF
	RET

MOSTRAR_UNI_MIN_AL_OFF:
	// Mostrar unidades de minutos
	CBI		PORTC, PC1				// Se deshabilita transistor para PC1
	CBI		PORTC, PC2				// Se deshabilita transistor para PC2
	CBI		PORTC, PC3				// Se deshabilita transistor para PC3
	SBI		PORTC, PC0				// Habilitar transistor 1 - Unidades minutos
	OUT		PORTD, R8
	RET
MOSTRAR_DEC_MIN_AL_OFF: 
	// Mostrar decenas de minutos
	CBI		PORTC, PC0				// Se deshabilita transistor para PC0
	CBI		PORTC, PC2				// Se deshabilita transistor para PC2
	CBI		PORTC, PC3				// Se deshabilita transistor para PC3
	SBI		PORTC, PC1				// Habilitar transistor 2 - Decenas minutos
	OUT		PORTD, R6
	RET
MOSTRAR_UNI_HOR_AL_OFF: 
	// Mostrar decenas de horas
	CBI		PORTC, PC0				// Se deshabilita transistor para PC0
	CBI		PORTC, PC1				// Se deshabilita transistor para PC1
	CBI		PORTC, PC3				// Se deshabilita transistor para PC3
	SBI		PORTC, PC2				// Habilitar transistor 3 - Unidades horas
	OUT		PORTD, R8
	RET
MOSTRAR_DEC_HOR_AL_OFF:  
	// Mostrar decenas de horas
	CBI		PORTC, PC0				// Se deshabilita transistor para PC0
	CBI		PORTC, PC1				// Se deshabilita transistor para PC1
	CBI		PORTC, PC2				// Se deshabilita transistor para PC2
	SBI		PORTC, PC3				// Habilitar transistor 4 - Decenas horas
	OUT		PORTD, R6
	RET

// -------------------------------------------------- MODOS --------------------------------------------------------
RELOJ_NORMAL: 
	// El modo reloj normal, ?nicamente quiero que sume en reloj normal
	CBI		PORTC, PC4
	CBI		PORTC, PC5
	CBI		PORTB, PB3
	CPI		R20, 0x01				// Se compara bandera de activaci?n
	BRNE	NO_ES_EL_MODO			// Si no ha habido interrupci?n, sale
	LDI		R20, 0x00
	RJMP	CONTADOR				// Si hubo interrupci?n, va a la rutina para modificar el tiempo
	RET

FECHA_NORMAL: 
	SBI		PORTC, PC4
	CBI		PORTC, PC5
	CBI		PORTB, PB3
	CPI		R20, 0x01				// Se compara bandera de activaci?n
	BRNE	NO_ES_EL_MODO
	LDI		R20, 0x00				// Si hubo interrupci?n, va a la rutina para modificar el tiempo
	RJMP	CONTADOR
	RET
NO_ES_EL_MODO: 
	RET

CONFIG_MIN: 
	CBI		PORTC, PC4
	SBI		PORTC, PC5
	CBI		PORTB, PB3
	SBI		PORTB, PB0				// No se permite toggle en leds cada 500ms
	CPI		ACCION, 0x02			// Se revisa bandera de activaci?n
	BREQ	INC_MIN					// Dependiendo del valor de la bandera inc o dec
	CPI		ACCION, 0x03
	BREQ	DEC_MIN
	RET

CONFIG_HOR: 
	CBI		PORTC, PC4
	CBI		PORTC, PC5
	SBI		PORTB, PB3
	SBI		PORTB, PB0				// No se permite toggle en leds cada 500ms
	CPI		ACCION, 0x02			// Se revisa bandera de activaci?n
	BREQ	INC_HOR					// Dependiendo del valor de la bandera inc o dec
	CPI		ACCION, 0x03
	BREQ	DEC_HOR
	RET

CONFIG_MES:
	SBI		PORTC, PC4
	CBI		PORTC, PC5
	SBI		PORTB, PB3
	SBI		PORTB, PB0				// No se permite toggle en leds cada 500ms
	CPI		ACCION, 0x02			// Se revisa bandera de activaci?n
	BREQ	INC_MES					// Dependiendo del valor de la bandera inc o dec
	CPI		ACCION, 0x03
	BREQ	DEC_MES
	RET

CONFIG_DIA:
	SBI		PORTC, PC4
	SBI		PORTC, PC5
	CBI		PORTB, PB3
	SBI		PORTB, PB0				// No se permite toggle en leds cada 500ms
	CPI		ACCION, 0x02			// Se revisa bandera de activaci?n
	BREQ	INC_DIA					// Dependiendo del valor de la bandera inc o dec
	CPI		ACCION, 0x03
	BREQ	DEC_DIA
	RET

CONFIG_MIN_ALARM:
	CBI		PORTC, PC4
	SBI		PORTC, PC5
	SBI		PORTB, PB3
	CPI		ACCION, 0x02			// Se revisa bandera de activaci?n
	BREQ	INC_MIN_ALARM			// Dependiendo del valor de la bandera inc o dec
	CPI		ACCION, 0x03
	BREQ	DEC_MIN_ALARM
	RET

CONFIG_HOR_ALARM:
	SBI		PORTC, PC4
	SBI		PORTC, PC5
	SBI		PORTB, PB3
	CPI		ACCION, 0x02			// Se revisa bandera de activaci?n
	BREQ	INC_HOR_ALARM			// Dependiendo del valor de la bandera inc o dec
	CPI		ACCION, 0x03
	BREQ	DEC_HOR_ALARM
	RET

ALARM_OFF:
	CALL	SHOW_WAKE_UP
	CALL	TURN_ME_OFF
	RET

// -----------------------------------Subrutinas para ejecutar modos----------------------------------------------------
INC_MIN: 
	CALL	INC_DISP1
	LDI		ACCION, 0x00
	RET
DEC_MIN: 
	CALL	DEC_DISP1
	LDI		ACCION, 0x00
	RET
INC_HOR: 
	CALL	INC_DISP2
	LDI		ACCION, 0x00
	RET
DEC_HOR: 
	CALL	DEC_DISP2
	LDI		ACCION, 0x00
	RET

INC_MES: 
	CALL	INC_DISP_MES
	LDI		ACCION, 0x00
	RET
DEC_MES: 
	CALL	DEC_DISP_MES
	LDI		ACCION, 0x00
	RET
INC_DIA: 
	CALL	INC_DISP_DIA
	LDI		ACCION, 0x00
	RET
DEC_DIA: 
	CALL	DEC_DISP_DIA
	LDI		ACCION, 0x00
	RET

INC_MIN_ALARM:
	CALL	INC_DISP_MINAL
	LDI		ACCION, 0x00
	RET
DEC_MIN_ALARM:
	CALL	DEC_DISP_MINAL
	LDI		ACCION, 0x00
	RET
INC_HOR_ALARM:
	CALL	INC_DISP_HORAL
	LDI		ACCION, 0x00
	RET
DEC_HOR_ALARM:
	CALL	DEC_DISP_HORAL
	LDI		ACCION, 0x00
	RET

// --------------------------------------------------- Sub rutina para alarma ------------------------------------------
TAL_VEZ_WAKE_UP:
	// Se compara la hora de la alarma con la actual
	CP		R5, R19					// Comparamos unidades min
	BREQ	CONFIRMAR_DECENAS
	RET 

CONFIRMAR_DECENAS:
	CP		R3, R22					// Comparamos decenas min
	BREQ	CONFIRMAR_UNI_HRS
	RET

CONFIRMAR_UNI_HRS: 
	CP		R12, R23				// Comparamos unidades hrs
	BREQ	CONFIRMAR_DEC_HRS	
	RET

CONFIRMAR_DEC_HRS: 
	CP		R13, R25				// Comparamos decenas hrs
	BREQ	WAKE_UP
	
WAKE_UP: 
	SBI		PINB, PB5				// Se enciende la alarma
	RET

SHOW_WAKE_UP: 
	LDI		R16, 0x3E				// Valor para U
	MOV		R6, R16
	LDI		R16, 0x67				// Valor para P
	MOV		R8, R16					// Se mostrar? UP en modo apagar alarma
	RET
// --------------------------------------------------------- Apagar alarma ------------------------------------------------
TURN_ME_OFF: 
	SBIC	PINB, PB5				// Si est? apagada no hace nada
	SBI		PINB, PB5				// Si est? encendida la apaga
	RET	

// ------------------------------------------------- Subrutina para incrementar minutos ------------------------------------
INC_DISP1: 		
	INC		R19						// Incrementa el valor
	CPI		R19, 0x0A				// Compara el valor del contador 
    BREQ	OVER_DECENAS			// Si al comparar no es igual, salta a mostrarlo
	LPM		R4, Z
	RET					

OVER_DECENAS:
    LDI		R19, 0x00				// Resetea el contador de unidades a 0
	INC		R22						// Incrementamos el contador de decenas de minutos
	CPI		R22, 0x06				// Comparamos si ya es 6
	BREQ	RESETEO_HORA			// Si no es 6, sigue para actualizar
	RET

RESETEO_HORA:
    LDI		R19, 0x00				// Resetea el contador a 0
	LDI		R22, 0x00
	RET

// ------------------------------------------------ Subrutina para decrementar minutos --------------------------------------
DEC_DISP1: 
	DEC		R19						// R19 decrementar?
	CPI		R19, 0xFF				// Si el contador llega a 0, reiniciar el contador
	BREQ	RESET_MINUTOS			// Si es igual a 0 no hace nada y vuelve a main
	RET					// Regresa a main si ya decremento

RESET_MINUTOS: 
	LDI		R19, 0x09
	DEC		R22
	CPI		R22, 0xFF
	BREQ	RESET_DECENAS
	RET

RESET_DECENAS:
	LDI		R22, 0x05
	RET
