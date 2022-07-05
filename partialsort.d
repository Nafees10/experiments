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
	
	/*time = bench((){
		output = mergeSort!"a < b"(list)[X - 1];
	}, runs);
	writefln!"executed mergeSort, %d times:\n%s"(runs, time);*/

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

T weirdAlgo(T)(T[] input, ulong count){
	T[] selection = radixSort(input[0 .. count]);
	input = input[count .. $];
	T cmp = selection[$ - 1];
	T[] temp;
	temp.length = count;
	ulong i;
	foreach (num; input){
		if (num < cmp){
			temp[i ++] = num;
			if (i == temp.length){
				selection = mergeEq(selection, radixSort(temp));
				i = 0;
				cmp = selection[$ - 1];
			}
		}
	}
	if (i)
		selection = merge(selection, radixSort(temp[0 .. i]), count);
	return selection[$ - 1];
}

T[] radixSort(T)(T[] input) if (isNumeric!T){
	static immutable T mask = 255;
	static immutable ubyte end = T.sizeof * 8;
	size_t[256] counts;
	T[] output = new T[input.length];
	for (ubyte i = 0; i < end; i += 8){
		counts[] = 0;
		for (size_t j = 0; j < input.length; j ++)
			++ counts[(input[j] >> i) & mask];
		for (size_t j = 1; j < counts.length; j ++)
			counts[j] += counts[j - 1];
		foreach_reverse (val; input)
			output[-- counts[(val >> i) & mask]] = val;
		swap(input, output);
	}
	.destroy(counts);
	return input;
}

/// Merge 2 sorted arrays of same length. discard second half
T[] mergeEq(alias less = "a < b", T)(T[] A, T[] B){
	T[] R;
	R.length = A.length;
	for (size_t i, a, b; i < R.length; i ++)
		R[i] = A[a] < B[b] ? A[a ++] : B[b ++];
	return R;
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
