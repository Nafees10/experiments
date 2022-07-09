#include <chrono>
#include <iostream>
#include <stdlib.h>
#include <time.h>

#define ulong unsigned long long
#define ushort unsigned short

#define SIZE 1000000

void radixSort(ulong *input, ulong size, ulong *output){
	const ushort end = sizeof(ulong) * 8;
	ulong counts[256];
	for (ulong i = 0; i < end; i += 8){
		for (ulong j = 0; j < 256; j ++)
			counts[j] = 0;
		for (ulong j = 0; j < size; j ++)
			counts[(input[j] >> i) & 255] ++;
		for (ulong j = 1; j < 256; j ++)
			counts[j] += counts[j - 1];
		for (long long j = size - 1; j >= 0; j --)
			output[-- counts[(input[j] >> i) & 255]] = input[j];
		ulong *temp = input;
		input = output;
		output = temp;
	}
}

void fillRand(ulong *arr, ulong size){
	for (ulong i = 0; i < size; i ++)
		arr[i] = rand();
}

ulong* dup(ulong *arr, ulong size){
	ulong *ret = new ulong[size];
	for (int i = 0; i < size; i ++)
		ret[i] = arr[i];
	return ret;
}

int main() {
	unsigned long long n = 0;
	srand(time(0));
	ulong *list = new ulong[SIZE];
	ulong msecs = 0;
	for (int i = 0; i < 100; i ++){
		ulong *sorted = new ulong[SIZE], *input = dup(list, SIZE);
		auto start = std::chrono::high_resolution_clock::now();
		radixSort(input, SIZE, sorted);
		auto finish = std::chrono::high_resolution_clock::now();
		msecs += std::chrono::duration_cast<std::chrono::milliseconds>(finish-start).count();
		delete[] sorted;
		delete[] input;
	}
	std::cout << msecs / 100 << std::endl;
	return 0;
}