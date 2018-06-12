
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include "curand.h"

#include "stdlib.h"
#include "stdio.h"
#include "time.h"
#include <typeinfo>
#include <vector>
#include <algorithm>

#define VERBOSE 0
#define INTEGER_SCALE_FACTOR 100

// Command line argument definitions
#define DEFAULT_NUM_REPEATS 1
#define DEFAULT_NUM_ITERATIONS 1
#define DEFAULT_NUM_ELEMENTS 128
#define DEFAULT_SEED 0
#define DEFAULT_DEVICE 0

#define MIN_ARGS 1
#define MAX_ARGS 6

#define ARG_EXECUTABLE 0
#define ARG_REPEATS 1
#define ARG_ITERATIONS 2
#define ARG_ELEMENTS 3
#define ARG_SEED 4
#define ARG_DEVICE 5

#define MAX 10

// Lazy CUDA Error handling
static void HandleError(const char *file, int line, cudaError_t status = cudaGetLastError()) {
	if (status != cudaSuccess || (status = cudaGetLastError()) != cudaSuccess)
	{
		if (status == cudaErrorUnknown)
		{
			printf("%s(%i) An Unknown CUDA Error Occurred :(\n", file, line);
			exit(1);
		}
		printf("%s(%i) CUDA Error Occurred;\n%s\n", file, line, cudaGetErrorString(status));
		exit(1);
	}
}

#define CUDA_CALL( err ) (HandleError(__FILE__, __LINE__ , err))
#define CUDA_CHECK() (HandleError(__FILE__, __LINE__))


// Kernals

__global__ void setQuantities(
	unsigned int numInputs,
	unsigned int value,
	unsigned int * d_quantity
	){
	unsigned int tid = threadIdx.x + (blockDim.x * blockIdx.x);
	if (tid < numInputs){
		d_quantity[tid] = value;
	}

}


__global__ void atomicInc_kernel(
	unsigned int numIterations, 
	unsigned int numInputs, 
	float * d_probabilities, 
	unsigned int * d_quantity,
	unsigned int * d_count
){
	unsigned int tid = threadIdx.x + (blockDim.x * blockIdx.x);

	if (tid < numInputs){
		if(tid == 0){
			printf("d_quantity[%u] = %u\n", tid, d_quantity[tid]);
		}
		for (int iteration = 0; iteration < numIterations; iteration++){
			// If a value is less than the probabiltiy, apply the min.

			unsigned int old = atomicInc(d_quantity + tid, MAX);

			// If old is MAX, could not increment.
			if(tid == 0){
				printf("tid %u: iter %d, old %u\n", tid, iteration, old );
			}
			if(old < MAX){
				d_count[tid]++;
			}
		}
	}
}

__global__ void atomicDec_kernel(
	unsigned int numIterations, 
	unsigned int numInputs, 
	float * d_probabilities, 
	unsigned int * d_quantity,
	unsigned int * d_count
){
	unsigned int tid = threadIdx.x + (blockDim.x * blockIdx.x);

	if (tid < numInputs){
		if(tid == 0){
			printf("d_quantity[%u] = %u\n", tid, d_quantity[tid]);
		}		
		for (int iteration = 0; iteration < numIterations; iteration++){

			unsigned int old = atomicDec(d_quantity + tid, MAX);

			if(tid == 0){
				printf("tid %u: iter %d, old %u\n", tid, iteration, old );
			}

			// If old is not the maximum value, we have claimed a resource?
			if(old > 0){
				d_count[tid]++;
			}
		}
	}
}

__device__ unsigned int atomicIncCAS(unsigned int * address, unsigned int val){
	unsigned int old = *address;
	unsigned int assumed;
	do {
		assumed = old;
		old = atomicCAS(address, assumed, ((assumed >= val) ? 0 : (assumed+1)));
	} while (assumed != old);
	return old;
}
__device__ unsigned int atomicDecCAS(unsigned int * address, unsigned int val){
	unsigned int old = *address;
	unsigned int assumed;
	do {
		assumed = old;
		old = atomicCAS(address, assumed, (((assumed == 0) | (assumed > val)) ? val : (assumed-1)));
	} while (assumed != old);
	return old;
}

__device__ unsigned int atomicIncNoWrap(unsigned int * address, unsigned int val){
	unsigned int old = *address;
	unsigned int assumed;
	do {
		assumed = old;
		old = atomicCAS(address, assumed, ((assumed >= val) ? assumed : (assumed+1)));
	} while (assumed != old);
	return old;
}

