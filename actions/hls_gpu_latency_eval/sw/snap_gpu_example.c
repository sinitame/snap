/*
 * Copyright 2017 International Business Machines
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * SNAP GPU Example
 *
 * Demonstration how to use SNAP with a GPU.
 * Data is generated by the FPGA (vector of size N) and GPU get this data to
 * perform an addition of this vector with itself before sending back the result
 * in the HOST memory.
 * 
 */

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <getopt.h>
#include <malloc.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <assert.h>
#include <inttypes.h>

#include <snap_tools.h>
#include <libsnap.h>
#include <action_create_vector.h>
#include <snap_hls_if.h>

#include <kernel.h>

int verbose_flag = 0;

void memset_volatile(volatile void *s, char c, size_t n)
{
        volatile char *p = s;
            while (n-- > 0) {
                        *p++ = c;
                            }
}

// Function that fills the MMIO registers / data structure 
// these are all data exchanged between the application and the action
static void snap_prepare_gpu_example(struct snap_job *cjob,
				 struct gpu_example_job *mjob,
	             int size,int max_iteration,uint8_t type,
				 void *addr_read,void *addr_write,
                 void *addr_read_flag, void *addr_write_flag)
{
	fprintf(stderr, "  prepare gpu_example job of %ld bytes size\n", sizeof(*mjob));

	assert(sizeof(*mjob) <= SNAP_JOBSIZE);
	memset(mjob, 0, sizeof(*mjob));

    mjob->vector_size = (uint64_t)size;
    mjob->max_iteration = (uint64_t)max_iteration;
	
    // Setting output params : where result will be written in host memory
	snap_addr_set(&mjob->read, addr_read, size*sizeof(uint32_t), type,
		      SNAP_ADDRFLAG_ADDR | SNAP_ADDRFLAG_SRC |
		      SNAP_ADDRFLAG_END);
	
    snap_addr_set(&mjob->write, addr_write, size*sizeof(uint32_t), type,
		      SNAP_ADDRFLAG_ADDR | SNAP_ADDRFLAG_DST |
		      SNAP_ADDRFLAG_END);

    snap_addr_set(&mjob->read_flag, addr_read_flag, 64, type,
		      SNAP_ADDRFLAG_ADDR | SNAP_ADDRFLAG_SRC |
		      SNAP_ADDRFLAG_END);

    snap_addr_set(&mjob->write_flag, addr_write_flag, 64, type,
		      SNAP_ADDRFLAG_ADDR | SNAP_ADDRFLAG_SRC |
		      SNAP_ADDRFLAG_END);
	
    snap_job_set(cjob, mjob, sizeof(*mjob), NULL, 0);
}

