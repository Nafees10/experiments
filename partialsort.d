import std.stdio;
import std.random : uniform;
import std.datetime.stopwatch;
import std.conv : to;
import std.algorithm;
import std.functional;
import std.traits;
import std.string;

struct Times{
	ulong min = ulong.max;
	ulong max = 0;
	ulong total = 0;
	ulong avg = 0;
	string toString() const @safe pure{
		return format!"min\tmax\tavg\ttotal\t/msecs\n%d\t%d\t%d\t%d"(min, max, avg, total);
	}
}

Times bench(void delegate(ref StopWatch sw) func, ulong runs = 100_000){
	Times time;
	StopWatch sw = StopWatch(AutoStart.no);
	foreach (i; 0 .. runs){
		func(sw);
		immutable ulong currentTime = sw.peek.total!"msecs" - time.total;
		time.min = currentTime < time.min ? currentTime : time.min;
		time.max = currentTime > time.max ? currentTime : time.max;
		time.total = sw.peek.total!"msecs";
	}
	time.avg = time.total / runs;
	return time;
}

Times bench(void delegate() func, ulong runs = 100_000){
	Times time;
	StopWatch sw = StopWatch(AutoStart.no);
	foreach (i; 0 .. runs){
		sw.start();
		func();
		sw.stop();
		immutable ulong currentTime = sw.peek.total!"msecs" - time.total;
		time.min = currentTime < time.min ? currentTime : time.min;
		time.max = currentTime > time.max ? currentTime : time.max;
		time.total = sw.peek.total!"msecs";
	}
	time.avg = time.total / runs;
	return time;
}

void main(string[] args){
	ulong N = 1_000_000, X = 10_000, runs = 1_000;
	try{
		if (args.length > 1)
			N = args[1].to!ulong;
		if (args.length > 2)
			X = args[2].to!ulong;
		if (args.length > 3)
			runs = args[3].to!ulong;
	}catch (Exception){
		writeln("crapass input. should be:\n[N] [X] [runs]");
		return;
	}

	Times time;
	ulong[] list = getRand(N);
	ulong output;
	// run few times to "warm up" cpu
	foreach (i; 0 .. 10)
		output = weirdAlgo(list, X);
	
	time = bench((){
		output = mergeSort!"a < b"(list)[X - 1];
	}, runs);
	writefln!"executed mergeSort, %d times:\n%s"(runs, time);

	time = bench((ref StopWatch sw){
		ulong[] input = list.dup;
		sw.start();
		output = radixSort(input)[X - 1];
		sw.stop();
	}, runs);
	writefln!"executed radixSort, %d times:\n%s"(runs, time);

	time = bench((){
		output = weirdAlgo(list, X);
	}, runs);
	writefln!"executed weirdAlgo, %d times:\n%s"(runs, time);

	assert (isSorted(radixSort(list)));
}

ulong[] getRand(ulong size){
	ulong[] ret;
	ret.length = size;
	foreach (i; 0 .. size)
		ret[i] = uniform(0, ulong.max);
	return ret;
}

T weirdAlgo(alias less = "a < b", T)(T[] input, ulong count){
	assert(count < input.length);

	// populate selection with first count elements of input, sorted
	T[] selection = mergeSort!less(input[0 .. count]);
	// remove first count elements from input, to optimise
	input = input[count .. $];

	T cmp = selection[$ - 1];
	T[] temp;
	temp.length = count;
	ulong i;
	foreach (num; input){
		if (binaryFun!less(num, cmp)){
			temp[i ++] = num;
			if (i == temp.length){
				//selection = merge!less(selection, mergeSort!less(temp), count);
				selection = merge!less(selection, radixSort(temp), count);
				i = 0;
				cmp = selection[$ - 1];
			}
		}
	}
	if (i){
		selection = merge!less(selection,
						mergeSort!less(temp[0 .. i]),
						count);
	}
	return selection[$ - 1];
}

T[] radixSort(uint N = 8, T)(T[] input) if (isNumeric!T){
	static immutable T mask = (1 << N) - 1;
	static immutable ubyte iterations = (T.sizeof * 8 / N) + (T.sizeof * 8 % N > 0);
	size_t[] counts;
	counts.length = 1 << N;
	T[] output;
	output.length = input.length;
	foreach (iter; 0 .. iterations){
		counts[] = 0;
		immutable ubyte shift = cast(ubyte)(iter * N);
		immutable T remaining = input[0] >> shift;
		bool isSorted = true;
		// construct counts
		foreach (val; input){
			immutable T shifted = val >> shift;
			isSorted = isSorted && shifted == remaining;
			immutable uint digit = shifted & mask;
			counts[digit] ++;
		}
		if (isSorted)
			return input;
		prefixSum(counts);
		// construct output
		foreach_reverse (val; input){
			immutable uint digit = (val >> shift) & mask;
			output[-- counts[digit]] = val;
		}
		// swap arrays
		swap(input, output);
	}
	return input;
}

void prefixSum(T)(T[] arr) if (isNumeric!T){
	foreach (i; 1 .. arr.length)
		arr[i] += arr[i - 1];
}

T[] mergeSort(alias less = "a < b", T)(T[] arr, ulong maxLen = 0){
	if (arr.length == 1){
		return arr;
	}
	if (arr.length == 2){
		if (binaryFun!less(arr[0], arr[1]))
			return arr;
		return [arr[1], arr[0]];
	}
	ulong mid = (arr.length + 1) / 2;
	return merge!less(mergeSort!less(arr[0 .. mid], maxLen),
					mergeSort!less(arr[mid .. $], maxLen),
					maxLen);
}

/// Merge 2 sorted arrays
T[] merge(alias less = "a < b", T)(T[] A, T[] B, ulong maxLen = 0){
	T[] R;
	R.length = maxLen && maxLen < A.length + B.length ? maxLen : A.length + B.length;

	ulong a, b, i;
	if (A.length && B.length){
		while (i < R.length){
			if (binaryFun!less(A[a], B[b])){
				R[i ++] = A[a ++];
				if (a == A.length)
					break;
			}else{
				R[i ++] = B[b ++];
				if (b == B.length)
					break;
			}
		}
	}
	if (a < A.length){
		R[i .. $] = A[a .. a + R.length - i];
	}else if (b < B.length){
		R[i .. $] = B[b .. b + R.length - i];
	}
	return R;
}