__device__ unsigned int atomicDecNoWrap(unsigned int * address, unsigned int val){
	unsigned int old = *address;
	unsigned int assumed;
	do {
		assumed = old;
		old = atomicCAS(address, assumed, (((assumed == 0) | (assumed > val)) ? assumed : (assumed-1)));
	} while (assumed != old);
	return old;
}


__global__ void atomicIncNoWrap_kernel(
	unsigned int numIterations, 
	unsigned int numInputs, 
	float * d_probabilities, 
	unsigned int * d_quantity,
	unsigned int * d_count
){
	unsigned int tid = threadIdx.x + (blockDim.x * blockIdx.x);

	if (tid < numInputs){
		if(tid == 0){
			printf("d_quantity[%u] = %u\n", tid, d_quantity[tid]);
		}
		for (int iteration = 0; iteration < numIterations; iteration++){
			// If a value is less than the probabiltiy, apply the min.

			unsigned int old = atomicIncNoWrap(d_quantity + tid, MAX);

			// If old is MAX, could not increment.
			if(tid == 0){
				printf("tid %u: iter %d, old %u\n", tid, iteration, old );
			}
			if(old < MAX){
				d_count[tid]++;
			}
		}
	}
}
__global__ void atomicDecNoWrap_kernel(
	unsigned int numIterations, 
	unsigned int numInputs, 
	float * d_probabilities, 
	unsigned int * d_quantity,
	unsigned int * d_count
){
	unsigned int tid = threadIdx.x + (blockDim.x * blockIdx.x);

	if (tid < numInputs){
		if(tid == 0){
			printf("d_quantity[%u] = %u\n", tid, d_quantity[tid]);
		}		
		for (int iteration = 0; iteration < numIterations; iteration++){

			unsigned int old = atomicDecNoWrap(d_quantity + tid, MAX);

			if(tid == 0){
				printf("tid %u: iter %d, old %u\n", tid, iteration, old );
			}

			// If old is not the maximum value, we have claimed a resource?
			if(old > 0){
				d_count[tid]++;
			}
		}
	}
}



void generateInputData(unsigned int numInputs, unsigned long long int seed, float * d_data){
	curandGenerator_t rng = NULL;
	// Create RNG
	curandCreateGenerator(&rng, CURAND_RNG_PSEUDO_DEFAULT); // @todo - curand error check
	// Seed the RNG
	curandSetPseudoRandomGeneratorSeed(rng, seed); // @todo - curand error check
	// Populate device array
	curandGenerateUniform(rng, d_data, numInputs); // @todo - curand error check
	// Cleanup rng
	curandDestroyGenerator(rng); // @todo - curand error check
}

void checkUsage(
	int argc,
	char *argv[],
	unsigned int *numRepeats,
	unsigned int *numIterations,
	unsigned int *numElements,
	unsigned long long int *seed,
	unsigned int *device
	){

		bool helpFlag = false;
		for(int i = 1; i < argc; i++){
			if(strcmp(argv[i], "-h") == 0){
				helpFlag = true;
			} else if(strcmp(argv[i], "--help") == 0){
				helpFlag = true;
			}
		}

		// If an incorrect number of arguments is specified, or -h is any arguement print usage.
		if (argc < MIN_ARGS || argc > MAX_ARGS || helpFlag ){
			const char *usage = "Usage: \n"
				"%s <num_iterations> <num_elements> <seed> <device>\n"
				"\n"
				"    <num_iterations> number of iterations to repeat (default %u)\n"
				"    <num_elements>   number of threads to launch (default %u)\n"
				"    <seed>           seed for RNG (default %llu)\n"
				"    <device>         CUDA Device index (default %d)\n"
				"\n";
			fprintf(stdout, usage, argv[ARG_EXECUTABLE], DEFAULT_NUM_ITERATIONS, DEFAULT_NUM_ELEMENTS, DEFAULT_SEED, DEFAULT_DEVICE);
			fflush(stdout);
			exit(EXIT_FAILURE);
		}

		// If there are more than 1 arg (the filename)5
		if(argc > MIN_ARGS){
			// Extract the number of repeats
			(*numRepeats) = (unsigned int) atoi(argv[ARG_REPEATS]);
			// Extract the number of iterations
			(*numIterations) = (unsigned int) atoi(argv[ARG_ITERATIONS]);
			// Extract the number of elements
			(*numElements) = (unsigned int) atoi(argv[ARG_ELEMENTS]);
			// Extract the seed
			(*seed) = strtoull(argv[ARG_SEED], nullptr, 0);
			if (argc >= ARG_DEVICE + 1){
				// Extract the device
				(*device) = (unsigned int)atoi(argv[ARG_DEVICE]);
			}

		}

		printf("repeats:    %u\n", (*numRepeats));
		printf("iterations: %u\n", (*numIterations));
		printf("threads:    %u\n", (*numElements));
		printf("seed:       %llu\n", (*seed));
		printf("device:     %u\n", (*device));

}