/* main program of the application for the hls_helloworld example        */
/* This application will always be run on CPU and will call either       */
/* a software action (CPU executed) or a hardware action (FPGA executed) */
int main(int argc, char *argv[])
{
	// Init of all the default values used 
	int ch = 0;
    int rc =0;
    int card_no = 0;
	struct snap_card *card = NULL;
	struct snap_action *action = NULL;
	char device[128];
	struct snap_job cjob;
	struct gpu_example_job mjob;
	const char *num_iteration = NULL;
	const char *size = NULL;
    int vector_size = 0, max_iteration = 0;
	uint32_t volatile *obuff = NULL, *ibuff = NULL;
    uint8_t volatile *read_flag = NULL, *write_flag=NULL;
	uint32_t type = SNAP_ADDRTYPE_HOST_DRAM;
	uint64_t addr_read = 0x0ull;
	uint64_t addr_write = 0x0ull;
	uint64_t addr_write_flag = 0x0ull;
	uint64_t addr_read_flag= 0x0ull;
    struct timeval etime, stime, begin_time, end_time;
    unsigned long long int lcltime = 0x0ull;
    int exit_code = EXIT_SUCCESS;
	snap_action_flag_t action_irq = (SNAP_ACTION_DONE_IRQ | SNAP_ATTACH_IRQ);

	// collecting the command line arguments
	while (1) {
		int option_index = 0;
		static struct option long_options[] = {
			{ "vector_size",	 required_argument, NULL, 's' },
			{ "max_iteration",	 required_argument, NULL, 'n' },
            { 0, no_argument, NULL, 0 },
		};

		ch = getopt_long(argc, argv,
                                 "s:n:",
				 long_options, &option_index);
		if (ch == -1)
			break;

		switch (ch) {
            case 's':
                size = optarg;
                break;
            case 'n':
                num_iteration = optarg;
                break;
            default:
                break;
        }
	}

    if (size != NULL) {
        vector_size = atoi(size);
    }

    if (num_iteration != NULL) {
        max_iteration = atoi(num_iteration);
    }


    size_t set_size = vector_size*sizeof(uint32_t);

    /* Allocate in host memory a buffer for the vector generated by the FPGA 
     * and a memory area to store the GPU result 
     */

    ibuff = snap_malloc(set_size); //64Bytes aligned malloc
    obuff = snap_malloc(set_size); //64Bytes aligned malloc
    write_flag = snap_malloc(64);
    read_flag = snap_malloc(64);
    
    memset_volatile(ibuff, 0x0, set_size);
    memset_volatile(obuff, 0x0, set_size);
    memset_volatile(write_flag, 0x0, 64);
    memset_volatile(read_flag, 0x0, 64);
    write_flag[0] = 0x0;
    read_flag[0] = 0x0;

    printf("%" PRIu8 "\n",write_flag[0]);
    printf("%" PRIu8 "\n",read_flag[0]);
    //memset_volatile(write_flag,0x1,1);
    //memset_volatile(read_flag,0x0,1);

    // prepare params to be written in MMIO registers for action
    type  = SNAP_ADDRTYPE_HOST_DRAM;
    addr_read = (unsigned long)obuff;
    addr_write = (unsigned long)ibuff;
    addr_write_flag = (unsigned long)write_flag;
    addr_read_flag = (unsigned long)read_flag;

	/* Display the parameters that will be used for the example */
	printf("PARAMETERS:\n"
	       "  vector_size:      %d\n"
	       "  max_iteration:    %d\n"
	       "  addr_read:        %016llx\n"
	       "  addr_write:       %016llx\n"
	       "  addr_read_flag:   %016llx\n"
	       "  addr_write_flag:  %016llx\n",
           vector_size, max_iteration,
           (long long)addr_read,(long long)addr_write,
           (long long)addr_read_flag,(long long)addr_write_flag);

	/***************************************************
 	 *              FPGA related 
 	 ***************************************************/
    snprintf(device, sizeof(device)-1, "/dev/cxl/afu%d.0s", card_no);
	card = snap_card_alloc_dev(device, SNAP_VENDOR_ID_IBM, SNAP_DEVICE_ID_SNAP);
	action = snap_attach_action(card, GPU_LATENCY_EVAL_ACTION_TYPE, action_irq, 60);
	snap_prepare_gpu_example(&cjob, &mjob,vector_size,max_iteration,type,
            (void *)addr_read, (void *)addr_write, 
            (void *)addr_read_flag,(void *)addr_write_flag);


    /////////////////////////////////////////////////////////////////////////
    //                      LAUNCHING THE ACTION
    ////////////////////////////////////////////////////////////////////////
	gettimeofday(&stime, NULL);

    rc =snap_action_sync_execute_job_set_regs(action, &cjob);
	if (rc != 0){
        printf("error while setting registers");
    }
    /* Start Action and wait for finish */
    snap_action_start(action);

	//--- Collect the timestamp AFTER the call of the action
	gettimeofday(&etime, NULL);

    /////////////////////////////////////////////////////////////////////////
    //                      START PROCESSING
    ////////////////////////////////////////////////////////////////////////
    
    //Initialize vector
    for (int k=0; k<vector_size; k++){
        obuff[k] = k;
    }

    printf("*********** Initialization *************\n");
    printf("Writting [%u,%u,%u, ... , %u]\n",obuff[0],obuff[1],obuff[2],obuff[vector_size-1]);
    
    // FPGA can read vector and write buffer
    read_flag[0] = 1;
    write_flag[0] = 1;

    gettimeofday(&begin_time, NULL);
    
    for(int i=0; i<max_iteration;i++){
        
        while(write_flag[0] == 1 || read_flag[0] == 1){} // FPGA is writting or reading -> flags go to 0

        for (int k=0; k<vector_size; k++){
            obuff[k]=ibuff[k]+ibuff[k];
        }
        
        printf("*********** Interation %u/%u *************\n", i+1, max_iteration);
        printf("Received [%u,%u,%u, ... , %u]\n",ibuff[0],ibuff[1],ibuff[2],ibuff[vector_size-1]);
        printf("Writting [%u,%u,%u, ... , %u]\n",obuff[0],obuff[1],obuff[2],obuff[vector_size-1]);
        
        //FPGA can read
        read_flag[0] = 1;

        //FPGA can write
        write_flag[0] = 1;


    }
	
    gettimeofday(&end_time, NULL);
    
    switch(cjob.retc) {
        case SNAP_RETC_SUCCESS:
            fprintf(stdout, "SUCCESS\n");
            break;
        case SNAP_RETC_TIMEOUT:
            fprintf(stdout, "ACTION TIMEOUT\n");
            break;
        case SNAP_RETC_FAILURE:
            fprintf(stdout, "FAILED\n");
            fprintf(stderr, "err: Unexpected RETC=%x!\n", cjob.retc);
            break;
        default:
            break;
    }

	// Display the time of the action call
	fprintf(stdout, "SNAP registers set + action start took %lld usec\n",
		(long long)timediff_usec(&etime, &stime));

	// Display the time of the action excecution
    lcltime = (long long)(timediff_usec(&end_time, &begin_time));
    fprintf(stdout, "SNAP action average processing time for %u iteration is %f usec\n",
                max_iteration, (float)lcltime/(float)(max_iteration));
    
    // Detach action + disallocate the card
	snap_detach_action(action);
	snap_card_free(card);


	__free((void *)obuff);
	__free((void *)ibuff);
	__free((void *)read_flag);
	__free((void *)write_flag);
	exit(exit_code);

}
