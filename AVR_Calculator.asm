;**** Includes ****
.include "tn261def.inc"
.equ 	F_END = 0x3FF 
.equ	TxD = 6 ; PA5
.equ	RxD = 5 ; PA6

;**** Global Register Variables ****

.def tmp = r16
.def temp = r17
.def 	BitCounter = r18
.def	TxByte = r19
.def	RxByte = r20

; Регистры для хранения 4-байтовых чисел A и B
.def	A0 = r21
.def 	A1 = r22
.def	A2 = r23
.def	A3 = r24
.def 	buff = r25
.def	B0 = r26
.def	B1 = r27
.def	B2 = r28
.def	B3 = r29

.org F_END - 32
; Строковые константы
lineEnter:
	.db "Enter ", 0

lineAandB:
	.db "Result of A&B: ", 0

; Задание, Вариант 15
; Операция - И, диапазон - [0; 4 294 967 295] (4 байта, без отрицательных)
; c = Fclk / baudrate = 4*10^6 / 9600 = 416,6 = 417 тактов - время передачи одного бита
; число "полезных" циклов x = 9
; b = (c - x - 14) / 6 = (417 - 9 - 14) / 6 = 65,6 = 66 - коэф. задержки



;**** Таблица векторов прерываний ****
.cseg ;все, что идет после этой директивы, находится в памяти программ
.org 0 ;адрес следующей строки кода указан в данной директиве (0000)


rjmp RESET ;Вектор сброса
reti ;rjmp EXT_INT0 вектор внешнего прерывания
reti ;rjmp PIN_CHANGE ;вектор прерывания по изменению состояния выводов
reti ;rjmp TIM1_CMP1A ;вектор прерывания по совпадению с A таймера T1
reti ;rjmp TIM1_CMP1B ;вектор прерывания по совпадению с B таймера T1
reti ;rjmp TIM1_OVF ;вектор прерывания по переполнению таймера T1
reti ;rjmp TIM0_OVF ;вектор прерывания по переполнению таймера T0
reti ;rjmp USI_STRT ;вектор прерывания по обнаружению условия старта USI
reti ;rjmp USI_OVF ;вектор прерывания по переполнению USI
reti ;rjmp EE_RDY ;вектор прерывания по готовности EEPROM
reti ;rjmp ANA_COMP ;вектор прерывания от аналогового компаратора
reti ;rjmp ADC ;вектор прерывания по завершению преобразования АЦП

; RX в терминале - вход, значит, PA6 - выход (1)
; TX в терминале - выход, значит, PA5 - вход (0)
; 1101 1111 = 0xdf


RESET:  					; инициализация стека
   ldi temp, RAMEND
   out SPL, Temp 				; загружаем RAMEND в указатель стека

   ldi temp, 0xdf		
   out DDRA, temp				; настройка режима работы порта A
   sbi PORTA, TxD     				; разряд 6 PORTA = 1, выход лог. 1
   sbi ACSRA, ACD	     			; выставляем 1 в разряде ACD регистра управления аналоговым компаратором
   rjmp main


UART_delay:
	ldi temp, 66 				; задержка b = 66
UART_delay1: 
	dec temp
	brne UART_delay1
	ret

;-----------------------------------------------------------------------------

putchar:
	ldi BitCounter, 0x0a 			; BitCounter = 9 + sb
	com TxByte 				; инвертируем TxByte
	sec 					; устанавливаем бит переноса C = 1
	
carryIsZero:
	brcs carryIsNotZero 			; если перенос C = 0, переход на carryIsNotZero
	nop					; 1 МЦ, выравниваем число МЦ для блоков putchar и getchar
	nop					; 1 МЦ
	nop					; 1 МЦ
	sbi PORTA, TxD 				; PA6 = 1	

addDelay1:
	rcall UART_delay			; задержка 0.5 бит
	rcall UART_delay			; задержка 0.5 бит
	lsr TxByte 				; сдвиг вправо		
	dec BitCounter			   	; BitCounter--
	brne carryIsZero			; переход по неравенству
	ret

carryIsNotZero:						
	cbi PORTA, TxD 				; PA6 = 0
	rjmp addDelay1

;-----------------------------------------------------------------------------

getchar:
	ldi BitCounter, 0x09 			; BitCounter = 8 + sb
	
RxDIsZero:
	sbic PINA, RxD 				; если PA5 = 0, пропускаем следующую команду
	rjmp RxDIsZero				; зацикливание
	rcall UART_delay			; задержка 0.5 бит
	
