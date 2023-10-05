#include <stdio.h>
#include "xil_printf.h"
#include "xil_types.h"
#include "xparameters.h"
#include "xaxidma.h"

#define FFT_SIZE 4096

#define DMA_DEV_ID XPAR_AXI_DMA_0_DEVICE_ID
#define DMA_TRANSFER_SIZE FFT_SIZE*2	//in MM2S and S2MM we send 2*4096 (re and im parts) 32 bit words


//static XAxiDma dma_driver;	//DMA driver instance
//static XAxiDma_Config *dma_cfg;

int main()
{
	XAxiDma dma_driver;	//DMA driver instance
	XAxiDma_Config *dma_cfg;

	s32 status;

	u32 *data_mm2s = (u32 *)malloc(DMA_TRANSFER_SIZE * sizeof(u32));

	if (data_mm2s == NULL)
	{
	     // Check if malloc failed to allocate memory
	     printf("Memory allocation failed!\n");
	     return XST_FAILURE;  // Return an error code
	 }

	u32 *data_s2mm = (u32 *)malloc(DMA_TRANSFER_SIZE * sizeof(u32));

	if (data_s2mm == NULL)
	{
		// Check if malloc failed to allocate memory
		printf("Memory allocation failed!\n");
		return XST_FAILURE;  // Return an error code
	}

	Xil_DCacheDisable();

	print("\nDEBUG: main started!\n");

	//init DMA driver
	dma_cfg = XAxiDma_LookupConfig(DMA_DEV_ID);
	status = XAxiDma_CfgInitialize(&dma_driver, dma_cfg);

	if(dma_cfg == NULL)
	{
		print("Fatal error when setting up DMA config!\n");
		return XST_FAILURE;
	}

	if(status != XST_SUCCESS)
	{
		print("Fatal error when initializing DMA!\n");
		return XST_FAILURE;
	}

	//initialize dummy data (pulse at origin) for PL transfer
	for(int i = 0; i < FFT_SIZE; i++)
	{
		data_mm2s[2*i] = 0;
		data_mm2s[2*i+1] = 0;
	}
	data_mm2s[0] = 2047;

	//schedule data move operation to PL
	status = XAxiDma_SimpleTransfer(&dma_driver, data_mm2s, DMA_TRANSFER_SIZE*4, XAXIDMA_DMA_TO_DEVICE);
	if(status != XST_SUCCESS)
	{
		print("Fatal error when scheduling PS->PL transfer!\n");
		return XST_FAILURE;
	}

	print("PS->PL transfer started, waiting for transfer finish!\n");

	//wait for some time
	while(XAxiDma_Busy(&dma_driver, XAXIDMA_DMA_TO_DEVICE))
	{
		print("Waiting for another 50us!\n");
		usleep(50);
	}

	print("PS->PL transfer finished!\n");

	//schedule data move operation to PS
	status = XAxiDma_SimpleTransfer(&dma_driver, data_s2mm, DMA_TRANSFER_SIZE*4, XAXIDMA_DEVICE_TO_DMA);
	if(status != XST_SUCCESS)
	{
		print("Fatal error when scheduling PL->PS transfer!\n");
		return XST_FAILURE;
	}

    print("PL->PS transfer started, waiting for transfer finish!\n");

	//wait for some time
	while(XAxiDma_Busy(&dma_driver, XAXIDMA_DEVICE_TO_DMA))
	{
		print("Waiting for another 50us!\n");
		usleep(50);
	}

	print("PL->PS transfer finished!\n");

	//print the received output
	for(int i = 0; i < FFT_SIZE; i++)
	{
		xil_printf("@ addr: %d FFT: %d + j*%d\n", i, data_s2mm[2*i], data_s2mm[2*i+1]);
	}

	free(data_s2mm);
	free(data_mm2s);

	return XST_SUCCESS;
}
