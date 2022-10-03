/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
typedef
struct {
	unsigned int Date;						//0
	unsigned int Global_reset;				//1
	unsigned int START;						//2
	unsigned int STOP;						//3
	unsigned int SEND_BYTE;					//4
	unsigned int STATE;						//5
	unsigned int ERROR;						//6
	unsigned int package;					//7
	unsigned int ACK;						//8
	unsigned int SLAVE_ADDR;				//9
	unsigned int CELL_ADDR;					//10
	unsigned int PACKAGE;					//11
	unsigned int RECEIVE_BYTE;				//12
	unsigned int Done;						//13
} T_I2C;


volatile	T_I2C *I2C1;

int numOfDevices, numOfRequests;
int DevicesAddr[256];
int checkDevice[256];



int data, state, receive_byte, done;

void writeI2C (int devAddr, int cellAddr, int data){
	I2C1 -> CELL_ADDR  = cellAddr;
	I2C1 -> PACKAGE    = data;
	I2C1 -> SLAVE_ADDR = devAddr;

	state = I2C1->STATE;
	while (state != 0)

		{
			state = I2C1->STATE;
		}

	done = I2C1 -> Done;
}

int readI2C (int devAddr, int cellAddr){
	I2C1 -> CELL_ADDR = cellAddr;
	I2C1 -> PACKAGE = data;
	I2C1 -> SLAVE_ADDR = devAddr;
	state = I2C1->STATE;
	while (state != 0)

		{
			state = I2C1->STATE;
		}
	done = I2C1 -> Done;
	receive_byte = I2C1 -> RECEIVE_BYTE;
	return 	receive_byte;
}

int main()
{
    init_platform();

    I2C1 = (T_I2C *)((unsigned int*) XPAR_AXI4LITE_2_TMS_0_BASEADDR + 2097152*0);

	checkDevice[0] = readI2C(97,4);
    cleanup_platform();
    return 0;

}