addDelay2:
	rcall UART_delay			; задержка 0.5 бит
	rcall UART_delay			; задержка 0.5 бит
	clc 					; очищаем бит переноса C = 0
	sbic PINA, RxD	   			; если PA5 = 0, пропускаем следующую команду
	sec 					; устанавливаем бит переноса C = 1
	dec BitCounter	   			; BitCounter--
	brne shiftRight				; если BitCounter = 0, сдвиг вправо
	nop					; 1 МЦ, выравниваем число МЦ для блоков putchar и getchar
	nop					; 1 МЦ
	nop					; 1 МЦ
	mov TxByte, RxByte 			; возврат RxByte
	rcall putchar				; вызываем putchar
	ret
	
shiftRight:
	ror RxByte				; сдвиг вправо через перенос
	nop					; 1 МЦ
	rjmp addDelay2

;-----------------------------------------------------------------------------

multiplyBy10:
	ldi BitCounter, 0x20			; количество циклов - 32 (число сим-волов)
	ldi temp, 0x0A				; установка temp=10
	clr buff				; очищаем буфер
	clc					; сбрасываем флаг переноса
	ror A3					; сдвиг вправо через перенос A3[7]=C ... C=A3[0]
	ror A2					; сдвиг вправо через перенос A2[7]=C ... C=A2[0]
	ror A1					; сдвиг вправо через перенос A1[7]=C ... C=A1[0]
	ror A0					; сдвиг вправо через перенос A0[7]=C ... C=A0[0]
multiplyLoop:	
	brcc multiplyROR			; если С=0, то переходим на multiplyROR
	add buff, temp				; иначе складываем buff+temp, temp=10
multiplyROR:
	ror buff				; сдвиг вправо через перенос buff[7]=C ... C=buff[0]
	ror A3					; сдвиг вправо через перенос A3[7]=C ... C=A3[0]
	ror A2					; сдвиг вправо через перенос A2[7]=C ... C=A2[0]
	ror A1					; сдвиг вправо через перенос A1[7]=C ... C=A1[0]
	ror A0					; сдвиг вправо через перенос A0[7]=C ... C=A0[0]
	dec BitCounter				; уменьшение счетчика циклов
	brne multiplyLoop       		; если BitCounter!=0, то зацикливаем
	ret					; возврат

;-----------------------------------------------------------------------------

divBy10:
	ldi BitCounter, 0x21			; max количество циклов - 21
	ldi temp, 0x0A				; установка temp=10
	clr buff				; очищаем буфер
	clc					; сбрасываем флаг переноса
divLoop:
	rol A0                    		; сдвиг влево через перенос A0[0]=C ... C=A0[7]
	rol A1					; сдвиг влево через перенос A1[0]=C ... C=A1[7]
	rol A2					; сдвиг влево через перенос A2[0]=C ... C=A2[7]
	rol A3					; сдвиг влево через перенос A3[0]=C ... C=A3[7]
	dec BitCounter				; уменьшение счетчика циклов
	breq divExit				; если BitCounter=0, заканчиваем
	rol buff				; сдвиг влево через перенос buff[0]=C ... C=buff[7]
	sub buff, temp              		; вычитаем buff-temp, temp=10
	brmi divNegativeResult			; если buff<0, то переходим на res-Negative
	sec					; устанавливаем флаг переноса C=1
	rjmp divLoop				; зацикливаем
divNegativeResult:
	add buff, temp				; возвращаем buff+temp
	clc					; сбрасываем флаг переноса
	rjmp divLoop				; возвращаемся в цикл
divExit:
	ret
	 
;-----------------------------------------------------------------------------
	
AandB:
	and A0, B0				; логическое И младших регистров A и B
	and A1, B1
	and A2, B2
	and A3, B3
	ret

;-----------------------------------------------------------------------------	

input:
	clr A0					; инициализация регистров А0...А3
	clr A1
	clr A2
	clr A3
	clt

	rcall getchar				; ввод первого символа
	cpi RxByte, '\r'			; проверяем был ли введен знак новой стро-ки
	breq newLine				; если новая строка - переходим на newLine
	brne addNewDigit			; если не новая строка - добавляем цифру к числу (addNewDigit)
	set
	
inputDigit:
	rcall getchar				; ввод символа     
	cpi RxByte, '\r'			; проверяем был ли введен знак новой стро-ки
	breq newLine				; умножаем tmp_byte3:tmp_byte0 на 10
	rcall multiplyBy10	