void initDevice(unsigned int device, int *major, int *minor){
	int deviceCount = 0;
	cudaError_t status;
	// Get the number of cuda device.
	status = cudaGetDeviceCount(&deviceCount);
	if (status != cudaSuccess){
		fprintf(stderr, "Cuda Error getting device count.\n");
		fflush(stderr);
		exit(EXIT_FAILURE);
	}
	// If there are any devices
	if (deviceCount > 0){
		// Ensure the device count is not bad.
		if (device >= (unsigned int)deviceCount){
			device = DEFAULT_DEVICE;
			fprintf(stdout, "Warning: device %d is invalid, using device %d\n", device, DEFAULT_DEVICE);
			fflush(stdout);
		}
		// Set the device
		status = cudaSetDevice(device);
		// If there were no errors, proceed.
		if (status == cudaSuccess){
			// Get properties
			cudaDeviceProp props;
			status = cudaGetDeviceProperties(&props, device);
			// If we have properties, print the device.
			if (status == cudaSuccess){
				fprintf(stdout, "Device: %s\n  pci %d bus %d\n  tcc %d\n  SM %d%d\n\n", props.name, props.pciDeviceID, props.pciBusID, props.tccDriver, props.major, props.minor);
				(*major) = props.major;
				(*minor) = props.minor;
			}
		}
		else {
			fprintf(stderr, "Error setting CUDA Device %d.\n", device);
			fflush(stderr);
			exit(EXIT_FAILURE);
		}
	}
	else {
		fprintf(stderr, "Error: No CUDA Device found.\n");
		fflush(stderr);
		exit(EXIT_FAILURE);
	}			
}

template <typename T, bool INC_NOT_DEC, bool NO_WRAP, bool verbose>
int test(
	unsigned int numRepeats, 
	unsigned int numIterations, 
	unsigned int numElements, 
	unsigned long long int seed, 
	float * d_probabilities,
	unsigned int * d_quantity, 
	unsigned int * d_count,
	unsigned int * h_quantity,
	unsigned int * h_count
	){
	unsigned int initialValue = 0;
	
	if (INC_NOT_DEC){
		if(NO_WRAP){
			fprintf(stdout, "atomicIncNoWrap \n");
		} else {
			fprintf(stdout, "atomicInc \n");
		}
		initialValue = 0;
	}
	else {
		if(NO_WRAP){
			fprintf(stdout, "atomicDecNoWrap \n");
		} else {
			fprintf(stdout, "atomicDec \n");
		}
		initialValue = MAX;
	}

	float milliTotal = 0.0f;
	int blockSize = 0;
	int minGridSize = 0;
	int gridSize = 0;
	for (unsigned int repeat = 0; repeat < numRepeats; repeat++){
		// Reset counts
		CUDA_CALL(cudaMemset(d_count, 0, numElements * sizeof(unsigned int)));
		
		// REset quantities

		CUDA_CALL(cudaOccupancyMaxPotentialBlockSize(&minGridSize, &blockSize, setQuantities, 0, numElements));
		gridSize = (numElements + blockSize - 1) / blockSize;
		setQuantities << <gridSize, blockSize >> >(numElements, initialValue, d_quantity);
		CUDA_CHECK();
		

		// Create timing elements
		cudaEvent_t start, stop;
		float milliseconds = 0;
		cudaEventCreate(&start);
		cudaEventCreate(&stop);

		// Get pointer to kernel
		void(*kernel)(unsigned int, unsigned int, float*, unsigned int *, unsigned int *);
		if (INC_NOT_DEC){
			if(NO_WRAP){
				kernel = atomicIncNoWrap_kernel;
			} else {
				kernel = atomicInc_kernel;
			}
		}
		else {
			if(NO_WRAP){
				kernel = atomicDecNoWrap_kernel;
			} else {
				kernel = atomicDec_kernel;
			}
		}

		// Compute launch args and launch kernel
		CUDA_CALL(cudaOccupancyMaxPotentialBlockSize(&minGridSize, &blockSize, kernel, 0, numElements));
		gridSize = (numElements + blockSize - 1) / blockSize;

		// Execute the kernel
		CUDA_CALL(cudaEventRecord(start));
		kernel << <gridSize, blockSize >> >(numIterations, numElements, d_probabilities, d_quantity, d_count);
		CUDA_CHECK();
		cudaDeviceSynchronize();
		CUDA_CALL(cudaEventRecord(stop));

		// Capture timing 
		cudaEventSynchronize(stop);
		cudaEventElapsedTime(&milliseconds, start, stop);

		// Copy out results
		CUDA_CALL(cudaMemcpy(h_count, d_count, numElements * sizeof(unsigned int), cudaMemcpyDeviceToHost));
		CUDA_CALL(cudaMemcpy(h_quantity, d_quantity, numElements * sizeof(unsigned int), cudaMemcpyDeviceToHost));

		// Calculate some stats based on counts.
		// for(unsigned int i = 0; i < numElements; i++){
		for(unsigned int i = 0; i < 1; i++){
			fprintf(stdout, "%u: count %u, quantity %u\n", i, h_count[i], h_quantity[i]);
		}

		if(verbose){
			fprintf(stdout, "  > time %fms value ", milliseconds);
		}

		fflush(stdout);
		milliTotal += milliseconds;
	}

	float milliAverage = milliTotal / numRepeats;


	fprintf(stdout, "  Value: ");
	fprintf(stdout, "  Total  : %fms\n", milliTotal);
	fprintf(stdout, "  Average: %fms\n\n", milliAverage);
	fflush(stdout);


	// return milliTotal < 0.12f ? EXIT_SUCCESS : EXIT_FAILURE;
	return EXIT_SUCCESS;
}