addNewDigit:
	subi RxByte, '0'			; преобразуем символ ASCII в цифру
	add A0, RxByte				; складываем младший байт числа с введенной цифрой
	brcc inputDigit				; не было переноса - переходим на inputDigit
	inc A1					; прибавляем к A1 единицу
	brne inputDigit				; переходим ко вводу очередной цифры по неравенству 
	inc A2					; аналогично
	brne inputDigit
	inc A3
	brne inputDigit

newLine:
	ldi TxByte, '\n'
	rcall putchar
	brtc inputFinish			; проверяем знак
	com A3
	com A2
	com A1
	com A0
	inc A0
	brne inputFinish
	inc A1
	brne inputFinish
	inc A2
	brne inputFinish
	inc A3

inputFinish:
	ret

;-----------------------------------------------------------------------------	
	
outputNumber:
	ldi tmp, 0x0A				; записываем в регистр tmp количе-ство разрядов (10)

buffToStack:
	rcall divBy10				; получаем в remain остаток от деле-ния на 10 - то что нам нужно выводить
	mov TxByte, buff			; копируем значение буфера в TxByte
	subi TxByte, 0xD0			; преобразуем цифру в символ ASCII (как бы прибавляем '0' (код 0x30))
	push TxByte				; заносим в стек
	dec tmp					; уменьшаем количество разрядов
	brne buffToStack	  		; если tmp не 0
	clt					; флаг T определяет, была ли уже ненулевая цифра
	ldi tmp, 0x0A

removeZeros:
	pop TxByte
	cpi tmp, 1				; последний символ выводить необходимо обязательно
	breq outputSymbol			; выводим символ, если он последний
	brts outputSymbol			; если флаг T установлен (была ненулевая цифра) - выводим символ
	cpi TxByte, '0'				; сравниваем символ с 0
	breq skipOutput				; если символ ноль - пропускаем вы-вод
	set					; если не ноль - устанавливаем флаг T

outputSymbol:
  	rcall putchar				; выводим символ

skipOutput:
	dec tmp					; уменьшаем количество разрядов
	brne removeZeros			; если число разрядов не 0 продолжаем вы-вод числа
	ldi TxByte,'\r'				; иначе переводим каретку и строку
	rcall putchar
	ldi TxByte,'\n'
	rcall putchar
	ret					; возврат

;-----------------------------------------------------------------------------
	
writeString:
	lpm TxByte, z				; загружаем байт TxByte из памяти программ
	cpi TxByte, '\0'			; сравниваем TxByte с нулем
	breq writeStringFinish			; если TxByte=0, переходим writ-eStringFinish
	rcall putchar				; вызываем подпрограмму putchar
	adiw z, 1				; складываем регистровую пару z с 1
	rjmp writeString			; зацикливаем

writeStringFinish:
	ret					; возврат

;-----------------------------------------------------------------------------

main:
	clr B0					; инициализируем регистры A и B
	clr B1
	clr B2
	clr B3
	clr A0
	clr A1
	clr A2
	clr A3
	
	ldi zl, low(lineEnter << 1)		; загружаем значение строки "Enter " в регистровую пару
	ldi zh, high(lineEnter << 1)
	rcall writeString			; выводим в терминал
	ldi TxByte, 'A'				; выводим подстроку "A: "
	rcall putchar
	ldi TxByte, ':'
	rcall putchar
	ldi TxByte, ' '
	rcall putchar
	
	rcall input				; вводим число А
	mov B0, A0				; копируем его в B
	mov B1, A1
	mov B2, A2
	mov B3, A3
	
	ldi zl, low(lineEnter << 1)		; загружаем значение строки "Enter " в регистровую пару
	ldi zh, high(lineEnter << 1)
	rcall writeString			; выводим в терминал
	ldi TxByte, 'B'				; выводим подстроку "B: "
	rcall putchar
	ldi TxByte, ':'
	rcall putchar
	ldi TxByte, ' '
	rcall putchar
	
	rcall input				; вводим число B
	rcall AandB				; вызываем подпрограмму логического И
	ldi zl, low(lineAandB << 1)		; загружаем подстроку "Result of A&B: "
	ldi zh, high(lineAandB << 1)
	rcall writeString			; выводим в терминал
	
	rcall outputNumber			; вызываем подпрограмму вывода числа
	ldi TxByte, '\r'			; загружаем в TxByte символ перевода ка-ретки
	rcall putchar				; вызываем подпрограмму putchar
	ldi TxByte, '\n'			; загружаем в TxByte символ перевода стро-ки
	rcall putchar				; вызываем подпрограмму putchar
	rjmp main