int main(int argc, char *argv[])
{
	unsigned int numRepeats = DEFAULT_NUM_REPEATS;
	unsigned int numIterations = DEFAULT_NUM_ITERATIONS;
	unsigned int numElements = DEFAULT_NUM_ELEMENTS;
	unsigned long long int seed = DEFAULT_SEED;
	unsigned int device = DEFAULT_DEVICE;
	int major = 0;
	int minor = 0;

	checkUsage(argc, argv, &numRepeats, &numIterations, &numElements, &seed, &device);

	// Initialise the device
	initDevice(device, &major, &minor);
 
	// Alloc Rands.
	float *d_probabilities = NULL;
	CUDA_CALL(cudaMalloc((void**)&d_probabilities, numElements * sizeof(float)));

	// Alloc quantity as unsigned int
	unsigned int *h_quantity = (unsigned int *)malloc(numElements * sizeof(unsigned int));
	unsigned int *d_quantity = NULL;
	CUDA_CALL(cudaMalloc((void**)&d_quantity, numElements * sizeof(unsigned int)));
	
	unsigned int *h_count = (unsigned int *)malloc(numElements * sizeof(unsigned int));
	unsigned int *d_count = NULL;
	CUDA_CALL(cudaMalloc((void**)&d_count, numElements * sizeof(unsigned int)));

	// Generate rands
	generateInputData(numElements, seed, d_probabilities);

	std::vector<int> testResults = std::vector<int>();

	// Test float atomicInc
	testResults.push_back(
		test<unsigned int, true, false, VERBOSE>(numRepeats, numIterations, numElements, seed, d_probabilities, d_quantity, d_count, h_quantity, h_count)
	);
	testResults.push_back(
		test<unsigned int, true, true, VERBOSE>(numRepeats, numIterations, numElements, seed, d_probabilities, d_quantity, d_count, h_quantity, h_count)
	);
	// Test float atomicDec
	testResults.push_back(
		test<unsigned int, false, false, VERBOSE>(numRepeats, numIterations, numElements, seed, d_probabilities, d_quantity, d_count, h_quantity, h_count)
	);
	testResults.push_back(
		test<unsigned int, false, true, VERBOSE>(numRepeats, numIterations, numElements, seed, d_probabilities, d_quantity, d_count, h_quantity, h_count)
	);


	size_t numPasses = std::count(testResults.begin(), testResults.end(), 0);
	size_t numTests = testResults.size();

	int retcode = numPasses == numTests ? EXIT_SUCCESS : EXIT_FAILURE;

	printf("testResults: %lu passes of %lu: returnCode %d\n", numPasses, numTests, retcode);



	// Free arrays.
	CUDA_CALL(cudaFree(d_probabilities));
	CUDA_CALL(cudaFree(d_quantity));
	CUDA_CALL(cudaFree(d_count));
	free(h_count);
	free(h_quantity);


	// Reset the device.
	CUDA_CALL(cudaDeviceReset());

    return retcode;
}
